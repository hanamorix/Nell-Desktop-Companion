import CryptoKit
import Foundation
import Testing
@testable import NellCore

// MARK: finding Claude Code and kitty

@Test func claudeComesFromYourLoginShellFirst() {
    let all: (String) -> Bool = { _ in true }
    // rc files may print anything first; only the marked line counts
    let said = "Welcome back!\n/usr/local/bin/other\n\nnell-claude=/Users/x/.nvm/versions/node/v22/bin/claude\n"
    #expect(locateClaude(shellOutput: said, home: "/Users/x", isExecutable: all) == "/Users/x/.nvm/versions/node/v22/bin/claude")
}

@Test func claudeFallsBackToTheUsualPlaces() {
    let home = "/Users/x"
    // not found, an alias or a function, a relative PATH entry, or a hung shell (no output): the fixed places, in order
    for said in ["nell-claude=\n", "nell-claude=claude\n", "nell-claude=bin/claude\n", "", "/usr/local/bin/foo\n"] {
        #expect(locateClaude(shellOutput: said, home: home, isExecutable: { $0 == "/opt/homebrew/bin/claude" }) == "/opt/homebrew/bin/claude", "\(said)")
    }
    #expect(claudeCandidates(home: home) == ["/Users/x/.local/bin/claude", "/opt/homebrew/bin/claude", "/usr/local/bin/claude",
                                             "/Users/x/.claude/local/claude", "/Users/x/.npm-global/bin/claude"])
    // the shell's answer must still be a file you can run
    #expect(locateClaude(shellOutput: "nell-claude=/gone/claude\n", home: home, isExecutable: { $0 == "/Users/x/.local/bin/claude" })
            == "/Users/x/.local/bin/claude")
    #expect(locateClaude(shellOutput: "", home: home, isExecutable: { _ in false }) == nil)
}

