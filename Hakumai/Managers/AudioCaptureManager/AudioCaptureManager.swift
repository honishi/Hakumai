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

final class AudioCaptureManager {
    private(set) weak var delegate: AudioCaptureManagerDelegate?
    private var recorder: AudioQueueRecorder!

    init() {}
    deinit {}
}

extension AudioCaptureManager: AudioCaptureManagerType {
    func start(_ delegate: AudioCaptureManagerDelegate) {
        self.delegate = delegate
        recorder = AudioQueueRecorder()
        recorder.prepare()
        recorder.prepareQueue()
        recorder.setupBuffer()
        recorder.startRecord()
        // self.delegate = delegate
        // startRecord()
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 10) {
            self.recorder.stopRecord()
            let documentDirectories = FileManager.default.urls(
                for: FileManager.SearchPathDirectory.documentDirectory,
                in: FileManager.SearchPathDomainMask.userDomainMask)
            let docDirectory = (documentDirectories.first)!

            var importFilePathURL = docDirectory.appendingPathComponent("audiotest")
            importFilePathURL.appendPathExtension("aiff")

            var exportFilePathURL = docDirectory.appendingPathComponent("audiotest")
            exportFilePathURL.appendPathExtension("m4a")

            let fileManager = FileManager.default
            try? fileManager.removeItem(at: exportFilePathURL)

            let asset = AVURLAsset(url: importFilePathURL)
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
                print("Failed to create export session")
                return
            }
            exportSession.outputURL = exportFilePathURL
            exportSession.outputFileType = .m4a
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    print("Export completed")
                    guard let data = try? Data(contentsOf: exportFilePathURL) else { return }
                    self.delegate?.audioCaptureManager(self, didCapture: data)
                case .failed, .unknown, .exporting, .waiting, .cancelled:
                    if let error = exportSession.error {
                        print("Export failed: \(error.localizedDescription)")
                    } else {
                        print("Export failed")
                    }
                @unknown default:
                    print("Export failed with unknown status")
                }
            }
        }
    }

    func stop() {}
}

private extension AudioCaptureManager {}

private extension AudioCaptureManager {}

// swiftlint:disable all
import AudioToolbox

class AudioQueueRecorder {
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

    var currentMusicDataFormat = AudioStreamBasicDescription(
        mSampleRate: 44100,
        mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: AudioFormatFlags(kLinearPCMFormatFlagIsBigEndian|kLinearPCMFormatFlagIsSignedInteger|kLinearPCMFormatFlagIsPacked),
        mBytesPerPacket: 4,
        mFramesPerPacket: 1,
        mBytesPerFrame: 4,
        mChannelsPerFrame: 2,
        mBitsPerChannel: 16,
        mReserved: 0)

    let myAudioCallback: AudioQueueInputCallback = { (
        inUserData: UnsafeMutableRawPointer?,
        inAQ: AudioQueueRef,
        inBuffer: UnsafeMutablePointer<AudioQueueBuffer>,
        _: UnsafePointer<AudioTimeStamp>,
        inNumPackets: UInt32,
        inPacketDesc: Optional<UnsafePointer<AudioStreamPacketDescription>>) -> Void  in

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

        if !(receivedUserData.isRunning) {
            return
        }

        AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, nil)

    }

    func prepare() {
        dataFormat = currentMusicDataFormat

        var aAudioFileID: AudioFileID?

        let documentDirectories = FileManager.default.urls(
            for: FileManager.SearchPathDirectory.documentDirectory,
            in: FileManager.SearchPathDomainMask.userDomainMask)
        let docDirectory = (documentDirectories.first)!

        var audioFilePathURL = docDirectory.appendingPathComponent("audiotest")
        audioFilePathURL.appendPathExtension("aiff")

        let fileManager = FileManager.default
        try? fileManager.removeItem(at: audioFilePathURL)

        let result = AudioFileCreateWithURL(audioFilePathURL as CFURL,
                                            kAudioFileAIFFType,
                                            &currentMusicDataFormat,
                                            AudioFileFlags.eraseFile,
                                            &aAudioFileID)
        log.debug("result: \(result)")

        audioFile = aAudioFileID!
    }

    func prepareQueue() {

        var aQueue: AudioQueueRef!

        AudioQueueNewInput(
            &currentMusicDataFormat,
            myAudioCallback,
            unsafeBitCast(self, to: UnsafeMutableRawPointer.self),
            .none,
            CFRunLoopMode.commonModes.rawValue,
            0,
            &aQueue)

        if let aQueue = aQueue {
            audioQueue = aQueue
        }

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

    func writeToFile(buffer: UnsafeMutablePointer<AudioQueueBuffer>, numberOfPackets: UInt32, inPacketDesc: Optional<UnsafePointer<AudioStreamPacketDescription>>) {

        guard let audioFile = audioFile else {
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
        if let audioFile = audioFile {
            AudioFileClose(audioFile)
        }
    }

    func setupBuffer() {
        // typically 3
        let kNumberBuffers: Int = 3

        // typically 0.5
        bufferByteSize = deriveBufferSize(audioQueue: audioQueue, audioDataFormat: currentMusicDataFormat, seconds: 0.5)

        for i in 0..<kNumberBuffers {
            var newBuffer: AudioQueueBufferRef?

            AudioQueueAllocateBuffer(
                audioQueue,
                bufferByteSize,
                &newBuffer)

            if let newBuffer = newBuffer {
                buffers.append(newBuffer)
            }

            AudioQueueEnqueueBuffer(
                audioQueue,
                buffers[i],
                0,
                nil)
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
