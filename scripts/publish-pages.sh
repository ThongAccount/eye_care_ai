#!/usr/bin/env bash
#
# Publish the static site (landing page + legal pages) to the `gh-pages` branch.
#
# The published tree is the WHOLE site, rebuilt from `web/` on every run, so a
# partial copy can never drop something that is currently live. That was a real
# bug: the old recipe in docs/web/README.md started with `git rm -rf .` and
# never copied `robots.txt`, so following it deleted the live robots.txt.
#
# Usage:
#   scripts/publish-pages.sh --out <gh-pages worktree> [--push]
#
#   --out    directory that receives the published tree. It must be a git
#            worktree of this repository on the `gh-pages` branch.
#   --push   commit the result and push it to `origin/gh-pages`.
#
# Published layout (and why):
#
#   index.html        <- web/site/index.html        landing page, canonical URL
#   styles.css        <- web/site/styles.css
#   favicon.png       <- web/favicon.png
#   icons/            <- web/icons/
#   legal/            <- web/legal/*.html
#   robots.txt        <- web/robots.txt
#
# LINK PATHS: every link inside the published files is relative to the PUBLISHED
# root - index.html and styles.css sit at the root, legal/ is a subfolder - so
# the landing page links to "legal/privacy.html" and "favicon.png", and the
# legal pages link back to the landing page with "../index.html".
# "web/site/" and "web/legal/" are SOURCE folders, not URL folders: copying
# web/site/index.html to the root is what makes those paths correct, and
# writing the links against the source layout is exactly what broke them.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR=""
PUSH=0

while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT_DIR="${2:?--out needs a path}"; shift 2 ;;
    --push) PUSH=1; shift ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    *) echo "publish-pages: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

if [ -z "$OUT_DIR" ]; then
  echo "publish-pages: --out <gh-pages worktree> is required" >&2
  exit 2
fi

# --- 1. every source must exist before anything is touched --------------------
REQUIRED=(
  "web/site/index.html"
  "web/site/styles.css"
  "web/favicon.png"
  "web/robots.txt"
  "web/legal/privacy.html"
  "web/legal/terms.html"
)
MISSING=()
for f in "${REQUIRED[@]}"; do
  [ -s "$REPO_ROOT/$f" ] || MISSING+=("$f")
done
if [ ! -d "$REPO_ROOT/web/icons" ]; then
  MISSING+=("web/icons/")
fi
if [ ${#MISSING[@]} -gt 0 ]; then
  echo "publish-pages: missing source files, nothing was published:" >&2
  printf '  %s\n' "${MISSING[@]}" >&2
  exit 1
fi

# --- 2. guard the destination -------------------------------------------------
case "$OUT_DIR" in
  /|"$REPO_ROOT"|"$REPO_ROOT/"*)
    echo "publish-pages: refusing to publish into '$OUT_DIR'" >&2
    exit 2
    ;;
esac
mkdir -p "$OUT_DIR"

# --- 3. rebuild the whole tree (keep .git) ------------------------------------
find "$OUT_DIR" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +

cp "$REPO_ROOT/web/site/index.html"       "$OUT_DIR/index.html"
cp "$REPO_ROOT/web/site/styles.css"       "$OUT_DIR/styles.css"
cp "$REPO_ROOT/web/favicon.png"           "$OUT_DIR/favicon.png"
cp "$REPO_ROOT/web/robots.txt"            "$OUT_DIR/robots.txt"
cp -r "$REPO_ROOT/web/icons"              "$OUT_DIR/icons"
mkdir -p "$OUT_DIR/legal"
cp "$REPO_ROOT/web/legal/privacy.html"    "$OUT_DIR/legal/privacy.html"
cp "$REPO_ROOT/web/legal/terms.html"      "$OUT_DIR/legal/terms.html"

# --- 4. verify the copy before it can be published ----------------------------
EXPECTED=(
  "index.html" "styles.css" "favicon.png" "robots.txt"
  "icons/Icon-192.png" "icons/Icon-512.png"
  "icons/Icon-maskable-192.png" "icons/Icon-maskable-512.png"
  "legal/privacy.html" "legal/terms.html"
)
BROKEN=()
for f in "${EXPECTED[@]}"; do
  [ -s "$OUT_DIR/$f" ] || BROKEN+=("$f")
done
if [ ${#BROKEN[@]} -gt 0 ]; then
  echo "publish-pages: the published tree is incomplete, nothing was committed:" >&2
  printf '  %s\n' "${BROKEN[@]}" >&2
  exit 1
fi

echo "publish-pages: published $(find "$OUT_DIR" -type f ! -name .git ! -path '*/.git/*' | wc -l) files to $OUT_DIR"

# --- 5. commit + push ---------------------------------------------------------
if [ "$PUSH" -eq 1 ]; then
  git -C "$OUT_DIR" add -A
  if git -C "$OUT_DIR" diff --cached --quiet; then
    echo "publish-pages: nothing changed, nothing to publish"
  else
    git -C "$OUT_DIR" commit -q -F - <<'MSG'
docs: publish the landing page, the legal pages and robots.txt

Rebuilds the whole gh-pages tree from web/ so the published site always
matches the repository and nothing that is live can be dropped by a partial
copy.

Every link was written for the SOURCE layout, where the landing page lives in
web/site/ and the legal pages in web/legal/. The published site copies
web/site/index.html to the root and web/legal/* into legal/, so those links
resolved one directory too high and returned 404: the live home page could not
open the privacy policy, could not open the terms, had no icon, and the Home
links inside both legal pages were dead.

The landing page now links to favicon.png, legal/privacy.html and
legal/terms.html; both legal pages link back to the landing page with
../index.html. robots.txt moves into web/ (it existed only on this branch), so
the published tree always carries it.
MSG
    git -C "$OUT_DIR" push origin HEAD:gh-pages
    echo "publish-pages: pushed to origin/gh-pages"
  fi
fi
