import Testing

@testable import xcodeinstall

@Suite("XcodeVersionExtractor Tests")
struct XcodeVersionExtractorTests {

    @Test("Extract version from underscore-separated filename")
    func testUnderscoreSeparated() {
        #expect(XcodeVersionExtractor().extractVersion(from: "Xcode_14.0.1.xip") == "14.0.1")
    }

    @Test("Extract version from space-separated filename")
    func testSpaceSeparated() {
        #expect(XcodeVersionExtractor().extractVersion(from: "Xcode 14.xip") == "14")
    }

    @Test("Extract version from beta filename")
    func testBetaVersion() {
        #expect(XcodeVersionExtractor().extractVersion(from: "Xcode 14 beta 5.xip") == "14-beta-5")
    }

    @Test("Extract version from Release Candidate filename")
    func testReleaseCandidateVersion() {
        #expect(
            XcodeVersionExtractor().extractVersion(from: "Xcode_14.0.1_Release_Candidate.xip")
                == "14.0.1-Release-Candidate"
        )
    }

    @Test("Extract version from dash-separated filename")
    func testDashSeparated() {
        #expect(XcodeVersionExtractor().extractVersion(from: "Xcode-16.2.xip") == "16.2")
    }

    @Test("Extract version from .app filename")
    func testAppExtension() {
        #expect(XcodeVersionExtractor().extractVersion(from: "Xcode-14.0.1.app") == "14.0.1")
    }

    @Test("Returns nil for bare Xcode.xip")
    func testBareXcode() {
        #expect(XcodeVersionExtractor().extractVersion(from: "Xcode.xip") == nil)
    }

    @Test("Returns nil for non-Xcode filename")
    func testNonXcode() {
        #expect(XcodeVersionExtractor().extractVersion(from: "Something_else.xip") == nil)
    }

    @Test("Returns nil for unsupported extension")
    func testUnsupportedExtension() {
        #expect(XcodeVersionExtractor().extractVersion(from: "Xcode_14.0.1.dmg") == nil)
    }

    @Test("Extract version with simple number")
    func testSimpleNumber() {
        #expect(XcodeVersionExtractor().extractVersion(from: "Xcode_16.xip") == "16")
    }

    @Test("Strips Apple silicon suffix")
    func testAppleSiliconSuffix() {
        #expect(XcodeVersionExtractor().extractVersion(from: "Xcode_16.2_Apple_silicon.xip") == "16.2")
    }

    @Test("Strips Apple silicon suffix from .app")
    func testAppleSiliconSuffixApp() {
        #expect(XcodeVersionExtractor().extractVersion(from: "Xcode-26.5-Apple-silicon.app") == "26.5")
    }

    @Test("Strips Universal suffix")
    func testUniversalSuffix() {
        #expect(XcodeVersionExtractor().extractVersion(from: "Xcode_16.2_Universal.xip") == "16.2")
    }

    @Test("Strips Apple silicon suffix from beta")
    func testAppleSiliconBeta() {
        #expect(
            XcodeVersionExtractor().extractVersion(from: "Xcode 16 beta 3 Apple silicon.xip")
                == "16-beta-3"
        )
    }
}
