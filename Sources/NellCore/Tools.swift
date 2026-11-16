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

/// The oldest kitty Nell runs with. The panel kitten came to macOS in 0.42.0 and `macos_ns_window_layer` in 0.48.0;
/// 0.48.1 fixed the `--edge none` panel shrinking with a top margin, and 0.50.0 fixed remote-control `send-key`,
/// `set-colors` and `ls` ignoring options. `--focus-policy`, `--layer` and `--start-as-hidden` have no changelog entry,
/// so the floor is the release they were verified on.
public let minKittyVersion = "0.50.0"

/// Whether the dotted version `v` is at least `min`, number by number: 0.9 < 0.10, and 0.50 is 0.50.0.
public func versionAtLeast(_ v: String, _ min: String) -> Bool {
    func numbers(_ s: String) -> [Int]? {
        let n = s.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        return n.contains(nil) ? nil : n.compactMap { $0 }
    }
    guard let a = numbers(v), let b = numbers(min) else { return false }
    for i in 0..<max(a.count, b.count) {
        let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
        if x != y { return x > y }
    }
    return true
}

/// The kitty.app's version, from its Info.plist.
public func kittyVersion(_ app: String) -> String? {
    NSDictionary(contentsOfFile: app + "/Contents/Info.plist")?["CFBundleShortVersionString"] as? String
}

public enum KittyFound: Equatable, Sendable {
    case ready(String)
    /// None: the installer can put one in ~/Applications.
    case missing
    /// Only a too-old one, in /Applications (nil: its version can't be read); the installer puts the current one in ~/Applications.
    case tooOld(version: String?)
    /// ~/Applications/kitty.app is too old (nil: or can't run), and the installer never replaces a kitty.app.
    case blocked(version: String?)
}

/// The first kitty.app that has kitty and kitten and is at least `minKittyVersion`, else what the user can do about it.
public func findKitty(home: String, isExecutable: (String) -> Bool = isExecutableFile, version: (String) -> String? = kittyVersion,
                      exists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }) -> KittyFound {
    let apps = kittyApps(home: home)
    func runs(_ app: String) -> Bool { let k = KittyCommands(app: app); return isExecutable(k.kitty) && isExecutable(k.kitten) }
    if let app = apps.first(where: { runs($0) && version($0).map { versionAtLeast($0, minKittyVersion) } == true }) { return .ready(app) }
    if exists(apps[1]) { return .blocked(version: runs(apps[1]) ? version(apps[1]) : nil) }
    return runs(apps[0]) ? .tooOld(version: version(apps[0])) : .missing
}

/// Kovid Goyal's Developer ID team, which signs every official kitty.
public let kittyTeam = "NTY7FVCEKP"
/// Signed through Apple's root with a Developer ID certificate (the intermediate's and leaf's Apple markers) issued to
/// kitty's team. An ad-hoc or self-made signature can't satisfy it, whatever its identifier claims.
public let kittyRequirement = "anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and "
    + "certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = \"\(kittyTeam)\""
public func kittyVerify(_ path: String) -> [String] { ["/usr/bin/codesign", "--verify", "--deep", "--strict", "-R=" + kittyRequirement, path] }
/// Where an install copies kitty before renaming it into place; a leftover is from an install that was cut short.
public func kittyStaging(in folder: URL) -> URL { folder.appending(path: ".kitty.app.nell-install") }

public struct KittyDMG: Equatable, Sendable {
    public let name: String, url: String, size: Int
    public let sha256: String? // GitHub's published digest, when it has one
}

/// The macOS DMG in kitty's release JSON: named exactly `kitty-<version>.dmg` and served from kitty's own releases. The
/// whole URL is matched: curl collapses `..`, so a prefix check could be walked out of them.
public func kittyDMG(fromRelease json: Data) -> KittyDMG? {
    guard let obj = try? JSONSerialization.jsonObject(with: json) as? [String: Any], let assets = obj["assets"] as? [[String: Any]] else { return nil }
    for a in assets {
        guard let name = a["name"] as? String, name.wholeMatch(of: /kitty-[0-9]+(\.[0-9]+)*\.dmg/) != nil,
              let url = a["browser_download_url"] as? String,
              url.wholeMatch(of: /https:\/\/github\.com\/kovidgoyal\/kitty\/releases\/download\/v[0-9.]+\/kitty-[0-9.]+\.dmg/) != nil,
              url.hasSuffix("/" + name), let size = a["size"] as? Int, size > 0 else { continue }
        let digest = (a["digest"] as? String).flatMap { $0.hasPrefix("sha256:") ? $0.dropFirst(7).lowercased() : nil }
        return KittyDMG(name: name, url: url, size: size, sha256: digest)
    }
    return nil
}

public struct InstallFailed: Error, CustomStringConvertible {
    public let description: String
    init(_ d: String) { description = d }
    public static let cancelled = InstallFailed("Cancelled.")
}

