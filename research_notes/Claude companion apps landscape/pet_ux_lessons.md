# Design lessons from desktop companions and floating overlays (for a native macOS pixel-art companion)

Research date: 2026-11-14. Budget-limited pass (~17 web calls). Sourcing has three levels, and each finding says which applies:
- **(full text):** the page was fetched and read in full.
- **(snippet):** the claim comes from search-result summaries only, and the full page was not read.
- **(headline only):** the fetched page returned only its title.

Quotes are kept under 15 words.

## What drives long-term retention vs quick uninstall (Shimeji, Desktop Goose, Clippy/BonziBuddy, Bongo Cat, VPet, RunCat, etc.)

### Takeaway
The pets that last are cheap to run, stay out of the way, and do one small thing that is tied to what the user is already doing. Bongo Cat drums when you type, and RunCat runs at the speed of your CPU. On top of that they add a long tail of depth: collectibles and cosmetics, workshop or mod content, and many animations. Clippy is the counter-example. It interrupted constantly, offered help nobody needed, and was designed for first use rather than for repeated use.

### Cited Findings
- **Bongo Cat, what it is:** a corner-of-the-screen "idle and productivity" game in which the cat bops every time a key is pressed outside the game. Its unobtrusive presence is credited as a big part of its success (snippet). — [Insider Gaming](https://insider-gaming.com/what-is-bongo-cat-on-steam/); [PC Gamer headline: cat "smacks your Windows taskbar like a bongo drum when you type"](https://www.pcgamer.com/games/life-sim/one-of-the-biggest-games-on-steam-right-now-is-bongo-cat-a-cat-with-a-hat-who-smacks-your-windows-taskbar-like-a-bongo-drum-when-you-type) (headline only)
- **Bongo Cat, retention loop:** points unlock cats, hats, emotes and floating icons. These items are tradeable on the Steam Marketplace, and commentators partly attribute its popularity to that (snippet). — [Gamepressure](https://www.gamepressure.com/newsroom/bongo-cat-now-has-more-players-than-banana-clicker-but-the-realit/z97d86); [Insider Gaming](https://insider-gaming.com/what-is-bongo-cat/)
- **Bongo Cat, multiplayer:** a later update added multiplayer, with up to 100 cats on screen at once (headline only). — [PC Gamer](https://www.pcgamer.com/games/life-sim/bongo-cat-still-one-of-the-biggest-games-on-steam-gets-even-bigger-with-multiplayer-you-can-now-have-up-to-100-cats-on-your-screen-at-once-all-of-them-happily-bapping-away-as-their-owners-type)
- **Bongo Cat, player counts (sources conflict, all third-party estimates):**
  - One tracker gives a peak of about 194,508 concurrent players in May 2025. Another gives an all-time peak of 181,847, with about 135,848 in-game in a July 2026 snapshot (snippet).
  - The creator reportedly told Eurogamer that bots made up roughly half of the earlier concurrent numbers. After a crackdown the count fell to about 75,000 (snippet; the Eurogamer article was not read). This is a caution that the item-trading economy attracts idle-farming bots.
  - Sources: [Steam tracker](https://tracker.gg/population/steam/3419430); [SteamPulse](https://www.steampulse.org/game/3419430); [Total Apex Gaming](https://totalapexgaming.com/?p=62559)
- **Bongo Cat, monetization:** one report says earnings peaked at about $4,050 in its breakout month, so popularity did not equal profit (snippet). — [Total Apex Gaming](https://totalapexgaming.com/?p=62559)
- **VPet-Simulator, ratings:** a free, open-source desktop pet rated "Overwhelmingly Positive" on Steam, with about 51k reviews, roughly 98% positive (snippet; counts vary by snapshot). — [Steam store](https://store.steampowered.com/app/1920960/VPet_Simulator/); [Vaporlens summary](https://vaporlens.app/app/1920960/v_pet_simulator)
- **VPet-Simulator, depth:** the Steam listing advertises 200+ animation types, plus feeding, work and interactions. Reviewers cite low system requirements as a positive (snippet). — [Steam store](https://store.steampowered.com/app/1920960/VPet_Simulator/); [Vaporlens](https://vaporlens.app/app/1920960/v_pet_simulator)
- **VPet-Simulator, workshop:** Steam Workshop content can include pet animations, items/food/drink, work types, speech text and themes, and most of it needs no code changes (snippet). — [Steam store](https://store.steampowered.com/app/1920960/VPet_Simulator/)
- **VPet-Simulator, press:** described as a "free Tamagotchi-like" that took over Steam (headline only). — [GamesRadar](https://www.gamesradar.com/a-free-tamagotchi-like-that-puts-a-little-anime-girl-on-your-desktop-is-taking-over-steam)
- **Desktop Goose, behaviour:** made by Sam Chiet (samperson) and inspired by Untitled Goose Game. The goose drags memes and "Goose Notepad" notes onto the screen and grabs and drags your cursor. It is deliberately mischievous, which is the opposite of the "helpful assistant" framing (snippet). — [itch.io page](https://samperson.itch.io/desktop-goose); [PC Gamer](https://www.pcgamer.com/the-horrible-goose-can-now-live-on-your-desktop-and-steal-your-cursor); [Kotaku](https://kotaku.com/untitled-goose-fan-game-unleashes-havoc-on-your-desktop-1841351806)
- **Desktop Goose, customization:** it added an official modding API and GIF support. A `config.goos` file lets users tune its aggression, and the itch page noted that mods were not yet supported on Mac (snippet). Kotaku reported Windows security flagging the download, which is a trust and friction cost for unsigned pet apps (snippet). — [itch.io](https://samperson.itch.io/desktop-goose); [Kotaku](https://kotaku.com/untitled-goose-fan-game-unleashes-havoc-on-your-desktop-1841351806)
- **Desktop Goose, release date (conflict):** press coverage dates from January–February 2020, while one source claims a September 2020 itch release. The early-2020 press dates are more credible. — [SoyaCincau, 2020-02-03](https://soyacincau.com/2020/02/03/turn-an-organised-windows-desktop-into-a-honking-mess-with-a-goose/)
- **RunCat (macOS):** a menu-bar cat that runs faster as CPU usage rises, which makes the animation double as a gauge. It can also show memory, storage, battery and network status. Many alternative "runners" are available, some as paid in-app purchases, and it requires macOS 14+ (snippet from App Store listing). — [Mac App Store](https://apps.apple.com/au/app/runcat/id1429033973?mt=12)
- **RunCat 365:** the GitHub repo is the Windows taskbar port (C#/.NET 9). The page gives no data on resource use (full text). — [GitHub RunCat365](https://github.com/Kyome22/RunCat365)
- **Clippy, research basis:** based on Reeves and Nass's "Media Equation" research, which found that people respond socially to computers. Alan Cooper called Clippy a tragic misinterpretation of that work (snippet). — [CIO NZ](https://www2.cio.co.nz/article/662045/what-went-wrong-clippy-virtual-assistant-pioneer-people-loved-to-hate/); [CommandBar blog](https://www.commandbar.com/blog/what-clippy-taught-us-all)
- **Clippy, complaints:** the main complaint was interruption, pestering users about trivial tasks. Its illustrator Kevan Atteberry said many found its functionality "too basic and annoying" (snippet). — [Yahoo/Business Insider](https://ca.finance.yahoo.com/news/designer-microsofts-super-annoying-clippy-160000754.html); [BGR](https://bgr.com/2155953/what-happened-to-clippy-why-microsoft-retired-office-assistant/)
- **Clippy, testing:** a Microsoft executive (Roz Ho) reported that female test users found the characters "leering" and "too male", which points to a narrow design process (snippet). — [Dice](https://www.dice.com/career-advice/clippy-when-the-dev-process-goes-wrong)
- **Clippy, when it was turned off (conflict):** sources disagree on whether it was turned off by default in Office 2000 or Office XP. Both agree it was removed in Office 2007 (snippet). — [BGR](https://bgr.com/2155953/what-happened-to-clippy-why-microsoft-retired-office-assistant/); [Medium/TwentyBN](https://medium.com/twentybn/5-lessons-from-clippys-failure-efc69297eac1)
- **Clippy, lessons commonly drawn:** design for the 100th use, not the first; test with diverse users; be careful with human-like characters that claim more intelligence than they have (snippet). — [Medium/TwentyBN "5 Lessons"](https://medium.com/twentybn/5-lessons-from-clippys-failure-efc69297eac1); [CommandBar](https://www.commandbar.com/blog/what-clippy-taught-us-all)

### Inferences
- **Reactivity beats proactivity.** The two biggest modern successes, Bongo Cat and RunCat, react to signals the user is already producing (typing, CPU load) and never ask for attention. Clippy initiated contact and was hated for it. For an AI companion: speaking unprompted should be rare, user-tunable and easy to silence. Ambient reactions such as animation changes from agent or terminal activity can be frequent.
- **Long-tail depth drives multi-year retention, not novelty.** Bongo Cat has collectibles, VPet has 200+ animations and a workshop, Desktop Goose has mods and a config file, RunCat has many runners. A skin or mod format that the community can extend is the strongest lever seen.
- **Being lightweight is a feature that reviewers notice** (VPet's praise for low requirements). On a laptop, CPU and battery cost is likely the top silent reason for uninstalling, but no source quantified this.
- **Mischief works as a one-off toy** (Desktop Goose went viral). The sources found do not show it retaining users for years. A companion meant to live on the desktop daily should borrow the charm, not the cursor-stealing.

### Gaps
- No sources were gathered for oneko/Neko, eSheep, BonziBuddy (adware/privacy angle), Desktop Mate, or tamagotchi-style menubar pets. These were not searched because of the budget.
- No negative or critical reviews were collected for Bongo Cat, VPet or Desktop Mate. The reasons people uninstall are therefore inferred, not sourced.
- No retention or DAU data exists beyond third-party concurrent-player trackers.
- The Desktop Goose creator interview: the Medium "Making Dumb-smart Things" piece about Sam Chiet was found but not read, and it is unconfirmed whether it discusses the goose. — [Medium](https://medium.com/art-%EF%B8%8E-code/making-dumb-smart-things-29fca36e647f)

## Animation lessons: idle variety, randomness, sleep, drag/click reactions, sprite/mod formats

### Takeaway
The best-documented extensible format is Shimeji(-ee). Each image set is a folder of frames plus `actions.xml` (animations and poses) and `behaviors.xml` (a weighted-random behaviour picker, where frequency 0 disables a behaviour or reserves it for interaction-only use). Aseprite's JSON export gives frame rects, tags and slices. No source gave a hard number for how many idle variants are needed before a pet feels repetitive.

### Cited Findings
- **Shimeji-ee, file layout:** each image set lives in `img/[NAME]` and must contain every image its actions file references. Per-set `img/[NAME]/conf/actions.xml` or `conf/[NAME]/actions.xml` overrides the shared `conf/actions.xml` (likewise for `behaviors.xml`), and folders in `img/unused` are skipped (snippet of a readme copy). — [Shimeji-ee readme (Scribd copy)](https://www.scribd.com/document/470896340/readme-txt)
- **Shimeji-ee, frequency weights:** behaviours in `behaviors.xml` carry a frequency weight, and setting it to 0 turns a behaviour off. Interaction-only actions are listed with frequency 0 and hidden, so they fire only when triggered (snippet). — [Shimeji-ee readme (Scribd copy)](https://www.scribd.com/document/470896340/readme-txt); [omgartist tutorial](https://omgartist.netlify.app/how-to-edit-a-shimeji)
- **Shimeji-ee, shared config:** all Shimeji in the same folder share one config unless a set ships its own `conf` (snippet). — [DeviantArt set notes](https://i-forget-to-forget.deviantart.com/art/Shimeji-Envy-New-Version-202183974?offset=100)
- **VPet, animation count:** advertises 200+ animation types and supports workshop-uploaded animations. This is the only animation-count datapoint found (snippet). — [Steam store](https://store.steampowered.com/app/1920960/VPet_Simulator/)
- **Aseprite CLI export:**
  - `--data` writes sprite-sheet JSON, and `--format` chooses `json-hash` (the default) or `json-array`.
  - `--list-tags` adds `meta.frameTags` entries with `name`, `from` and `to`.
  - `--list-slices` adds `meta.slices` with name, color and keys (frame, bounds, center, pivot).
  - `--split-tags` saves each tag to its own file.
  - The CLI page did not explicitly document a per-frame `duration` field or a tag `direction` field (full text).
  - Source: [Aseprite CLI docs](https://www.aseprite.org/docs/cli/)
- **RunCat, data-driven speed:** animation speed is driven by live data (CPU %), which is a single loop that never feels repetitive because its tempo varies (snippet). — [Mac App Store](https://apps.apple.com/au/app/runcat/id1429033973?mt=12)
- **Bongo Cat, input as frames:** the "animation" is a direct per-keystroke reaction. Each keypress is a frame of feedback (snippet). — [Insider Gaming](https://insider-gaming.com/what-is-bongo-cat-on-steam/)

### Inferences
- **A Shimeji-style weighted behaviour table** (idle, look around, stretch, sit, walk, sleep, each with a frequency) is a proven, moddable model. Reserve frequency 0 for "reaction-only" states such as being dragged, clicked, petted, or the agent finishing a task.
- **Combat repetition with variable tempo and context, not just more frames.** Tie the idle choice and speed to real signals (agent busy, idle, error) the way RunCat does, and randomise idle timing and order.
- **Choose one export format and validate it.** Aseprite json-array plus frameTags maps cleanly to state-named animations. Confirm in practice whether the JSON includes per-frame duration before relying on it, since the CLI docs did not say. One way to check is to export a sample with the local Aseprite MCP.
- **Sleeping after inactivity** is a widely seen convention: oneko sleeps when the cursor is still, and VPet has a sleep state. It doubles as the main energy-saving state (see the next section). This is not sourced here.

### Gaps
- The `actions.xml`/`behaviors.xml` element schema (Pose, Animation, Move, Sequence, conditions) was not retrieved. The Shimeji-ee GitHub repo or the original Group Finity docs would be the source.
- No source gave a design rule for the number of idle variants, idle timing intervals, or the inactivity delay before sleep.
- No source on drag or "petting" reaction design (squash, struggle, dangle) beyond the general mention of VPet's touch interactions.

## macOS overlay pitfalls: NSPanel vs NSWindow, click-through, Spaces/full-screen, multi-monitor, Stage Manager, energy, permissions

### Takeaway
Apple DTS's recipe for an overlay that stays visible even over full-screen apps has five parts:
1. Run as an accessory app (`LSUIElement`).
2. Use a non-activating `NSPanel`, not an `NSWindow`.
3. Set the level to `.screenSaver`.
4. Set the collection behaviour to `[.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary, .stationary]`.
5. Set `hidesOnDeactivate = false`.

For energy, Apple says to stop work when a window is occluded. However, an always-on-top transparent panel will rarely report itself as occluded, so the pet needs its own idle/sleep throttling.

### Cited Findings
- **Apple DTS, accessory policy:** regular foreground apps are not layered above other apps' full-screen Spaces. Overlay utilities use `.accessory` activation policy or `LSUIElement`, which removes the Dock icon and menu bar (full text). — [Apple Developer Forums thread 826308](https://developer.apple.com/forums/thread/826308)
- **Apple DTS, panel vs window:** an `NSWindow` activates its app when ordered front, which can make a full-screen app leave its Space. A `.nonactivatingPanel` `NSPanel` avoids this (full text). — [Apple Developer Forums 826308](https://developer.apple.com/forums/thread/826308)
- **Apple DTS, window level:** `.floating` (level 3) and `.statusBar` (25) both sit below full-screen content, and `.screenSaver` (1000) works (full text). — [Apple Developer Forums 826308](https://developer.apple.com/forums/thread/826308)
- **Apple DTS, behaviours and test conditions:** with `[.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary, .stationary]` plus `isFloatingPanel = true` and `hidesOnDeactivate = false`, no Space-change observers or `orderFrontRegardless()` re-calls are needed. DTS tested this on macOS 26 over Safari, QuickTime and full-screen YouTube, using a titled panel (full text). — [Apple Developer Forums 826308](https://developer.apple.com/forums/thread/826308)
- **Community recipes:** blog recipes use the same `.nonactivatingPanel` + `isFloatingPanel` + `canJoinAllSpaces`/`fullScreenAuxiliary` pattern. One claims `.fullScreenAuxiliary` is required on Sonoma+ for full-screen use (snippet). — [Cindori floating panel](https://cindori.com/developer/floating-panel); [fazm.ai](https://fazm.ai/blog/swiftui-floating-panel)
- **Raycast, Space-following bug:** Raycast's changelog includes a fix so its floating window "will now follow the current space". A separate bug had AI Chat lose Always-on-Top after opening from a notification or a window-layout restore. Even mature apps hit these edge cases (snippet). — [Raycast changelog](https://www.raycast.com/changelog/macos-v1)
- **Click-through, `ignoresMouseEvents`:** this property makes the whole window transparent to mouse events. It is all-or-nothing, not per-pixel (snippet of Apple doc). — [Apple docs: ignoresMouseEvents](https://developer.apple.com/documentation/appkit/nswindow/ignoresmouseevents)
- **Click-through, borderless windows:** reportedly, a borderless `NSWindow` by default passes clicks through fully transparent pixels and catches clicks on opaque ones. Explicitly setting `ignoresMouseEvents = false` disables that per-pixel pass-through (snippet, from an Electron workaround repo describing native behaviour; not verified in Apple docs). — [loomhq ElectronMacOSClickThrough](https://github.blesdmm.dns-dynamic.net/loomhq/ElectronMacOSClickThrough); [npm package](https://npmjs.com/package/@loomhq/electron-click-through-workaround)
- **Click-through, Sonoma regression (native pitfall):** a developer reports a transparent window that stops passing clicks through after repeated redraws. They cannot simply set `ignoresMouseEvents`, because only parts of the window are transparent (snippet). — [Apple Developer Forums 737584](https://developer.apple.com/forums/thread/737584)
- **Click-through, Electron-specific:** in Electron/Chromium, per-pixel pass-through reportedly broke around Electron 38 (Chromium 139, mid-2025). Electron's `panel` window type reportedly absorbs all clicks. This applies to Electron, not to native NSPanel (snippet). — [Peek click-through research](https://tangled.org/burrito.space/peek/blob/main/notes/click-through-research.md)
- **Energy, Apple's rule:** stop work when your window or app becomes hidden, and refresh and resume when it is visible again. Use `windowDidChangeOcclusionState` and check `occlusionState.contains(.visible)` (full text). — [Apple Energy Efficiency Guide: Work When Visible](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/WorkWhenVisible.html)
- **Energy, what counts as occluded:** occluded means covered by other windows, the screen saver running, or sitting on a Space the user isn't in. A non-rectangular window whose bounding box is visible counts as visible, and **a fully transparent window may count as visible**. A status item makes the app count as visible while the menu bar shows (full text). — [Apple: Work When Visible](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/WorkWhenVisible.html)
- **Energy, OpenGL and App Nap:** OpenGL content cannot take part in occlusion calculations, so an app that renders with OpenGL is assumed always visible and can't App Nap (full text). — [Apple: Work When Visible](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/WorkWhenVisible.html)
- **Energy, prior art:** Zed stops its display link when the window is occluded. Mozilla notes that occlusion state flaps during native full-screen transitions, so transient changes should be ignored or debounced (snippet). — [Zed commit](https://git.secluded.site/zed/commit/07fce7aae1ebe03a344160e3083837044d7de850); [Mozilla bug 1831967](https://bugzilla.mozilla.org/show_bug.cgi?id=1831967)

### Inferences
- **Use the DTS recipe as the baseline**, but treat level `.screenSaver` plus floating over full-screen apps as an opt-in setting. "Covers content" is a classic annoyance, and level 1000 sits above nearly everything. A sensible default is `.floating` with `.canJoinAllSpaces`, plus a toggle labelled something like "show over full-screen apps".
- **The DTS test conditions differ from this project.** DTS tested on macOS 26 with a *titled* panel. This machine runs Darwin 27, and the companion will be a borderless, transparent panel. Re-verify the recipe on the current OS, especially that Space-following and click-through survive together.
- **Per-pixel click-through should be native.** Keep the panel borderless and non-opaque with a clear background, don't touch `ignoresMouseEvents`, and/or override `hitTest`, returning nil over transparent sprite pixels. Toggling `ignoresMouseEvents` from a global mouse monitor is a fallback, but global mouse monitoring may raise permission prompts (unverified). Watch for the Sonoma redraw regression.
- **Occlusion-based pausing will rarely trigger** for a top-level, all-Spaces, transparent pet, given Apple's note that transparent windows may count as visible. The main energy control has to be the pet itself:
  - Drop to a low frame rate (pixel art at 6–12 fps is the norm) and redraw only when the frame changes.
  - After N minutes of user inactivity, enter a sleep state that runs a slow loop or stops entirely.
  - Pause on screen lock and display sleep.
  - Avoid OpenGL; prefer CALayer contents swapping or SpriteKit/Metal with on-demand rendering.

### Gaps
- No sources were gathered for Stage Manager behaviour, multi-monitor placement (which screen, separate Spaces per display), notch/menubar safe areas, or timer vs `CADisplayLink` (macOS 14+ `NSView.displayLink`) energy comparisons. These were not searched.
- Accessibility or Input Monitoring permission requirements are unsourced. Reacting to global typing like Bongo Cat would likely need Input Monitoring, and reading other apps' windows would need Accessibility, but neither was verified here.
- No measured energy-impact figures for continuous sprite animation on Apple Silicon.

## Chat-overlay UX: ephemeral/fading messages, summon/hide hotkey, not losing information

### Takeaway
Raycast's model is the one sourced pattern. A hotkey-summoned, floating "Quick AI" handles one-off questions, and a single shortcut (Cmd+J) promotes the exchange into a persistent, resizable AI Chat window, carrying over the answer, model and attachments. The ephemeral surface stays light, and nothing is lost because escalation to a durable surface is one keystroke.

### Cited Findings
- **Raycast Quick AI:** it is "a single hotkey away" and appears as a floating window above other apps, intended for fast one-off questions (snippet, Raycast marketing and manual). — [Raycast AI page](https://raycast.com/core-features/ai); [Raycast manual](https://manual.raycast.com/v1/ai)
- **Raycast AI Chat:** opens by default in a resizable floating window, with a configurable toggle hotkey (snippet, changelog v1.50.0, April 2023). — [Raycast changelog 1.50.0](https://www.raycast.com/changelog/macos/1-50-0)
- **Cmd+J hand-off:** moves a Quick AI exchange into the AI Chat window while keeping the answer, model and attachments. This is how the ephemeral view avoids losing information (snippet, third-party guide). — [StarryHope guide](https://www.starryhope.com/mac/raycast-ai-mac/)
- **Screen Awareness (Aug 2026):** sends the focused window to AI Chat by default, and users can redirect it to Quick AI in settings (snippet). — [Raycast manual: Screen Awareness](https://manual.raycast.com/ai/screen-awareness); [9to5Mac, 2026-08-12](https://9to5mac.com/2026/08/12/raycast-adds-a-new-way-to-ask-ai-about-whatever-is-on-your-screen/)
- **Floating-window edge cases:** Raycast had to fix floating windows not following the current Space and losing Always-on-Top (snippet). — [Raycast changelog](https://www.raycast.com/changelog/macos-v1)

### Inferences
- **Two-tier chat for a pixel companion.**
  - The ephemeral tier is speech bubbles next to the sprite: auto-fade after a few seconds, pause fading on hover, and never steal focus (non-activating panel).
  - The durable tier is a history or log window, opened with one click or hotkey, where every bubble is also appended. Fading should only ever hide a copy, never the only record.
- **Separate hotkeys.** Use one global hotkey to summon or hide the companion's input, and a separate one, or the same hotkey held, to open history. Raycast's toggle-hotkey plus promote-to-window pattern is the reference.
- **Focus rule.** Bubbles that appear without user action must not take keyboard focus, which follows the Clippy lesson on interruption. Only the user-summoned input field should become key.

### Gaps
- No sources were gathered on iMessage-style or Spotlight-style fading bubble timing, notification-style persistence (Notification Center as the "lost message" backstop), or how other overlay chat apps (ChatGPT desktop's companion window, Apple Intelligence/Siri overlays) handle history. These were not searched.
- No usability studies on auto-dismiss timing for transient messages.
