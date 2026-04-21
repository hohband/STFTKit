import Accelerate

final class STFTProcessor: @unchecked Sendable {
    let fftSize: Int
    let packedBins: Int
    let log2n: vDSP_Length
    let fftSetup: FFTSetup
    let window: [Float]

    init(configuration: STFTConfiguration) {
        self.fftSize = configuration.fftSize
        self.packedBins = configuration.fftSize / 2
        self.log2n = vDSP_Length(round(log2(Double(configuration.fftSize))))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        self.window = configuration.window.generate(length: configuration.fftSize)
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    func processFrame(_ buffer: [Float]) -> (real: [Float], imag: [Float]) {
        var frame = buffer
        if frame.count != fftSize {
            if frame.count < fftSize {
                frame.append(contentsOf: [Float](repeating: 0, count: fftSize - frame.count))
            } else {
                frame = Array(frame[0..<fftSize])
            }
        }

        var windowed = [Float](repeating: 0.0, count: fftSize)
        vDSP_vmul(frame, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        var realp = [Float](repeating: 0.0, count: packedBins)
        var imagp = [Float](repeating: 0.0, count: packedBins)

        realp.withUnsafeMutableBufferPointer { realBP in
            imagp.withUnsafeMutableBufferPointer { imagBP in
                var fftInOut = DSPSplitComplex(realp: realBP.baseAddress!, imagp: imagBP.baseAddress!)
                windowed.withUnsafeBytes { windowBytes in
                    let windowPtr = windowBytes.bindMemory(to: DSPComplex.self).baseAddress!
                    vDSP_ctoz(windowPtr, 2, &fftInOut, 1, vDSP_Length(packedBins))
                }
                vDSP_fft_zrip(fftSetup, &fftInOut, 1, log2n, FFTDirection(FFT_FORWARD))
            }
        }

        return (realp, imagp)
    }

    func reconstructFrame(real: [Float], imag: [Float]) -> [Float] {
        var realp = real
        var imagp = imag

        realp.withUnsafeMutableBufferPointer { realBP in
            imagp.withUnsafeMutableBufferPointer { imagBP in
                var fftInOut = DSPSplitComplex(realp: realBP.baseAddress!, imagp: imagBP.baseAddress!)
                vDSP_fft_zrip(fftSetup, &fftInOut, 1, log2n, FFTDirection(FFT_INVERSE))
            }
        }

        var scale: Float = 1.0 / Float(fftSize)
        var realScaled = [Float](repeating: 0, count: packedBins)
        var imagScaled = [Float](repeating: 0, count: packedBins)
        vDSP_vsmul(&realp, 1, &scale, &realScaled, 1, vDSP_Length(packedBins))
        vDSP_vsmul(&imagp, 1, &scale, &imagScaled, 1, vDSP_Length(packedBins))

        var output = [Float](repeating: 0.0, count: fftSize)
        output.withUnsafeMutableBytes { outputBytes in
            let outputPtr = outputBytes.bindMemory(to: DSPComplex.self).baseAddress!
            realScaled.withUnsafeBufferPointer { realBP in
                imagScaled.withUnsafeBufferPointer { imagBP in
                    var fftInOut = DSPSplitComplex(
                        realp: UnsafeMutablePointer(mutating: realBP.baseAddress!),
                        imagp: UnsafeMutablePointer(mutating: imagBP.baseAddress!)
                    )
                    vDSP_ztoc(&fftInOut, 1, outputPtr, 2, vDSP_Length(packedBins))
                }
            }
        }

        return output
    }

    func magnitudePhase(real: inout [Float], imag: inout [Float]) -> (magnitude: [Float], phase: [Float]) {
        var mag = [Float](repeating: 0.0, count: packedBins)
        var phase = [Float](repeating: 0.0, count: packedBins)

        real.withUnsafeMutableBufferPointer { realP in
            imag.withUnsafeMutableBufferPointer { imagP in
                var fftInOut = DSPSplitComplex(realp: realP.baseAddress!, imagp: imagP.baseAddress!)
                vDSP_zvabs(&fftInOut, 1, &mag, 1, vDSP_Length(packedBins))
                vDSP_zvphas(&fftInOut, 1, &phase, 1, vDSP_Length(packedBins))
            }
        }

        return (mag, phase)
    }

    func complexFromMagnitudePhase(magnitude: inout [Float], phase: inout [Float]) -> (real: [Float], imag: [Float]) {
        let count = packedBins
        var realp = [Float](repeating: 0, count: count)
        var imagp = [Float](repeating: 0, count: count)
        var n = Int32(count)

        var cosPhase = [Float](repeating: 0, count: count)
        vvcosf(&cosPhase, &phase, &n)
        vDSP_vmul(&cosPhase, 1, &magnitude, 1, &realp, 1, vDSP_Length(count))

        var sinPhase = [Float](repeating: 0, count: count)
        vvsinf(&sinPhase, &phase, &n)
        vDSP_vmul(&sinPhase, 1, &magnitude, 1, &imagp, 1, vDSP_Length(count))

        return (realp, imagp)
    }
}
