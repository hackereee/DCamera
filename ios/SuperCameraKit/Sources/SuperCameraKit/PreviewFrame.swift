import Foundation

public struct PreviewFrame {
    public let y: Data
    public let u: Data
    public let v: Data
    public let width: Int
    public let height: Int
    public let timestampNs: Int64

    public init(y: Data, u: Data, v: Data, width: Int, height: Int, timestampNs: Int64) {
        self.y = y
        self.u = u
        self.v = v
        self.width = width
        self.height = height
        self.timestampNs = timestampNs
    }
}
