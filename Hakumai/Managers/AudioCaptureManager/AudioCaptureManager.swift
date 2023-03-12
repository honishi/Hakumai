//
//  AudioCaptureManager.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2023/03/11.
//  Copyright © 2023 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AudioToolbox
import AVFoundation

private let audioFileName = "hakumai-audio"

final class AudioCaptureManager {
    private var recorder: AudioQueueRecorder?
    private(set) var captures: [Data] = []
    private var timer: Timer?

    init() {}

    deinit {
        stop()
    }
}

extension AudioCaptureManager: AudioCaptureManagerType {
    func start(interval: TimeInterval) {
        guard !isRunning else { return }
        startCapture()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.endCapture {
                self?.startCapture()
            }
        }
    }

    func stop() {
        endCapture {}
        timer?.invalidate()
        timer = nil
    }

    var isRunning: Bool { timer != nil }
    var latestCapture: Data? { captures.last }
}

private extension AudioCaptureManager {
    func startCapture() {
        recorder = AudioQueueRecorder()
        guard let recorder = recorder else { return }
        recorder.prepareFile()
        recorder.prepareQueue()
        recorder.setupBuffer()
        recorder.startRecord()
    }

    func endCapture(completion: @escaping () -> Void) {
        guard let recorder = recorder else {
            completion()
            return
        }
        recorder.stopRecord()

        // Library/Caches
        let directories = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        guard let cacheDirectory = directories.first else {
            completion()
            return
        }

        guard let recordedAiffFileUrl = recorder.audioFileUrl else { return }

        var m4aFileUrl = cacheDirectory.appendingPathComponent(audioFileName)
        m4aFileUrl.appendPathExtension("m4a")

        convert(aiffFileUrl: recordedAiffFileUrl, toM4aFileUrl: m4aFileUrl) { [weak self] in
            guard let self = self,
                  $0 == .completed,
                  let data = try? Data(contentsOf: m4aFileUrl) else {
                completion()
                return
            }
            if self.captures.count > 5 {
                self.captures.removeFirst()
            }
            self.captures.append(data)
            log.debug(self.captures)
            completion()
        }
    }

    func convert(aiffFileUrl: URL, toM4aFileUrl m4aFileUrl: URL, completion: @escaping (AVAssetExportSession.Status) -> Void) {
        try? FileManager.default.removeItem(at: m4aFileUrl)

        let asset = AVURLAsset(url: aiffFileUrl)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            log.error("Failed to create export session")
            return
        }
        exportSession.outputURL = m4aFileUrl
        exportSession.outputFileType = .m4a
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                log.debug("Export completed")
            case .failed, .unknown, .exporting, .waiting, .cancelled:
                log.error("Export failed: \(exportSession.error?.localizedDescription ?? "-")")
            @unknown default:
                log.error("Export failed with unknown status")
            }
            completion(exportSession.status)
        }
    }
}

private extension AudioCaptureManager {}

// Based on https://www.toyship.org/2020/05/04/095135
private class AudioQueueRecorder {
    private(set) var audioFileUrl: URL?

    private var dataFormat: AudioStreamBasicDescription!
    private var audioQueue: AudioQueueRef!
    private var buffers: [AudioQueueBufferRef]
    private var audioFile: AudioFileID!
    private var bufferByteSize: UInt32
    private var currentPacket: Int64
    private var isRunning: Bool

    init() {
        buffers = []
        bufferByteSize = 0
        currentPacket = 0
        isRunning = false
    }

    private var currentAudioDataFormat = AudioStreamBasicDescription(
        mSampleRate: 44100,
        mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: AudioFormatFlags(kLinearPCMFormatFlagIsBigEndian|kLinearPCMFormatFlagIsSignedInteger|kLinearPCMFormatFlagIsPacked),
        mBytesPerPacket: 4,
        mFramesPerPacket: 1,
        mBytesPerFrame: 4,
        mChannelsPerFrame: 2,
        mBitsPerChannel: 16,
        mReserved: 0)

    // swiftlint:disable all
    private let audioQueueInputCallback: AudioQueueInputCallback = { (
        inUserData: UnsafeMutableRawPointer?,
        inAQ: AudioQueueRef,
        inBuffer: UnsafeMutablePointer<AudioQueueBuffer>,
        _: UnsafePointer<AudioTimeStamp>,
        inNumPackets: UInt32,
        inPacketDesc: Optional<UnsafePointer<AudioStreamPacketDescription>>) -> Void in
        // swiftlint:enable all

        guard let userData = inUserData else {
            assert(false, "no user data...")
            return
        }

        let unManagedUserData = Unmanaged<AudioQueueRecorder>.fromOpaque(userData)
        let receivedUserData = unManagedUserData.takeUnretainedValue()

        receivedUserData.writeToFile(
            buffer: inBuffer,
            numberOfPackets: inNumPackets ,
            inPacketDesc: inPacketDesc)

        guard receivedUserData.isRunning else { return }
        AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, nil)
    }

    func startRecord() {
        currentPacket = 0
        isRunning = true
        AudioQueueStart(audioQueue, nil)
    }

    func stopRecord() {
        isRunning = false
        AudioQueueStop(audioQueue, true)
        AudioQueueDispose(audioQueue, true)
        closeFile()
    }
}

