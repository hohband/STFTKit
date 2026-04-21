# STFTKit

**Zero-dependency STFT/iSTFT for iOS & macOS in pure Swift.**

> Tired of wrapping `vDSP` manually every time you need spectrogram analysis? STFTKit gives you a clean Swift API for Short-Time Fourier Transform — nothing more, nothing less.

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2016+|macOS%2013+-blue.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## TL;DR

```swift
import STFTKit

let stft = STFT()
let spectrogram = stft.forward(audioSignal)
let reconstructed = stft.inverse(spectrogram)  // Nearly identical to original!
```

- ✅ **Zero external dependencies** — Only Swift + Apple Accelerate
- ✅ **Perfect reconstruction** — Overlap-add with window normalization
- ✅ **Real-time ready** — Single-frame FFT for streaming
- ✅ **Pure Swift** — No bridging, no C code
- ✅ **Batteries included** — Hann & Hamming windows, magnitude/phase extraction

---

## Why STFTKit?

If you've ever needed spectrogram analysis on iOS, you've probably run into one of these:

| Approach | Problem |
|----------|---------|
| **AudioKit** | Powerful, but massive surface area. You need to understand node graphs just to run an FFT. |
| **vDSP directly** | 50+ lines of boilerplate: split complex arrays, setup initialization, bin packing... every single time. |
| **Third-party wrappers** | Often incomplete — forward FFT only, no inverse transform, or no perfect reconstruction. |

**STFTKit is different.** It's a single-purpose library that does one thing: STFT, done right.

### Comparison with similar libraries

| Feature | **STFTKit** | AudioKit | AuraSignal | TempiFFT |
|---------|:-----------:|:--------:|:----------:|:---------:|
| **Scope** | STFT only | Full audio platform | DSP toolkit | Real-time spectrum |
| **STFT + iSTFT** | ✅ Perfect | ⚠️ Partial | ✅ | ❌ Forward only |
| **Dependencies** | Zero | Heavy | Swift Numerics | Zero |
| **Inverse transform** | ✅ | ⚠️ | ✅ | ❌ |
| **Center padding** | ✅ | ❌ | ❌ | ❌ |
| **Documentation** | EN + CN | EN only | EN only | EN only |
| **API complexity** | Low | High | Medium | Medium |

---

## Installation

### Swift Package Manager

```swift
// In Package.swift
dependencies: [
    .package(url: "https://github.com/hohband/STFTKit.git", from: "1.0.0")
]
```

```swift
// In your target
.target(name: "YourApp", dependencies: ["STFTKit"])
```

### Xcode

File → Add Package Dependencies → `https://github.com/hohband/STFTKit.git`

---

## Quick Start

### Basic Usage

```swift
import STFTKit

// Create with default config (fftSize=2048, hopSize=1024, Hann window)
let stft = STFT()

// Forward transform: signal → spectrogram
let spectrogram = stft.forward(audioSamples)

// Inverse transform: spectrogram → signal (nearly perfect reconstruction)
let reconstructed = stft.inverse(spectrogram)
```

### Custom Configuration

```swift
let config = STFTConfiguration(
    fftSize: 4096,                    // FFT window size (power of 2)
    hopSize: 1024,                    // Frame step
    window: .hann(periodic: true),    // Hann or .hamming
    centerPadding: true               // Zero-pad signal for edge-aligned analysis
)

let stft = STFT(configuration: config)
```

### Recommended: 75% Overlap for Perfect Reconstruction

```swift
let config = STFTConfiguration(
    fftSize: 2048,
    hopSize: 512,    // 75% overlap → perfect reconstruction
    window: .hann(periodic: true),
    centerPadding: true
)
```

---

## API Reference

### Full-Signal Processing

#### `forward(_:)` — Signal to Spectrogram

```swift
public func forward(_ signal: [Float]) -> Spectrogram
```

Transforms an entire audio signal into a spectrogram (time-frequency representation).

#### `inverse(_:)` — Spectrogram to Signal

```swift
public func inverse(_ spectrogram: Spectrogram) -> [Float]
```

Reconstructs a time-domain signal from a spectrogram using overlap-add with window normalization.

> **Note:** With 75% overlap (hopSize = fftSize/4) and Hann window, reconstruction error is below `1e-5`.

---

### Magnitude & Phase

#### `magnitudes(from:)`

