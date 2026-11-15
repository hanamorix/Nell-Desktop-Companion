import Foundation
import Testing
@testable import NellCore

private let shows = Set(Showcase.scenes.flatMap { $0.steps.flatMap(\.shows) })

/// Every face, emoji, body loop and in-between in the real exported sheet has a showcase step.
@Test func showcaseCoversTheWholeSheet() throws {
    let unusedFaces: Set<String> = ["awe"] // drawn but unused: the user chose scared for approvals (Task 7)
    for name in try realSheet().tags.keys.sorted() {
        let parts = name.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { continue }
        let (kind, value) = (parts[0], parts[1])
        switch kind {
        case "face":
            if unusedFaces.contains(value) { continue }
            let f = try #require(Face(rawValue: value), "\(name) has no Face case")
            #expect(shows.contains(.face(f)), "\(name)")
        case "emoji":
            let e = try #require(Emoji(rawValue: value), "\(name) has no Emoji case")
            #expect(shows.contains(.emoji(e)), "\(name)")
        case "body":
            let b = try #require(Body(rawValue: value), "\(name) has no Body case")
            #expect(shows.contains(.body(b)), "\(name)")
        case "between": #expect(shows.contains(.between(value)), "\(name)")
        default: break
        }
    }
    for f in [Face.idle, .intent, .exhausted, .happy, .smile, .sad, .scared] { #expect(shows.contains(.face(f)), "\(f)") }
    for e in Emoji.allCases { #expect(shows.contains(.emoji(e)), "\(e)") }
}

@Test func showcaseCoversBubblesConsoleAndPlacement() {
    for k in BubbleKindName.allCases { #expect(shows.contains(.bubble(k)), "\(k)") }
    #expect(shows.contains(.badge))
    for p in [ConsolePhase.hidden, .open, .minimised] { #expect(shows.contains(.console(p)), "\(p)") }
    for n in 0...5 { #expect(shows.contains(.paper(n)), "\(n) stacks") }
    let places = shows.compactMap { if case .placement(let p) = $0 { p } else { nil } }
    #expect(places.count == 8, "four quadrants and four corners")
    #expect(Set(Showcase.scenes.map(\.name)).count == Showcase.scenes.count, "scene names are unique")
}

/// Each synthetic hook goes through the same decoder the hook server uses.
@Test func showcaseHooksDecode() throws {
    for scene in Showcase.scenes {
        for step in scene.steps {
            for case .hook(_, let fields, _) in step.actions {
                let e = try HookEvent.decode(JSONEncoder().encode(fields))
                #expect(!e.name.isEmpty && !e.sessionId.isEmpty, "\(scene.name)/\(step.name)")
            }
        }
    }
}

@Test func showcaseArguments() {
    #expect(Showcase.requested(["Nell"]) == nil)
    #expect(Showcase.requested(["Nell", "--showcase"]) == .some(nil))
    #expect(Showcase.requested(["Nell", "--showcase", "bubbles"]) == .some("bubbles"))
    #expect(Showcase.requested(["Nell", "--showcase", "-NSDocumentRevisionsDebugMode"]) == .some(nil))
    #expect(Showcase.scene(named: "paper")?.steps.count == 6)
    #expect(Showcase.scene(named: "nope") == nil)
}
