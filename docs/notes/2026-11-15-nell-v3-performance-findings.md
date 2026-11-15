# v3 performance findings: CPU and RAM stress test (2026-11-15)

The user asked for a stress test "to make sure that Nell has little impact on CPU / RAM Usage". This doc records how Nell was measured, the results against the pass bars, and the one fix the numbers called for.

## Method

- **What runs.** `scripts/stress.sh` runs the sandboxed showcase Nell (`build/showcase/Nell.app`, Task 11) in three phases. It never touches the user's own Nell.
- **How each phase runs:**
  - Each phase launches the showcase with `open -n`.
  - It samples only the showcase's pid, once a second, with `ps -o %cpu=,rss=,time=`.
  - It takes one `footprint` snapshot just before the end.
  - It then kills that pid and waits for it to exit.
- **Phases:**

  | Phase | Default length | What runs |
  |---|---|---|
  | Idle | 12 min | `--showcase idle`: no events at all. The first 600 s animate normally; after 600 s with no events, Nell's long-quiet mode stops breathing and slows blinks to every 8–15 s. |
  | Busy | 5 min | The full showcase cycle (every scene, a step every 3 s). |
  | Burst | 2 min | `--showcase burst`: about 20 hook events a second (prompts, tool use, test results, failures, replies, approvals, context reads), plus a console open/minimise and a placement change about once a second. |

- **Why idle runs 12 minutes, not 10.** The brief's 10 minutes ends exactly at the 600 s quiet switch, so nothing after it could be measured.
- **How the numbers are worked out:**
  - `cpu_avg` is CPU time used divided by wall time, in % of one core. `ps`'s `%cpu` is a decaying average, so averaging it would smear the phases together.
  - `cpu_after_quiet` is the same ratio, from 615 s to the end of the idle phase.
  - `cpu_peak` is the highest 1 s `%cpu` sample.
  - RSS start, peak and end come from the samples.
  - The leak check is the least-squares RSS slope over the second half of each phase.
  - `footprint_mb` is the process's physical footprint, which is what Activity Monitor shows. It includes graphics memory that RSS does not count.
- **Stalls.** The showcase logs `STALL` whenever its main-thread step timer fires more than 1 s late. The burst phase counts those lines.
- **Profiling.** I profiled the burst with `sample <pid> 5`, and checked candidate causes with 60 s A/B burst runs: CPU time over 60 s after a 10 s warm-up, with one local change each.

## Machine

- Apple M3 Pro, 11 cores (`machdep.cpu.brand_string`, `hw.ncpu`)
- 18 GB memory (`hw.memsize` = 19327352832)
- macOS 27.3
- Release build (`swift build -c release`), ad-hoc signed, run from `build/showcase/Nell.app`

## Results

Run `build/stress/20261115-125031` (`bash scripts/stress.sh`, defaults 12 + 5 + 2 min). CPU is in % of one core.

| Phase | CPU avg | CPU peak | CPU after quiet | RSS start → peak → end (MB) | RSS slope, 2nd half | Footprint | Stalls | Result |
|---|---|---|---|---|---|---|---|---|
| Idle (12 min) | **0.72 %** ✓ | 3.9 % | **0.17 %** ✓ | 9.3 → **81.4** → 60.5 ✗ | +0.05 MB/min ✓ | 21 MB | n/a | FAIL (RSS) |
| Busy (5 min) | **2.13 %** ✓ | 10.2 % | n/a | 8.4 → **89.4** → 88.9 ✗ | +0.13 MB/min ✓ | 31 MB | n/a | FAIL (RSS) |
| Burst (2 min) | **29.75 %** ✗ | 38.7 % | n/a | 12.1 → **89.9** → 77.2 ✗ | −9.65 MB/min ✓ | 133 MB (101 MB graphics) | 0 ✓ | FAIL (CPU, RSS) |

Against the bars:
- **CPU passes in idle and busy.**
  - Idle averages 0.72 % (bar ≤ 1 %) and drops to 0.17 % once the 600 s quiet switch stops her breathing (bar ≤ 0.2 %).
  - The full showcase cycle averages 2.13 % (bar ≤ 10 %).
- **Burst CPU fails:** 29.75 % against ≤ 25 %. It never stalled; no main-thread timer fired more than 1 s late.
- **No leaks.** Every second-half RSS slope is under 1 MB/min, and the burst's is negative.
- **RSS fails the 80 MB bar in every phase.** Idle exceeds it only for its first 11 s (80.8–81.4 MB during launch), then settles at 76.7 MB and later 60.5 MB. Busy and burst sit around 85–90 MB. The memory section below explains what RSS counts here.

The first full run (`build/stress/20261115-122302`, script defaults then 10 + 5 + 2) gave the same picture:
- idle 0.73 % (the 10 min phase ended at the quiet switch, so there was no after-quiet figure)
- busy 2.13 %
- burst 29.5 %, no stalls
- RSS peaks 81.3, 89.8 and 90.8 MB

## Fix: decode the sprite sheet once

