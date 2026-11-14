# Nell v2 Console Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace v1's kitty OS windows with one hidden kitty panel. The panel shows Claude Code inside a console bubble that Nell draws. It opens only on your click, toggles between open and minimised, is placed by a tested layout engine so nothing overlaps, and uses Departure Mono everywhere. Clicks pass through Nell unless ⌥ is held.

**Architecture:** As in v1, pure logic goes in `NellCore` with tests, and AppKit/SwiftUI glue goes in `Nell`.

- **New in `NellCore`:**
  - `PanelCommands`: argv builders for the kitty panel.
  - `Layout`: placement maths.
  - `PanelGeometry`: kitty margins and size, plus calibration.
  - `ConsoleState`: hidden, open or minimised, and which tab is showing.
  - Bubble filtering and new bubble kinds.
- **In `Nell`:** `KittyController` drives the panel, and `CompanionView` draws from the `Layout` frames.

**Tech Stack:**
- Swift 6.4 with the Command Line Tools only (run tests with `scripts/test.sh`; no SwiftUI `@State`).
- kitty 0.50.0 `kitten panel`.
- Claude Code 2.1.321.
- Departure Mono (SIL OFL).

**Spec:** `docs/specs/2026-11-14-nell-v2-console-design.md`. Read it with the v1 spec and `docs/notes/2026-11-14-kitty-panel-spike-findings.md`. Branch: continue on `nell-v2` (cut from `nell-v1`).

## Global Constraints

- The console opens **only** after a user click: the ⌘ chip, the minimised bubble, **Open console**, **Open terminal** or **Answer in terminal**. Every such open also focuses it. Nell never opens it by herself.
  - The one exception is the hook script's fallback, when Nell herself isn't running. It shows the panel for a `PermissionRequest` only, never for `Notification`.
- No kitty OS window may ever be on screen. There is one kitty instance, launched with `kitten panel … --start-as-hidden --focus-policy on-demand`.
- Panel flags, exactly:
  ```
  --edge none --layer overlay -o macos_ns_window_layer=NSScreenSaverWindowLevel --focus-policy on-demand --start-as-hidden
  -c <support>/kitty.conf -o allow_remote_control=socket-only -o tab_bar_style=hidden --listen-on unix:<support>/kitty-{kitty_pid}.sock
  ```
- Tab 1 is `env NELL_MODE=code`. Tab 2 is chat, opened with `@ launch --type=tab --keep-focus --env NELL_MODE=chat`. All matching uses `env:NELL_MODE=<mode>`.
- **Console size:** target 100 × 30 cells, capped at 55% of the screen width and 70% of the screen height, with a 16 pt gap from screen edges and 12 pt between the console and Nell or her bubbles.
- **Side:** the console goes toward the wider side, measured from Nell's centre. Bubbles rise above Nell when she's in the lower half of the screen and drop below her when she's in the upper half.
- **While the console is open,** Code's `status`, `reply` and `user` bubbles are not added to the column. Approvals, questions, alerts, errors and console-needed bubbles always are.
- **Font:**
  - Departure Mono for every Nell text, at 11 pt.
  - kitty uses `font_family Departure Mono` and `font_size 11` in `kitty.conf`.
  - Nell registers the font for her own process with `CTFontManagerRegisterFontsForURL(.process)`.
  - On first launch she copies the font into `~/Library/Fonts/` (approved by the user), unless it's already there.
- **Grabbing:** Nell's sprite takes clicks only while ⌥ is held. ⌥-drag moves her, and ⌥-right-click opens her menu. The console hides during a drag and is re-placed on drop.
- **Calibration:** never hard-code kitty's +56 px or +37 px offsets in the app. Measure them once after the first show, using CGWindowList bounds for kitty's pid. The spike values only appear as test fixtures.

## Review Focus

