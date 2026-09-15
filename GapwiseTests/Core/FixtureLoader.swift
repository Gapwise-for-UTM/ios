import Foundation
import XCTest

private final class FixtureBundleToken {}

enum FixtureLoader {
    static func data(named name: String) throws -> Data {
        let bundle: Bundle
        #if SWIFT_PACKAGE
            bundle = .module
        #else
            bundle = Bundle(for: FixtureBundleToken.self)
        #endif

        let url =
            bundle.url(forResource: name, withExtension: "ics", subdirectory: "Fixtures")
            ?? bundle.url(forResource: name, withExtension: "ics")
        return try Data(contentsOf: XCTUnwrap(url, "Missing fixture \(name).ics"))
    }
}
