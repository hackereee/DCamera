import Foundation

public protocol VideoEncoderProtocol {
    func start(path: String, width: Int, height: Int)
    func encodeFrame(_ data: Data) -> Bool
    func finalizeOutput() -> Bool
    func release()
}