1. **Nell dragged anywhere on screen,** including corners, the top edge, the middle, and a narrow display: every frame stays on screen, and the console never overlaps Nell, her column or the bar. Covered by the grid test in Task 2.
2. **An approval arrives while the console is open:** its bubble shows beside Nell and is not covered. Covered by `pendingApprovalVisibleWithConsoleOpen` in Task 2 and the filter test in Task 3.
3. **Nell crashes while the console is open, then relaunches:** the existing kitty is reused, and the panel is hidden on reconnect because the console phase starts as hidden. Covered by the Task 5 reconnect step and the Task 7 checklist.
4. **Nell dragged with the console open:** the console never visibly drifts from its frame. It hides at drag start and shows at its new place on drop. Covered by Task 6 and the Task 7 checklist.
5. **A prompt sent to Chat while the console shows Code:** it reaches the Chat tab, and the visible tab doesn't change. Covered by Task 1 Step 3 and the Task 7 checklist.

---

### Task 1: Verify the remaining panel unknowns (gate)

**Files:**
- Modify: `docs/notes/2026-11-14-kitty-panel-spike-findings.md`, adding a "v2 build checks" section.
- Create: `Sources/Nell/Resources/fonts/DepartureMono-Regular.otf` and `Sources/Nell/Resources/fonts/OFL.txt`, downloaded from `https://github.com/rektdeckard/departure-mono` (`public/assets/DepartureMono-Regular.otf` and the repository's licence file).

- [ ] **Step 1: Working directory.** Launch a test panel with `Process.currentDirectoryURL` set to a test folder, using a tiny Swift script in the scratchpad. Expected: `kitten @ ls` shows that folder as the window's `cwd`. If it doesn't, record "use `/bin/zsh -c 'cd <dir> && exec <cmd>'`".
- [ ] **Step 2: Spaces.** Show the panel, switch Spaces with ⌃→, and ask the user whether the panel is still visible. If it isn't, record which override fixes it, trying `-o macos_hide_from_tasks` or similar.
- [ ] **Step 3: Tabs.** Add a chat tab. Check that `@ focus-tab --match env:NELL_MODE=chat` changes the visible tab, read with `get-text --match state:focused` and confirmed by the user, and that focusing code switches it back. Check that `send-text --stdin` to chat leaves the visible tab unchanged.
- [ ] **Step 4: Font.** Copy the OTF into `~/Library/Fonts/`, start a panel with `-o font_family='Departure Mono' -o font_size=11`, and confirm with `kitten @ ls` or kitty's `--debug-font-fallback` log that kitty loaded Departure Mono. Record the cell size kitty reports, then ask the user whether the console font looks crisp.
- [ ] **Step 5: Measure.** Using CGWindowList bounds for kitty's pid, record measured minus requested size and position at `font_size 11` for two different requests, to confirm the offset is a constant.
- [ ] **Step 6:** Write the results into the notes file, kill the test panels, and commit `spike: v2 panel checks (cwd, spaces, tabs, font, offsets)`. **If Step 2 or 3 fails with no fix, stop and report to the user.**

### Task 2: Layout engine

**Files:**
- Create: `Sources/NellCore/Layout.swift`
- Test: `Tests/NellCoreTests/LayoutTests.swift`

**Interfaces:**
- Produces:
  - `public enum ConsolePhase: Equatable, Sendable { case hidden, open, minimised }`
  - `public enum Side: Equatable, Sendable { case left, right }`
  - `public struct LayoutInput { screen: CGRect; nellOrigin: CGPoint; nellSize: CGSize; columnSize: CGSize; console: ConsolePhase; cell: CGSize; consoleChrome: CGSize; minimisedSize: CGSize }`
    - All rects use AppKit screen coordinates (y up).
    - `nellOrigin` is the bottom-left of the block that holds the sprite, chips and bar.
    - `cell` is one Departure Mono cell in points.
    - `consoleChrome` is the title strip plus borders.
  - `public struct Layout: Equatable { panelFrame, nellFrame, columnFrame: CGRect; consoleFrame, minimisedFrame: CGRect?; side: Side; columnUp: Bool; faceRight: Bool }`
  - `public func layout(_ i: LayoutInput) -> Layout`, where `panelFrame` is the union of all the other frames plus a 6 pt tail margin.

**Rules** (copy the numbers from Global Constraints):
- **nellFrame:** `nellOrigin` plus `nellSize`, clamped inside `screen` with a 16 pt margin.
- **columnFrame:** aligned to Nell's edge on the side away from the console (right-aligned when the console is on the left). It sits above Nell when `columnUp` and below her otherwise. If the space there is shorter than `columnSize.height`, its height is clipped to that space.
- **side:** `.left` when `nellFrame.midX - screen.minX > screen.maxX - nellFrame.midX`.
- **consoleFrame** (only when `.open`):
  - Size = min(100 × 30 cells + chrome, 55% of the screen width, 70% of the screen height).
  - Then shrink it until it fits horizontally between the 16 pt screen margin and the nearer of `nellFrame` or `columnFrame`, minus the 12 pt gap.
  - Its bottom lines up with `nellFrame.minY`, then it's raised as needed so it stays inside the screen.
- **minimisedFrame** (only when `.minimised`): `minimisedSize`, on the same side as the console, bottom-aligned with Nell.
- **faceRight:** `side == .right`.

- [ ] **Step 1: Write the failing tests.** The screen is `(0,0,1800,1130)`, the cell is `7×14`, Nell is `160×200` and the column is `270×300`.
  - `bottomRightOpensLeft`: Nell at x=1620, y=16 gives `.left`, a console whose maxX ≤ the column's minX − 12 and whose minY == 16, and `faceRight == false`.
  - `bottomLeftOpensRight`: the mirror image, with `faceRight == true`.
  - `topHalfColumnGoesDown`: Nell's y=900 gives `columnUp == false`.
  - `consoleCappedAt55x70`: a 1000×700 screen gives console width ≤ 550 and height ≤ 490.
  - `narrowScreenShrinksNeverOverlaps`: a 700×700 screen gives a console that doesn't intersect Nell, the column or the bar.
  - `minimisedOnlyWhenMinimised`
  - `allFramesInsideScreenAcrossGrid`: for Nell origins on a 50 pt grid over the whole screen and every phase, every frame is inside the screen and the console intersects neither Nell nor the column.
  - `pendingApprovalVisibleWithConsoleOpen`: the column still has height ≥ 80 when the console is open in the bottom-right case.
- [ ] **Step 2:** Run `scripts/test.sh`. Expected: FAIL, because `layout` doesn't exist.
- [ ] **Step 3:** Implement `Layout.swift` following the rules above.
- [ ] **Step 4:** Run `scripts/test.sh`. Expected: everything passes. Commit `feat: layout engine for console, column and Nell`.

### Task 3: Console state, bubble rules, panel geometry and commands

**Files:**
- Create: `Sources/NellCore/ConsoleState.swift`, `Sources/NellCore/PanelGeometry.swift`
- Modify: `Sources/NellCore/KittyCommands.swift`. Remove `launchKitty`, `sessionFile` and `launchWindow`, and add panel builders.
- Modify: `Sources/NellCore/BubbleStore.swift`. Add the `.consoleNeeded` kind and `settleConsoleNeeded(mode:)`.
- Modify: `Sources/Nell/Resources/nell-hook.sh`. The fallback runs for `PermissionRequest` only.
- Test: `Tests/NellCoreTests/ConsoleStateTests.swift` and `Tests/NellCoreTests/PanelGeometryTests.swift`. Update `KittyCommandsTests.swift`, `BubbleStoreTests.swift` and `Tests/hook-script-test.sh`.

**Interfaces:**
- Consumes: `ConsolePhase` (Task 2), `Mode`, `Paths`, `claudeArgs`.
- Produces:
  - `public struct ConsoleState: Equatable, Sendable { phase: ConsolePhase = .hidden; tab: Mode = .code }` with these methods:
    - `mutating func pressCodeChip(selected: inout Mode)`: if `selected != .code`, it sets `selected = .code; tab = .code; phase = .open`. Otherwise it toggles `.open` and `.minimised`, and `.hidden` becomes `.open`.
    - `mutating func open(tab: Mode = .code)`, `mutating func minimise()`, `mutating func chatConnected()`. The last sets `tab = .code` if it was `.chat`.
  - `public func showsInColumn(_ kind: BubbleKind, mode: Mode, consoleOpen: Bool) -> Bool`
  - `BubbleKind.consoleNeeded`. It's pinned like approvals and settled by `settleConsoleNeeded(mode:)`.
  - `public struct PanelCalibration: Equatable, Codable, Sendable { extraSize: CGSize; topOffset: CGFloat }`. The spike values (56, 56, 37) are the default until measured. It has `static func measured(requested: CGRect, actual: CGRect) -> PanelCalibration`, where both rects use top-left coordinates.
  - `public func panelRequest(content: CGRect, screenTop: CGFloat, cal: PanelCalibration) -> (marginLeft: Int, marginTop: Int, widthPx: Int, heightPx: Int)`. `content` is in AppKit coordinates and `screenTop` is the display's frame maxY.
  - Additions to `KittyCommands`:
    - `launchPanel(paths:request:claude:args:)`. It wraps the command in `/usr/bin/env NELL_MODE=code <claude> <args>`.
    - `launchTab(socket:mode:cwd:claude:args:)`
    - `placePanel(socket:request:)`, which runs `resize-os-window --action os-panel --incremental margin-left= margin-top= columns=<w>px lines=<h>px`
    - `showPanel(socket:)` and `hidePanel(socket:)`
    - `focusTab(socket:mode:)`
    - `closeTab(socket:mode:)`
    - `focus`, `sendText` and `sendEnter` are kept unchanged.

- [ ] **Step 1: Write the failing tests.**
  - `firstCodePressFromChatOpensConsole`: selected `.chat`, then `pressCodeChip`, gives selected `.code` and phase `.open`.
  - `codePressTogglesOpenMinimised`
  - `chatChipLeavesConsoleAlone`: this is a NellModel rule, so test it as `ConsoleState` staying unchanged.
  - `chatConnectedReturnsToCodeTab`
  - `codeChatterHiddenWhileConsoleOpen`: `showsInColumn(.reply, .code, true)` is false. `.approval`, `.question`, `.alert`, `.error` and `.consoleNeeded` are true. Chat `.reply` is true.
  - `consoleNeededPinnedUntilSettled`
  - `calibrationRoundTripsSpikeNumbers`: requesting 700×420 at (300, 350 from top) and measuring 756×476 at (300, 387) gives (56, 56, 37). With that calibration, a content rect produces a request whose measured frame equals the content rect.
  - `launchPanelArgsMatchGlobalConstraints`: it contains every flag listed there, `--start-as-hidden` and `--focus-policy on-demand`, and never `--session`.
  - `placePanelUsesIncrementalOsPanel`
  - The hook-script test: a `Notification` with Nell down no longer calls kitten, and a `PermissionRequest` calls `resize-os-window … --action show` and `focus-window`.
- [ ] **Step 2:** Run `scripts/test.sh && bash Tests/hook-script-test.sh`. Expected: FAIL.
- [ ] **Step 3:** Implement. Delete the v1 builders and their tests, since no app code will use them after Task 5.
- [ ] **Step 4:** Run both test commands. Expected: everything passes. Commit `feat: console state, panel geometry and commands, console-needed bubbles`.

### Task 4: Font and click-through rules

**Files:**
- Modify: `Sources/NellCore/SpriteSheet.swift`. `isInteractive` gains the grab rule.
- Create: `Sources/Nell/Fonts.swift`
- Test: update the `isInteractive` test in `Tests/NellCoreTests/SpriteSheetTests.swift`.

**Interfaces:**
- Produces:
  - `public func isInteractive(_ p: CGPoint, rects: [CGRect], grabRects: [CGRect], optionHeld: Bool) -> Bool`. The v1 two-argument version is removed.
  - `enum Fonts { static func register(); static func installForKitty() -> Bool; static func ui(_ size: CGFloat = 11) -> Font }`. `installForKitty` copies the font to `~/Library/Fonts/DepartureMono-Regular.otf` only if no file with that name exists there.

- [ ] **Step 1: Write the failing tests.**
  - `spriteOnlyInteractiveWithOption`: a point inside `grabRects` is false without ⌥ and true with it.
  - `buttonsAlwaysInteractive`
- [ ] **Step 2:** Run `scripts/test.sh`. Expected: FAIL.
- [ ] **Step 3:** Implement `isInteractive` and `Fonts` (resource `fonts/DepartureMono-Regular.otf`).
- [ ] **Step 4:** Run `scripts/test.sh` and `swift build`. Expected: everything passes and the build is clean. Commit `feat: option-to-grab hit rule, Departure Mono registration and install`.

### Task 5: KittyController on the panel

**Files:**
- Modify: `Sources/Nell/KittyController.swift`
- Modify: `Sources/Nell/Resources/kitty.conf`. Add `font_family Departure Mono` and `font_size 11`, and remove the OS-window settings.
- Modify: `Sources/NellCore/SavedState.swift`. Add `calibration: PanelCalibration?`, which round-trips.

**Interfaces:**
- Consumes: Task 3 builders, `PanelGeometry`, `SavedState`.
- Produces, on `@MainActor final class KittyController`:
  - `func ensureRunning(projectDir: String, state: inout SavedState) throws -> Bool`. It reuses a live socket, then **hides the panel** on reconnect. Otherwise it launches the panel hidden with the code args, and then the chat tab.
  - `func ensureTab(_ m: Mode, cwd: String, state: inout SavedState) -> Bool`, which replaces `ensureWindow`.
  - `func place(content: CGRect, screen: NSScreen)`. It uses `state.calibration` or the default.
  - `func showConsole(tab: Mode)`. It runs `focusTab`, then `showPanel`, then `focus`. On the first show of a launch, it measures the real frame through CGWindowList and saves the calibration to state.
  - `func hideConsole()`
  - `func restartCode(in:state:)`. It closes the code tab and launches a new one, then focuses it.
  - `send(_:to:)` and `quit()` are kept as they are. Only `toggle` is removed, replaced by `showConsole` and `hideConsole`.

- [ ] **Step 1:** Add a `SavedState` round-trip test that includes the calibration (`savedStateRoundTripsCalibration`). Watch it fail, then add the field and watch it pass.
- [ ] **Step 2:** Rewrite `KittyController` to the interface above. The working directory comes from the Task 1 finding.
- [ ] **Step 3: Live check from the shell.** Bundle the app, open it, and confirm with CGWindowList for kitty's pid that **no kitty window is on screen** after launch and after sending a prompt to each tab. Confirm `nell.log` shows `SessionStart` for both modes. Commit `feat: kitty panel controller with tabs, calibration and hidden start`.

### Task 6: Nell's window and views on the layout

**Files:**
- Modify: `Sources/Nell/CompanionView.swift`, `Sources/Nell/OverlayPanel.swift`, `Sources/Nell/NellModel.swift`, `Sources/Nell/AppDelegate.swift`

**Interfaces:**
- Consumes: `layout()`, `ConsoleState`, `showsInColumn`, `isInteractive` (new), `Fonts`, and the `KittyController` console API.
- Produces:
  - `NellModel.console: ConsoleState` (published).
  - `NellModel.codeChip()`, `openConsole(tab:)` and `minimiseConsole()`.
  - `PanelController.apply(_ layout: Layout)`, which sets the panel frame and stores the frames for hit-testing.

- [ ] **Step 1: The model.**
  - The chips call `codeChip()`, or select Chat.
  - Bubbles are added only when `showsInColumn` allows it.
  - When `disconnected` begins, add `.consoleNeeded` with "Claude needs you in the console", or "Chat needs a one-time OK" for chat.
  - An approval settled with `.none` that wasn't quiet adds `.consoleNeeded("Answer in the console")` instead of showing kitty.
  - `openConsole` settles `.consoleNeeded` for that tab's mode.
  - A chat `SessionStart` calls `console.chatConnected()`, and the console switches back to the code tab if it's open.
  - Every user-initiated open calls `kitty.showConsole`. Minimise and the drag start call `hideConsole`.
- [ ] **Step 2: The view.**
  - One root view the size of `layout.panelFrame`, with each piece placed at its layout frame converted to panel-local coordinates.
  - **Console frame:** a dark, 3 pt-bordered rectangle with a title strip (⌘ and the project name, plus a minimise control) and a tail toward Nell. The interior is fully transparent and not interactive.
  - **Minimised bubble:** a one-line Code status bubble that opens the console when clicked.
  - **Speech bubbles:** placeholder rectangles with a 2 pt border and a tail. User bubbles are light grey, not blue. Nell's sprite flips when `faceRight` is set.
  - Every `Text` uses `Fonts.ui()`.
- [ ] **Step 3: Hit-testing.** Report bubbles with buttons, the chips, the bar, the minimised bubble and the console title strip as `rects`, and the sprite as `grabRects`. The 10 Hz timer passes `NSEvent.modifierFlags.contains(.option)`. A hovered bubble is found from the pointer position alone.
- [ ] **Step 4: Drag and menu.**
  - The sprite's `DragGesture` hides the console on start, recomputes the layout on end, saves the position, and places and shows the console again if it's open.
  - ⌥-right-click opens the menu: Open project…, Hide Nell, Quit.
- [ ] **Step 5: Wiring.** The app delegate calls `Fonts.register()` and `Fonts.installForKitty()` before kitty launches. It recomputes the layout on screen changes and whenever the bubble count changes, and re-places the console after every layout change. Nothing calls `kitty.show` or `focus` except the user-initiated opens.
- [ ] **Step 6:** Run `scripts/test.sh` and `swift build`. Expected: everything passes and the build is clean. Commit `feat: console bubble, layout-driven window, option-grab, Departure Mono UI`.

### Task 7: End-to-end check with the user

- [ ] **Step 1:** Run `bash scripts/bundle.sh`, then quit the old Nell (`osascript -e 'quit app id "local.nell.companion"'`) and `open build/Nell.app`.
- [ ] **Step 2: Shell checks.**
  - After launch, no kitty window is on screen (CGWindowList onscreen = 0 for kitty's pid).
  - `nell.log` shows `SessionStart` for both modes.
  - A prompt sent to chat with `kitten @ send-text` still leaves no kitty window on screen.
  - A `kill -9` of Nell followed by a relaunch leaves exactly one kitty, with the panel hidden.
- [ ] **Step 3: With the user.** Go through each item and record the result:
  - [ ] ⌘ from Chat opens the console beside Nell, on the side with more room, showing Claude Code. Typing works at once.
  - [ ] ⌘ again minimises it to the one-line status bubble, and clicking that bubble reopens it.
  - [ ] With the console open, sending Code work shows no status or reply bubbles. An approval still appears beside Nell, and Allow works.
  - [ ] ⌥-drag Nell to the bottom-left. The console hides during the drag, reappears on her right, and she faces it.
  - [ ] Without ⌥, clicks on Nell reach the window behind her.
  - [ ] ⌥-right-click opens her menu.
  - [ ] The console text is Departure Mono and looks crisp, and so are Nell's bubbles.
  - [ ] Nothing overlaps at the bottom-right, the bottom-left, or near the top of the screen.
- [ ] **Step 4:** Commit any fixes, each with a test where the logic is in `NellCore`. Write `docs/notes/YYYY-MM-DD-nell-v2-build-ledger.md` and add it to `docs/README.md`. A second display is still unverified because none was available, so note that in the ledger.
