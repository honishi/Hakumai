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
    static let shared = AudioCaptureManager()

    private var audioStreamDescription: AudioStreamBasicDescription
    private var audioQueue: AudioQueueRef?
    private var audioQueueBuffers: [AudioQueueBufferRef] = []
    private var audioQueueInputs: [AudioQueueInput] = []
    private var audioFileId: AudioFileID?

    private struct AudioQueueInput {
        let date: Date
        let audioDataByteSize: UInt32
        let audioData: UnsafeMutableRawPointer
        let numberOfPackets: UInt32
        var packetDescription: AudioStreamPacketDescription?
    }

    // swiftlint:disable all
    private let audioQueueInputCallback: AudioQueueInputCallback = { (
        inUserData: UnsafeMutableRawPointer?,
        inAQ: AudioQueueRef,
        inBuffer: UnsafeMutablePointer<AudioQueueBuffer>,
        _: UnsafePointer<AudioTimeStamp>,
        inNumPackets: UInt32,
        inPacketDesc: Optional<UnsafePointer<AudioStreamPacketDescription>>
    ) -> Void in
        // swiftlint:enable all
        guard let userData = inUserData else {
            fatalError("no user data...")
        }
        let unManagedUserData = Unmanaged<AudioCaptureManager>.fromOpaque(userData)
        let receivedUserData = unManagedUserData.takeUnretainedValue()
        receivedUserData.handleAudioQueueInputs(
            buffer: inBuffer,
            numberOfPackets: inNumPackets,
            inPacketDesc: inPacketDesc
        )
    }

    init() {
        audioStreamDescription = AudioStreamBasicDescription(
            mSampleRate: 44100,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: AudioFormatFlags(
                kLinearPCMFormatFlagIsBigEndian |
                    kLinearPCMFormatFlagIsSignedInteger |
                    kLinearPCMFormatFlagIsPacked
            ),
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 16,
            mReserved: 0
        )
    }

    deinit {
        stop()
    }
}

extension AudioCaptureManager: AudioCaptureManagerType {
    func start() {
        setupAudioQueue()
        setupAudioQueueBuffer()
        startAudioQueue()
    }

    func stop() {
        endAudioQueue()
        removeAllAudioQueueInputs()
    }

    func requestLatestCapture(completion: @escaping (Data?) -> Void) {
        _requestLatestCapture(completion: completion)
    }

    var isRunning: Bool { audioQueue != nil }
}

private extension AudioCaptureManager {
    func setupAudioQueue() {
        guard audioQueue == nil else {
            log.debug("audio queue already prepared.")
            return
        }
        var audioQueue: AudioQueueRef!
        let result = AudioQueueNewInput(
            &audioStreamDescription,
            audioQueueInputCallback,
            unsafeBitCast(self, to: UnsafeMutableRawPointer.self),
            .none,
            CFRunLoopMode.commonModes.rawValue,
            0,
            &audioQueue
        )
        log.debug("AudioQueueNewInput: \(result)")
        guard let audioQueue = audioQueue else { return }
        self.audioQueue = audioQueue
    }

    func setupAudioQueueBuffer() {
        guard let audioQueue = audioQueue else { return }
        let kNumberBuffers: Int = 3 // typically 3

        let bufferByteSize = deriveBufferSize(
            audioQueue: audioQueue,
            audioStreamDescription: audioStreamDescription,
            seconds: 0.5    // typically 0.5
        )

        for _ in 0..<kNumberBuffers {
            var buffer: AudioQueueBufferRef?
            let allocateResult = AudioQueueAllocateBuffer(audioQueue, bufferByteSize, &buffer)
            log.debug("AudioQueueAllocateBuffer: \(allocateResult)")
            guard let buffer = buffer else { continue }
            audioQueueBuffers.append(buffer)
            let enqueuResult = AudioQueueEnqueueBuffer(audioQueue, buffer, 0, nil)
            log.debug("AudioQueueEnqueueBuffer: \(enqueuResult)")
        }
    }

    func deriveBufferSize(
        audioQueue: AudioQueueRef,
        audioStreamDescription: AudioStreamBasicDescription,
        seconds: Float64
    ) -> UInt32 {
        let maxBufferSize: UInt32 = 0x50000
        var maxPacketSize: UInt32 = audioStreamDescription.mBytesPerPacket

        if maxPacketSize == 0 {
            var maxVBRPacketSize = UInt32(MemoryLayout<UInt32>.size)
            AudioQueueGetProperty(audioQueue, kAudioQueueProperty_MaximumOutputPacketSize, &maxPacketSize, &maxVBRPacketSize)
        }

        let numBytesForTime = UInt32(Float64(audioStreamDescription.mSampleRate) * Float64(maxPacketSize) * Float64(seconds))
        let outBufferSize = UInt32(numBytesForTime < maxBufferSize ? numBytesForTime : maxBufferSize)

        return outBufferSize
    }

