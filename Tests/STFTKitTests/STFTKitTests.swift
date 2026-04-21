import XCTest
@testable import STFTKit

// MARK: - Test Signal Generators

/// Generate a pure sine wave at given frequency and phase
func generateSineWave(frequency: Float, sampleRate: Float, frameCount: Int, phase: Float = 0) -> [Float] {
    return (0..<frameCount).map { i in
        sin(2 * .pi * frequency * Float(i) / sampleRate + phase)
    }
}

/// Generate a complex multi-frequency test signal
func generateComplexSignal(sampleRate: Float, frameCount: Int) -> [Float] {
    let f1: Float = 440   // A4
    let f2: Float = 880   // A5
    let f3: Float = 1320  // E6 (harmonics)
    return (0..<frameCount).map { i in
        let t = Float(i) / sampleRate
        return 0.5 * sin(2 * .pi * f1 * t)
             + 0.3 * sin(2 * .pi * f2 * t)
             + 0.2 * sin(2 * .pi * f3 * t)
             + 0.1 * Float.random(in: -1...1)  // small noise
    }
}

// MARK: - Test Cases

final class STFTTests: XCTestCase {

    // MARK: - Perfect Reconstruction Tests

    /// Test that forward + inverse STFT achieves near-perfect reconstruction with 75% overlap
    func testPerfectReconstruction_SineWave() {
        let sampleRate: Float = 44100
        let frameCount = 44100  // 1 second
        let signal = generateSineWave(frequency: 440, sampleRate: sampleRate, frameCount: frameCount)

        let config = STFTConfiguration(
            fftSize: 2048,
            hopSize: 512,
            window: .hann(periodic: true),
            centerPadding: true
        )
        let stft = STFT(configuration: config)

        let spectrogram = stft.forward(signal)
        let reconstructed = stft.inverse(spectrogram)

        XCTAssertEqual(reconstructed.count, signal.count, "Reconstructed length should match original")

        // Check reconstruction error
        let maxError = zip(signal, reconstructed).map { abs($0 - $1) }.max() ?? 0
        let tolerance: Float = 1e-5
        XCTAssertLessThan(maxError, tolerance, "Reconstruction error \(maxError) exceeds tolerance \(tolerance)")
    }

    /// Test reconstruction with different hop sizes
    func testReconstructionWithVariousHopSizes() {
        let sampleRate: Float = 44100
        let frameCount = 22050
        let signal = generateComplexSignal(sampleRate: sampleRate, frameCount: frameCount)

        let fftSize = 1024

        // Test 50%, 75%, 87.5% overlap
        let hopSizes = [512, 256, 128]

        for hopSize in hopSizes {
            let config = STFTConfiguration(
                fftSize: fftSize,
                hopSize: hopSize,
                window: .hann(periodic: true),
                centerPadding: true
            )
            let stft = STFT(configuration: config)

            let spectrogram = stft.forward(signal)
            let reconstructed = stft.inverse(spectrogram)

            // Check relative reconstruction error (NRMSE)
            let signalPower = signal.map { $0 * $0 }.reduce(0, +)
            let noise = zip(signal, reconstructed).map { ($0 - $1) * ($0 - $1) }.reduce(0, +)
            let nrmse = sqrt(noise / signalPower)

            XCTAssertLessThan(nrmse, 1e-4, "NRMSE for hopSize=\(hopSize) too high: \(nrmse)")
        }
    }

