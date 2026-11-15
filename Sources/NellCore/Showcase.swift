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
    }

    /// What a step is there to show. The app checks each one after the step and logs any mismatch.
    public enum Visual: Hashable, Sendable {
        case face(Face), emoji(Emoji), body(Body), between(String), paper(Int), bubble(BubbleKindName), badge,
             console(ConsolePhase), placement(String)
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
    }

    public static let stepDuration: TimeInterval = 3

    /// `--showcase` alone (or followed by another flag) = all scenes; `--showcase <scene>` holds one; nil = not showcase.
    public static func requested(_ args: [String]) -> String?? {
        guard let i = args.firstIndex(of: "--showcase") else { return nil }
        let next = args.indices.contains(i + 1) ? args[i + 1] : nil
        return .some(next.flatMap { $0.hasPrefix("-") ? nil : $0 })
    }

    public static func scene(named name: String) -> Scene? { scenes.first { $0.name == name } }

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
