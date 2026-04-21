# STFTKit

[中文文档](README.zh-CN.md)

A Swift package for Short-Time Fourier Transform (STFT) and Inverse STFT, built on Apple's Accelerate framework for high-performance audio signal processing.

## Features

- Forward STFT and Inverse STFT with overlap-add reconstruction
- Single-frame FFT processing for real-time use cases
- Magnitude/phase extraction and reconstruction
- Hann and Hamming window functions (symmetric or periodic)
- Center-padding mode for edge-aligned analysis
- Window-sum-squared normalization for perfect reconstruction
- Zero external dependencies

## Requirements

- Swift 5.9+
- iOS 16.0+ / macOS 13.0+

## Installation

Add STFTKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/hohband/STFTKit.git", from: "1.0.0")
]
```

Then add `STFTKit` to your target's dependencies:

```swift
.target(name: "YourApp", dependencies: ["STFTKit"])
```

## Quick Start

```swift
import STFTKit

// Create an STFT instance with default configuration
let stft = STFT()

// Prepare an audio signal (mono Float array)
let signal: [Float] = /* your audio samples */

// Forward transform -> Spectrogram
let spectrogram = stft.forward(signal)

// Inverse transform -> reconstructed signal
let reconstructed = stft.inverse(spectrogram)
```

## Configuration

`STFTConfiguration` controls the analysis parameters:

```swift
let config = STFTConfiguration(
    fftSize: 2048,          // FFT size, must be power of 2
    hopSize: 1024,          // Hop size between frames
    window: .hann(periodic: true),  // Window function
    centerPadding: true     // Zero-pad signal centering
)
let stft = STFT(configuration: config)
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `fftSize` | 2048 | FFT window size (power of 2) |
| `hopSize` | 1024 | Samples between successive frames |
| `window` | `.hann(periodic: true)` | Window function applied to each frame |
| `centerPadding` | `true` | Pad the signal so frames center-align with edges |

Computed properties:
- `frequencyBins` — `fftSize / 2 + 1` (DC through Nyquist)
- `packedBins` — `fftSize / 2` (Accelerate's real-FFT packed format)

## API Reference

### Full-Signal Processing

#### `forward(_:)`

Computes the STFT of an entire signal, returning a `Spectrogram`.

```swift
let spectrogram = stft.forward(signal)
```

When `centerPadding` is `true`, the input is zero-padded by `fftSize/2` on both sides so that analysis frames center-align with the signal boundaries.

#### `inverse(_:)`

Reconstructs a time-domain signal from a `Spectrogram` using overlap-add with window-sum-squared normalization.

```swift
let signal = stft.inverse(spectrogram)
```

### Magnitude / Phase

#### `magnitudes(from:)`

Extracts magnitude values from a spectrogram as a flat `[Float]` array (frames × bins, row-major).

```swift
let mags = stft.magnitudes(from: spectrogram)
```

#### `spectrogram(fromMagnitudes:phases:frameCount:)`

Builds a `Spectrogram` from flat magnitude and phase arrays.

```swift
let spec = stft.spectrogram(fromMagnitudes: mags, phases: phases, frameCount: 100)
```

### Single-Frame Processing

For real-time or frame-by-frame workflows:

```swift
// Process one frame
let spectrum: ComplexSpectrum = stft.processFrame(frame)

// Reconstruct one frame
let samples: [Float] = stft.reconstructFrame(spectrum)
```

### Pack / Unpack Helpers

Convert between Accelerate's packed real-FFT format and the full `N/2+1` bin representation:

```swift
// Packed -> Full (DC ... Nyquist)
let fullBins: [ComplexBin] = stft.packedToFull(spectrum)

// Full -> Packed
let packed: ComplexSpectrum = stft.fullToPacked(fullBins)
```

Packing layout:
- `real[0]` holds the DC component
- `imag[0]` holds the Nyquist component
- `real[k], imag[k]` for `1 <= k < N/2` are the complex bins

## Data Types

### `Spectrogram`

A 2D container of complex frequency bins:

```swift
struct Spectrogram {
    var frames: [[ComplexBin]]
    var frameCount: Int         // Number of time frames
    var frequencyBins: Int      // Bins per frame (fftSize/2 + 1)
    subscript(frame: Int, bin: Int) -> ComplexBin
}
```

### `ComplexSpectrum`

Split-complex arrays from Accelerate's real FFT:

```swift
struct ComplexSpectrum {
    var real: [Float]
    var imag: [Float]
    var binCount: Int
}
```

### `ComplexBin`

A convenience typealias for a frequency bin:

```swift
typealias ComplexBin = (real: Float, imag: Float)
```

### `WindowFunction`

```swift
enum WindowFunction {
    case hann(periodic: Bool = true)
    case hamming(periodic: Bool = true)
}
```

- **periodic `true`** — use `N` in the denominator (for STFT analysis/reconstruction)
- **periodic `false`** — use `N-1` (symmetric window, for filter design)

## Reconstruction Quality

For perfect (or near-perfect) reconstruction, use 75% overlap:

```swift
let config = STFTConfiguration(
    fftSize: 2048,
    hopSize: 512,                    // 75% overlap
    window: .hann(periodic: true),
    centerPadding: true
)
```

The `inverse` method applies window-sum-squared normalization internally, compensating for the overlap-add windowing so the reconstructed signal closely matches the original.

## License

MIT
