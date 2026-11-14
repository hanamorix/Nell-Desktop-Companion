# Nell v2: Kitty + Nell, the console bubble

Date: 2026-11-14 · Status: approved 2026-11-14 · Builds on: [v1 design](2026-11-14-nell-v1-design.md) · Evidence: [kitty panel spike findings](../notes/2026-11-14-kitty-panel-spike-findings.md)

## Intent

In v1, kitty showed up as ordinary terminal windows. Several could open at launch, and more appeared after commands. The user doesn't want to see a terminal at all. v2 treats the two as one product, **Kitty + Nell**: the Claude Code session lives inside one of Nell's own speech bubbles, the **console bubble**, which opens and minimises with the ⌘ button.

This round is about **making it work as intended**. Art, the pixel-art GUI theme and visual polish come in a later design round, once everything behaves correctly. The user prefers that order because it makes the design stage easier.

## Goals

1. **No terminal window, ever.** Nothing kitty-shaped appears outside Nell's console bubble: not at launch, not after commands, not on approvals or alerts.
2. **The console bubble.** Pressing ⌘ shows the live Claude Code session, already working or waiting for input, inside a bubble that's part of Nell. You can click into it and type, just like kitty.
3. **Placement follows Nell.** The console opens on the side of the screen with more room:
   - on her left when she's at the bottom-right;
   - on her right when she's at the bottom-left.
   
   It's big enough to follow the work, but never takes over the screen.
4. **Minimise, not close.** ⌘ switches the console between **open** and **minimised**. Minimised, it shrinks to a one-line bubble showing what Claude is doing right now. Claude keeps running throughout.
5. **Nothing overlaps.** The console, the chat bubble column, approval bubbles and Nell herself never cover each other and always stay on screen.
6. **Click-through with ⌥ to grab.** Clicks pass through Nell, her bubbles' empty space and the console's surroundings. Holding **⌥ (Option)** makes Nell solid: ⌥ plus drag moves her, and ⌥ plus right-click opens her menu. When she's dropped, the whole layout rearranges for her new position.
7. **Departure Mono everywhere.** Nell's bubbles, the message bar, her menu and the console all use the Departure Mono pixel font (SIL OFL, bundled with Nell).
8. **Speech bubbles, not iMessage.** Bubbles get a speech-bubble shape with a tail pointing at Nell, and no blue iMessage styling. The shapes are functional placeholders that the art round will replace.

## Non-goals (this round)

- Pixel-art GUI theme, final bubble art, colour palette, and kitty's look beyond the font and the bubble fit. These belong to the **design round**.
- A settings screen for customising kitty. Customising this round means only what's needed for kitty to sit inside the bubble.
- Several projects or sessions at once (unchanged from v1).
- Supporting a second display beyond keeping Nell and the console on the display she's on. A second display was not available to test.

## Anti-goals

- A kitty window flashes or appears anywhere outside the console bubble.
- The console covers Nell, her approval bubbles or the message bar.
- The console fills, or nearly fills, the screen.
- A click meant for the app behind Nell is caught by Nell when ⌥ isn't held.
- Minimising or hiding the console stops or restarts Claude.

## Approaches considered

**How kitty lives inside Nell:**
1. **A kitty panel inside a bubble Nell draws (picked by the user).** kitty's `panel` mode gives a borderless window that Nell positions inside the bubble frame she draws. Kitty is still kitty: typing, scrolling, Claude's pickers and the config all work. The cost is two windows kept in step, so the console hides while Nell is dragged. The spike proved each step it depends on.
2. **A terminal drawn inside Nell's window (SwiftTerm).** It would be truly one window, but it drops kitty and adds a dependency, and Claude Code's interface may render less faithfully.
3. **A normal kitty window glued next to Nell.** Moving another app's window needs Accessibility permission, it can't float above full-screen apps as reliably, and window chrome may show. Worse than option 1 on every point.

**How to drag Nell while clicks pass through her:**
1. **Hold ⌥ to grab (picked by the user).** It's reliable and needs no permissions.
2. **Hover for about half a second to grab.** Rejected because a quick click right after the pointer arrives still passes through, so it feels inconsistent.
3. **Her body always takes clicks.** Rejected because it isn't click-through.

A Mac can't pass a click to the app behind and also start a drag in Nell without Accessibility permission. That's why ⌥ is needed.

**Font:** Departure Mono everywhere (picked by the user). The alternatives were Pixel Code, Pixelify Sans for chat plus Departure Mono for code, and VT323.

## Architecture changes from v1

### One kitty panel instead of kitty windows

