#!/bin/sh
# One-command installer for this repo's git hooks (see scripts/githooks/).
# Git hooks live under .git/hooks and are NEVER transferred by clone/push,
# so every machine (and every contributor) runs this once after cloning.
set -eu
root=$(git rev-parse --show-toplevel)
for hook in "$root"/scripts/githooks/*; do
  name=$(basename "$hook")
  ln -sf "../../scripts/githooks/$name" "$root/.git/hooks/$name"
  chmod +x "$root/.git/hooks/$name"
  echo "installed hook: $name"
done
