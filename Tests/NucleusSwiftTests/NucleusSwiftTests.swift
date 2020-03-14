import XCTest
@testable import NucleusSwift

final class NucleusSwiftTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        let Nucleus = NucleusClient("5e6d0f14341df6a7e35d5859")
        Nucleus.debug = true
        Nucleus.apiUrl = "ws://localhost:5000"
        Nucleus.appStarted()
        
        Nucleus.track(name: "ACTION1")
        
        print("running test")
        
//        XCTAssertEqual(Nucleus.appId, "test4")
        
        sleep(20)
        
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
