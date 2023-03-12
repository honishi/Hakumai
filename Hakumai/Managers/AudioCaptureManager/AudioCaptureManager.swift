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
    private var audioStreamDescription: AudioStreamBasicDescription
    private var audioQueue: AudioQueueRef?
    private var audioQueueBuffers: [AudioQueueBufferRef] = []

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
    }

    func requestLatestCapture(completion: (Data?) -> Void) {
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

    func _requestLatestCapture(completion: (Data?) -> Void) {
        completion(nil)

        /*
         // Library/Caches
         let directories = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
         guard let cacheDirectory = directories.first else {
         return
         }

         guard let recordedAiffFileUrl = recorder.audioFileUrl else { return }

         var m4aFileUrl = cacheDirectory.appendingPathComponent(audioFileName)
         m4aFileUrl.appendPathExtension("m4a")

         convert(aiffFileUrl: recordedAiffFileUrl, toM4aFileUrl: m4aFileUrl) { /* [weak self] */ _ in
         guard let self = self,
         $0 == .completed,
         let data = try? Data(contentsOf: m4aFileUrl) else {
         return
         }
         if self.captures.count > 5 {
         self.captures.removeFirst()
         }
         self.captures.append(data)
         log.debug(self.captures)
         }
         */
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
        log.debug(numberOfPackets)

        guard let audioQueue = audioQueue else { return }
        AudioQueueEnqueueBuffer(audioQueue, buffer, 0, nil)
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

// Based on https://www.toyship.org/2020/05/04/095135
private class AudioQueueRecorder {
    private(set) var isRunning: Bool
    private(set) var audioFileUrl: URL?

    private var dataFormat: AudioStreamBasicDescription!
    private var audioQueue: AudioQueueRef!
    private var buffers: [AudioQueueBufferRef]
    private var audioFile: AudioFileID!
    private var bufferByteSize: UInt32
    private var currentPacket: Int64

    private var audioQueueInputs: [AudioQueueInput] = []
    private var isWritingFile = false

    // swiftlint:disable all
    struct AudioQueueInput {
        let date: Date
        let inUserData: UnsafeMutableRawPointer?
        let inAQ: AudioQueueRef
        let inBuffer: UnsafeMutablePointer<AudioQueueBuffer>
        let inNumPackets: UInt32
        let inPacketDesc: Optional<UnsafePointer<AudioStreamPacketDescription>>
    }
    // swiftlint:enable all

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

        /*
         receivedUserData.appendToAudioQueueInputs(
         buffer: inBuffer,
         numberOfPackets: inNumPackets,
         inPacketDesc: inPacketDesc
         )
         */
    }

    func prepareIfNeeded() {
        guard audioQueue == nil else {
            log.debug("alread prepared.")
            return
        }
        prepareQueue()
        setupBuffer()
    }

    func startRecord() {
        prepareIfNeeded()

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

    func requestLatestFile(completion: @escaping (URL?) -> Void) {
        DispatchQueue.global(qos: .default).async {
            self._requestLatestFile(completion: completion)
        }
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
        let bufferByteSize = deriveBufferSize(
            audioQueue: audioQueue,
            audioDataFormat: currentAudioDataFormat,
            seconds: 0.5
        )

        for _ in 0..<kNumberBuffers {
            var buffer: AudioQueueBufferRef?
            AudioQueueAllocateBuffer(audioQueue, bufferByteSize, &buffer)
            guard let buffer = buffer else { continue }
            buffers.append(buffer)
            AudioQueueEnqueueBuffer(audioQueue, buffer, 0, nil)
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
    func _requestLatestFile(completion: (URL?) -> Void) {
        isWritingFile = true

        openFile()

        /*
         receivedUserData.writeToFile(
         buffer: inBuffer,
         numberOfPackets: inNumPackets,
         inPacketDesc: inPacketDesc
         )
         guard receivedUserData.isRunning else { return }
         AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, nil)
         */
    }

    func openFile() {
        guard audioFile == nil else {
            log.warning("audio file already opened.")
            return
        }

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
    func writeToFile(
        buffer: UnsafeMutablePointer<AudioQueueBuffer>,
        numberOfPackets: UInt32,
        inPacketDesc: Optional<UnsafePointer<AudioStreamPacketDescription>>
    ) {
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
