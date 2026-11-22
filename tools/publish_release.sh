#!/usr/bin/env bash
# Updates the ONE existing GitHub release (tag "release") with a new build.
# Taken over from Gun game: game files are uploaded before version.json, so running games
# never see a manifest pointing to files that are not there yet. Never creates releases or tags.
set -euo pipefail

: "${GAME_NAME:?Missing GAME_NAME}"
: "${GITHUB_REPOSITORY:?Missing GITHUB_REPOSITORY}"
: "${GH_TOKEN:?Missing GH_TOKEN}"
RELEASE_TAG="release"

for file in build_info.json version.json notes.md \
  "dist/${GAME_NAME}-windows.exe" "dist/${GAME_NAME}-macos.zip" "dist/${GAME_NAME}-linux.zip"; do
  [[ -s "$file" ]] || { echo "Missing or empty release file: $file" >&2; exit 1; }
done

# This release must already exist (created once by hand for the first publication).
assets="$(gh release view "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" --json assets --jq '.assets[].name')"
previous_manifest="$(mktemp)"
trap 'rm -f "$previous_manifest"' EXIT
if grep -qx "version.json" <<< "$assets"; then
  gh release download "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" --pattern version.json --output "$previous_manifest" --clobber
else
  echo "No version.json in the release yet: first publication."
  echo '{}' > "$previous_manifest"
fi

metadata="$(python3 - "$previous_manifest" <<'PY'
import json, re, sys

current = json.load(open("build_info.json", encoding="utf-8"))
previous = json.load(open(sys.argv[1], encoding="utf-8"))

def identity(info):
    version, build = info.get("version"), info.get("build")
    if not isinstance(version, str) or not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", version):
        raise SystemExit("Release version must be a numeric major.minor.patch")
    if type(build) is not int or build <= 0:
        raise SystemExit("Release build must be a positive integer")
    return tuple(map(int, version.split("."))), build

new_version, new_build = identity(current)
if previous:  # first publication (empty manifest) accepts any valid version
    old_version, old_build = identity(previous)
    major, minor, patch = old_version
    next_versions = {(major, minor, patch + 1), (major, minor + 1, 0), (major + 1, 0, 0)}
    retry = new_build == old_build and new_version == old_version
    if not retry and not (new_build > old_build and new_version in next_versions):
        raise SystemExit("Release must advance one patch, minor or major version with a newer build, or retry the same version and build")
manifest = json.load(open("version.json", encoding="utf-8"))
if identity(manifest) != (new_version, new_build):
    raise SystemExit("Update manifest does not match build_info.json")
print(current["version"], new_build, current["commit"])
PY
)"
read -r version build commit <<< "$metadata"
echo "Publishing ${GAME_NAME} v${version}, build ${build}, commit ${commit}"

gh release upload "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" --clobber \
  "dist/${GAME_NAME}-windows.exe" "dist/${GAME_NAME}-macos.zip" "dist/${GAME_NAME}-linux.zip"
# Existing updaters must not see the new manifest before every game file exists.
gh release upload "$RELEASE_TAG" version.json --repo "$GITHUB_REPOSITORY" --clobber
gh release edit "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" --draft=false --prerelease=false --latest \
  --title "${GAME_TITLE:-$GAME_NAME} v${version}" --notes-file notes.md

promotion="$(gh release view "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" --json isDraft,isPrerelease)"
python3 - "$promotion" <<'PY'
import json, sys
release = json.loads(sys.argv[1])
if release.get("isDraft") is not False or release.get("isPrerelease") is not False:
    raise SystemExit("The release was not successfully promoted")
PY

latest="$(gh api "repos/${GITHUB_REPOSITORY}/releases/latest" --jq '.tag_name')"
[[ "$latest" == "$RELEASE_TAG" ]] || { echo "The release is not latest" >&2; exit 1; }
