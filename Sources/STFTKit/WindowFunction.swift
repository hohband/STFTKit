import Foundation

public enum WindowFunction: Sendable {
    case hann(periodic: Bool = true)
    case hamming(periodic: Bool = true)

    public func generate(length: Int) -> [Float] {
        switch self {
        case .hann(let periodic):
            return Self.hannWindow(length: length, periodic: periodic)
        case .hamming(let periodic):
            return Self.hammingWindow(length: length, periodic: periodic)
        }
    }

    private static func hannWindow(length: Int, periodic: Bool) -> [Float] {
        let denominator = periodic ? Float(length) : Float(length - 1)
        return (0..<length).map { i in
            0.5 * (1.0 - cos(2.0 * .pi * Float(i) / denominator))
        }
    }

    private static func hammingWindow(length: Int, periodic: Bool) -> [Float] {
        let denominator = periodic ? Float(length) : Float(length - 1)
        return (0..<length).map { i in
            0.54 - 0.46 * cos(2.0 * .pi * Float(i) / denominator)
        }
    }
}
