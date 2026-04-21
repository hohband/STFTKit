import Foundation

public struct ComplexSpectrum {
    public var real: [Float]
    public var imag: [Float]

    public init(real: [Float], imag: [Float]) {
        precondition(real.count == imag.count, "real and imag must have same length")
        self.real = real
        self.imag = imag
    }

    public var binCount: Int { real.count }
}

public typealias ComplexBin = (real: Float, imag: Float)

public struct Spectrogram {
    public var frames: [[ComplexBin]]

    public init(frames: [[ComplexBin]]) {
        self.frames = frames
    }

    public var frameCount: Int { frames.count }

    public var frequencyBins: Int { frames.first?.count ?? 0 }

    public subscript(frame: Int, bin: Int) -> ComplexBin {
        get { frames[frame][bin] }
        set { frames[frame][bin] = newValue }
    }
}