- **Symptom.** The first burst profile showed `png_read_filter_row_paeth_neon` and `PNGReadPlugin::DecodeUncomposedFrames` on the main thread, called from `SpriteDriver.redraw`. The sprite sheet's `CGImage` came straight from `CGImageSourceCreateImageAtIndex`, which decodes lazily. Every `cropping(to:)` + draw re-decoded PNG blocks, on every animation frame.
- **Second cost.** The alpha mask for the right-click hit test was rebuilt from the composited frame on every redraw, with a 16 K-element closure map.
- **Fix** (commit `perf: decode the sprite sheet once, build the hit mask on demand`):
  - `loadSprites()` decodes the sheet once into a plain bitmap (`decodedBitmap`, NellCore).
  - `SpriteDriver.mask` is built only when the click-through poll asks for it (`SpriteMask(image:)`, NellCore), and cached until the next frame.
  - Both have tests: `decodedSheetIsAPlainBitmap` and `spriteMaskFromAnImage`.
- **Before and after**, same method (60 s burst A/B, after a 10 s warm-up): 

| Build | Burst CPU |
|---|---|
| Before both fixes (`076ea6a`'s `SpriteCompositor.swift`) | **32.5 %** |
| Mask fix only (decode reverted) | 30.5 % |
| Both fixes (`4511206`) | **29.3–29.8 %** (two runs) |

- The two fixes save about 3 points of one core, roughly 9 %, at burst load.
- The decode fix alone is within run-to-run noise (about ±2 %), but the profile no longer shows any PNG decoding on the main thread.
- The 1-minute smoke run before the fix (31.7 %) includes launch, so it isn't comparable..

## Burst: where the rest of the CPU goes

After the fix, the burst still averages about 29 % of one core, against a 25 % bar. I tested three candidates with 60 s A/B runs:

| Change tried (not kept) | Burst CPU |
|---|---|
| Baseline, after the decode fix | 29.8 % |
| No once-a-second placement change or console toggle (window resize and relayout) | 32.0 % |
| Task 12 `ColumnRow` / `Cap` placing with the same proposal they measure with | 29.3 % |
| `HoverRectsKey.reduce` stubbed out | 29.5 % |

- **None of them is the cause.** Each result is within run-to-run noise of the baseline (about ±2 %).
- **The remaining cost is SwiftUI re-rendering Nell's window once per event.** At 20 events a second that means re-laying out the bubble column (text measurement), recompositing the sprite when the emoji or face changes, and the Core Animation commit.
- **Fixing it would need coalescing or throttling renders.** That is a design change, so it is left as a finding rather than done in this task.
- **For scale:**
  - 29 % of one core is under 3 % of this 11-core machine.
  - Real Claude Code sessions send a few events a second at most, which the busy phase reflects.
  - No `STALL` was logged, so the UI kept up.

## RSS and memory

`ps`'s RSS counts every resident page mapped into the process, including the shared framework pages (SwiftUI, AppKit, Core Text) that every app maps. What is Nell's own is much smaller:

- **`vmmap --summary` on a busy showcase:** 91 MB RSS, of which only **28.5 MB is dirty, private memory**. The rest is shared `__TEXT`, `__OBJC_RO` and `__AUTH_CONST` pages of system frameworks.
- **Physical footprint** (what Activity Monitor shows), snapshots of the showcase:

  | State | Footprint | Graphics | RSS |
  |---|---|---|---|
  | Idle, after 12 min | 21 MB | about 0 | 60.5 MB |
  | Bubbles scene, console hidden (30 s) | 29 MB | 544 KB | 89.7 MB |
  | Console open | 24 MB | 464 KB | 84.3 MB |
  | Console minimised | 26 MB | 464 KB | 86.0 MB |
  | End of the busy phase | 31 MB | 0.5 MB | 88.9 MB |
  | End of the burst phase | **133 MB** | **101 MB** | 77.2 MB |

- **The large graphics figure appears only in the burst.** That phase resizes Nell's window (placement change, console open/minimise) every second. An open console on its own costs almost nothing (24 MB), so the console-sized transparent panel is not the cost. Repeated window resizing leaves Core Animation backing surfaces resident for a while.
  - It is not a leak: the burst's RSS falls over its second half.
  - A user moves Nell or toggles the console a few times a session, not once a second.
- **Code changes won't reach the RSS bar.** Nell's own memory is 21–31 MB in normal use; the remaining ~50–60 MB of RSS is shared framework code that any SwiftUI app maps. Meeting an 80 MB RSS bar would mean dropping SwiftUI, not tuning Nell. I left the bar unchanged in the script, so it reports FAIL.

## Takeaways

- **Idle and normal use are cheap.**
  - 0.72 % of one core idle, 0.17 % after 10 quiet minutes.
  - About 2 % during the full showcase cycle.
  - 21–31 MB of physical footprint, and no leak in any phase.
- **The decode fix is kept.** It also removes per-frame PNG decoding at normal load.
- **Two bars fail and are left as findings for a ruling:**
  - **Burst CPU, 29.75 % against 25 %.** The rest is SwiftUI re-rendering once per event at 20 events a second. Coalescing or throttling renders is a design change.
  - **RSS, 81–90 MB against 80 MB.** That is mostly shared framework pages; Nell's own footprint is 21–31 MB. A footprint-based bar would measure Nell itself.
- **Not measured:**
  - kitty and the `claude` processes, which the showcase never starts
  - a real Claude Code session's event rate
