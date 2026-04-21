import Foundation
import STFTKit

// ============================================================
// STFTKit Demo - Audio Signal Processing Examples
// ============================================================
// This file demonstrates various use cases for STFTKit.
// Run with: swift run --package-path Examples/STFTDemoDemo
// ============================================================

// MARK: - Helper Functions

/// Generate a sine wave at given frequency
func generateSineWave(frequency: Float, sampleRate: Float, duration: Float) -> [Float] {
    let frameCount = Int(sampleRate * duration)
    return (0..<frameCount).map { i in
        sin(2 * .pi * frequency * Float(i) / sampleRate)
    }
}

/// Generate a multi-frequency test signal
func generateTestSignal(sampleRate: Float, duration: Float) -> [Float] {
    let frameCount = Int(sampleRate * duration)
    let frequencies: [Float] = [220, 440, 880, 1760, 3520]  // Octaves of A
    let amplitudes: [Float] = [0.4, 0.6, 0.3, 0.15, 0.05]

    return (0..<frameCount).map { i in
        var sample: Float = 0
        for (freq, amp) in zip(frequencies, amplitudes) {
            sample += amp * sin(2 * .pi * freq * Float(i) / sampleRate)
        }
        return sample
    }
}

/// Print spectrogram info
func printSpectrogramInfo(_ spectrogram: Spectrogram) {
    print("  ├─ Frames: \(spectrogram.frameCount)")
    print("  ├─ Frequency bins: \(spectrogram.frequencyBins)")
    print("  └─ Resolution: \(spectrogram.frequencyBins * 2 - 1) FFT bins")
}

// MARK: - Demo 1: Basic STFT Usage

func demoBasicSTFT() {
    print("\n" + "=" .repeated(50))
    print("Demo 1: Basic STFT Forward/Inverse")
    print("=".repeated(50))

    let sampleRate: Float = 44100
    let duration: Float = 0.1  // 100ms

    // Generate a 440Hz sine wave (A4 note)
    let signal = generateSineWave(frequency: 440, sampleRate: sampleRate, duration: duration)
    print("\n📊 Input signal:")
    print("  ├─ Duration: \(duration)s")
    print("  ├─ Sample rate: \(Int(sampleRate)) Hz")
    print("  └─ Samples: \(signal.count)")

    // Configure STFT
    let config = STFTConfiguration(
        fftSize: 2048,
        hopSize: 512,
        window: .hann(periodic: true),
        centerPadding: true
    )

    print("\n⚙️  STFT Configuration:")
    print("  ├─ FFT size: \(config.fftSize)")
    print("  ├─ Hop size: \(config.hopSize)")
    print("  ├─ Window: Hann (periodic)")
    print("  └─ Overlap: \((1 - Float(config.hopSize) / Float(config.fftSize)) * 100)%")

    let stft = STFT(configuration: config)

    // Forward STFT
    print("\n🔄 Forward STFT...")
    let spectrogram = stft.forward(signal)
    print("✅ Spectrogram created:")
    printSpectrogramInfo(spectrogram)

    // Inverse STFT (perfect reconstruction)
    print("\n🔄 Inverse STFT...")
    let reconstructed = stft.inverse(spectrogram)

    // Calculate error
    let maxError = zip(signal, reconstructed).map { abs($0 - $1) }.max() ?? 0
    let signalPower = signal.map { $0 * $0 }.reduce(0, +)
    let noisePower = zip(signal, reconstructed).map { pow($0 - $1, 2) }.reduce(0, +)
    let snr = 10 * log10(signalPower / max(noisePower, 1e-10))

    print("✅ Reconstruction complete:")
    print("  ├─ Reconstructed samples: \(reconstructed.count)")
    print("  ├─ Max absolute error: \(maxError)")
    print("  └─ SNR: \(String(format: "%.1f", snr)) dB")
}

// MARK: - Demo 2: Magnitude Spectrum Analysis

