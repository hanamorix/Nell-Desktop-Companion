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
    #expect(Array(a.prefix(6)) == ["/usr/bin/env", "NELL_MODE=code", "/bin/zsh", "-l", "-i", "-c"])
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
    #expect(locateClaude(shellOutput: String(decoding: r.out, as: UTF8.self), home: home.path) == home.appending(path: "bin/claude").path, "status \(r.status): \(String(decoding: r.out, as: UTF8.self))")
}

/// The README's guard for an rc that execs tmux checks NELL_MODE; the lookup is started as Code is, so it sees it too.
@Test func claudeLookupPassesTheNellModeGuard() throws {
    let home = FileManager.default.temporaryDirectory.appending(path: "nell-claude-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: home.appending(path: "bin"), withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }
    try "#!/bin/sh\n".write(to: home.appending(path: "bin/claude"), atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: home.appending(path: "bin/claude").path)
    // an nvm-style PATH set in the rc, then the guarded takeover (a stand-in for `exec tmux`)
    let rc = "export PATH=\"$HOME/bin:$PATH\"\n[ -z \"$NELL_MODE\" ] && exec /usr/bin/true\n"
    for f in [".zshrc", ".bash_profile"] { try rc.write(to: home.appending(path: f), atomically: true, encoding: .utf8) }
    for shell in ["/bin/zsh", "/bin/bash"] {
        let env = KittyCommands.cleanEnvironment(home: home.path, user: "nobody", shell: shell, session: [:])
        let r = runTool(claudeLookup(shell: shell, home: home.path), environment: env, timeout: 10)
        #expect(locateClaude(shellOutput: String(decoding: r.out, as: UTF8.self), home: home.path) == home.appending(path: "bin/claude").path,
                "\(shell) status \(r.status): \(String(decoding: r.out, as: UTF8.self))")
    }
}

@Test func isExecutableFileRejectsFolders() {
    #expect(isExecutableFile("/bin/sh"))
    #expect(!isExecutableFile("/bin"))
    #expect(!isExecutableFile("/nonexistent"))
}

@Test func kittyIsFoundInApplicationsThenYourApplications() {
    #expect(kittyApps(home: "/Users/x") == ["/Applications/kitty.app", "/Users/x/Applications/kitty.app"])
    let mine: (String) -> Bool = { $0.hasPrefix("/Users/x/Applications/kitty.app") }
    let current: (String) -> String? = { _ in minKittyVersion }
    func find(_ isExecutable: @escaping (String) -> Bool, _ version: @escaping (String) -> String? = current,
              exists: @escaping (String) -> Bool = { _ in false }) -> KittyFound {
        findKitty(home: "/Users/x", isExecutable: isExecutable, version: version, exists: exists)
    }
    #expect(find(mine) == .ready("/Users/x/Applications/kitty.app"))
    #expect(find({ _ in true }) == .ready("/Applications/kitty.app"))
    #expect(find({ _ in false }) == .missing)
    // a kitty.app missing its kitten can't run Nell's panel; the installer won't replace it, so say what to do
    #expect(find({ mine($0) && !$0.hasSuffix("kitten") }, exists: mine) == .blocked(version: nil))
}

/// A kitty older than the panel and remote-control flags Nell uses would only fail once started; it's skipped like a
/// missing one, and the current one is installed beside it.
@Test func aTooOldKittyIsSkippedForACurrentOne() {
    let all: (String) -> Bool = { _ in true }
    let mine: (String) -> Bool = { $0.hasPrefix("/Users/x/Applications/kitty.app") }
    let oldInApplications: (String) -> String? = { $0.hasPrefix("/Applications/") ? "0.41.1" : minKittyVersion }
    #expect(findKitty(home: "/Users/x", isExecutable: all, version: oldInApplications, exists: { _ in true })
            == .ready("/Users/x/Applications/kitty.app"), "an install beside the old one is used from then on")
    #expect(findKitty(home: "/Users/x", isExecutable: { !mine($0) }, version: oldInApplications, exists: { !mine($0) })
            == .tooOld(version: "0.41.1"), "offer the install into ~/Applications")
    #expect(findKitty(home: "/Users/x", isExecutable: all, version: { _ in "0.41.1" }, exists: { _ in true })
            == .blocked(version: "0.41.1"), "the old one is in ~/Applications, where the installer would go")
    #expect(findKitty(home: "/Users/x", isExecutable: { !mine($0) }, version: { _ in nil }, exists: { !mine($0) })
            == .tooOld(version: nil), "a version Nell can't read isn't trusted")
    #expect(findKitty(home: "/Users/x", isExecutable: { !mine($0) }, version: { _ in "" }, exists: { !mine($0) })
            == .tooOld(version: nil), "an empty one is no version")
}

