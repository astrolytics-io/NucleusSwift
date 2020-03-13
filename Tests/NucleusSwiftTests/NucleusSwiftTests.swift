import XCTest
@testable import NucleusSwift

final class NucleusSwiftTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        let Nucleus = NucleusClient("test")
        Nucleus.debug = true
        Nucleus.appStarted()
        
        Nucleus.track(name: "ACTION1")
        
        print("running test")
        
        XCTAssertEqual(Nucleus.appId, "test")
        
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
