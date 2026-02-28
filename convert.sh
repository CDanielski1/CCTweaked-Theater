#!/usr/bin/env bash
set -euo pipefail

# CCTweaked-Theater Video Converter
# Splits a video into 120-second chunks, converts each to 32vid format,
# and updates catalog.json.
#
# Dependencies: ffmpeg, ffprobe, sanjuuni, jq
#
# Usage: ./convert.sh -i <input.mp4> -n <name> [-w <width>] [-h <height>] [-d <chunk_seconds>]
# Example: ./convert.sh -i shrek.mp4 -n shrek
#          ./convert.sh -i shrek.mp4 -n shrek -w 164 -h 81

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHUNK_DURATION=60
WIDTH=""
HEIGHT=""
INPUT=""
NAME=""

usage() {
    echo "Usage: $0 -i <input video> -n <name> [-w width] [-h height] [-d chunk_seconds]"
    echo ""
    echo "  -i    Input video file"
    echo "  -n    Name for the movie (used in catalog and folder name)"
    echo "  -w    Output width in characters (default: sanjuuni auto)"
    echo "  -h    Output height in characters (default: sanjuuni auto)"
    echo "  -d    Chunk duration in seconds (default: 120)"
    exit 1
}

while getopts "i:n:w:h:d:" opt; do
    case $opt in
        i) INPUT="$OPTARG" ;;
        n) NAME="$OPTARG" ;;
        w) WIDTH="$OPTARG" ;;
        h) HEIGHT="$OPTARG" ;;
        d) CHUNK_DURATION="$OPTARG" ;;
        *) usage ;;
    esac
done

if [[ -z "$INPUT" || -z "$NAME" ]]; then
    usage
fi

if ! command -v ffmpeg &>/dev/null; then
    echo "Error: ffmpeg not found. Install it first."
    exit 1
fi

if ! command -v ffprobe &>/dev/null; then
    echo "Error: ffprobe not found. Install it first."
    exit 1
fi

if ! command -v sanjuuni &>/dev/null; then
    echo "Error: sanjuuni not found. Install it or add it to PATH."
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "Error: jq not found. Install it first."
    exit 1
fi

# Get total duration
TOTAL_DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$INPUT" | cut -d. -f1)
echo "Video duration: ${TOTAL_DURATION}s"
echo "Chunk size: ${CHUNK_DURATION}s"
TOTAL_CHUNKS=$(( (TOTAL_DURATION + CHUNK_DURATION - 1) / CHUNK_DURATION ))
echo "Estimated chunks: $TOTAL_CHUNKS"

# Create output directory
MEDIA_DIR="${SCRIPT_DIR}/media/${NAME}"
mkdir -p "$MEDIA_DIR"

# Temp directory for intermediate files
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Build sanjuuni size flags
SIZE_FLAGS=""
if [[ -n "$WIDTH" ]]; then
    SIZE_FLAGS="$SIZE_FLAGS --width=$WIDTH"
fi
if [[ -n "$HEIGHT" ]]; then
    SIZE_FLAGS="$SIZE_FLAGS --height=$HEIGHT"
fi

echo ""
echo "Converting: $INPUT -> media/$NAME/"
echo "========================================"

INDEX=0
START=0

while [[ $START -lt $TOTAL_DURATION ]]; do
    echo ""
    echo "--- Chunk $INDEX (${START}s - $((START + CHUNK_DURATION))s) ---"

    TEMP_CHUNK="${TEMP_DIR}/chunk_${INDEX}.mp4"
    OUTPUT_FILE="${MEDIA_DIR}/${NAME}${INDEX}.32vid"

    # Extract chunk with ffmpeg
    echo "  Extracting segment..."
    ffmpeg -y -ss "$START" -i "$INPUT" -t "$CHUNK_DURATION" \
        -vf scale=320:-2 -c:v libx264 -preset ultrafast -c:a aac \
        "$TEMP_CHUNK" -loglevel warning

    # Convert with sanjuuni
    echo "  Converting to 32vid..."
    sanjuuni --32vid --dfpwm --compression=ans \
        $SIZE_FLAGS \
        -i "$TEMP_CHUNK" -o "$OUTPUT_FILE"

    FILESIZE=$(stat -c%s "$OUTPUT_FILE" 2>/dev/null || stat -f%z "$OUTPUT_FILE")
    echo "  Output: ${NAME}${INDEX}.32vid ($(( FILESIZE / 1024 )) KB)"

    # Clean up temp chunk
    rm -f "$TEMP_CHUNK"

    INDEX=$((INDEX + 1))
    START=$((START + CHUNK_DURATION))
done

echo ""
echo "========================================"
echo "Conversion complete: $INDEX chunks"

# Update catalog.json
CATALOG="${SCRIPT_DIR}/catalog.json"
MEDIA_PATH="media/${NAME}/${NAME}"

if [[ ! -f "$CATALOG" ]]; then
    echo "[]" > "$CATALOG"
fi

# Check if entry already exists
if jq -e --arg name "$NAME" '.[] | select(.name == $name)' "$CATALOG" >/dev/null 2>&1; then
    echo "Catalog entry for '$NAME' already exists, updating path..."
    jq --arg name "$NAME" --arg path "$MEDIA_PATH" \
        'map(if .name == $name then .path = $path else . end)' \
        "$CATALOG" > "${CATALOG}.tmp" && mv "${CATALOG}.tmp" "$CATALOG"
else
    echo "Adding '$NAME' to catalog..."
    jq --arg name "$NAME" --arg path "$MEDIA_PATH" \
        '. + [{"name": $name, "path": $path}]' \
        "$CATALOG" > "${CATALOG}.tmp" && mv "${CATALOG}.tmp" "$CATALOG"
fi

echo ""
echo "Done! Catalog updated:"
jq '.' "$CATALOG"
echo ""
echo "Next steps:"
echo "  1. git add media/$NAME/ catalog.json"
echo "  2. git commit -m 'Add $NAME'"
echo "  3. git push"