@Test func kittyVersionsCompareByNumber() {
    #expect(versionAtLeast("0.50.0", "0.50.0"))
    #expect(versionAtLeast("0.50", "0.50.0"))
    #expect(versionAtLeast("0.50.0", "0.50"))
    #expect(versionAtLeast("0.50.1", "0.50.0"))
    #expect(versionAtLeast("1.0", "0.50.0"))
    #expect(versionAtLeast("0.10", "0.9"))
    #expect(!versionAtLeast("0.9", "0.10"))
    #expect(!versionAtLeast("0.49.2", "0.50.0"))
    #expect(!versionAtLeast("0.5.0", "0.50.0"))
    #expect(!versionAtLeast("", "0.50.0"))
    #expect(!versionAtLeast("garbage", "0.50.0"))
    // a build suffix is compared by its numeric prefix
    #expect(versionAtLeast("0.50.0+git", "0.50.0"))
    #expect(versionAtLeast("0.50.1-dev", "0.50.0"))
    #expect(!versionAtLeast("0.49.2+git", "0.50.0"))
}

@Test func kittyVersionIsReadFromItsInfoPlist() throws {
    let app = FileManager.default.temporaryDirectory.appending(path: "nell-kitty-\(UUID().uuidString)/kitty.app")
    defer { try? FileManager.default.removeItem(at: app.deletingLastPathComponent()) }
    #expect(kittyVersion(app.path) == nil)
    try FileManager.default.createDirectory(at: app.appending(path: "Contents"), withIntermediateDirectories: true)
    let plist = try PropertyListSerialization.data(fromPropertyList: ["CFBundleShortVersionString": "0.48.1"], format: .xml, options: 0)
    try plist.write(to: app.appending(path: "Contents/Info.plist"))
    #expect(kittyVersion(app.path) == "0.48.1")
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
    #expect(kittyDMG(fromRelease: release([asset("kitty-0.50.0.dmg")]))?.sha256 == nil, "no digest published: the installer refuses it")
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
    // curl collapses dot-segments, so a prefix check alone could be walked out of kitty's releases
    let base = "https://github.com/kovidgoyal/kitty/releases/download/"
    for url in [base + "../../../../torvalds/linux/releases/download/v1/kitty-0.50.0.dmg", base + "v0.50.0/../../x/kitty-0.50.0.dmg",
                base + "%2e%2e/%2e%2e/x/kitty-0.50.0.dmg", base + "v0.50.0/sub/kitty-0.50.0.dmg", base + "v0.50.0/kitty-0.50.0.dmg?x=1"] {
        #expect(kittyDMG(fromRelease: release([asset("kitty-0.50.0.dmg", url: url)])) == nil, "\(url)")
    }
}

@Test func verifyPinsApplesDeveloperIDForKittysTeam() {
    // Apple's root, its Developer ID intermediate and leaf markers, and kitty's team: an ad-hoc signature can't satisfy it
    #expect(kittyVerify("/x/kitty.app") == ["/usr/bin/codesign", "--verify", "--deep", "--strict",
        #"-R=anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = "NTY7FVCEKP""#,
        "/x/kitty.app"])
}

