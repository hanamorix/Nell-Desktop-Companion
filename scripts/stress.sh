#!/bin/bash
# CPU and RAM stress test on a sandboxed showcase Nell (never the user's own):
#   bash scripts/stress.sh [idle_min=12] [busy_min=5] [burst_min=2]
# Each phase launches the showcase with `open -n`, samples only its pid once a second with `ps -o %cpu=,rss=`,
# then kills that pid. Raw samples and a summary CSV land in build/stress/<timestamp>/.
#
# Pass bars:
#   idle   CPU average <= 1 %, and <= 0.2 % after the 600 s long-quiet switch (measured from 615 s)
#   busy   CPU average <= 10 %
#   burst  CPU average <= 25 %, and no stalls (the showcase logs STALL when its main-thread timer fires > 1 s late)
#   all    RSS under 80 MB, and a second-half RSS slope under 1 MB/min (leak check)
set -euo pipefail
cd "$(dirname "$0")/.."
IDLE=${1:-12} BUSY=${2:-5} BURST=${3:-2} # idle runs past the 600 s quiet switch, so 2 min are measured after it
APP=build/showcase/Nell.app
BIN="$PWD/$APP/Contents/MacOS/Nell"
OUT="build/stress/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"
bash scripts/showcase.sh list >/dev/null # bundles the showcase if it's stale
if pgrep -f "$BIN" >/dev/null; then echo "a showcase is already running; quit it first (kill <its pid>)" >&2; exit 1; fi

echo "phase,minutes,cpu_avg,cpu_peak,rss_start_mb,rss_peak_mb,rss_end_mb,rss_slope_mb_per_min,cpu_after_quiet,stalls,pass" > "$OUT/summary.csv"

phase() { # phase <name> <scene, or "" for the full cycle> <minutes>
  local name=$1 scene=$2 minutes=$3 log="$OUT/$1.log" csv="$OUT/$1.csv"
  open -n --stderr "$PWD/$log" "$APP" --args --showcase $scene
  local pid=""
  for _ in $(seq 50); do pid=$(pgrep -f "$BIN" || true); [ -n "$pid" ] && break; sleep 0.2; done
  [ -n "$pid" ] || { echo "showcase didn't start" >&2; exit 1; }
  echo "t_s,cpu_pct,rss_kb" > "$csv"
  local t0 end; t0=$(date +%s); end=$((t0 + minutes * 60))
  while [ "$(date +%s)" -lt "$end" ]; do
    s=$(ps -o %cpu=,rss= -p "$pid") || break
    echo "$(( $(date +%s) - t0 )),$(echo $s | tr ' ' ',')" >> "$csv"
    sleep 1
  done
  kill "$pid" # the showcase only
  local stalls; stalls=$(grep -c STALL "$log" || true)
  awk -F, -v name="$name" -v minutes="$minutes" -v stalls="$stalls" '
    NR == 1 { next }
    { n++; t[n] = $1; c[n] = $2; r[n] = $3 / 1024 }
    END {
      half = t[n] / 2; sum = 0; peak = 0; rpeak = 0; qs = 0; qn = 0; m = 0; st = 0; sr = 0; str = 0; stt = 0
      for (i = 1; i <= n; i++) {
        sum += c[i]; if (c[i] > peak) peak = c[i]; if (r[i] > rpeak) rpeak = r[i]
        if (t[i] >= 615) { qs += c[i]; qn++ } # 600 s with no events, plus a little settling
        if (t[i] >= half) { m++; x = t[i] / 60; st += x; sr += r[i]; str += x * r[i]; stt += x * x }
      }
      avg = sum / n; slope = (m > 1) ? (m * str - st * sr) / (m * stt - st * st) : 0
      quiet = (qn > 0) ? sprintf("%.2f", qs / qn) : "n/a"
      bar = (name == "idle") ? 1 : (name == "busy") ? 10 : 25
      ok = avg <= bar && rpeak < 80 && slope < 1
      if (name == "idle" && qn > 0 && qs / qn > 0.2) ok = 0
      if (name == "burst" && stalls > 0) ok = 0
      printf "%s,%s,%.2f,%.1f,%.1f,%.1f,%.1f,%.3f,%s,%s,%s\n", name, minutes, avg, peak, r[1], rpeak, r[n], slope, quiet,
             (name == "burst") ? stalls : "n/a", ok ? "PASS" : "FAIL"
    }' "$csv" >> "$OUT/summary.csv"
  tail -1 "$OUT/summary.csv"
}

phase idle idle "$IDLE"
phase busy "" "$BUSY"
phase burst burst "$BURST"
echo "results: $OUT/summary.csv"
column -s, -t < "$OUT/summary.csv"