@Test func claudeLookupAsksTheShellClaudeWillRunIn() throws {
    let a = claudeLookup(shell: "/bin/zsh", home: "/Users/x")
    #expect(Array(a.prefix(4)) == ["/bin/zsh", "-l", "-i", "-c"])
    // sh inherits the login shell's PATH, so it finds the file claude will be, never an alias
    #expect(Array(a.suffix(3)) == ["/bin/sh", "-c", #"printf '\nnell-claude=%s\n' "$(command -v claude)""#])
    // the real thing, with a home whose rc prints and puts a fake claude on PATH
    let home = FileManager.default.temporaryDirectory.appending(path: "nell-claude-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: home.appending(path: "bin"), withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }
    try "#!/bin/sh\n".write(to: home.appending(path: "bin/claude"), atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: home.appending(path: "bin/claude").path)
    try "echo hello from zshrc\nexport PATH=\"$HOME/bin:$PATH\"\n".write(to: home.appending(path: ".zshrc"), atomically: true, encoding: .utf8)
    let env = KittyCommands.cleanEnvironment(home: home.path, user: "nobody", shell: "/bin/zsh", session: [:])
    let r = runTool(claudeLookup(shell: "/bin/zsh", home: home.path), environment: env, timeout: 10)
    #expect(locateClaude(shellOutput: String(decoding: r.out, as: UTF8.self), home: home.path) == home.appending(path: "bin/claude").path)
}

@Test func isExecutableFileRejectsFolders() {
    #expect(isExecutableFile("/bin/sh"))
    #expect(!isExecutableFile("/bin"))
    #expect(!isExecutableFile("/nonexistent"))
}

@Test func kittyIsFoundInApplicationsThenYourApplications() {
    #expect(kittyApps(home: "/Users/x") == ["/Applications/kitty.app", "/Users/x/Applications/kitty.app"])
    let mine: (String) -> Bool = { $0.hasPrefix("/Users/x/Applications/kitty.app/") }
    #expect(locateKitty(home: "/Users/x", isExecutable: mine) == "/Users/x/Applications/kitty.app")
    #expect(locateKitty(home: "/Users/x", isExecutable: { _ in true }) == "/Applications/kitty.app")
    #expect(locateKitty(home: "/Users/x", isExecutable: { _ in false }) == nil)
    // a kitty.app missing its kitten can't run Nell's panel
    #expect(locateKitty(home: "/Users/x", isExecutable: { mine($0) && !$0.hasSuffix("kitten") }) == nil)
}

// MARK: the release and the signature

private let dmgURL = "https://github.com/kovidgoyal/kitty/releases/download/v0.50.0/kitty-0.50.0.dmg"

private func release(_ assets: [[String: Any]]) -> Data { try! JSONSerialization.data(withJSONObject: ["tag_name": "v0.50.0", "assets": assets]) }
private func asset(_ name: String, url: String? = nil, size: Int = 10, digest: String? = nil) -> [String: Any] {
    var a: [String: Any] = ["name": name, "size": size, "browser_download_url": url ?? "https://github.com/kovidgoyal/kitty/releases/download/v0.50.0/\(name)"]
    a["digest"] = digest
    return a
}

@Test func theDMGIsPickedByItsExactName() {
    // the real release's neighbours: signatures, kittens, tarballs
    let json = release([asset("kitty-0.50.0.dmg.sig"), asset("kitten-darwin-arm64"), asset("kitty-0.50.0-arm64.txz"),
                        asset("kitty-0.50.0.dmg", size: 80076984, digest: "sha256:CC01"), asset("kitty-0.50.0.tar.xz")])
    #expect(kittyDMG(fromRelease: json) == KittyDMG(name: "kitty-0.50.0.dmg", url: dmgURL, size: 80076984, sha256: "cc01"))
    #expect(kittyDMG(fromRelease: release([asset("kitty-0.50.0.dmg")]))?.sha256 == nil, "no digest published: size only")
    #expect(kittyDMG(fromRelease: release([asset("kitty-0.50.0.dmg", digest: "sha512:ab")]))?.sha256 == nil)
}

@Test func aDMGFromAnywhereElseIsRefused() {
    #expect(kittyDMG(fromRelease: release([asset("kitty-0.50.0.dmg", url: "https://evil.example/kitty-0.50.0.dmg")])) == nil)
    #expect(kittyDMG(fromRelease: release([asset("kitty-0.50.0.dmg", url: "http://github.com/kovidgoyal/kitty/releases/download/v0.50.0/kitty-0.50.0.dmg")])) == nil)
    #expect(kittyDMG(fromRelease: release([asset("kitty-0.50.0.dmg", url: "https://github.com/kovidgoyal/kitty/releases/download/v0.50.0/other.dmg")])) == nil)
    #expect(kittyDMG(fromRelease: release([asset("evil-kitty-0.50.0.dmg")])) == nil)
    #expect(kittyDMG(fromRelease: release([asset("kitty-0.50.0.dmg", size: 0)])) == nil)
    #expect(kittyDMG(fromRelease: Data("{\"message\":\"API rate limit exceeded\"}".utf8)) == nil)
    #expect(kittyDMG(fromRelease: Data("garbage".utf8)) == nil)
}

@Test func teamComesFromItsOwnLineOfCodesignOutput() {
    let real = "Executable=/Volumes/kitty/kitty.app/Contents/MacOS/kitty\nIdentifier=net.kovidgoyal.kitty\nTeamIdentifier=NTY7FVCEKP\nRuntime Version=26.2.0\n"
    #expect(teamIdentifier(fromCodesign: real) == "NTY7FVCEKP")
    #expect(teamIdentifier(fromCodesign: "Identifier=x\nTeamIdentifier=not set\n") == "not set")
    #expect(teamIdentifier(fromCodesign: "Identifier=TeamIdentifier=NTY7FVCEKP\n") == nil)
    #expect(teamIdentifier(fromCodesign: "") == nil)
}

// MARK: the installer, with every tool faked

/// Answers the installer's commands as the real tools would on a good download, unless told to fail a step.
private final class FakeTools: @unchecked Sendable {
    var calls: [[String]] = []
    var dmgBytes = Data(repeating: 7, count: 4096)
    var served: Data? // what the download writes, if not the real bytes (a truncated download)
    var team = "NTY7FVCEKP"
    var failing: Set<String> = [] // "api", "download", "attach", "verify", "verify-copy", "spctl", "ditto"
    var symlinkApp = false
    lazy var json = release([asset("kitty-0.50.0.dmg.sig"), asset("kitty-0.50.0.dmg", size: dmgBytes.count,
                             digest: "sha256:" + SHA256.hash(data: dmgBytes).map { String(format: "%02x", $0) }.joined())])

    func run(_ a: [String]) -> (status: Int32, out: Data) {
        calls.append(a)
        let fm = FileManager.default
        func fail(_ step: String, _ said: String = "") -> (status: Int32, out: Data)? { failing.contains(step) ? (1, Data(said.utf8)) : nil }
        switch (a[0] as NSString).lastPathComponent {
        case "curl":
            let out = URL(fileURLWithPath: a[a.firstIndex(of: "-o")! + 1])
            if a.last!.hasPrefix("https://api.github.com/") {
                if let f = fail("api", "curl: (6) Could not resolve host: api.github.com") { return f }
                try! json.write(to: out)
            } else {
                try! (served ?? dmgBytes).write(to: out)
                if let f = fail("download", "curl: (18) transfer closed with 100 bytes remaining") { return f }
            }
        case "hdiutil" where a[1] == "attach":
            if let f = fail("attach", "hdiutil: attach failed - image not recognized") { return f }
            let mount = URL(fileURLWithPath: a[a.firstIndex(of: "-mountpoint")! + 1])
            try! fm.createDirectory(at: mount, withIntermediateDirectories: true)
            if symlinkApp { try! fm.createSymbolicLink(atPath: mount.appending(path: "kitty.app").path, withDestinationPath: "/Applications/kitty.app") }
            else { try! fm.createDirectory(at: mount.appending(path: "kitty.app/Contents/MacOS"), withIntermediateDirectories: true) }
        case "hdiutil": break // detach
        case "codesign" where a[1] == "-dv": return (0, Data("Identifier=net.kovidgoyal.kitty\nTeamIdentifier=\(team)\n".utf8))
        case "codesign":
            let copy = !a.last!.contains("/mount/")
            if let f = fail(copy ? "verify-copy" : "verify", "kitty.app: a sealed resource is missing or invalid") { return f }
        case "spctl": if let f = fail("spctl", "kitty.app: rejected") { return f }
        case "ditto":
            try! fm.createDirectory(at: URL(fileURLWithPath: a[2]).appending(path: "Contents"), withIntermediateDirectories: true) // a partial copy
            if let f = fail("ditto", "ditto: No space left on device") { return f }
            try! fm.removeItem(atPath: a[2]); try! fm.copyItem(atPath: a[1], toPath: a[2])
        default: Issue.record("unexpected tool \(a)")
        }
        return (0, Data())
    }
    func ran(_ tool: String, _ sub: String? = nil) -> Bool { calls.contains { $0[0].hasSuffix("/" + tool) && (sub == nil || $0.contains(sub!)) } }
    var tempDir: String? { calls.first.map { a in ((a[a.firstIndex(of: "-o")! + 1]) as NSString).deletingLastPathComponent } }
}

private func folder() -> URL { FileManager.default.temporaryDirectory.appending(path: "nell-install-\(UUID().uuidString)/Applications") }

@Test func aGoodDownloadIsVerifiedThenInstalled() throws {
    let tools = FakeTools(), into = folder()
    defer { try? FileManager.default.removeItem(at: into.deletingLastPathComponent()) }
    let app = try installKitty(into: into, run: tools.run)
    #expect(app == into.appending(path: "kitty.app"))
    #expect(FileManager.default.fileExists(atPath: app.appending(path: "Contents/MacOS").path), "the folder was created and kitty copied in")
    let order = tools.calls.map { ($0[0] as NSString).lastPathComponent + ($0.count > 1 ? " " + $0[1] : "") }
    #expect(order == ["curl -fsSL", "curl -fsSL", "hdiutil attach", "codesign --verify", "spctl --assess", "codesign -dv",
                      "ditto " + (tools.calls[6][1]), "codesign --verify", "spctl --assess", "codesign -dv", "hdiutil detach"])
    let attach = try #require(tools.calls.first { $0.contains("attach") })
    for flag in ["-nobrowse", "-readonly", "-noautoopen"] { #expect(attach.contains(flag)) }
    #expect(tools.calls[0].contains("=https") && tools.calls[1].contains("=https") && tools.calls[1].last == dmgURL)
    #expect(try FileManager.default.contentsOfDirectory(atPath: into.path) == ["kitty.app"], "no staging copy left")
    #expect(!FileManager.default.fileExists(atPath: try #require(tools.tempDir)), "the download is deleted")
}

