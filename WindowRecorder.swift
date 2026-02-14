#!/usr/bin/env swift

import Foundation
import ScreenCaptureKit
import AVFoundation
import AppKit

// Window Recorder using ScreenCaptureKit
// Captures specific window even if obscured

@available(macOS 12.3, *)
class WindowRecorder {
    private var streamOutput: StreamOutput?
    private var stream: SCStream?
    private let outputURL: URL

    init(outputURL: URL) {
        self.outputURL = outputURL
    }

    func selectAndRecordWindow() async throws {
        // Get available content
        let availableContent = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        // Filter out empty windows and system UI
        let windows = availableContent.windows.filter { window in
            window.title != nil &&
            !window.title!.isEmpty &&
            window.frame.width > 100 &&
            window.frame.height > 100 &&
            window.owningApplication != nil
        }

        guard !windows.isEmpty else {
            print("❌ No recordable windows found")
            exit(1)
        }

        // Display windows for selection
        print("\n📺 Available Windows:\n")
        for (index, window) in windows.enumerated() {
            let app = window.owningApplication?.applicationName ?? "Unknown"
            let title = window.title ?? "Untitled"
            print("  \(index + 1). \(app) - \(title)")
        }

        print("\nSelect window number (1-\(windows.count)): ", terminator: "")

        guard let input = readLine(),
              let selection = Int(input),
              selection > 0,
              selection <= windows.count else {
            print("❌ Invalid selection")
            exit(1)
        }

        try await startRecording(window: windows[selection - 1])
    }

    func recordWindow(at index: Int) async throws {
        // Get available content
        let availableContent = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        // Filter out empty windows and system UI
        let windows = availableContent.windows.filter { window in
            window.title != nil &&
            !window.title!.isEmpty &&
            window.frame.width > 100 &&
            window.frame.height > 100 &&
            window.owningApplication != nil
        }

        guard !windows.isEmpty else {
            print("❌ No recordable windows found")
            exit(1)
        }

        guard index > 0 && index <= windows.count else {
            print("❌ Invalid window index: \(index)")
            exit(1)
        }

        try await startRecording(window: windows[index - 1])
    }

    private func startRecording(window: SCWindow) async throws {
        let appName = window.owningApplication?.applicationName ?? "Unknown"
        let windowTitle = window.title ?? "Untitled"

        print("\n✅ Recording: \(appName) - \(windowTitle)")

        // Create filter for selected window
        let filter = SCContentFilter(desktopIndependentWindow: window)

        // Configure stream
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width) * 2 // Retina
        config.height = Int(window.frame.height) * 2
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true
        config.capturesAudio = true
        config.sampleRate = 48000
        config.channelCount = 2

        // Create stream output handler
        streamOutput = StreamOutput(outputURL: outputURL, config: config)

        // Create and start stream
        stream = SCStream(filter: filter, configuration: config, delegate: nil)

        try stream?.addStreamOutput(
            streamOutput!,
            type: .screen,
            sampleHandlerQueue: .global(qos: .userInteractive)
        )

        try stream?.addStreamOutput(
            streamOutput!,
            type: .audio,
            sampleHandlerQueue: .global(qos: .userInteractive)
        )

        try await stream?.startCapture()

        print("🎥 Recording started... Press Ctrl+C to stop")

        // Keep running - will be stopped by signal handler
    }

    func stopRecording() async {
        do {
            try await stream?.stopCapture()
            await streamOutput?.finishWriting()
            print("\n✅ Recording saved to: \(outputURL.path)")
        } catch {
            print("❌ Error stopping recording: \(error)")
        }
    }
}

@available(macOS 12.3, *)
class StreamOutput: NSObject, SCStreamOutput {
    private let outputURL: URL
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private let config: SCStreamConfiguration
    private var isRecording = false

    init(outputURL: URL, config: SCStreamConfiguration) {
        self.outputURL = outputURL
        self.config = config
        super.init()
        setupAssetWriter()
    }

    private func setupAssetWriter() {
        do {
            assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

            // Video settings
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: config.width,
                AVVideoHeightKey: config.height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 6_000_000,
                    AVVideoMaxKeyFrameIntervalKey: 30
                ]
            ]

            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput?.expectsMediaDataInRealTime = true

            // Audio settings
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: config.sampleRate,
                AVNumberOfChannelsKey: config.channelCount,
                AVEncoderBitRateKey: 128_000
            ]

            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput?.expectsMediaDataInRealTime = true

            if let videoInput = videoInput {
                assetWriter?.add(videoInput)
            }

            if let audioInput = audioInput {
                assetWriter?.add(audioInput)
            }

            assetWriter?.startWriting()
            assetWriter?.startSession(atSourceTime: .zero)
            isRecording = true

        } catch {
            print("❌ Error setting up asset writer: \(error)")
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard isRecording else { return }

        switch type {
        case .screen:
            if let videoInput = videoInput, videoInput.isReadyForMoreMediaData {
                videoInput.append(sampleBuffer)
            }
        case .audio:
            if let audioInput = audioInput, audioInput.isReadyForMoreMediaData {
                audioInput.append(sampleBuffer)
            }
        case .microphone:
            break
        @unknown default:
            break
        }
    }

    func finishWriting() async {
        isRecording = false
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        await assetWriter?.finishWriting()
    }
}

// Global recorder instance for signal handler
var globalRecorder: WindowRecorder?

// Signal handler function (no capture)
func handleSignal(_ sig: Int32) {
    print("\n🛑 Stopping recording...")
    if let recorder = globalRecorder {
        // Use a semaphore to wait for async completion
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await recorder.stopRecording()
            semaphore.signal()
        }
        semaphore.wait()
        exit(0)
    } else {
        exit(0)
    }
}

// Main execution
if #available(macOS 12.3, *) {
    // Initialize NSApplication for CoreGraphics
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)  // Run headless without dock icon

    if CommandLine.arguments.count < 2 {
        print("Usage: WindowRecorder <output-file.mp4> [window-index]")
        exit(1)
    }

    let outputPath = CommandLine.arguments[1]
    let outputURL = URL(fileURLWithPath: outputPath)

    // Optional pre-selected window index
    var preSelectedIndex: Int? = nil
    if CommandLine.arguments.count >= 3 {
        preSelectedIndex = Int(CommandLine.arguments[2])
    }

    let recorder = WindowRecorder(outputURL: outputURL)
    globalRecorder = recorder

    // Handle Ctrl+C gracefully
    signal(SIGINT, handleSignal)

    Task {
        do {
            if let index = preSelectedIndex {
                try await recorder.recordWindow(at: index)
            } else {
                try await recorder.selectAndRecordWindow()
            }
        } catch {
            print("❌ Error: \(error)")
            exit(1)
        }
    }

    // Keep the program running
    dispatchMain()
} else {
    print("❌ This tool requires macOS 12.3 or later")
    exit(1)
}