    func startAudioQueue() {
        guard let audioQueue = audioQueue else { return }
        AudioQueueStart(audioQueue, nil)
    }

    func endAudioQueue() {
        guard let audioQueue = audioQueue else { return }
        AudioQueueStop(audioQueue, true)
        AudioQueueDispose(audioQueue, true)
        self.audioQueue = nil
    }

    func _requestLatestCapture(completion: @escaping (Data?) -> Void) {
        log.debug(audioQueueInputs)
        openFile()
        writeToFile()
        closeFile()

        // Library/Caches
        let directories = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        guard let cacheDirectory = directories.first else {
            return
        }
        var m4aFileUrl = cacheDirectory.appendingPathComponent(audioFileName)
        m4aFileUrl.appendPathExtension("m4a")

        convert(aiffFileUrl: audioFileUrl, toM4aFileUrl: m4aFileUrl) {
            guard $0 == .completed,
                  let data = try? Data(contentsOf: m4aFileUrl) else {
                return
            }
            completion(data)
        }
    }
}

private extension AudioCaptureManager {
    // swiftlint:disable all
    func handleAudioQueueInputs(
        buffer: UnsafeMutablePointer<AudioQueueBuffer>,
        numberOfPackets: UInt32,
        inPacketDesc: Optional<UnsafePointer<AudioStreamPacketDescription>>
    ) {
        // swiftlint:enable all
        // log.debug(numberOfPackets)

        let byteSize = buffer.pointee.mAudioDataByteSize
        if let audioData = UnsafeMutableRawPointer(malloc(Int(byteSize))) {
            memcpy(audioData, buffer.pointee.mAudioData, Int(byteSize))
            let input = AudioQueueInput(
                date: Date(),
                audioDataByteSize: byteSize,
                audioData: audioData,
                numberOfPackets: numberOfPackets,
                packetDescription: inPacketDesc?.pointee
            )
            audioQueueInputs.append(input)
        }
        removeOldAudioQueueInputs()

        guard let audioQueue = audioQueue else { return }
        AudioQueueEnqueueBuffer(audioQueue, buffer, 0, nil)
    }

    private func deallocateAudioQueueInput(_ input: AudioQueueInput) {
        input.audioData.deallocate()
    }

    func removeOldAudioQueueInputs() {
        let origin = Date()
        let secondsForKeep: TimeInterval = 30
        let olds = audioQueueInputs.filter { origin.timeIntervalSince($0.date) > secondsForKeep }
        olds.forEach { deallocateAudioQueueInput($0) }
        audioQueueInputs = audioQueueInputs.filter { origin.timeIntervalSince($0.date) <= secondsForKeep }
        log.debug(audioQueueInputs.count)
    }

    func removeAllAudioQueueInputs() {
        audioQueueInputs.forEach { deallocateAudioQueueInput($0) }
        audioQueueInputs.removeAll()
    }
}

private extension AudioCaptureManager {
    var audioFileUrl: URL {
        // Library/Caches
        let directories = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        guard let cacheDirectory = directories.first else {
            fatalError()
        }

        var audioFileUrl = cacheDirectory.appendingPathComponent(audioFileName)
        audioFileUrl.appendPathExtension("aiff")
        log.debug(audioFileUrl)
        return audioFileUrl
    }

    func openFile() {
        guard audioFileId == nil else {
            log.warning("audio file already opened.")
            return
        }

        var audioFileId: AudioFileID?
        let audioFileUrl = self.audioFileUrl
        try? FileManager.default.removeItem(at: audioFileUrl)
        let result = AudioFileCreateWithURL(
            audioFileUrl as CFURL,
            kAudioFileAIFFType,
            &audioStreamDescription,
            AudioFileFlags.eraseFile,
            &audioFileId)
        log.debug("result: \(result)")
        self.audioFileId = audioFileId
    }

    func writeToFile() {
        guard let audioFileId = audioFileId else {
            fatalError("no audio data...")
        }

        var currentPacket: Int64 = 0
        audioQueueInputs.forEach {
            var newNumPackets: UInt32 = $0.numberOfPackets
            if $0.numberOfPackets == 0 && audioStreamDescription.mBytesPerPacket != 0 {
                newNumPackets = $0.audioDataByteSize / audioStreamDescription.mBytesPerPacket
            }

            let inNumPointer = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
            inNumPointer.initialize(from: &newNumPackets, count: 1)

            let writeResult = AudioFileWritePackets(
                audioFileId,
                false,
                $0.audioDataByteSize,
                nil,
                currentPacket,
                inNumPointer,
                $0.audioData
            )
            // log.debug("AudioFileWritePackets: \(writeResult)")
            currentPacket += Int64($0.numberOfPackets)

            if writeResult != noErr {
                // handle error
            }
        }
    }

    func closeFile() {
        guard let audioFileId = audioFileId else { return }
        AudioFileClose(audioFileId)
        self.audioFileId = nil
    }
}

private extension AudioCaptureManager {
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
