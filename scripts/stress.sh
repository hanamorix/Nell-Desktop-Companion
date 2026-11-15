#!/bin/bash
# CPU and RAM stress test on a sandboxed showcase Nell (never the user's own):
#   bash scripts/stress.sh [idle_min=12] [busy_min=5] [burst_min=2]
# Each phase launches the showcase with `open -n`, samples only its pid once a second with `ps -o %cpu=,rss=,time=`
# and every 10 s with `footprint` (physical footprint: what Activity Monitor shows, graphics included), then kills that
# pid. Raw samples and a summary CSV land in build/stress/<timestamp>/. RSS is recorded as information only: it counts
# shared system-framework pages that every SwiftUI app maps.
# cpu_avg is total CPU time over wall time (ps's %cpu is a decaying average, so averaging it smears phases together);
# cpu_after_quiet is the same from 615 s on. cpu_peak is the highest %cpu sample.
#
# Pass bars:
#   idle   CPU average <= 1 %, and <= 0.2 % after the 600 s long-quiet switch (measured from 615 s)
#   busy   CPU average <= 10 %
#   burst  CPU average <= 25 %, and no stalls (the showcase logs STALL when its main-thread timer fires > 1 s late)
#   idle, busy   footprint peak <= 80 MB, and a second-half footprint slope under 1 MB/min (leak check)
#   burst        memory is report-only: its once-a-second window resize (placement and console) is a torture case
set -euo pipefail
cd "$(dirname "$0")/.."
IDLE=${1:-12} BUSY=${2:-5} BURST=${3:-2} # idle runs past the 600 s quiet switch, so 2 min are measured after it
APP=build/showcase/Nell.app
BIN="$PWD/$APP/Contents/MacOS/Nell"
OUT="build/stress/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"
bash scripts/showcase.sh list >/dev/null # bundles the showcase if it's stale
if pgrep -f "$BIN" >/dev/null; then echo "a showcase is already running; quit it first (kill <its pid>)" >&2; exit 1; fi

echo "phase,minutes,cpu_avg,cpu_peak,cpu_after_quiet,stalls,footprint_peak_mb,footprint_slope_mb_per_min,graphics_peak_mb,rss_start_mb,rss_peak_mb,rss_end_mb,pass" > "$OUT/summary.csv"

mb() { awk -v v="$1" -v u="$2" 'BEGIN { print (u == "KB") ? v / 1024 : (u == "GB") ? v * 1024 : (u == "B") ? 0 : v }'; }
snapshot() { # snapshot <pid> <t> <txt> <csv>: one footprint sample
  footprint "$1" > "$3" 2>/dev/null || return 0
  local f g
  f=$(awk '/Footprint:/ { for (i = 1; i < NF; i++) if ($i == "Footprint:") { print $(i + 1), $(i + 2); exit } }' "$3")
  g=$(awk '/\(graphics\)/ && /Owned physical footprint/ { print $1, $2; exit }' "$3")
  [ -n "$f" ] && echo "$2,$(mb $f),$( [ -n "$g" ] && mb $g || echo 0)" >> "$4"
}

phase() { # phase <name> <scene, or "" for the full cycle> <minutes>
  local name=$1 scene=$2 minutes=$3 log="$OUT/$1.log" csv="$OUT/$1.csv" fcsv="$OUT/$1-footprint.csv"
  open -n --stderr "$PWD/$log" "$APP" --args --showcase $scene
  local pid=""
  for _ in $(seq 50); do pid=$(pgrep -f "$BIN" || true); [ -n "$pid" ] && break; sleep 0.2; done
  [ -n "$pid" ] || { echo "showcase didn't start" >&2; exit 1; }
  echo "t_s,cpu_pct,rss_kb,cpu_time_s" > "$csv"
  echo "t_s,footprint_mb,graphics_mb" > "$fcsv"
  local t0 end next=0; t0=$(date +%s); end=$((t0 + minutes * 60))
  while [ "$(date +%s)" -lt "$end" ]; do
    if [ $(( $(date +%s) - t0 )) -ge "$next" ]; then snapshot "$pid" $(( $(date +%s) - t0 )) "$OUT/$name-footprint.txt" "$fcsv"; next=$((next + 10)); fi
    s=$(ps -o %cpu=,rss=,time= -p "$pid") || break
    # time= is [h:]m:ss.ss of CPU used so far
    echo "$(( $(date +%s) - t0 )),$(echo $s | awk '{n = split($3, p, ":"); c = 0; for (i = 1; i <= n; i++) c = c * 60 + p[i]; print $1 "," $2 "," c}')" >> "$csv"
    sleep 1
  done
  snapshot "$pid" $(( $(date +%s) - t0 )) "$OUT/$name-footprint.txt" "$fcsv" # and one at the very end
  kill "$pid" # the showcase only
  while kill -0 "$pid" 2>/dev/null; do sleep 0.2; done # gone before the next phase looks for a showcase
  local stalls; stalls=$(grep -c STALL "$log" || true)
  awk -F, -v name="$name" -v minutes="$minutes" -v stalls="$stalls" '
    FNR == 1 { next }
    FILENAME ~ /-footprint\.csv$/ { fn++; ft[fn] = $1; fv[fn] = $2; if ($2 > fpeak) fpeak = $2; if ($3 > gpeak) gpeak = $3; next }
    { n++; t[n] = $1; c[n] = $2; r[n] = $3 / 1024; k[n] = $4 }
    END {
      half = t[n] / 2; sum = 0; peak = 0; rpeak = 0; m = 0; st = 0; sr = 0; str = 0; stt = 0
      for (i = 1; i <= n; i++) {
        sum += c[i]; if (c[i] > peak) peak = c[i]; if (r[i] > rpeak) rpeak = r[i]
        if (t[i] >= 615 && !q0) q0 = i # 600 s with no events, plus a little settling
      }
      for (i = 1; i <= fn; i++) if (ft[i] >= half) { m++; x = ft[i] / 60; st += x; sr += fv[i]; str += x * fv[i]; stt += x * x }
      avg = (t[n] > t[1]) ? 100 * (k[n] - k[1]) / (t[n] - t[1]) : 0
      slope = (m > 1) ? (m * str - st * sr) / (m * stt - st * st) : 0
      qn = (q0 && t[n] > t[q0]) ? 1 : 0; qv = qn ? 100 * (k[n] - k[q0]) / (t[n] - t[q0]) : 0
      quiet = qn ? sprintf("%.2f", qv) : "n/a"
      bar = (name == "idle") ? 1 : (name == "busy") ? 10 : 25
      ok = avg <= bar
      if (name != "burst" && (fn == 0 || fpeak > 80 || slope >= 1)) ok = 0 # burst memory is report-only
      if (name == "idle" && (!qn || qv > 0.2)) ok = 0
      if (name == "burst" && stalls > 0) ok = 0
      printf "%s,%s,%.2f,%.1f,%s,%s,%.1f,%.3f,%.1f,%.1f,%.1f,%.1f,%s\n", name, minutes, avg, peak, quiet,
             (name == "burst") ? stalls : "n/a", fpeak, slope, gpeak, r[1], rpeak, r[n], ok ? "PASS" : "FAIL"
    }' "$fcsv" "$csv" >> "$OUT/summary.csv"
  tail -1 "$OUT/summary.csv"
}

phase idle idle "$IDLE"
phase busy "" "$BUSY"
phase burst burst "$BURST"
echo "results: $OUT/summary.csv"
column -s, -t < "$OUT/summary.csv"
