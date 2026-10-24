#!/usr/bin/env bash
# Build a 30-second vertical YouTube Short from one photo and a synthesized sound bed.
# Usage: make_short.sh <photo.jpg> <output.mp4> <sound-style> <hook text> [seed] [seconds]
# Sound styles: wind | rain | brown | pink | white | storm | fire | ocean
set -euo pipefail

PHOTO="$1"; OUT="$2"; STYLE="${3:-wind}"; HOOK="${4:-Sleep sounds}"
SEED="${5:-$RANDOM}"; DUR="${6:-30}"
FONT=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

case "$STYLE" in
  wind)  BED="anoisesrc=c=brown:a=0.6:seed=$SEED,lowpass=f=900,highpass=f=60,volume='(1-0.3+0.3*sin(2*PI*t/10))':eval=frame" ;;
  rain)  BED="anoisesrc=c=pink:a=0.45:seed=$SEED,highpass=f=400,lowpass=f=9000" ;;
  brown) BED="anoisesrc=c=brown:a=0.7:seed=$SEED,lowpass=f=500,highpass=f=30" ;;
  pink)  BED="anoisesrc=c=pink:a=0.4:seed=$SEED,lowpass=f=7000,highpass=f=40" ;;
  white) BED="anoisesrc=c=white:a=0.18:seed=$SEED,lowpass=f=6000,highpass=f=80" ;;
  storm) BED="anoisesrc=c=brown:a=0.75:seed=$SEED,lowpass=f=700,volume='(1-0.35+0.35*sin(2*PI*t/10))':eval=frame" ;;
  fire)  BED="anoisesrc=c=velvet:a=0.35:seed=$SEED,highpass=f=1200,lowpass=f=6000,tremolo=f=7:d=0.6" ;;
  ocean) BED="anoisesrc=c=pink:a=0.55:seed=$SEED,lowpass=f=2500,volume='1-0.4+0.4*sin(2*PI*t/10)':eval=frame" ;;
  *) echo "unknown style $STYLE" >&2; exit 1 ;;
esac
FLOOR="anoisesrc=c=brown:a=0.25:seed=$((SEED+7)),lowpass=f=300"

# Text goes through files so quotes and colons in the hook are safe.
printf '%s' "$HOOK" > "$WORK/hook.txt"
printf '%s' "Full 3 hours on @DesertNightSounds" > "$WORK/cta.txt"

FPS=30; FRAMES=$((DUR*FPS))
# Photo: fill the 9:16 frame, then a slow, steady zoom for gentle motion.
VF="scale=2160:3840:force_original_aspect_ratio=increase,crop=2160:3840,\
zoompan=z='1+0.12*on/${FRAMES}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=${FRAMES}:s=1080x1920:fps=${FPS},\
drawbox=x=0:y=200:w=iw:h=330:color=black@0.35:t=fill,\
drawtext=fontfile=${FONT}:textfile=${WORK}/hook.txt:fontsize=78:fontcolor=white:borderw=4:bordercolor=black@0.6:x=(w-text_w)/2:y=320,\
drawtext=fontfile=${FONT}:textfile=${WORK}/cta.txt:fontsize=48:fontcolor=white:borderw=3:bordercolor=black@0.6:x=(w-text_w)/2:y=h-360:alpha='if(lt(t,3),0,min(1,(t-3)/1.5))',\
fade=t=in:st=0:d=1,format=yuv420p"

ffmpeg -hide_banner -loglevel error -y \
  -loop 1 -i "$PHOTO" \
  -f lavfi -t "$DUR" -i "$BED" \
  -f lavfi -t "$DUR" -i "$FLOOR" \
  -filter_complex "[0:v]${VF}[v];[1:a][2:a]amix=inputs=2:normalize=0,aformat=channel_layouts=stereo,loudnorm=I=-18:TP=-2,afade=t=in:d=1,afade=t=out:st=$((DUR-2)):d=2[a]" \
  -map "[v]" -map "[a]" -t "$DUR" \
  -c:v libx264 -preset veryfast -crf 23 -r $FPS -c:a aac -b:a 128k -movflags +faststart "$OUT"

ls -la "$OUT"
