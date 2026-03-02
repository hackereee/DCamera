import Foundation

enum TimestampConversion {
    static func toNanoseconds(value: Int64, timescale: Int32) -> Int64 {
        guard timescale > 0, value >= 0 else { return 0 }

        let scale = Int64(timescale)
        let quotient = value / scale
        let remainder = value % scale

        let billion: Int64 = 1_000_000_000
        let qMul = quotient.multipliedReportingOverflow(by: billion)
        if qMul.overflow {
            return Int64.max
        }

        let rMul = remainder.multipliedReportingOverflow(by: billion)
        if rMul.overflow {
            return Int64.max
        }
        let remPart = rMul.partialValue / scale

        let sum = qMul.partialValue.addingReportingOverflow(remPart)
        if sum.overflow {
            return Int64.max
        }
        return sum.partialValue
    }
}
