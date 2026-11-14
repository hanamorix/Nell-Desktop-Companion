# Kitty panel spike: 2026-11-14

Question: can kitty's panel mode sit inside a speech bubble that Nell draws, so the console looks like part of Nell and no terminal window is ever visible? Tested with kitty 0.50.0 on Darwin 27.3, with Claude Code 2.1.321 running inside the panel.

## Confirmed by measurement (CGWindowList and `kitten @`)

- **Launch:**
  ```
  kitten panel --edge none --margin-left X --margin-top Y --columns Wpx --lines Hpx --layer overlay \
    -o macos_ns_window_layer=NSScreenSaverWindowLevel -o allow_remote_control=socket-only \
    -o tab_bar_style=hidden --listen-on 'unix:<dir>/np-{kitty_pid}.sock' <cmd>
  ```
  This gives one borderless window owned by `kitty-quick-access` at **layer 1000**, the same level as Nell's panel.
- **Position:** `margin-left` maps exactly to screen x. `margin-top` is measured from below the menu bar: y = margin + 37 on this display.
- **Size:** the panel comes out a fixed **+56 px** wider and taller than requested (700×420 gave 756×476; 600×300 gave 656×356), so Nell asks for the target size minus 56.
- **Starting hidden:** `--start-as-hidden` keeps the panel off screen (onscreen 0) until `@ resize-os-window --action show`.
- **Moving and resizing while running:** `@ resize-os-window --action os-panel --incremental margin-left=… margin-top=… columns=…px lines=…px` takes about **22 ms per call**.
- **Hiding:** `@ resize-os-window --action hide|show` toggles it on and off screen. kitty and Claude keep running while it's hidden.
- **Chat as a hidden tab:** `@ launch --type=tab --keep-focus --env NELL_MODE=chat …` adds a second tab. With `tab_bar_style=hidden` the panel keeps showing the code tab. `send-text --stdin` and `send-key` to `env:NELL_MODE=chat` reach the background tab, and Claude answered.
- **Env tagging:** a window started with `/usr/bin/env NELL_MODE=code <cmd>` is matched by `--match env:NELL_MODE=code`.

## Why kitty windows kept appearing in v1

Nell's v1 kitty (pid 59873) had **both** its OS windows on screen at layer 0. So `--start-as hidden` together with `--session` doesn't keep them hidden, and `@ launch --type=os-window` shows the window before the `hide` call. A leftover kitty from the first spike (`nell-k2`) had also been running in the background, and it has now been stopped.

## Confirmed with the user at the screen

- [x] **Typing works only with `--focus-policy=on-demand`.** The default is `not-allowed`, and macOS honours it, so the panel refuses keyboard focus and the user couldn't type. After `@ resize-os-window --action os-panel --incremental focus-policy=on-demand`, the user clicked in and typed, and it reached Claude. The setting can be changed while the panel is running, and Nell should also pass it at launch.
- [x] **It stays visible over a full-screen app**, confirmed by the user with an app in full screen (⌃⌘F).
- [ ] Behaviour on a second display; only the built-in display was available.
