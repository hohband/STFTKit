# STFTKit iOS Demo

A real-time audio visualization app demonstrating STFTKit usage.

## Features

- Real-time FFT spectrum analyzer
- Adjustable FFT size (512/1024/2048/4096)
- Adjustable hop size
- Multiple window function support (Hann, Hamming)
- Audio input from device microphone

## Usage

```swift
import STFTKit

// Quick setup
let stft = STFT()

// Process audio buffer
let spectrogram = stft.forward(audioSamples)
let magnitudes = stft.magnitudes(from: spectrogram)

// Display as spectrum or spectrogram
```

## Requirements

- iOS 16.0+
- Microphone permission
- Swift 5.9+

## Installation

Add to your `Package.swift`:
```swift
.package(url: "https://github.com/hohband/STFTKit.git", from: "1.0.0")
```
