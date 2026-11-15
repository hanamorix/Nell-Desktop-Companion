import Foundation

/// Showcase mode: scenes that play every visual state through the real entry points (hook events, settles,
/// console actions, placement). Plain data, so a test can check it covers the whole sprite sheet and every bubble.
public enum Showcase {
    public enum Action: Sendable, Equatable {
        /// A hook event, encoded to JSON and decoded as the hook server does, then `NellModel.handle`.
        case hook(Mode, [String: JSONValue], requestId: String? = nil)
        /// A Code `Stop` whose transcript (written to the sandbox) reports this many context tokens.
        case stopWithContext(tokens: Int)
        /// `NellModel.requestSettled`: Allow, Deny or no decision.
        case settle(Mode, requestId: String, ApprovalAnswer)
        /// Typed into the bar and submitted: a user bubble.
        case say(String)
        case chatChip, codeChip, openConsole, minimiseConsole
        /// Nell's block at this fraction of the screen's free space (0,0 = bottom-left), then relayout.
        case place(x: Double, y: Double)
        /// A status-line reading (percent used; nil leaves that window as it was) whose windows reset in `resetsIn` seconds.
        case usage(session: Double?, weekly: Double?, resetsIn: TimeInterval)
        /// Switches the colour theme by name, as the Settings menu does.
        case theme(String)
    }

    /// What a step is there to show. The app checks each one after the step and logs any mismatch.
    public enum Visual: Hashable, Sendable {
        case face(Face), emoji(Emoji), body(Body), between(String), paper(Int), bubble(BubbleKindName), badge,
             console(ConsolePhase), placement(String), gauge(UsageKind, UsageLevel), theme(String)
    }

    public struct Step: Sendable {
        public let name: String
        public let actions: [Action]
        public let shows: [Visual]
        public init(_ name: String, _ actions: [Action], shows: [Visual] = []) { self.name = name; self.actions = actions; self.shows = shows }
    }

    /// Every scene starts from a fresh Nell: no sessions, no bubbles, console hidden, Chat selected, idle.
    public struct Scene: Sendable {
        public let name: String
        public let steps: [Step]
        /// Seconds between steps.
        public let stepDuration: TimeInterval
        public init(name: String, steps: [Step], stepDuration: TimeInterval = Showcase.stepDuration) {
            self.name = name; self.steps = steps; self.stepDuration = stepDuration
        }
    }

    public static let stepDuration: TimeInterval = 3

    /// `--showcase` alone (or followed by another flag) = all scenes; `--showcase <scene>` holds one; nil = not showcase.
    public static func requested(_ args: [String]) -> String?? {
        guard let i = args.firstIndex(of: "--showcase") else { return nil }
        let next = args.indices.contains(i + 1) ? args[i + 1] : nil
        return .some(next.flatMap { $0.hasPrefix("-") ? nil : $0 })
    }

    public static func scene(named name: String) -> Scene? { (scenes + stressScenes).first { $0.name == name } }

    // MARK: Hook JSON helpers