    /// Test reconstruction with different window functions
    func testReconstructionWithVariousWindows() {
        let signal = generateComplexSignal(sampleRate: 44100, frameCount: 4096)
        let fftSize = 1024
        let hopSize = 256

        let windows: [WindowFunction] = [
            .hann(periodic: true),
            .hann(periodic: false),
            .hamming(periodic: true),
            .hamming(periodic: false)
        ]

        for window in windows {
            let config = STFTConfiguration(
                fftSize: fftSize,
                hopSize: hopSize,
                window: window,
                centerPadding: true
            )
            let stft = STFT(configuration: config)

            let spectrogram = stft.forward(signal)
            let reconstructed = stft.inverse(spectrogram)

            let signalPower = signal.map { $0 * $0 }.reduce(0, +)
            let noise = zip(signal, reconstructed).map { ($0 - $1) * ($0 - $1) }.reduce(0, +)
            let nrmse = sqrt(noise / signalPower)

            XCTAssertLessThan(nrmse, 1e-4, "NRMSE for \(window) too high: \(nrmse)")
        }
    }

    // MARK: - Magnitude/Phase Tests

    /// Test that magnitude + phase can reconstruct the original spectrogram
    func testMagnitudePhaseReconstruction() {
        let sampleRate: Float = 44100
        let frameCount = 8192
        let signal = generateComplexSignal(sampleRate: sampleRate, frameCount: frameCount)

        let config = STFTConfiguration(fftSize: 2048, hopSize: 512)
        let stft = STFT(configuration: config)

        let spectrogram = stft.forward(signal)
        let magnitudes = stft.magnitudes(from: spectrogram)

        // Extract phases from original spectrogram
        var phases: [Float] = []
        for frame in spectrogram.frames {
            for bin in frame {
                let phase = atan2(bin.imag, bin.real)
                phases.append(phase)
            }
        }

        // Reconstruct from magnitude + phase
        let reconstructedSpectrogram = stft.spectrogram(
            fromMagnitudes: magnitudes,
            phases: phases,
            frameCount: spectrogram.frameCount
        )

        // Verify reconstruction matches original
        for f in 0..<spectrogram.frameCount {
            for k in 0..<spectrogram.frequencyBins {
                let original = spectrogram[f, k]
                let reconstructed = reconstructedSpectrogram[f, k]

                XCTAssertEqual(original.real, reconstructed.real, accuracy: 1e-6)
                XCTAssertEqual(original.imag, reconstructed.imag, accuracy: 1e-6)
            }
        }
    }

    // MARK: - Single Frame Processing Tests

    /// Test single frame processing and reconstruction
    func testSingleFrameProcessing() {
        let frame = generateSineWave(frequency: 1000, sampleRate: 44100, frameCount: 2048)

        let config = STFTConfiguration(fftSize: 2048, hopSize: 512)
        let stft = STFT(configuration: config)

        let spectrum = stft.processFrame(frame)
        XCTAssertEqual(spectrum.binCount, 1025, "Frequency bins should be fftSize/2 + 1")

        let reconstructed = stft.reconstructFrame(spectrum)

        // Single frame reconstruction is less accurate due to no overlap-add
        let maxError = zip(frame, reconstructed).map { abs($0 - $1) }.max() ?? 0
        XCTAssertLessThan(maxError, 0.1, "Single frame reconstruction error too high")
    }

    // MARK: - Boundary & Edge Case Tests

    /// Test with empty signal
    func testEmptySignal() {
        let config = STFTConfiguration()
        let stft = STFT(configuration: config)

        let emptySignal: [Float] = []
        let spectrogram = stft.forward(emptySignal)

        XCTAssertEqual(spectrogram.frameCount, 0, "Empty signal should produce 0 frames")
    }

    /// Test with signal shorter than fftSize
    func testShortSignal() {
        let config = STFTConfiguration(fftSize: 2048, hopSize: 512)
        let stft = STFT(configuration: config)

        let shortSignal: [Float] = [Float](repeating: 0, count: 512)
        let spectrogram = stft.forward(shortSignal)

        // Should still produce frames (padded with zeros internally)
        XCTAssertGreaterThan(spectrogram.frameCount, 0)
    }