private extension AudioQueueRecorder {
    func prepareQueue() {
        var aQueue: AudioQueueRef!

        AudioQueueNewInput(
            &currentAudioDataFormat,
            audioQueueInputCallback,
            unsafeBitCast(self, to: UnsafeMutableRawPointer.self),
            .none,
            CFRunLoopMode.commonModes.rawValue,
            0,
            &aQueue)

        guard let aQueue = aQueue else { return }
        audioQueue = aQueue
    }

    func setupBuffer() {
        // typically 3
        let kNumberBuffers: Int = 3

        // typically 0.5
        bufferByteSize = deriveBufferSize(audioQueue: audioQueue, audioDataFormat: currentAudioDataFormat, seconds: 0.5)

        for i in 0..<kNumberBuffers {
            var newBuffer: AudioQueueBufferRef?
            AudioQueueAllocateBuffer(audioQueue, bufferByteSize, &newBuffer)
            if let newBuffer = newBuffer {
                buffers.append(newBuffer)
            }
            AudioQueueEnqueueBuffer(audioQueue, buffers[i], 0, nil)
        }
    }

    func deriveBufferSize(audioQueue: AudioQueueRef, audioDataFormat: AudioStreamBasicDescription, seconds: Float64) -> UInt32 {
        let maxBufferSize: UInt32 = 0x50000
        var maxPacketSize: UInt32 = audioDataFormat.mBytesPerPacket

        if maxPacketSize == 0 {
            var maxVBRPacketSize = UInt32(MemoryLayout<UInt32>.size)
            AudioQueueGetProperty(audioQueue, kAudioQueueProperty_MaximumOutputPacketSize, &maxPacketSize, &maxVBRPacketSize)
        }

        let numBytesForTime = UInt32(Float64(audioDataFormat.mSampleRate) * Float64(maxPacketSize) * Float64(seconds))
        let outBufferSize = UInt32(numBytesForTime < maxBufferSize ? numBytesForTime : maxBufferSize)

        return outBufferSize
    }
}

private extension AudioQueueRecorder {
    func prepareFile() {
        dataFormat = currentAudioDataFormat

        var aAudioFileID: AudioFileID?

        // Library/Caches
        let directories = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        guard let cacheDirectory = directories.first else { return }

        var audioFileUrl = cacheDirectory.appendingPathComponent(audioFileName)
        audioFileUrl.appendPathExtension("aiff")
        self.audioFileUrl = audioFileUrl
        log.debug(audioFileUrl)

        try? FileManager.default.removeItem(at: audioFileUrl)
        let result = AudioFileCreateWithURL(
            audioFileUrl as CFURL,
            kAudioFileAIFFType,
            &currentAudioDataFormat,
            AudioFileFlags.eraseFile,
            &aAudioFileID)
        log.debug("result: \(result)")
        audioFile = aAudioFileID
    }

    // swiftlint:disable all
    func writeToFile(buffer: UnsafeMutablePointer<AudioQueueBuffer>, numberOfPackets: UInt32, inPacketDesc: Optional<UnsafePointer<AudioStreamPacketDescription>>) {
        // swiftlint:enable all

        guard let audioFile = audioFile else {
            // TODO: Crash here when close main window...
            assert(false, "no audio data...")
            return
        }

        var newNumPackets: UInt32 = numberOfPackets
        if numberOfPackets == 0 && dataFormat.mBytesPerPacket != 0 {
            newNumPackets = buffer.pointee.mAudioDataByteSize / dataFormat.mBytesPerPacket
        }

        let inNumPointer = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
        inNumPointer.initialize(from: &newNumPackets, count: 1)

        let writeResult = AudioFileWritePackets(audioFile,
                                                false,
                                                buffer.pointee.mAudioDataByteSize,
                                                inPacketDesc,
                                                currentPacket,
                                                inNumPointer,
                                                buffer.pointee.mAudioData)
        currentPacket += Int64(numberOfPackets)

        if writeResult != noErr {
            // handle error
        }
    }

    func closeFile() {
        guard let audioFile = audioFile else { return }
        AudioFileClose(audioFile)
    }
}
