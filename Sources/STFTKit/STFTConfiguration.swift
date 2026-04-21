import Foundation

public struct STFTConfiguration: Sendable {
    public var fftSize: Int
    public var hopSize: Int
    public var window: WindowFunction
    public var centerPadding: Bool

    public var frequencyBins: Int { fftSize / 2 + 1 }
    public var packedBins: Int { fftSize / 2 }

    public init(
        fftSize: Int = 2048,
        hopSize: Int = 1024,
        window: WindowFunction = .hann(periodic: true),
        centerPadding: Bool = true
    ) {
        precondition(fftSize > 0 && (fftSize & (fftSize - 1)) == 0, "fftSize must be a power of 2")
        precondition(hopSize > 0 && hopSize <= fftSize, "hopSize must be in 1...fftSize")
        self.fftSize = fftSize
        self.hopSize = hopSize
        self.window = window
        self.centerPadding = centerPadding
    }

    public static let `default` = STFTConfiguration()
}