/// The real codesign: an ad-hoc signature whose identifier smuggles in a `TeamIdentifier=` line passes a plain
/// `--verify` and would fool a text parse of `codesign -dv`, but never the pinned requirement.
@Test func aSpoofedTeamCantPassTheRealCheck() throws {
    let dir = FileManager.default.temporaryDirectory.appending(path: "nell-spoof-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let fake = dir.appending(path: "echo").path
    try FileManager.default.copyItem(atPath: "/bin/echo", toPath: fake)
    try #require(runTool(["/usr/bin/codesign", "-f", "-s", "-", "-i", "x\nTeamIdentifier=\(kittyTeam)", fake]).status == 0)
    #expect(runTool(["/usr/bin/codesign", "--verify", "--deep", "--strict", fake]).status == 0, "the spoof does fool a plain verify")
    #expect(runTool(kittyVerify(fake)).status == 3, "3: the requirement is well-formed and unmet (a malformed one fails differently)")
}

@Test(.enabled(if: FileManager.default.fileExists(atPath: "/Applications/kitty.app")))
func theRealKittyPassesTheCheck() { #expect(runTool(kittyVerify("/Applications/kitty.app")).status == 0) }

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

    var cancelAt: String? // the tool during which Cancel is pressed
    let token = Cancellation() // the installer's
    func run(_ a: [String], _ c: Cancellation?) -> (status: Int32, out: Data) {
        calls.append(a)
        if let t = cancelAt, a[0].hasSuffix("/" + t), !a.last!.hasPrefix("https://api.github.com/"), let c {
            if t == "ditto" { try? FileManager.default.createDirectory(atPath: a[2] + "/Contents", withIntermediateDirectories: true) } // half copied
            c.cancel(); return (-1, Data()) // killed
        }
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
            if c != nil { Issue.record("Cancel must never stop the attach: a half-killed attach can leave a mount the detach misses") }
            if cancelAt == "attach" { token.cancel() } // pressed while it attaches: it still finishes
            if let f = fail("attach", "hdiutil: attach failed - image not recognized") { return f }
            let mount = URL(fileURLWithPath: a[a.firstIndex(of: "-mountpoint")! + 1])
            try! fm.createDirectory(at: mount, withIntermediateDirectories: true)
            if symlinkApp { try! fm.createSymbolicLink(atPath: mount.appending(path: "kitty.app").path, withDestinationPath: "/Applications/kitty.app") }
            else { try! fm.createDirectory(at: mount.appending(path: "kitty.app/Contents/MacOS"), withIntermediateDirectories: true) }
        case "hdiutil": if c != nil { Issue.record("Cancel must never stop the detach") }
        case "codesign":
            // as the real one: only the pinned requirement tells kitty's team from any other signature
            if team != kittyTeam, a.contains("-R=" + kittyRequirement) { return (3, Data("test-requirement: code failed to satisfy specified code requirement(s)".utf8)) }
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
    #expect(order == ["curl -fsSL", "curl -fsSL", "hdiutil attach", "codesign --verify", "spctl --assess",
                      "ditto " + (tools.calls[5][1]), "codesign --verify", "spctl --assess", "hdiutil detach"])
    #expect(tools.calls.filter { $0[0].hasSuffix("/codesign") } == [kittyVerify(tools.calls[3].last!), kittyVerify(tools.calls[6].last!)],
            "the image and the copy both pass the pinned requirement")
    let attach = try #require(tools.calls.first { $0.contains("attach") })
    for flag in ["-nobrowse", "-readonly", "-noautoopen"] { #expect(attach.contains(flag)) }
    #expect(tools.calls[0].contains("=https") && tools.calls[1].contains("=https") && tools.calls[1].last == dmgURL)
    #expect(try FileManager.default.contentsOfDirectory(atPath: into.path) == ["kitty.app"], "no staging copy left")
    #expect(!FileManager.default.fileExists(atPath: try #require(tools.tempDir)), "the download is deleted")
}