/// Installs the latest official kitty as `folder`/kitty.app (Nell uses ~/Applications, which needs no password).
/// Nothing from the download runs: it must match its published size and sha256 before it's mounted (read-only), and
/// pass the pinned Developer ID requirement and Gatekeeper (notarization) before it's copied, and again once copied.
/// The copy goes to a staging name and is renamed into place only then, so any failure leaves no kitty.app, and
/// `cancel` stops the running step with the same cleanup. The image is always detached and the download deleted.
/// `run` runs one tool (with the cancellation, when it may be cancelled) and returns its status and output, stderr included.
public func installKitty(into folder: URL, cancel: Cancellation = Cancellation(),
                         run: ([String], Cancellation?) -> (status: Int32, out: Data) = { runTool($0, stderr: true, cancel: $1) }) throws -> URL {
    let fm = FileManager.default
    let dest = folder.appending(path: "kitty.app"), staging = kittyStaging(in: folder)
    guard !fm.fileExists(atPath: dest.path) else {
        throw InstallFailed("There's already a kitty.app in \(folder.path), but it isn't one Nell can run (it needs its kitty and kitten). "
                            + "Move it to the Trash, or reinstall kitty from its site, then open Nell again.")
    }
    let tmp = fm.temporaryDirectory.appending(path: "nell-kitty-\(UUID().uuidString)")
    try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: tmp) }

    @discardableResult func step(_ argv: [String], _ failure: String, cancellable: Bool = true) throws -> String {
        if cancel.isCancelled { throw InstallFailed.cancelled } // nothing new starts after Cancel
        let r = run(argv, cancellable ? cancel : nil), said = String(decoding: r.out, as: UTF8.self)
        if cancel.isCancelled { throw InstallFailed.cancelled }
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
        try step(kittyVerify(app.path), "This kitty's signature isn't valid or isn't from kitty's developer (Developer ID team \(kittyTeam)), "
                 + "so Nell won't install it.")
        try step(["/usr/sbin/spctl", "--assess", "--type", "execute", app.path], "macOS Gatekeeper rejected this kitty, so Nell won't install it.")
    }

    let curl = ["/usr/bin/curl", "-fsSL", "--proto", "=https", "--proto-redir", "=https"]
    let json = tmp.appending(path: "release.json")
    try step(curl + ["--max-time", "30", "-o", json.path, "https://api.github.com/repos/kovidgoyal/kitty/releases/latest"],
             "Couldn't read kitty's latest release from GitHub.")
    guard let dmg = (try? Data(contentsOf: json)).flatMap(kittyDMG(fromRelease:)) else {
        throw InstallFailed("kitty's latest release on GitHub has no macOS download.")
    }
    guard let want = dmg.sha256 else { throw InstallFailed("\(dmg.name) has no published checksum on GitHub, so Nell can't check the download.") }
    let image = tmp.appending(path: dmg.name)
    try step(curl + ["--max-time", "1800", "-o", image.path, dmg.url], "Couldn't download \(dmg.name).")
    let got = (try? Data(contentsOf: image, options: .mappedIfSafe)) ?? Data()
    guard got.count == dmg.size else { throw InstallFailed("The download of \(dmg.name) is incomplete (\(got.count) of \(dmg.size) bytes).") }
    if SHA256.hash(data: got).map({ String(format: "%02x", $0) }).joined() != want {
        throw InstallFailed("The download of \(dmg.name) doesn't match its published checksum.")
    }

    let mount = tmp.appending(path: "mount")
    // detached even when attach fails: it may have mounted before it failed
    // never cancelled: it's the cleanup
    defer { if run(["/usr/bin/hdiutil", "detach", mount.path], nil).status != 0 { _ = run(["/usr/bin/hdiutil", "detach", "-force", mount.path], nil) } }
    // never cancelled either: killed midway, it could still mount after the detach looked, under a deleted temp folder
    try step(["/usr/bin/hdiutil", "attach", "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mount.path, image.path],
             "Couldn't open \(dmg.name).", cancellable: false)
    try verify(mount.appending(path: "kitty.app"))

    try fm.createDirectory(at: folder, withIntermediateDirectories: true)
    try? fm.removeItem(at: staging) // a copy an interrupted install left
    do {
        try step(["/usr/bin/ditto", mount.appending(path: "kitty.app").path, staging.path], "Couldn't copy kitty into \(folder.path).")
        try verify(staging)
        if cancel.isCancelled { throw InstallFailed.cancelled }
        try fm.moveItem(at: staging, to: dest) // never replaces: a kitty.app that appeared meanwhile makes this fail
    } catch {
        try? fm.removeItem(at: staging)
        throw error as? InstallFailed ?? InstallFailed("Couldn't put kitty in \(folder.path): \(error.localizedDescription)")
    }
    return dest
}
