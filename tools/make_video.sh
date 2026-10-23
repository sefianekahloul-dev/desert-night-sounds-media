#!/usr/bin/env bash
# Build a long Desert Night Sounds video from one photo and a synthesized sound bed.
# Usage: make_video.sh <photo.jpg> <output.mp4> <hours> <sound-style> [seed]
# Sound styles: wind | rain | brown | pink | white | storm | fire | ocean
# The 10-minute segment is built once, then looped with stream copy, so the
# result stays small enough for GitHub (keep hours <= 3).
set -euo pipefail

PHOTO="$1"; OUT="$2"; HOURS="${3:-3}"; STYLE="${4:-wind}"; SEED="${5:-$RANDOM}"
SEG=600                                   # seconds per segment (loops cleanly)
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# Slow swells: periods divide 600 s so the loop point stays seamless.
case "$STYLE" in
  wind)  BED="anoisesrc=c=brown:a=0.6:seed=$SEED,lowpass=f=900,highpass=f=60,volume='(1-0.3+0.3*sin(2*PI*t/20))*(1-0.15+0.15*sin(2*PI*t/60))':eval=frame" ;;
  rain)  BED="anoisesrc=c=pink:a=0.45:seed=$SEED,highpass=f=400,lowpass=f=9000,volume='1-0.08+0.08*sin(2*PI*t/30)':eval=frame" ;;
  brown) BED="anoisesrc=c=brown:a=0.7:seed=$SEED,lowpass=f=500,highpass=f=30" ;;
  pink)  BED="anoisesrc=c=pink:a=0.4:seed=$SEED,lowpass=f=7000,highpass=f=40" ;;
  white) BED="anoisesrc=c=white:a=0.18:seed=$SEED,lowpass=f=6000,highpass=f=80" ;;
  storm) BED="anoisesrc=c=brown:a=0.75:seed=$SEED,lowpass=f=700,volume='(1-0.35+0.35*sin(2*PI*t/60))*(1-0.12+0.12*sin(2*PI*t/10))':eval=frame" ;;
  fire)  BED="anoisesrc=c=velvet:a=0.35:seed=$SEED,highpass=f=1200,lowpass=f=6000,tremolo=f=7:d=0.6" ;;
  ocean) BED="anoisesrc=c=pink:a=0.55:seed=$SEED,lowpass=f=2500,volume='1-0.4+0.4*sin(2*PI*t/10)':eval=frame" ;;
  *) echo "unknown style $STYLE" >&2; exit 1 ;;
esac

# A quiet brown-noise floor under every style keeps the sound warm and even.
FLOOR="anoisesrc=c=brown:a=0.25:seed=$((SEED+7)),lowpass=f=300"

ffmpeg -hide_banner -loglevel error -y \
  -loop 1 -framerate 1 -i "$PHOTO" \
  -f lavfi -t "$SEG" -i "$BED" \
  -f lavfi -t "$SEG" -i "$FLOOR" \
  -filter_complex "[1:a][2:a]amix=inputs=2:normalize=0,aformat=channel_layouts=stereo,loudnorm=I=-23:TP=-3:LRA=7[a];[0:v]scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,format=yuv420p[v]" \
  -map "[v]" -map "[a]" -t "$SEG" \
  -c:v libx264 -preset veryfast -tune stillimage -crf 30 -g 300 -r 1 \
  -c:a aac -b:a 56k -ar 44100 \
  "$WORK/seg.mp4"

LOOPS=$(( HOURS * 3600 / SEG - 1 ))
ffmpeg -hide_banner -loglevel error -y -stream_loop "$LOOPS" -i "$WORK/seg.mp4" \
  -c copy -movflags +faststart "$OUT"

ls -la "$OUT"
