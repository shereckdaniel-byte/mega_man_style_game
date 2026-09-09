#!/usr/bin/env bash
#
# Builds every platform, or the ones named.
#
#   tools/export.sh                 # all four
#   tools/export.sh Linux Web       # just these
#
# ## Why this is a script and not a line in a README
#
# Because the interesting part is not `godot --export-release`, it is the two
# things that go wrong around it: **templates** and **a stale import cache**.
#
# Export templates are ~1 GB and are not in the repository. Without them the
# export fails with a message about the template being missing, which reads like
# a broken preset. This checks first and says which it is.
#
# And an export runs the project's importer: a `.godot/` built by a different
# Godot, or missing entirely on a fresh clone, produces a build with no
# textures and no error. `--import` first, always.
set -uo pipefail

GODOT="${GODOT:-godot}"
ALL=(Linux Windows macOS Web)
WANT=("$@")
if [ ${#WANT[@]} -eq 0 ]; then WANT=("${ALL[@]}"); fi

if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
  echo "no godot: set GODOT=/path/to/godot"
  exit 2
fi

VERSION="$(cat .godot-version 2>/dev/null || echo unknown)"
TEMPLATES="${HOME}/.local/share/godot/export_templates/${VERSION%-*}.stable"
if [ ! -d "$TEMPLATES" ] || [ -z "$(ls -A "$TEMPLATES" 2>/dev/null)" ]; then
  echo "No export templates for $VERSION."
  echo
  echo "  They are about 1 GB and are not committed. Either open the editor and"
  echo "  use Editor > Manage Export Templates, or:"
  echo
  echo "    curl -fsSL -o t.tpz https://github.com/godotengine/godot/releases/download/${VERSION}/Godot_v${VERSION}_export_templates.tpz"
  echo "    mkdir -p \"$TEMPLATES\" && unzip -j t.tpz 'templates/*' -d \"$TEMPLATES\""
  echo
  echo "Nothing was built."
  exit 3
fi

echo "importing"
"$GODOT" --headless --import >/dev/null 2>&1

failed=0
for preset in "${WANT[@]}"; do
  out=$(grep -A 12 "^name=\"$preset\"" export_presets.cfg | grep '^export_path=' | head -1 | cut -d'"' -f2)
  if [ -z "$out" ]; then
    echo "unknown preset '$preset' -- known: ${ALL[*]}"
    failed=1
    continue
  fi
  mkdir -p "$(dirname "$out")"
  echo "building $preset -> $out"
  if ! "$GODOT" --headless --export-release "$preset" "$out"; then
    echo "  $preset failed"
    failed=1
    continue
  fi
  echo "  $(du -h "$out" 2>/dev/null | cut -f1) $out"
done

exit $failed
