#!/usr/bin/env bash
# Sync blog folders (each with content.md) into _posts for Jekyll.
# Run from repo root: ./script/sync_posts.sh

set -e
cd "$(dirname "$0")/.."
POSTS_DIR="_posts"
mkdir -p "$POSTS_DIR"

skip_dir() {
  case "$1" in
    _*|.*|assets|script) return 0 ;;
    *) [[ -f "$1/content.md" ]] && return 1 || return 0 ;;
  esac
}

for dir in */; do
  dir="${dir%/}"
  skip_dir "$dir" && continue
  content_path="$dir/content.md"
  # Extract date from first line of front matter (date: 2025-03-10 ...)
  date_line=$(grep -m1 "^date:" "$content_path" || true)
  date_str=$(echo "$date_line" | sed -n 's/^date: *\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*/\1/p')
  if [[ -z "$date_str" ]]; then
    echo "Skip $dir: no valid date in content.md front matter" >&2
    continue
  fi
  out_name="${date_str}-${dir}.md"
  out_path="$POSTS_DIR/$out_name"
  cp "$content_path" "$out_path"
  echo "Synced $content_path -> $out_path"
done

echo "Done. Commit _posts/ and push."
