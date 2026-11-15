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

// MARK: Stress scenes (by name only; not in the showcase cycle)

@Test func idleSceneHoldsWithNoEvents() throws {
    let idle = try #require(Showcase.scene(named: "idle"))
    #expect(idle.steps.count == 1 && idle.steps[0].actions.isEmpty)
    #expect(idle.stepDuration >= 3600, "never resets during a 10 min idle phase")
    #expect(!Showcase.scenes.contains { $0.name == "idle" || $0.name == "burst" }, "the default cycle skips the stress scenes")
}

@Test func burstSceneIsAbout20EventsASecond() throws {
    let burst = try #require(Showcase.scene(named: "burst"))
    let perSecond = 1 / burst.stepDuration
    let hooks = burst.steps.reduce(0) { n, s in n + s.actions.filter { if case .hook = $0 { true } else if case .stopWithContext = $0 { true } else { false } }.count }
    let rate = Double(hooks) / (Double(burst.steps.count) / perSecond)
    #expect(rate >= 18 && rate <= 30, "\(rate) hook events per second")
    let moves = burst.steps.filter { $0.actions.contains { if case .place = $0 { true } else { false } } }.count
    let seconds = Double(burst.steps.count) / perSecond
    #expect(Double(moves) / seconds >= 0.9 && Double(moves) / seconds <= 1.1, "a placement change about once a second")
    let console = burst.steps.filter { $0.actions.contains { $0 == .codeChip || $0 == .minimiseConsole } }.count
    #expect(Double(console) / seconds >= 0.9, "console open/minimise about once a second")
    for kind in ["PreToolUse", "PostToolUse", "PostToolUseFailure", "Stop", "PermissionRequest", "UserPromptSubmit"] {
        #expect(burst.steps.contains { $0.actions.contains { if case .hook(_, let f, _) = $0 { f["hook_event_name"] == .string(kind) } else { false } } }, "\(kind)")
    }
}

@Test func showcasePlaysTheRoutedBodyChanges() {
    // pairs with no drawn in-between of their own: the animator routes them through idle or typing
    for pair in ["sleeping-typing", "sleeping-yawning", "yawning-idle", "yawning-sleeping", "idle-yawning"] {
        #expect(shows.contains(.between(pair)), "\(pair)")
    }
}

@Test func showcaseCoversUsageChips() {
    for k in [UsageKind.session, .weekly] { for l in [UsageLevel.none, .low, .mid, .high] { #expect(shows.contains(.gauge(k, l)), "\(k) \(l)") } }
    let tired = Showcase.scenes.flatMap(\.steps).contains { s in
        s.shows.contains(.face(.exhausted)) && s.shows.contains(.body(.idle))
            && s.actions.contains { if case .usage(let a, let b, _) = $0 { (a ?? 0) > 90 || (b ?? 0) > 90 } else { false } }
    }
    #expect(tired)
}
