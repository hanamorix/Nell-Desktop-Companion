import Foundation
import Testing
@testable import NellCore

/// The app's palette must be exactly the design system's base colours (tokens.json), both ways.
@Test func plumNightMatchesTokensJSON() throws {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "../../concept-nell-design-system/tokens.json")
    let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
    let tokens = (json["color"] as! [String: Any])["tokens"] as! [[String: String]]
    var base: [String: String] = [:]
    for t in tokens where t["value"]?.hasPrefix("#") == true { base[t["name"]!] = t["value"]! }
    #expect(base.count == 22)
    #expect(PlumNight.palette == base)
}
