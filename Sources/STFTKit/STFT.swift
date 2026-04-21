import Foundation

public final class STFT {
    public let configuration: STFTConfiguration
    private let processor: STFTProcessor

    public init(configuration: STFTConfiguration = .default) {
        self.configuration = configuration
        self.processor = STFTProcessor(configuration: configuration)
    }

    // MARK: - Full-signal STFT/ISTFT

    public func forward(_ signal: [Float]) -> Spectrogram {
        let fftSize = configuration.fftSize
        let hopSize = configuration.hopSize
        let freqBins = configuration.frequencyBins
        let packedBins = configuration.packedBins

        var padded: [Float]
        if configuration.centerPadding {
            let padSize = fftSize / 2
            padded = [Float](repeating: 0, count: signal.count + 2 * padSize)
            for i in 0..<signal.count {
                padded[padSize + i] = signal[i]
            }
        } else {
            padded = signal
        }

        var specFrames = [[ComplexBin]]()

        for start in stride(from: 0, through: padded.count - fftSize, by: hopSize) {
            let end = start + fftSize
            let frame = Array(padded[start..<end])

            let (realPacked, imagPacked) = processor.processFrame(frame)

            var frameSpec = [ComplexBin](repeating: (0, 0), count: freqBins)
            frameSpec[0] = (real: realPacked[0], imag: 0)
            for k in 1..<packedBins {
                frameSpec[k] = (real: realPacked[k], imag: imagPacked[k])
            }
            frameSpec[freqBins - 1] = (real: 0, imag: imagPacked[0])

            specFrames.append(frameSpec)
        }

        return Spectrogram(frames: specFrames)
    }

    public func inverse(_ spectrogram: Spectrogram) -> [Float] {
        let fftSize = configuration.fftSize
        let hopSize = configuration.hopSize
        let freqBins = configuration.frequencyBins
        let packedBins = configuration.packedBins
        let frameCount = spectrogram.frameCount
        let window = processor.window

        let outputLength = frameCount * hopSize + fftSize - hopSize
        var buffer = [Float](repeating: 0, count: outputLength)
        var windowSumSq = [Float](repeating: 0, count: outputLength)

        for frame in 0..<frameCount {
            var realPacked = [Float](repeating: 0, count: packedBins)
            var imagPacked = [Float](repeating: 0, count: packedBins)

            realPacked[0] = spectrogram[frame, 0].real
            for k in 1..<packedBins {
                realPacked[k] = spectrogram[frame, k].real
                imagPacked[k] = spectrogram[frame, k].imag
            }
            imagPacked[0] = spectrogram[frame, freqBins - 1].imag

            var signal = processor.reconstructFrame(real: realPacked, imag: imagPacked)

            for i in 0..<fftSize {
                signal[i] *= window[i]
            }

            let writeStart = frame * hopSize
            for i in 0..<fftSize {
                let idx = writeStart + i
                if idx < outputLength {
                    buffer[idx] += signal[i]
                    windowSumSq[idx] += window[i] * window[i]
                }
            }
        }

        for i in 0..<outputLength {
            if windowSumSq[i] > 1e-8 {
                buffer[i] /= windowSumSq[i]
            }
        }

        let expectedLength = (frameCount - 1) * hopSize
        if buffer.count > expectedLength {
            return Array(buffer[0..<expectedLength])
        }
        return buffer
    }

    // MARK: - Magnitude/Phase

    public func magnitudes(from spectrogram: Spectrogram) -> [Float] {
        let freqBins = spectrogram.frequencyBins
        var result = [Float]()
        result.reserveCapacity(spectrogram.frameCount * freqBins)

        for frame in spectrogram.frames {
            for bin in frame {
                let mag = sqrt(bin.real * bin.real + bin.imag * bin.imag)
                result.append(mag)
            }
        }
        return result
    }

    public func spectrogram(fromMagnitudes magnitudes: [Float], phases: [Float], frameCount: Int) -> Spectrogram {
        let freqBins = configuration.frequencyBins
        var frames = [[ComplexBin]]()

        for f in 0..<frameCount {
            let offset = f * freqBins
            var frameBins = [ComplexBin]()
            frameBins.reserveCapacity(freqBins)
            for k in 0..<freqBins where offset + k < magnitudes.count && offset + k < phases.count {
                let m = magnitudes[offset + k]
                let p = phases[offset + k]
                frameBins.append((real: m * cos(p), imag: m * sin(p)))
            }
            frames.append(frameBins)
        }

        return Spectrogram(frames: frames)
    }

    // MARK: - Single-frame processing

    public func processFrame(_ frame: [Float]) -> ComplexSpectrum {
        let (real, imag) = processor.processFrame(frame)
        return ComplexSpectrum(real: real, imag: imag)
    }

    public func reconstructFrame(_ spectrum: ComplexSpectrum) -> [Float] {
        processor.reconstructFrame(real: spectrum.real, imag: spectrum.imag)
    }

    // MARK: - Pack/Unpack helpers

    public func packedToFull(_ packed: ComplexSpectrum) -> [ComplexBin] {
        let packedBins = configuration.packedBins
        let freqBins = configuration.frequencyBins
        var bins = [ComplexBin](repeating: (0, 0), count: freqBins)

        bins[0] = (real: packed.real[0], imag: 0)
        for k in 1..<packedBins {
            bins[k] = (real: packed.real[k], imag: packed.imag[k])
        }
        bins[freqBins - 1] = (real: 0, imag: packed.imag[0])

        return bins
    }

    public func fullToPacked(_ bins: [ComplexBin]) -> ComplexSpectrum {
        let packedBins = configuration.packedBins
        let freqBins = configuration.frequencyBins
        var real = [Float](repeating: 0, count: packedBins)
        var imag = [Float](repeating: 0, count: packedBins)

        real[0] = bins[0].real
        for k in 1..<packedBins {
            real[k] = bins[k].real
            imag[k] = bins[k].imag
        }
        imag[0] = bins[freqBins - 1].imag

        return ComplexSpectrum(real: real, imag: imag)
    }
}