    /// Test center padding toggle
    func testCenterPaddingToggle() {
        let signal = generateSineWave(frequency: 440, sampleRate: 44100, frameCount: 4096)

        let configWithPadding = STFTConfiguration(fftSize: 2048, hopSize: 512, centerPadding: true)
        let stftWithPadding = STFT(configuration: configWithPadding)

        let configWithoutPadding = STFTConfiguration(fftSize: 2048, hopSize: 512, centerPadding: false)
        let stftWithoutPadding = STFT(configuration: configWithoutPadding)

        let spectrogramWithPadding = stftWithPadding.forward(signal)
        let spectrogramWithoutPadding = stftWithoutPadding.forward(signal)

        // Frame counts should differ due to different padding strategies
        XCTAssertNotEqual(spectrogramWithPadding.frameCount, spectrogramWithoutPadding.frameCount)
    }

    // MARK: - Configuration Tests

    /// Test configuration computed properties
    func testConfigurationComputedProperties() {
        let fftSizes = [512, 1024, 2048, 4096]

        for fftSize in fftSizes {
            let config = STFTConfiguration(fftSize: fftSize)

            XCTAssertEqual(config.frequencyBins, fftSize / 2 + 1)
            XCTAssertEqual(config.packedBins, fftSize / 2)
        }
    }

    /// Test precondition failures for invalid configurations
    func testInvalidFFTSizePrecondition() {
        XCTAssertThrowsError(
            _ = STFTConfiguration(fftSize: 1000)  // Not a power of 2
        ) { error in
            XCTAssertTrue(error is AssertionError)
        }
    }

    func testInvalidHopSizePrecondition() {
        XCTAssertThrowsError(
            _ = STFTConfiguration(fftSize: 2048, hopSize: 4096)  // hopSize > fftSize
        ) { error in
            XCTAssertTrue(error is AssertionError)
        }
    }

    // MARK: - Spectrogram Data Structure Tests

    /// Test Spectrogram subscript access
    func testSpectrogramSubscript() {
        var frames: [[ComplexBin]] = []
        for _ in 0..<10 {
            var frame: [ComplexBin] = []
            for k in 0..<1025 {
                frame.append((real: Float(k), imag: Float(k) * 2))
            }
            frames.append(frame)
        }

        let spectrogram = Spectrogram(frames: frames)

        XCTAssertEqual(spectrogram.frameCount, 10)
        XCTAssertEqual(spectrogram.frequencyBins, 1025)
        XCTAssertEqual(spectrogram[0, 0].real, 0)
        XCTAssertEqual(spectrogram[5, 100].imag, 200)
    }

    // MARK: - Packed/Full Conversion Tests

    /// Test packed to full spectrum conversion
    func testPackedFullConversion() {
        let config = STFTConfiguration(fftSize: 2048)
        let stft = STFT(configuration: config)

        let frame = generateSineWave(frequency: 1000, sampleRate: 44100, frameCount: 2048)
        let spectrum = stft.processFrame(frame)

        let fullBins = stft.packedToFull(spectrum)
        let packedBack = stft.fullToPacked(fullBins)

        // Verify round-trip accuracy
        for k in 0..<spectrum.binCount {
            XCTAssertEqual(spectrum.real[k], packedBack.real[k], accuracy: 1e-6)
            XCTAssertEqual(spectrum.imag[k], packedBack.imag[k], accuracy: 1e-6)
        }
    }

    // MARK: - Performance Benchmark (informational)

    func testPerformanceForward() {
        let signal = generateComplexSignal(sampleRate: 44100, frameCount: 44100)
        let config = STFTConfiguration(fftSize: 2048, hopSize: 512)
        let stft = STFT(configuration: config)

        measure {
            _ = stft.forward(signal)
        }
    }

    func testPerformanceRoundTrip() {
        let signal = generateComplexSignal(sampleRate: 44100, frameCount: 22050)
        let config = STFTConfiguration(fftSize: 2048, hopSize: 512)
        let stft = STFT(configuration: config)

        measure {
            let spectrogram = stft.forward(signal)
            _ = stft.inverse(spectrogram)
        }
    }
}