v1 launched kitty with `--start-as hidden --session …`. The spike showed that **both windows ended up on screen anyway**, which is the bug the user saw.

v2 launches **one kitty instance in panel mode**:

```
kitten panel --edge none --margin-left X --margin-top Y --columns Wpx --lines Hpx \
  --layer overlay -o macos_ns_window_layer=NSScreenSaverWindowLevel \
  --focus-policy on-demand --start-as-hidden \
  -c <support>/kitty.conf -o allow_remote_control=socket-only -o tab_bar_style=hidden \
  --listen-on 'unix:<support>/kitty-{kitty_pid}.sock' \
  /usr/bin/env NELL_MODE=code <claude …code args>
```

- It runs with the clean environment from v1 (spike deviation 2), with its working directory set to the project folder.
- **Tab 1 is Code.** The console always shows this tab.
- **Tab 2 is Chat**, added with `@ launch --type=tab --keep-focus --env NELL_MODE=chat --cwd <chatDir> claude …chat args`. It's never shown in the normal flow; chat appears only as Nell's bubbles. `send-text --stdin` and `send-key` reach it while it's in the background, as the spike confirmed.
- `--focus-policy on-demand` is **required**. With the default `not-allowed`, the user couldn't type into the console.
- kitty's v1 OS windows, the session file and `KittyCommands.launchWindow` for OS windows all go. `ensureWindow` becomes "ensure tab": the same `ls` check, relaunching a missing tab with `--resume`.
- Kept from v1: env tagging, `--stdin` sending, killing kitty with SIGTERM on Quit, and reusing a live kitty after a crash only if `kitten @ ls` answers.

### The console bubble

- **States:**
  - **hidden:** at launch, until ⌘ is first used.
  - **open**
  - **minimised**
- **Controls:**
  - The ⌘ chip selects Code mode. When Code is already selected, ⌘ toggles the console between **open** and **minimised**.
  - The 💬 chip selects Chat mode and leaves the console as it is.
- **Open:** Nell draws the bubble frame (border, a title strip with the project name and a minimise control, and a tail pointing at Nell). The kitty panel is shown inside it with `resize-os-window --action show`, then `focus-window`, so it can be typed in at once.
- **Minimised:** the panel is hidden with `--action hide`, and Nell draws a one-line bubble in the console's place. It shows the live status from hooks, the same text as v1's status bubble (for example "Running `npm test`"), and clicking it opens the console again. Nothing parses kitty's screen for progress counts. *(my call)*
- **Only you open the console** *(user's decision)*. It opens only when you click ⌘, the minimised bubble, an **Open console** button, **Open terminal** or **Answer in terminal**. Every open focuses it, so you can type straight away. Nell never opens it by herself.
- **First ⌘ press:** selects Code **and** opens the console, even if Chat was selected, because pressing the console button should show the session. *(my call)*
- **Code bubbles while the console is open:**
  - While it's open, Code-mode **status, reply and your-message bubbles are not added to the column**, since the console already shows them. Code **approvals, questions, alerts and errors still appear**.
  - While it's minimised or hidden, Code bubbles behave as in v1, except the status line lives in the minimised bubble.
  - Chat bubbles are unaffected.
  
  *(my call)*
- **Fitting kitty into the frame:**
  - Kitty is placed with `@ resize-os-window --action os-panel --incremental margin-left=… margin-top=… columns=…px lines=…px`.
  - The spike found kitty draws 56 px wider and taller than requested, and that `margin-top` counts from just below the menu bar. Nell **measures the panel's real frame once after it first appears** (CGWindowList bounds for kitty's pid) and corrects both offsets, rather than hard-coding them. On the test display the menu bar gap was 39 pt, but the measured y-offset was 37.
- **Which window sits on top:**
  - Both windows are at screen-saver level.
  - Nell's frame is a ring around a transparent centre that doesn't take clicks, so whichever window is in front, kitty stays visible and gets the clicks inside the frame.
- **Every v1 "show kitty" trigger becomes a bubble with an Open console button**, and the console itself stays closed:
  - the 8-second "can't hear Claude" nudge, which also covers the folder-trust dialog, becomes "Claude needs you in the console" plus **Open console**;
  - an approval settled with no decision (a timeout, or the hook dying) becomes "Answer in the console" plus **Open console**, with needs-you and the sound as before.
  
  **Open terminal** and **Answer in terminal** are your own clicks, so they open the console directly.
  
  Chat's tab appears only for Chat's first-run trust prompt. Nell shows "Chat needs a one-time OK" plus **Open console**, and opening it shows the Chat tab (`focus-tab`). The console switches back to Code when Chat's `SessionStart` arrives, or as soon as you press ⌘ or minimise. If `focus-tab` turns out not to change the visible tab, the fallback is a second, separate panel just for Chat, used only in this case. *(approved)*
