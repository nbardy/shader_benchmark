#!/usr/bin/env bash
# Render the animated hyper-Menger-on-S3 loop to an h264 mp4.
#
# Renders FRAMES frames of shader.wgsl with shader-bench --time spanning one
# exact LOOP_SECONDS loop (frame N is NOT rendered twice: t goes 0 .. LOOP*(N-1)/N
# so the video tiles seamlessly), then encodes with ffmpeg.
#
# Usage: ./render_video.sh            (720 frames, 30 fps, 24 s, 1024px)
#        FRAMES=180 SIZE=512 ./render_video.sh   (quick preview)

set -euo pipefail
cd "$(dirname "$0")"

FRAMES="${FRAMES:-720}"
FPS="${FPS:-30}"
LOOP_SECONDS="${LOOP_SECONDS:-24.0}"  # must match LOOP_SECONDS in shader.wgsl
SIZE="${SIZE:-1024}"
OUT="${OUT:-menger_3sphere.mp4}"
# Phase offset: the first frame is the video's hero/thumbnail image, and the
# shape at phase 0 is a weak opener. The shader is LOOP-periodic, so any
# offset keeps the loop seamless — 3.0 was chosen by eye.
START_OFFSET="${START_OFFSET:-3.0}"

BENCH="$(cd ../../shader_harness && pwd)/target/release/shader-bench"
if [[ ! -x "$BENCH" ]]; then
    echo "shader-bench not built; run: cd ../../shader_harness && source ~/.cargo/env && cargo build --release" >&2
    exit 1
fi
command -v ffmpeg >/dev/null || { echo "ffmpeg not found (try: brew install ffmpeg)" >&2; exit 1; }

mkdir -p frames
for ((i = 0; i < FRAMES; i++)); do
    t=$(awk -v i="$i" -v n="$FRAMES" -v l="$LOOP_SECONDS" -v o="$START_OFFSET" 'BEGIN { x = o + l * i / n; if (x >= l) x -= l; printf "%.6f", x }')
    out=$(printf "frames/frame_%04d.png" "$i")
    "$BENCH" --shader shader.wgsl --output "$out" --size "$SIZE" --time "$t" > /dev/null
    printf "\rframe %d/%d (t=%s)" "$((i + 1))" "$FRAMES" "$t"
done
echo

ffmpeg -y -framerate "$FPS" -i frames/frame_%04d.png \
    -c:v libx264 -pix_fmt yuv420p -crf 18 -preset slow -movflags +faststart \
    "$OUT"
echo "wrote $OUT"