    static func hook(_ name: String, _ fields: [String: JSONValue] = [:], session: String = "showcase") -> [String: JSONValue] {
        fields.merging(["hook_event_name": .string(name), "session_id": .string(session)]) { a, _ in a }
    }
    static func bash(_ command: String) -> [String: JSONValue] { ["command": .string(command)] }
    static func pre(_ id: String, _ command: String) -> Action {
        .hook(.code, hook("PreToolUse", ["tool_name": .string("Bash"), "tool_input": .object(bash(command)), "tool_use_id": .string(id)]))
    }
    static func post(_ id: String, _ command: String, stdout: String = "") -> Action {
        .hook(.code, hook("PostToolUse", ["tool_name": .string("Bash"), "tool_input": .object(bash(command)), "tool_use_id": .string(id),
                                          "tool_response": .object(["stdout": .string(stdout), "stderr": .string(""), "interrupted": .bool(false)])]))
    }
    static func failed(_ id: String, _ command: String, error: String) -> Action {
        .hook(.code, hook("PostToolUseFailure", ["tool_name": .string("Bash"), "tool_input": .object(bash(command)), "tool_use_id": .string(id),
                                                 "error": .string(error), "is_interrupt": .bool(false)]))
    }
    static func prompt(_ m: Mode, _ text: String) -> Action { .hook(m, hook("UserPromptSubmit", ["prompt": .string(text)])) }
    static func stop(_ m: Mode, reply: String? = nil) -> Action {
        .hook(m, hook("Stop", reply.map { ["last_assistant_message": .string($0)] } ?? [:]))
    }
    static func stopFailure(_ m: Mode, _ error: String) -> Action { .hook(m, hook("StopFailure", ["error": .string(error)])) }
    static func permission(_ m: Mode, _ id: String, _ toolUseId: String, _ command: String) -> [Action] {
        [.hook(m, hook("PreToolUse", ["tool_name": .string("Bash"), "tool_input": .object(bash(command)), "tool_use_id": .string(toolUseId)])),
         .hook(m, hook("PermissionRequest", ["tool_name": .string("Bash"), "tool_input": .object(bash(command))]), requestId: id)]
    }
    static let questionInput: JSONValue = .object(["questions": .array([.object(["question": .string("Tabs or spaces for this project?")])])])
    static func question(_ id: String) -> [Action] {
        [.hook(.code, hook("PreToolUse", ["tool_name": .string("AskUserQuestion"), "tool_input": questionInput, "tool_use_id": .string("q1")])),
         .hook(.code, hook("PermissionRequest", ["tool_name": .string("AskUserQuestion"), "tool_input": questionInput]), requestId: id)]
    }

    static let passOut = "✔ Test run with 12 tests passed after 0.4 seconds."
    static let longChat = (1...14).map { "Line \($0): a longer Chat reply, so the bubble has to scroll to show all of it." }.joined(separator: "\n")
    static let longCode = "I refactored the session tracker so approvals settle in one place, moved the context meter onto the Code session only, "
        + "and added tests for every hook the showcase drives.\nNext, the compositor.\nThen the export script.\nThen the report."
    static let longUser = "Could you look at why the bubble column overlaps the console when Nell sits near the top of the screen, and fix it?"

    // MARK: Scenes