/// Every way it can go wrong: a clear reason, no kitty.app, no staging copy, the image detached, the download deleted.
@Test(arguments: [
    ("api", "GitHub"), ("nodigest", "no published checksum"), ("download", "download"), ("truncated", "incomplete"), ("corrupt", "checksum"), ("attach", "open"),
    ("verify", "signature"), ("spctl", "Gatekeeper"), ("team", "kitty's developer"), ("symlink", "no kitty.app"),
    ("ditto", "copy"), ("verify-copy", "signature"), ("cancel-download", "Cancelled"), ("cancel-ditto", "Cancelled"),
])
func anyFailureAbortsAndLeavesNothingInstalled(step: String, reason: String) throws {
    let tools = FakeTools(), into = folder()
    defer { try? FileManager.default.removeItem(at: into.deletingLastPathComponent()) }
    switch step {
    case "truncated": tools.served = tools.dmgBytes.prefix(1000)
    case "corrupt": var d = tools.dmgBytes; d[10] = 0; tools.served = d
    case "team": tools.team = "WRONGTEAM1"
    case "symlink": tools.symlinkApp = true
    case "nodigest": tools.json = release([asset("kitty-0.50.0.dmg", size: tools.dmgBytes.count)])
    case "cancel-download": tools.cancelAt = "curl" // the download, not the API read
    case "cancel-ditto": tools.cancelAt = "ditto"
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
    if ["api", "nodigest", "download", "truncated", "corrupt", "cancel-download"].contains(step) { #expect(!tools.ran("hdiutil"), "\(step): an unchecked download is never even mounted") }
    if !["ditto", "verify-copy", "cancel-ditto"].contains(step) { #expect(!tools.ran("ditto"), "\(step): nothing unverified is copied") }
}

@Test func anExistingKittyIsNeverReplaced() throws {
    let tools = FakeTools(), into = folder()
    defer { try? FileManager.default.removeItem(at: into.deletingLastPathComponent()) }
    try FileManager.default.createDirectory(at: into.appending(path: "kitty.app/Contents/yours"), withIntermediateDirectories: true)
    // e.g. one Nell rejected (no kitten): say what to do with it
    #expect { try installKitty(into: into, run: tools.run) } throws: { ($0 as? InstallFailed)?.description.contains("Trash") == true }
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
    let app = try installKitty(into: into, run: { a, c in
        let r = runTool(a, stderr: true, cancel: c)
        print("RUN \(a.joined(separator: " "))\n  -> \(r.status) \(String(decoding: r.out, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))")
        return r
    })
    print("INSTALLED \(app.path)")
    #expect(runTool(["/usr/bin/codesign", "--verify", "--deep", "--strict", app.path]).status == 0)
}

/// Cancel while the download is checked (or between any two steps): nothing new starts, so the attach never runs.
@Test func nothingStartsAfterCancel() throws {
    let tools = FakeTools(), into = folder()
    defer { try? FileManager.default.removeItem(at: into.deletingLastPathComponent()) }
    tools.token.cancel()
    #expect { try installKitty(into: into, cancel: tools.token, run: tools.run) } throws: { ($0 as? InstallFailed)?.description == "Cancelled." }
    #expect(tools.calls.isEmpty)
}

/// Cancel while the image attaches: the attach finishes, its mount is detached, then the install stops as cancelled.
@Test func cancelDuringAttachLetsItFinishThenDetaches() throws {
    let tools = FakeTools(), into = folder()
    defer { try? FileManager.default.removeItem(at: into.deletingLastPathComponent()) }
    tools.cancelAt = "attach"
    #expect { try installKitty(into: into, cancel: tools.token, run: tools.run) } throws: { ($0 as? InstallFailed)?.description == "Cancelled." }
    let order = tools.calls.map { ($0[0] as NSString).lastPathComponent + " " + $0[1] }
    #expect(order.suffix(2) == ["hdiutil attach", "hdiutil detach"], "nothing runs between the attach and its detach")
    #expect(!tools.ran("codesign") && !tools.ran("ditto"))
    #expect(!FileManager.default.fileExists(atPath: try #require(tools.tempDir)))
}