func demoMagnitudeSpectrum() {
    print("\n" + "=" .repeated(50))
    print("Demo 2: Magnitude Spectrum Analysis")
    print("=".repeated(50))

    let sampleRate: Float = 44100
    let duration: Float = 0.1

    // Multi-frequency signal
    let signal = generateTestSignal(sampleRate: sampleRate, duration: duration)

    let stft = STFT(configuration: .default)
    let spectrogram = stft.forward(signal)

    // Get magnitudes
    let magnitudes = stft.magnitudes(from: spectrogram)

    // Find dominant frequencies in first frame
    let firstFrameMagnitudes = Array(magnitudes.prefix(spectrogram.frequencyBins))
    let maxMagnitude = firstFrameMagnitudes.max() ?? 0

    // Find peak indices (simplified peak detection)
    var peaks: [(bin: Int, frequency: Float, magnitude: Float)] = []
    let threshold = maxMagnitude * 0.1

    for i in 1..<(firstFrameMagnitudes.count - 1) {
        if firstFrameMagnitudes[i] > threshold &&
           firstFrameMagnitudes[i] > firstFrameMagnitudes[i-1] &&
           firstFrameMagnitudes[i] > firstFrameMagnitudes[i+1] {
            let frequency = Float(i) * sampleRate / Float(stft.configuration.fftSize)
            peaks.append((bin: i, frequency: frequency, magnitude: firstFrameMagnitudes[i]))
        }
    }

    // Sort by magnitude and take top 5
    peaks.sort { $0.magnitude > $1.magnitude }
    let topPeaks = Array(peaks.prefix(5))

    print("\n📈 Top 5 dominant frequencies (first frame):")
    for (index, peak) in topPeaks.enumerated() {
        print("  \(index + 1). \(String(format: "%.1f", peak.frequency)) Hz (bin \(peak.bin), mag: \(String(format: "%.4f", peak.magnitude)))")
    }
}

// MARK: - Demo 3: Real-time Style Frame Processing

func demoFrameProcessing() {
    print("\n" + "=" .repeated(50))
    print("Demo 3: Real-time Frame Processing")
    print("=".repeated(50))

    let sampleRate: Float = 44100
    let fftSize = 1024

    let stft = STFT(configuration: STFTConfiguration(
        fftSize: fftSize,
        hopSize: 256
    ))

    print("\n🎤 Simulating real-time audio processing...")
    print("  └─ Processing frames of \(fftSize) samples...")

    // Simulate processing 10 frames
    for frameIndex in 0..<10 {
        // In real use, this would come from audio buffer
        let frame = generateSineWave(
            frequency: Float(200 + frameIndex * 50),  // Chirp-like
            sampleRate: sampleRate,
            duration: Float(fftSize) / sampleRate
        )

        // Process single frame
        let spectrum = stft.processFrame(frame)

        // Get magnitude spectrum
        let packedBins = fftSize / 2
        var real = spectrum.real
        var imag = spectrum.imag
        let (mags, _) = stft.configuration.fftSize == fftSize
            ? extractMagnitudes(from: Array(zip(real, imag)), packedBins: packedBins)
            : ([], [])

        let peakMag = mags.max() ?? 0
        print("  Frame \(frameIndex + 1): peak magnitude = \(String(format: "%.4f", peakMag))")
    }
}

/// Helper to extract magnitudes (simplified for demo)
func extractMagnitudes(from bins: [(real: Float, imag: Float)], packedBins: Int) -> (magnitudes: [Float], phases: [Float]) {
    var magnitudes: [Float] = []
    var phases: [Float] = []

    for bin in bins.prefix(packedBins) {
        let mag = sqrt(bin.real * bin.real + bin.imag * bin.imag)
        let phase = atan2(bin.imag, bin.real)
        magnitudes.append(mag)
        phases.append(phase)
    }

    return (magnitudes, phases)
}

// MARK: - Demo 4: Spectral Processing Pipeline

