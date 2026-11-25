import Darwin
import XCTest
@testable import NetStatsCore

final class SwapSamplingTests: XCTestCase {
    func testPreservesKernelByteCountsWithoutPageSizeMultiplication() {
        let sample = SystemSampler.readSwap { usage, _ in
            usage.xsu_pagesize = 16_384
            usage.xsu_used = 4_322_328_576
            usage.xsu_total = 6_442_450_944
            return 0
        }
        XCTAssertEqual(sample, SwapUsage(usedBytes: 4_322_328_576, totalBytes: 6_442_450_944))
    }

    func testNoSwapAllocatedIsAValidReading() {
        XCTAssertEqual(SystemSampler.readSwap { _, _ in 0 }, SwapUsage(usedBytes: 0, totalBytes: 0))
    }

    func testDisplayDistinguishesUnallocatedSwapFromAnUnavailableReading() {
        XCTAssertEqual(ByteFormatter.swap(nil), "—")
        XCTAssertEqual(ByteFormatter.swap(SwapUsage(usedBytes: 0, totalBytes: 0)), "0 B / 0 B")
        XCTAssertEqual(ByteFormatter.swap(SwapUsage(usedBytes: 0, totalBytes: 1 << 30)), "0 B / 1.0 GB")
    }

    func testFailedOrIncompleteReadsDoNotReportZeroUsage() {
        XCTAssertNil(SystemSampler.readSwap { _, _ in -1 })
        XCTAssertNil(SystemSampler.readSwap { _, size in
            size = MemoryLayout<UInt64>.size
            return 0
        })
        XCTAssertNil(SystemSnapshot.empty.memory.swap)
    }
}