    public static let scenes: [Scene] = [
        Scene(name: "faces", steps: [
            Step("idle", [], shows: [.face(.idle), .body(.idle), .console(.hidden)]),
            Step("intent", [prompt(.chat, "hello")], shows: [.face(.intent), .body(.typing)]),
            // a test result with no PreToolUse first, so she stays typing and the face isn't hidden by a yawn
            Step("happy", [post("t1", "swift test", stdout: passOut)], shows: [.face(.happy), .emoji(.heart)]),
            Step("sad", [failed("t2", "swift test", error: "Exit code 1\n✘ Test run with 12 tests failed after 0.4 seconds with 1 issue.")],
                 shows: [.face(.sad), .emoji(.crying)]),
            Step("scared", permission(.chat, "r1", "u1", "rm -rf build"), shows: [.face(.scared), .emoji(.warning)]),
            Step("smile", [.settle(.chat, requestId: "r1", .allow)], shows: [.face(.smile), .emoji(.thumbsup)]),
            // exhausted shows on her last typing frames, behind a blink, before the yawn's drawn face takes over
            Step("exhausted", [pre("t3", "swift test")], shows: [.face(.exhausted), .body(.yawning), .between("typing-yawning")]),
        ]),
        Scene(name: "body", steps: [
            Step("idle", [], shows: [.body(.idle)]),
            Step("typing", [prompt(.chat, "go"), .hook(.chat, hook("PreToolUse", ["tool_name": .string("Read"), "tool_use_id": .string("c1")]))],
                 shows: [.body(.typing), .between("idle-typing")]),
            Step("yawning", [pre("t1", "npm test")], shows: [.body(.yawning), .between("typing-yawning")]),
            Step("back to typing", [post("t1", "npm test", stdout: "Tests: 4 passed, 4 total")],
                 shows: [.body(.typing), .between("yawning-typing")]),
            Step("typing to sleeping", [stop(.chat), stopFailure(.code, "rate_limit")], shows: [.body(.sleeping), .between("typing-sleeping"), .emoji(.plug)]),
            Step("sleeping to idle", [stop(.code)], shows: [.body(.idle), .between("sleeping-idle")]),
            Step("idle to sleeping", [stopFailure(.code, "rate_limit")], shows: [.body(.sleeping), .between("idle-sleeping")]),
            Step("limit lifts", [.hook(.code, hook("Notification", ["message": .string("Resuming"), "notification_type": .string("quota_auto_resume_fired")]))],
                 shows: [.body(.idle), .between("sleeping-idle")]),
            Step("typing again", [prompt(.chat, "and again")], shows: [.body(.typing), .between("idle-typing")]),
            Step("typing to idle", [stop(.chat)], shows: [.body(.idle), .between("typing-idle")]),
            // pairs with no drawn in-between: the animator routes them through idle or typing
            Step("idle to yawning", [prompt(.code, "run the tests"), pre("t2", "swift test")], shows: [.body(.yawning), .between("idle-yawning")]),
            Step("yawning to idle", [post("t2", "swift test", stdout: passOut)], shows: [.body(.idle), .between("yawning-idle")]),
            Step("yawning again", [prompt(.code, "and again"), pre("t3", "swift test")], shows: [.body(.yawning), .between("idle-yawning")]),
            Step("yawning to sleeping", [stopFailure(.code, "rate_limit")], shows: [.body(.sleeping), .between("yawning-sleeping")]),
            Step("sleeping to yawning", [prompt(.code, "try again"), pre("t4", "swift test")],
                 shows: [.body(.yawning), .between("sleeping-yawning")]),
            Step("yawning to sleeping again", [stopFailure(.code, "rate_limit")], shows: [.body(.sleeping), .between("yawning-sleeping")]),
            // her usual Code wake-up: the first tool call of a turn clears the limit mid-turn
            Step("sleeping to typing", [prompt(.chat, "wake up"), .hook(.chat, hook("PreToolUse", ["tool_name": .string("Read"), "tool_use_id": .string("c2")]))],
                 shows: [.body(.typing), .between("sleeping-typing")]),
            Step("typing to idle again", [stop(.chat)], shows: [.body(.idle)]),
        ]),
        Scene(name: "paper", steps:
            (1...5).map { n in Step("\(n) stacks", [.stopWithContext(tokens: n * 100_000 + 5_000)], shows: [.paper(n)]) }
            + [Step("cleared", [.hook(.code, hook("SessionStart", ["source": .string("clear")]))], shows: [.paper(0)])]),
        Scene(name: "emoji", steps: [
            Step("heart", [post("t1", "pytest", stdout: "3 passed in 0.1s")], shows: [.emoji(.heart)]),
            Step("thumbsup", permission(.code, "r1", "u1", "git push") + [.settle(.code, requestId: "r1", .allow)], shows: [.emoji(.thumbsup)]),
            Step("crying", [failed("t2", "pytest", error: "Exit code 1\n1 failed, 2 passed in 0.1s")], shows: [.emoji(.crying)]),
            Step("alert", [failed("u2", "ls nope", error: "Exit code 1\nls: nope: No such file or directory")], shows: [.emoji(.alert)]),
            Step("plug", [stopFailure(.chat, "rate_limit")], shows: [.emoji(.plug)]),
            Step("question", [stop(.chat)] + question("q1"), shows: [.emoji(.question)]),
            Step("warning", permission(.code, "r2", "u3", "rm -rf node_modules"),
                 shows: [.emoji(.warning)]),
            Step("warning over heart", [post("t3", "pytest", stdout: "5 passed in 0.1s")], shows: [.emoji(.warning), .face(.scared)]),
        ]),
        Scene(name: "bubbles", steps: [
            Step("short user", [.say("hi Nell")], shows: [.bubble(.user)]),
            Step("2-word chat reply", [prompt(.chat, "hi Nell"), stop(.chat, reply: "Hi there!")], shows: [.bubble(.reply)]),
            Step("long user", [.say(longUser)], shows: [.bubble(.user)]),
            Step("long chat reply scrolls", [prompt(.chat, longUser), stop(.chat, reply: longChat)], shows: [.bubble(.reply)]),
            Step("code reply, more in", [prompt(.code, "refactor it"), stop(.code, reply: longCode)], shows: [.bubble(.reply), .badge]),
            Step("status", [prompt(.code, "check"), pre("u1", "git status")], shows: [.bubble(.status)]),
            Step("alert", [.hook(.code, hook("Notification", ["message": .string("Claude is waiting for your input"), "notification_type": .string("idle_prompt")]))],
                 shows: [.bubble(.alert)]),
            Step("error", [stopFailure(.code, "server_error")], shows: [.bubble(.error)]),
            Step("approval", [prompt(.chat, "clean up")] + permission(.chat, "r1", "u2", "rm -rf build"), shows: [.bubble(.approval)]),
            Step("approval allowed", [.settle(.chat, requestId: "r1", .allow)], shows: [.bubble(.approval)]),
            Step("approval denied", permission(.chat, "r2", "u3", "git push --force") + [.settle(.chat, requestId: "r2", .deny)],
                 shows: [.bubble(.approval)]),
            Step("question", [prompt(.code, "set it up")] + question("q1"), shows: [.bubble(.question)]),
            Step("console needed", permission(.chat, "r3", "u4", "make deploy") + [.settle(.chat, requestId: "r3", .none)],
                 shows: [.bubble(.consoleNeeded)]),
        ]),
        Scene(name: "console", steps: [
            Step("hidden", [], shows: [.console(.hidden)]),
            Step("open", [.codeChip], shows: [.console(.open)]),
            Step("minimised with status", [.minimiseConsole, prompt(.code, "build it"), pre("u1", "swift build")], shows: [.console(.minimised)]),
            Step("minimised idle", [stop(.code)], shows: [.console(.minimised)]),
            Step("open again", [.openConsole], shows: [.console(.open)]),
            Step("back to chat", [.minimiseConsole, .chatChip], shows: [.console(.minimised)]),
        ]),
        Scene(name: "usage", steps: [
            Step("no reading", [], shows: [.gauge(.weekly, .none), .gauge(.session, .none), .face(.idle)]),
            // the tired windows reset 2 s later, before the next step; a reading still stamped with an old reset can't
            // bring them back, and the fresh windows after that climb again (each stamped later than the last)
            Step("tired", [.usage(session: 95, weekly: 50, resetsIn: 2)],
                 shows: [.gauge(.session, .high), .gauge(.weekly, .mid), .face(.exhausted), .body(.idle)]),
            Step("reset passed", [.usage(session: 95, weekly: 50, resetsIn: -60)],
                 shows: [.gauge(.session, .low), .gauge(.weekly, .low), .face(.idle)]),
            Step("low", [.usage(session: 20, weekly: 30, resetsIn: 3600)], shows: [.gauge(.weekly, .low), .gauge(.session, .low)]),
            Step("mid", [.usage(session: 60, weekly: 70, resetsIn: 3600)], shows: [.gauge(.weekly, .mid), .gauge(.session, .mid)]),
            Step("high", [.usage(session: 85, weekly: 81, resetsIn: 3600)], shows: [.gauge(.weekly, .high), .gauge(.session, .high), .face(.idle)]),
        ]),
        Scene(name: "themes", steps: [
            // the Stop comes first: it settles any open Chat approval, and the Allow/Deny buttons must stay on screen
            Step("dressed", [.say("Could you tidy the build folder?"), stop(.chat, reply: "Sure, I'll sort that out.")]
                    + permission(.chat, "r1", "u1", "rm -rf build")
                    + [.usage(session: 85, weekly: 60, resetsIn: 3600), .openConsole],
                 shows: [.bubble(.user), .bubble(.reply), .bubble(.approval), .gauge(.session, .high), .gauge(.weekly, .mid), .console(.open)]),
        ] + Themes.all.flatMap { [
            Step($0.id, [.theme($0.id), .openConsole], shows: [.theme($0.id), .console(.open)]),
            Step("\($0.id) minimised", [.minimiseConsole], shows: [.console(.minimised)]),
        ] }),
        // a pending approval under tall Chat bubbles: the column keeps it whole (Allow/Deny on screen), above her and below
        Scene(name: "crowded", steps: [
            Step("approval under tall bubbles", [prompt(.code, "clean up")] + permission(.code, "r1", "u1", "rm -rf build")
                    + [.say(longUser), prompt(.chat, longUser), stop(.chat, reply: longChat), .say("and a short one"),
                       prompt(.chat, "and a short one"), stop(.chat, reply: "Short reply.")],
                 shows: [.bubble(.approval), .bubble(.reply), .bubble(.user)]),
            Step("column below her", [.place(x: 0.75, y: 1)], shows: [.bubble(.approval)]),
            Step("console open", [.place(x: 1, y: 0), .openConsole], shows: [.bubble(.approval), .console(.open)]),
            Step("question with dismiss", [.minimiseConsole] + question("q1"), shows: [.bubble(.question)]),
            // two pinned bubbles with long text, below her: measures whether pinned rows alone outgrow the column
            Step("two tall pinned below her", [.settle(.code, requestId: "r1", .allow), .place(x: 0.75, y: 1)]
                    + permission(.code, "r2", "u2", "find . -name '*.orig' -o -name '*.rej' -o -name '*.bak' | xargs rm -f && git clean -fdx build dist"),
                 shows: [.bubble(.question), .bubble(.approval)]),
        ]),
        Scene(name: "placement", steps: [
            ("bottom-left quadrant", 0.25, 0.25), ("bottom-right quadrant", 0.75, 0.25),
            ("top-left quadrant", 0.25, 0.75), ("top-right quadrant", 0.75, 0.75),
            ("bottom-left corner", 0.0, 0.0), ("bottom-right corner", 1.0, 0.0),
            ("top-left corner", 0.0, 1.0), ("top-right corner", 1.0, 1.0),
        ].map { name, x, y in
            Step(name, [.place(x: x, y: y), .say("hi"), prompt(.chat, "hi"), stop(.chat, reply: "Hi there!")],
                 shows: [.placement(name), .bubble(.user), .bubble(.reply)])
        }),
    ]
}