/// Every way it can go wrong: a clear reason, no kitty.app, no staging copy, the image detached, the download deleted.
@Test(arguments: [
    ("api", "GitHub"), ("download", "download"), ("truncated", "incomplete"), ("corrupt", "checksum"), ("attach", "open"),
    ("verify", "signature"), ("spctl", "Gatekeeper"), ("team", "WRONGTEAM1"), ("symlink", "no kitty.app"),
    ("ditto", "copy"), ("verify-copy", "signature"),
])
func anyFailureAbortsAndLeavesNothingInstalled(step: String, reason: String) throws {
    let tools = FakeTools(), into = folder()
    defer { try? FileManager.default.removeItem(at: into.deletingLastPathComponent()) }
    switch step {
    case "truncated": tools.served = tools.dmgBytes.prefix(1000)
    case "corrupt": var d = tools.dmgBytes; d[10] = 0; tools.served = d
    case "team": tools.team = "WRONGTEAM1"
    case "symlink": tools.symlinkApp = true
    default: tools.failing = [step]
    }
    #expect {
        try installKitty(into: into, run: tools.run)
    } throws: { e in
        (e as? InstallFailed)?.description.contains(reason) == true
    }
    #expect(!FileManager.default.fileExists(atPath: into.appending(path: "kitty.app").path), "\(step): nothing installed")
    #expect(((try? FileManager.default.contentsOfDirectory(atPath: into.path)) ?? []).isEmpty, "\(step): no staging copy left")
    #expect(tools.ran("hdiutil", "attach") == tools.ran("hdiutil", "detach"), "\(step): every mount is detached")
    #expect(!FileManager.default.fileExists(atPath: try #require(tools.tempDir)), "\(step): the download is deleted")
    if ["api", "download", "truncated", "corrupt"].contains(step) { #expect(!tools.ran("hdiutil"), "\(step): an unchecked download is never even mounted") }
    if step != "ditto" && step != "verify-copy" { #expect(!tools.ran("ditto"), "\(step): nothing unverified is copied") }
}

@Test func anExistingKittyIsNeverReplaced() throws {
    let tools = FakeTools(), into = folder()
    defer { try? FileManager.default.removeItem(at: into.deletingLastPathComponent()) }
    try FileManager.default.createDirectory(at: into.appending(path: "kitty.app/Contents/yours"), withIntermediateDirectories: true)
    #expect(throws: InstallFailed.self) { try installKitty(into: into, run: tools.run) }
    #expect(FileManager.default.fileExists(atPath: into.appending(path: "kitty.app/Contents/yours").path))
    #expect(tools.calls.isEmpty)
}

@Test func aCopyLeftByAnInterruptedInstallIsReplaced() throws {
    let tools = FakeTools(), into = folder()
    defer { try? FileManager.default.removeItem(at: into.deletingLastPathComponent()) }
    try FileManager.default.createDirectory(at: into.appending(path: ".kitty.app.nell-install/Contents/half"), withIntermediateDirectories: true)
    _ = try installKitty(into: into, run: tools.run)
    #expect(try FileManager.default.contentsOfDirectory(atPath: into.path) == ["kitty.app"])
}

/// The real pipeline, once, into a throwaway folder: `NELL_LIVE_KITTY_INSTALL=<empty folder> scripts/test.sh --filter liveKitty`.
@Test(.enabled(if: ProcessInfo.processInfo.environment["NELL_LIVE_KITTY_INSTALL"] != nil))
func liveKittyInstallIntoATempFolder() throws {
    let into = URL(fileURLWithPath: ProcessInfo.processInfo.environment["NELL_LIVE_KITTY_INSTALL"]!)
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    try #require(!into.path.hasPrefix("/Applications") && !into.path.hasPrefix(home + "/Applications"), "never a real Applications folder")
    let app = try installKitty(into: into, run: { a in
        let r = runTool(a, stderr: true)
        print("RUN \(a.joined(separator: " "))\n  -> \(r.status) \(String(decoding: r.out, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))")
        return r
    })
    print("INSTALLED \(app.path)")
    #expect(runTool(["/usr/bin/codesign", "--verify", "--deep", "--strict", app.path]).status == 0)
}