func demoSpectralProcessing() {
    print("\n" + "=" .repeated(50))
    print("Demo 4: Spectral Processing Pipeline")
    print("=".repeated(50))

    let sampleRate: Float = 44100
    let signal = generateTestSignal(sampleRate: sampleRate, duration: 0.2)

    let config = STFTConfiguration(fftSize: 2048, hopSize: 512)
    let stft = STFT(configuration: config)

    print("\n🔧 Spectral processing pipeline:")

    // Step 1: Forward STFT
    print("\n  Step 1: Forward STFT")
    let spectrogram = stft.forward(signal)
    print("  ✅ Created spectrogram with \(spectrogram.frameCount) frames")

    // Step 2: Extract magnitudes and phases
    print("\n  Step 2: Extract magnitudes and phases")
    let magnitudes = stft.magnitudes(from: spectrogram)

    var phases: [Float] = []
    for frame in spectrogram.frames {
        for bin in frame {
            phases.append(atan2(bin.imag, bin.real))
        }
    }
    print("  ✅ Extracted \(magnitudes.count) magnitude values")

    // Step 3: Apply spectral processing (e.g., noise reduction simulation)
    print("\n  Step 3: Apply spectral processing (noise gate)")
    var processedMagnitudes = magnitudes
    let threshold: Float = 0.01

    for i in 0..<processedMagnitudes.count {
        if processedMagnitudes[i] < threshold {
            processedMagnitudes[i] = 0  // Gate out low-energy bins
        }
    }

    let gatedFrames = processedMagnitudes.filter { $0 > 0 }.count
    print("  ✅ Gated \(magnitudes.count - gatedFrames) low-energy bins")

    // Step 4: Reconstruct from processed magnitudes
    print("\n  Step 4: Reconstruct spectrogram from magnitudes")
    let processedSpectrogram = stft.spectrogram(
        fromMagnitudes: processedMagnitudes,
        phases: phases,
        frameCount: spectrogram.frameCount
    )
    print("  ✅ Reconstructed spectrogram")

    // Step 5: Inverse STFT
    print("\n  Step 5: Inverse STFT")
    let processedSignal = stft.inverse(processedSpectrogram)
    print("  ✅ Processed signal: \(processedSignal.count) samples")

    // Calculate processing effect
    let originalEnergy = signal.map { $0 * $0 }.reduce(0, +)
    let processedEnergy = processedSignal.map { $0 * $0 }.reduce(0, +)
    let energyRatio = processedEnergy / originalEnergy

    print("\n  📊 Processing result:")
    print("    ├─ Original energy: \(String(format: "%.4f", originalEnergy))")
    print("    ├─ Processed energy: \(String(format: "%.4f", processedEnergy))")
    print("    └─ Energy retained: \(String(format: "%.1f", energyRatio * 100))%")
}

// MARK: - Demo 5: Compare Window Functions

func demoWindowComparison() {
    print("\n" + "=" .repeated(50))
    print("Demo 5: Window Function Comparison")
    print("=".repeated(50))

    let signal = generateTestSignal(sampleRate: 44100, duration: 0.2)

    let windows: [(name: String, window: WindowFunction)] = [
        ("Hann (periodic)", .hann(periodic: true)),
        ("Hann (symmetric)", .hann(periodic: false)),
        ("Hamming (periodic)", .hamming(periodic: true)),
        ("Hamming (symmetric)", .hamming(periodic: false))
    ]

    print("\n📊 Reconstruction quality by window function:")
    print("-" .repeated(45))

    for (name, window) in windows {
        let config = STFTConfiguration(
            fftSize: 2048,
            hopSize: 512,
            window: window,
            centerPadding: true
        )
        let stft = STFT(configuration: config)

        let spectrogram = stft.forward(signal)
        let reconstructed = stft.inverse(spectrogram)

        // Calculate NRMSE
        let signalPower = signal.map { $0 * $0 }.reduce(0, +)
        let noise = zip(signal, reconstructed).map { pow($0 - $1, 2) }.reduce(0, +)
        let nrmse = sqrt(noise / max(signalPower, 1e-10))

        let bars = String(repeating: "█", count: Int((1 - nrmse) * 50))
        print("  \(name.padding(toLength: 22, withPad: " ", startingAt: 0))│ \(bars) \(String(format: "%.2e", nrmse))")
    }
}

// MARK: - String Extension

extension String {
    func repeated(_ count: Int) -> String {
        return String(repeating: self, count: count)
    }
}

// MARK: - Main Entry Point

print("""
╔══════════════════════════════════════════════════════════╗
║              STFTKit Demo Suite v1.0                     ║
║     Short-Time Fourier Transform for iOS/macOS         ║
╚══════════════════════════════════════════════════════════╝
""")

// Run all demos
demoBasicSTFT()
demoMagnitudeSpectrum()
demoFrameProcessing()
demoSpectralProcessing()
demoWindowComparison()

print("\n" + "=" .repeated(50))
print("All demos completed! 🎉")
print("=" .repeated(50))
print("\nNext steps:")
print("  1. Try modifying the STFTConfiguration parameters")
print("  2. Process your own audio files")
print("  3. Integrate STFTKit into your audio processing pipeline")
print("")
