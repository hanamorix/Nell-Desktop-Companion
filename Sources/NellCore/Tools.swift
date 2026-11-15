import CryptoKit
import Foundation

/// A regular file you can run (`isExecutableFile(atPath:)` alone also passes folders).
public func isExecutableFile(_ path: String) -> Bool {
    var dir: ObjCBool = false
    return FileManager.default.fileExists(atPath: path, isDirectory: &dir) && !dir.boolValue && FileManager.default.isExecutableFile(atPath: path)
}

// MARK: Claude Code

/// Where Claude Code's installers put it, after your login shell's PATH.
/// shortcut: npm's global bin is guessed as ~/.npm-global (a custom prefix, or nvm, is found through your shell's PATH).
public func claudeCandidates(home: String) -> [String] {
    [home + "/.local/bin/claude", "/opt/homebrew/bin/claude", "/usr/local/bin/claude", home + "/.claude/local/claude", home + "/.npm-global/bin/claude"]
}

/// Asks your login shell, started as Claude will be, which claude it runs. sh inherits that shell's PATH, so the answer
/// is the file, never an alias or function; the marker sets it apart from anything your rc files print.
public func claudeLookup(shell: String, home: String) -> [String] {
    KittyCommands.viaLoginShell(shell, cwd: home, ["/bin/sh", "-c", #"printf '\nnell-claude=%s\n' "$(command -v claude)""#])
}

/// The claude your login shell finds (`shellOutput` is `claudeLookup`'s), else the first of the usual places that exists.
public func locateClaude(shellOutput: String, home: String, isExecutable: (String) -> Bool = isExecutableFile) -> String? {
    let found = shellOutput.split(whereSeparator: \.isNewline).last { $0.hasPrefix("nell-claude=") }.map { String($0.dropFirst(12)) }
    return ([found].compactMap { $0 }.filter { $0.hasPrefix("/") } + claudeCandidates(home: home)).first(where: isExecutable)
}

// MARK: kitty

public func kittyApps(home: String) -> [String] { [KittyCommands().app, home + "/Applications/kitty.app"] }

public func locateKitty(home: String, isExecutable: (String) -> Bool = isExecutableFile) -> String? {
    kittyApps(home: home).first { let k = KittyCommands(app: $0); return isExecutable(k.kitty) && isExecutable(k.kitten) }
}

/// Kovid Goyal's Developer ID team, which signs every official kitty.
public let kittyTeam = "NTY7FVCEKP"

public struct KittyDMG: Equatable, Sendable {
    public let name: String, url: String, size: Int
    public let sha256: String? // GitHub's published digest, when it has one
}

/// The macOS DMG in kitty's release JSON: named exactly `kitty-<version>.dmg` and served from kitty's own releases.
public func kittyDMG(fromRelease json: Data) -> KittyDMG? {
    guard let obj = try? JSONSerialization.jsonObject(with: json) as? [String: Any], let assets = obj["assets"] as? [[String: Any]] else { return nil }
    for a in assets {
        guard let name = a["name"] as? String, name.wholeMatch(of: /kitty-[0-9]+(\.[0-9]+)*\.dmg/) != nil,
              let url = a["browser_download_url"] as? String, url.hasPrefix("https://github.com/kovidgoyal/kitty/releases/download/"),
              url.hasSuffix("/" + name), let size = a["size"] as? Int, size > 0 else { continue }
        let digest = (a["digest"] as? String).flatMap { $0.hasPrefix("sha256:") ? $0.dropFirst(7).lowercased() : nil }
        return KittyDMG(name: name, url: url, size: size, sha256: digest)
    }
    return nil
}

/// The `TeamIdentifier=` line of `codesign -dv` (which prints to stderr).
public func teamIdentifier(fromCodesign output: String) -> String? {
    output.split(whereSeparator: \.isNewline).first { $0.hasPrefix("TeamIdentifier=") }.map { String($0.dropFirst(15)) }
}

public struct InstallFailed: Error, CustomStringConvertible {
    public let description: String
    init(_ d: String) { description = d }
}

/// Installs the latest official kitty as `folder`/kitty.app (Nell uses ~/Applications, which needs no password).
/// Nothing from the download runs: it must match its published size and checksum before it's mounted (read-only), and
/// pass codesign, Gatekeeper and kitty's team check before it's copied, and again once copied. The copy goes to a
/// staging name and is renamed into place only then, so any failure, or a quit midway, leaves no kitty.app. The image
/// is always detached and the download deleted. `run` runs one tool and returns its status and output, stderr included.
public func installKitty(into folder: URL, run: ([String]) -> (status: Int32, out: Data) = { runTool($0, stderr: true) }) throws -> URL {
    let fm = FileManager.default
    let dest = folder.appending(path: "kitty.app"), staging = folder.appending(path: ".kitty.app.nell-install")
    guard !fm.fileExists(atPath: dest.path) else { throw InstallFailed("\(dest.path) already exists.") }
    let tmp = fm.temporaryDirectory.appending(path: "nell-kitty-\(UUID().uuidString)")
    try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: tmp) }

    @discardableResult func step(_ argv: [String], _ failure: String) throws -> String {
        let r = run(argv), said = String(decoding: r.out, as: UTF8.self)
        guard r.status == 0 else {
            let why = said.split(whereSeparator: \.isNewline).last.map { " (\($0))" } ?? ""
            throw InstallFailed(failure + why)
        }
        return said
    }
    func verify(_ app: URL) throws {
        guard (try? fm.attributesOfItem(atPath: app.path))?[.type] as? FileAttributeType == .typeDirectory else {
            throw InstallFailed("The download has no kitty.app.")
        }
        try step(["/usr/bin/codesign", "--verify", "--deep", "--strict", app.path], "kitty's signature isn't valid, so Nell won't install it.")
        try step(["/usr/sbin/spctl", "--assess", "--type", "execute", app.path], "macOS Gatekeeper rejected this kitty, so Nell won't install it.")
        let team = teamIdentifier(fromCodesign: try step(["/usr/bin/codesign", "-dv", app.path], "Couldn't read kitty's signature."))
        guard team == kittyTeam else {
            throw InstallFailed("This kitty is signed by team \(team ?? "none"), not kitty's developer (\(kittyTeam)), so Nell won't install it.")
        }
    }

    let curl = ["/usr/bin/curl", "-fsSL", "--proto", "=https", "--proto-redir", "=https"]
    let json = tmp.appending(path: "release.json")
    try step(curl + ["--max-time", "30", "-o", json.path, "https://api.github.com/repos/kovidgoyal/kitty/releases/latest"],
             "Couldn't read kitty's latest release from GitHub.")
    guard let dmg = (try? Data(contentsOf: json)).flatMap(kittyDMG(fromRelease:)) else {
        throw InstallFailed("kitty's latest release on GitHub has no macOS download.")
    }
    let image = tmp.appending(path: dmg.name)
    try step(curl + ["--max-time", "1800", "-o", image.path, dmg.url], "Couldn't download \(dmg.name).")
    let got = (try? Data(contentsOf: image, options: .mappedIfSafe)) ?? Data()
    guard got.count == dmg.size else { throw InstallFailed("The download of \(dmg.name) is incomplete (\(got.count) of \(dmg.size) bytes).") }
    if let want = dmg.sha256, SHA256.hash(data: got).map({ String(format: "%02x", $0) }).joined() != want {
        throw InstallFailed("The download of \(dmg.name) doesn't match its published checksum.")
    }

    let mount = tmp.appending(path: "mount")
    // detached even when attach fails: it may have mounted before it failed
    defer { if run(["/usr/bin/hdiutil", "detach", mount.path]).status != 0 { _ = run(["/usr/bin/hdiutil", "detach", "-force", mount.path]) } }
    try step(["/usr/bin/hdiutil", "attach", "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mount.path, image.path],
             "Couldn't open \(dmg.name).")
    try verify(mount.appending(path: "kitty.app"))

    try fm.createDirectory(at: folder, withIntermediateDirectories: true)
    try? fm.removeItem(at: staging) // a copy an interrupted install left
    do {
        try step(["/usr/bin/ditto", mount.appending(path: "kitty.app").path, staging.path], "Couldn't copy kitty into \(folder.path).")
        try verify(staging)
        try fm.moveItem(at: staging, to: dest) // never replaces: a kitty.app that appeared meanwhile makes this fail
    } catch {
        try? fm.removeItem(at: staging)
        throw error as? InstallFailed ?? InstallFailed("Couldn't put kitty in \(folder.path): \(error.localizedDescription)")
    }
    return dest
}