```swift
public func magnitudes(from spectrogram: Spectrogram) -> [Float]
```

Extracts magnitude values from a spectrogram for visualization or further processing.

#### `spectrogram(fromMagnitudes:phases:frameCount:)`

```swift
public func spectrogram(fromMagnitudes: [Float], phases: [Float], frameCount: Int) -> Spectrogram
```

Reconstructs a spectrogram from magnitude and phase arrays — useful for spectral editing, noise reduction, and more.

---

### Single-Frame Processing

For real-time or streaming scenarios:

```swift
// Process one frame at a time (e.g., from audio buffer callback)
let spectrum: ComplexSpectrum = stft.processFrame(audioFrame)

// Reconstruct a single frame
let samples: [Float] = stft.reconstructFrame(spectrum)
```

---

### Pack/Unpack Helpers

```swift
// Convert packed FFT → full spectrum (DC to Nyquist)
let fullBins: [ComplexBin] = stft.packedToFull(spectrum)

// Convert full spectrum → packed format for inverse FFT
let packed: ComplexSpectrum = stft.fullToPacked(fullBins)
```

---

## Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `fftSize` | 2048 | FFT window size (must be power of 2) |
| `hopSize` | 1024 | Step between frames (samples) |
| `window` | `.hann(periodic: true)` | Window function |
| `centerPadding` | `true` | Zero-pad signal center-aligned |

### Computed Properties

```swift
config.frequencyBins  // fftSize / 2 + 1 (DC to Nyquist)
config.packedBins     // fftSize / 2 (Accelerate packed format)
```

---

## Use Cases

STFTKit is ideal for:

- 🎤 **Noise reduction** — Analyze frequency content, apply spectral subtraction
- 📊 **Spectrogram visualization** — Display audio as a time-frequency heatmap
- 🎵 **Audio effects** — Time-stretching, pitch-shifting (via magnitude manipulation)
- 🔊 **Sound analysis** — Pitch detection, onset detection, instrument recognition
- 🎙 **Voice processing** — Voice activity detection, acoustic feature extraction
- 📱 **Music apps** — Tuners, audio editors, podcast tools

---

## Data Types

### `Spectrogram`

Container for the complex frequency-domain representation of multiple time frames.

```swift
public struct Spectrogram {
    public var frames: [[ComplexBin]]  // [frame][frequency_bin]

    public var frameCount: Int { frames.count }
    public var frequencyBins: Int { frames.first?.count ?? 0 }

    // 2D subscript access
    public subscript(frame: Int, bin: Int) -> ComplexBin
}
```

### `ComplexSpectrum`

Packed complex array for Accelerate FFT operations.

```swift
public struct ComplexSpectrum {
    public var real: [Float]  // Real parts
    public var imag: [Float]  // Imaginary parts
    public var binCount: Int { real.count }
}
```

### `ComplexBin`

Convenience type alias for a single frequency bin:

```swift
public typealias ComplexBin = (real: Float, imag: Float)
```

### `WindowFunction`

```swift
public enum WindowFunction: Sendable {
    case hann(periodic: Bool = true)
    case hamming(periodic: Bool = true)
}
```

---

## Requirements

| Requirement | Version |
|-------------|---------|
| Swift | 5.9+ |
| iOS | 16.0+ |
| macOS | 13.0+ |
| Framework | Apple Accelerate |

---

## Testing

STFTKit includes comprehensive test coverage:

```bash
# Run all tests
swift test --enable-test-discovery

# Run specific test suite
swift test --filter STFTTests
```

Tests cover:
- ✅ Perfect reconstruction accuracy (NRMSE < 1e-4)
- ✅ Various FFT sizes (512, 1024, 2048, 4096)
- ✅ Different overlap ratios (50%, 75%, 87.5%)
- ✅ All window functions (Hann, Hamming, periodic, symmetric)
- ✅ Magnitude/phase extraction and reconstruction
- ✅ Edge cases (empty signal, short signal)
- ✅ Performance benchmarks

---

## Examples

See the `Examples/` directory for:
- **macOS CLI Demo** — Run FFT analysis from command line
- **iOS Visualization** — Real-time spectrogram display (coming soon)

---

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

## Acknowledgments

Built with [Apple's Accelerate framework](https://developer.apple.com/documentation/accelerate) for hardware-optimized FFT operations.