- **When Nell isn't running,** the hook script's fallback still shows the kitty panel by itself (`resize-os-window --action show` and `focus-window`) for approvals, because no Nell is there to show a button. It appears without Nell's frame. This is the only time the console opens without a click, and it exists to keep v1's anti-goal that an approval must never be lost silently. The script no longer raises kitty for plain `Notification` events. *(my call, flagged to the user)*

### Layout engine

All the placement maths goes into one pure, tested function in `NellCore`:

```
layout(screen: CGRect /*visibleFrame*/, nellOrigin: CGPoint, console: ConsoleState,
       bubbles: [CGSize]) -> Layout
Layout = { nellFrame, consoleFrame?, minimisedFrame?, side: .left/.right,
           column: .up/.down, faceRight: Bool, panelFrame /*Nell's NSPanel*/ }
```

**Rules:**
- **Side:** the console goes toward the wider part of the screen, measured from Nell's centre.
- **Bubble column:** chat bubbles rise above Nell if she's in the lower half of the screen, or drop below her if she's in the upper half.
- **Console size:**
  - The target is about **100 columns × 30 lines** of Departure Mono.
  - It's capped at **55% of the screen's width and 70% of its height**, with a 16 pt minimum gap from the screen edges.
  - The console's bottom lines up with Nell's desk, and it moves up if needed to fit.
- **No overlap:** the console rectangle never intersects Nell's sprite, her bubble column or the message bar. When space is tight, the console shrinks before it ever overlaps, and **pending approval bubbles always stay visible**.
- **Facing:** Nell faces the console, so the sprite flips when the console is on her right.
- **Tests:** bottom-right and bottom-left placement, top half, a narrow screen, a pending approval with the console open, and that every output rectangle stays inside the screen. These cover the user's examples and the no-overlap rule.

**Nell's window** grows to cover her own area plus the console frame. Click-through keeps working because only interactive rectangles take clicks. Those are Nell's sprite when ⌥ is held, bubbles that have buttons, the chips, the message bar and the minimised bubble.

### Click-through and ⌥ grab

- **The 10 Hz pointer check** (v1) becomes: a point is interactive if it's inside a button-bearing bubble, a chip, the message bar or the minimised bubble, **or** if ⌥ is held and it's on Nell's sprite.
- **Plain bubbles** with text only, such as replies and status, pass clicks through. They still need hover to pause fading, and that works without taking clicks because the timer can see the pointer.
- **Dragging:**
  - While ⌥ is held, a drag on Nell moves her.
  - At the start of the drag the console panel hides, so the two windows never drift apart. Minimised it stays minimised.
  - On drop, the layout is recomputed, the position is saved for that display, and the console reappears at its new place.
- **The right-click menu** (Open project…, Hide Nell, Quit) opens with ⌥ plus right-click. The global ⌥⌘N hotkey still focuses the bar.

### Departure Mono

- **Nell:** the font file ships in `Sources/Nell/Resources/fonts/`. Nell registers it for her own process with `CTFontManagerRegisterFontsForURL` (`.process` scope), so nothing is installed system-wide for her UI. It's used at 11 or 22 px, its pixel grid.
- **kitty:** kitty only loads installed fonts, so on first launch Nell copies the font into `~/Library/Fonts/` (user scope, no admin password) and sets `font_family Departure Mono` in her `kitty.conf`. *(approved by the user on 2026-11-14)*

## Kept from v1

Everything not mentioned above stays as it is:
- hooks only through `--settings`;
- the approval and question rules;
- the input hold;
- the fixed `nell.sock`;
- the event log;
- the state machine;
- the bubble fade rules.

The console bubble is a new bubble *kind*, outside the fading column, so the fade rules don't touch it.

## Left to the builder

- The exact visuals of the placeholder bubble shape and tail, the title strip and the minimised bubble. They should be functional and plain, since the design round replaces them.
- The animation, if any, when the console opens or minimises. None is fine.
- How Nell's large window is split into SwiftUI views.
- Whether the measurement step runs once per launch or once per display change.

## Verify during the build

- That the kitty panel appears on every Space, as Nell does. The spike only confirmed it shows over a full-screen app.

- Placing the panel on a second display (`--output-name`) and moving it there when Nell is dragged across.
- That `Process.currentDirectoryURL` reaches the panel's child, or else `cd` through `/bin/zsh -c` as the spike did.
- That `focus-tab` switches the panel's visible tab for Chat's trust dialog, and switches back.