extension Showcase {
    /// Load for `scripts/stress.sh`, played only by name: `idle` sits with no events past the 600 s long-quiet switch;
    /// `burst` fires about 20 hook events a second, with a console toggle and a placement change about once a second.
    public static let stressScenes: [Scene] = [
        Scene(name: "idle", steps: [Step("no events", [])], stepDuration: 24 * 3600),
        Scene(name: "burst", steps: (0..<200).map(burstStep), stepDuration: 0.05),
    ]

    static func burstStep(_ i: Int) -> Step {
        var a: [Action]
        switch i % 10 {
        case 0: a = [prompt(.code, "burst \(i)")]
        case 1: a = [pre("b\(i)", "ls")]
        case 2: a = [post("b\(i - 1)", "ls", stdout: "README.md")]
        case 3: a = [pre("t\(i)", "swift test")]
        case 4: a = [post("t\(i - 1)", "swift test", stdout: passOut)]
        case 5: a = [failed("f\(i)", "ls nope", error: "Exit code 1\nls: nope: No such file or directory")]
        case 6: a = [stop(.chat, reply: "Burst reply \(i)")]
        case 7: a = Array(permission(.code, "r\(i)", "p\(i)", "rm -rf build").suffix(1)) // the PermissionRequest
        case 8: a = [.settle(.code, requestId: "r\(i - 1)", .allow), prompt(.chat, "and \(i)")]
        default: a = [.stopWithContext(tokens: (i % 7) * 100_000)]
        }
        if i % 20 == 0 { a += [i % 40 == 0 ? .codeChip : .minimiseConsole, .place(x: Double(i % 7) / 6, y: Double(i % 5) / 4)] }
        return Step("burst \(i)", a)
    }
}

/// `BubbleKind` without its payload, so scenes can name kinds and a test can enumerate them.
public enum BubbleKindName: String, CaseIterable, Sendable { case user, reply, status, approval, question, alert, error, consoleNeeded }

extension BubbleKind {
    /// Exhaustive on purpose: a new `BubbleKind` won't compile until it has a name, and then the showcase test fails.
    public var name: BubbleKindName {
        switch self {
        case .user: .user
        case .reply: .reply
        case .status: .status
        case .approval: .approval
        case .question: .question
        case .alert: .alert
        case .error: .error
        case .consoleNeeded: .consoleNeeded
        }
    }
}
