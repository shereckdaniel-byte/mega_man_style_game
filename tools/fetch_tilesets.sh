#!/usr/bin/env bash
#
# Pulls every generated tileset this project uses off PixelLab and imports it.
#
#   tools/fetch_tilesets.sh            # everything in the table below
#   tools/fetch_tilesets.sh mirror_field
#
# ## Why this exists
#
# The spritesheet PNG is served from `backblaze.pixellab.ai`, which this
# environment's egress policy answers 403 to (docs/SPRITES.md section 8). The
# *metadata* comes from `api.pixellab.ai`, which is allowed, so half of every
# tileset downloads and half does not.
#
# A generated tileset stays on PixelLab's server indefinitely, so nothing has to
# be regenerated and nothing has to be paid for twice -- the moment the host is
# allowed, this script is the whole recovery. It is written down as a script
# rather than as four lines in a document because the document has carried those
# four lines since stage 1 and they have been retyped every time.
#
# It checks the host first and says plainly which of the two things is wrong,
# because "403" on its own has been mistaken for a PixelLab problem before.
set -uo pipefail

API="https://api.pixellab.ai/mcp/sidescroller-tilesets"
ASSETS="assets/tilesets"
GODOT="${GODOT:-godot}"

# stage directory -> tileset id. The id is also saved inside each downloaded
# tileset.json, so this table can always be rebuilt from what is on disk.
#
# Stages 5-8 and the fortress are **not** in here because no tileset has been
# generated for them: they are greyboxed against stage 3's, which is a different
# problem from this one and is not fixed by opening the host.
declare -A TILESETS=(
  [dawn_boardwalk]=2e44791f-404c-4174-81fe-bc2f6a082215
  [substation]=d635e91f-b9d3-43ce-ae01-5f461fcf2377
  [breakers]=faa7f5cd-8181-430b-896e-a29051b2626f
  [mirror_field]=9ce2430f-2e8f-4aef-b342-19098469414d
)

want=("$@")
if [ ${#want[@]} -eq 0 ]; then
  want=("${!TILESETS[@]}")
fi

# The blocked host, checked once and up front. A tileset download that fails
# because of the egress policy looks identical to one that fails because the
# service is down, and only one of those is worth reporting to PixelLab.
probe=$(curl -sS -o /dev/null -w '%{http_code}' "https://backblaze.pixellab.ai/" 2>&1 || true)
if [ "$probe" != "200" ] && [ "$probe" != "404" ] && [ "$probe" != "403" ]; then
  echo "backblaze.pixellab.ai is not reachable from this session."
  echo "The spritesheets live there and the egress policy has to allow the host."
  echo "See docs/SPRITES.md section 8. Nothing has been downloaded."
  exit 2
fi

failed=0
for stage in "${want[@]}"; do
  id="${TILESETS[$stage]:-}"
  if [ -z "$id" ]; then
    echo "unknown stage '$stage' -- known: ${!TILESETS[*]}"
    failed=1
    continue
  fi
  mkdir -p "$ASSETS/$stage"
  echo "$stage ($id)"
  if ! curl -fsSL -o "$ASSETS/$stage/tileset.png" "$API/$id/image"; then
    echo "  the spritesheet did not download -- the 302 goes to backblaze.pixellab.ai"
    failed=1
    continue
  fi
  if ! curl -fsSL -o "$ASSETS/$stage/tileset.json" "$API/$id/metadata"; then
    echo "  the metadata did not download, which is the *allowed* host -- so this"
    echo "  one is PixelLab's end rather than the egress policy"
    failed=1
    continue
  fi
  echo "  $(wc -c < "$ASSETS/$stage/tileset.png") bytes of art, $(wc -c < "$ASSETS/$stage/tileset.json") of metadata"
done

if [ "$failed" -ne 0 ]; then
  echo
  echo "Something did not come down; not importing a partial set."
  exit 1
fi

echo
echo "importing"
"$GODOT" --headless --script res://tools/pixellab_tileset_import.gd
