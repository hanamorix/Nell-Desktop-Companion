# v3 performance findings: CPU and RAM stress test (2026-11-15)

The user asked for a stress test "to make sure that Nell has little impact on CPU / RAM Usage". This doc records how Nell was measured, the results against the pass bars, and the one fix the numbers called for.

## Method

- **What runs.** `scripts/stress.sh` runs the sandboxed showcase Nell (`build/showcase/Nell.app`, Task 11) in three phases. It never touches the user's own Nell.
- **How each phase runs:**
  - Each phase launches the showcase with `open -n`.
  - It samples only the showcase's pid, once a second, with `ps -o %cpu=,rss=,time=`.
  - Every 10 s, and once at the end, it samples the physical footprint with `footprint` (that tool is slower than `ps`).
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
  - **Memory is the physical footprint**, which is what Activity Monitor shows. It includes graphics memory that RSS does not count. The script reports its peak and the least-squares slope over the second half of each phase; the slope is the leak check.
  - RSS start, peak and end are recorded for information only. They count the shared system-framework pages that every SwiftUI app maps (see the memory section).
- **Pass bars** (the controller's ruling on memory):

  | Phase | CPU | Memory |
  |---|---|---|
  | Idle | average ≤ 1 %, and ≤ 0.2 % after the 600 s quiet switch | steady footprint ≤ 80 MB, second-half slope < 1 MB/min |
  | Busy | average ≤ 10 % | steady footprint ≤ 80 MB, second-half slope < 1 MB/min |
  | Burst | average ≤ 25 %, no stalls | report-only, because its once-a-second window resize (placement and console) is a torture case |

  "Steady footprint" is the median of the footprint samples in the second half of the phase. The peak is reported but not barred (the controller's later ruling).
- **Stalls.** The showcase logs `STALL` whenever its main-thread step timer fires more than 1 s late. The burst phase counts those lines.
- **Profiling.** I profiled the burst with `sample <pid> 5`, and checked candidate causes with 60 s A/B burst runs: CPU time over 60 s after a 10 s warm-up, with one local change each.

## Machine

- Apple M3 Pro, 11 cores (`machdep.cpu.brand_string`, `hw.ncpu`)
- 18 GB memory (`hw.memsize` = 19327352832)
- macOS 27.3
- Release build (`swift build -c release`), ad-hoc signed, run from `build/showcase/Nell.app`

## Results

The verdicts combine two runs:
- **CPU** comes from the full run `build/stress/20261115-125031` (defaults 12 + 5 + 2 min).
- **Memory** comes from a short re-run `build/stress/20261115-132307` (`bash scripts/stress.sh 3 3 1`), made after the bar was ruled to be footprint. That run is labelled "memory re-run" below. Its idle phase is too short to reach the quiet switch, so its own idle CPU verdict doesn't count.
- The steady-footprint verdicts were re-derived from that run's 10 s footprint samples (`<phase>-footprint.csv`) with the current script's summary step. The full run has no footprint samples.

CPU is in % of one core.

| Phase | CPU avg | CPU after quiet | Stalls | Steady footprint | Footprint peak (not barred) | Footprint slope, 2nd half | Graphics peak | Result |
|---|---|---|---|---|---|---|---|---|
| Idle | **0.72 %** ✓ | **0.17 %** ✓ | n/a | **21 MB** ✓ | 22 MB | 0.00 MB/min ✓ | 0 | **PASS** |
| Busy | **2.13 %** ✓ | n/a | n/a | **30 MB** ✓ | 119 MB | −8.8 MB/min ✓ | 85 MB | **PASS** |
| Burst | **29.75 %** ✗ | n/a | 0 ✓ | 133 MB (report-only) | 134 MB | −1.8 MB/min | 101 MB | **FAIL** (CPU) |

RSS, for information only:

| Run | Idle start / peak / end | Busy | Burst |
|---|---|---|---|
| Full run | 9.3 / 81.4 / 60.5 MB | 8.4 / 89.4 / 88.9 MB | 12.1 / 89.9 / 77.2 MB |
| Memory re-run | 36.6 / 81.4 / 76.7 MB | 46.2 / 89.1 / 88.7 MB | 47.6 / 90.0 / 85.3 MB |

The memory re-run's CPU matched the full run: idle 0.85 % over its first 3 min, busy 2.13 %, burst 29.61 % with 0 stalls.

Against the bars:
- **Idle passes everything.**
  - CPU averages 0.72 % and drops to 0.17 % once the 600 s quiet switch stops her breathing.
  - Her steady footprint is 21 MB (peak 22 MB).
- **Busy CPU passes** (2.13 % against ≤ 10 %).
- **Busy memory passes: the steady footprint is 30 MB** (bar ≤ 80 MB). The peak is reported but not barred.
  - Between steps the footprint is 26–31 MB, but it spikes to 116–119 MB for 1–2 s at a time, with 84–100 MB of that being graphics memory.
  - A 0.5 s graphics trace of the full cycle tied the spikes to steps where bubbles appear or change (faces, body, emoji and bubbles scenes).
  - Removing the bubbles' `.compositingGroup()` didn't change them: 16 vs 13 of 77 samples over 10 MB, peak 100 MB both ways. The cause is still open.
  - The second-half slope is negative, so it is not a leak. Its size (−8.8 MB/min) comes from a spike landing early in the second half, not from a real fall.
- **Burst CPU fails** (29.75 % against ≤ 25 %; see the burst section). It never stalled.
- **Burst memory is report-only.** It held at 133–134 MB, with 101 MB of graphics, for the whole phase, with a negative slope.

The first full run (`build/stress/20261115-122302`, script defaults then 10 + 5 + 2) gave the same CPU picture:
- idle 0.73 % (the 10 min phase ended at the quiet switch, so there was no after-quiet figure)
- busy 2.13 %
- burst 29.5 %, no stalls

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

The memory bar is footprint, by the controller's ruling. RSS stays in the CSV as information only.

`ps`'s RSS counts every resident page mapped into the process, including the shared framework pages (SwiftUI, AppKit, Core Text) that every app maps. What is Nell's own is much smaller:

- **`vmmap --summary` on a busy showcase:** 91 MB RSS, of which only **28.5 MB is dirty, private memory**. The rest is shared `__TEXT`, `__OBJC_RO` and `__AUTH_CONST` pages of system frameworks.
- **Physical footprint** (what Activity Monitor shows), one-off snapshots of the showcase taken before footprint was sampled through each phase:

  | State | Footprint | Graphics | RSS |
  |---|---|---|---|
  | Idle, after 12 min | 21 MB | about 0 | 60.5 MB |
  | Bubbles scene, console hidden (30 s) | 29 MB | 544 KB | 89.7 MB |
  | Console open | 24 MB | 464 KB | 84.3 MB |
  | Console minimised | 26 MB | 464 KB | 86.0 MB |
  | End of the busy phase | 31 MB | 0.5 MB | 88.9 MB |
  | End of the burst phase | **133 MB** | **101 MB** | 77.2 MB |

- **Those single snapshots missed the busy phase's spikes.** Sampling every 10 s, and a 0.5 s graphics trace, show the busy footprint jumping to 116–119 MB for 1–2 s when bubbles appear or change (84–100 MB graphics), then falling back to 26–31 MB.
  - An open console on its own costs almost nothing (24 MB), so the console-sized transparent panel is not the cost.
  - Removing the bubbles' `.compositingGroup()` didn't change the spikes.
  - The cause is open, so it is reported here rather than fixed.
- **The burst holds 133–134 MB, 101 MB of it graphics, for its whole run.** It resizes Nell's window (placement change, console open/minimise) every second, which keeps Core Animation surfaces resident.
  - It is not a leak: the footprint slope is negative.
  - A user moves Nell or toggles the console a few times a session, not once a second, which is why burst memory is report-only.
- **RSS (81–90 MB) is mostly shared framework code** that any SwiftUI app maps. That is why the bar measures footprint instead.

## Takeaways

- **Idle and normal use are cheap.**
  - 0.72 % of one core idle, 0.17 % after 10 quiet minutes.
  - About 2 % during the full showcase cycle.
  - A 22 MB footprint while idle, 26–31 MB between busy steps, and no leak in any phase.
- **The decode fix is kept.** It also removes per-frame PNG decoding at normal load.
- **One bar fails and is left as a finding: burst CPU, 29.75 % against 25 %.** The rest is SwiftUI re-rendering once per event at 20 events a second. Coalescing or throttling renders is a design change.
- **Busy memory passes on its steady footprint (30 MB), but it has transient spikes, reported rather than barred.** These are 1–2 s graphics spikes (peak 119 MB, 84–100 MB of graphics) when bubbles appear or change. The cause is open; `.compositingGroup()` is ruled out.
- **Not measured:**
  - kitty and the `claude` processes, which the showcase never starts
  - a real Claude Code session's event rate
