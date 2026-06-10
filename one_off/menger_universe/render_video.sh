#!/usr/bin/env bash
# Render the Menger universe loop (intrinsic S^3 geodesic raymarch) to mp4.
#
# Renders FRAMES frames of shader.wgsl with shader-bench --time spanning one
# exact LOOP_SECONDS loop (frame N is NOT rendered twice: t goes
# 0 .. LOOP*(N-1)/N so the video tiles seamlessly), then encodes with ffmpeg.
#
# Usage: ./render_video.sh            (720 frames, 30 fps, 24 s, 1024px)
#        FRAMES=180 SIZE=512 ./render_video.sh   (quick preview)

set -euo pipefail
cd "$(dirname "$0")"

FRAMES="${FRAMES:-720}"
FPS="${FPS:-30}"
LOOP_SECONDS="${LOOP_SECONDS:-24.0}"  # must match LOOP_SECONDS in shader.wgsl
SIZE="${SIZE:-1024}"
OUT="${OUT:-menger_universe.mp4}"

BENCH="$(cd ../../shader_harness && pwd)/target/release/shader-bench"
if [[ ! -x "$BENCH" ]]; then
    echo "shader-bench not built; run: cd ../../shader_harness && source ~/.cargo/env && cargo build --release" >&2
    exit 1
fi
command -v ffmpeg >/dev/null || { echo "ffmpeg not found (try: brew install ffmpeg)" >&2; exit 1; }

mkdir -p frames
for ((i = 0; i < FRAMES; i++)); do
    t=$(awk -v i="$i" -v n="$FRAMES" -v l="$LOOP_SECONDS" 'BEGIN { printf "%.6f", l * i / n }')
    out=$(printf "frames/frame_%04d.png" "$i")
    "$BENCH" --shader shader.wgsl --output "$out" --size "$SIZE" --time "$t" > /dev/null
    printf "\rframe %d/%d (t=%s)" "$((i + 1))" "$FRAMES" "$t"
done
echo

ffmpeg -y -framerate "$FPS" -i frames/frame_%04d.png \
    -c:v libx264 -pix_fmt yuv420p -crf 18 -preset slow -movflags +faststart \
    "$OUT"
echo "wrote $OUT"
