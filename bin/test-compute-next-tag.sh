#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Exercises bin/compute-next-tag.sh against throwaway git repositories.
#
# Usage: bin/test-compute-next-tag.sh
#
# Every scenario creates a repository in a temporary directory, gives it role
# files and a release history, and then replays a series of merges through the
# real script, tagging as it goes just like the autotag workflow does. This
# repository is never touched and no network access is needed.

set -euo pipefail

script_under_test="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/compute-next-tag.sh"

failures=0
workdir=''

cleanup() {
	cd /
	if [ -n "$workdir" ]; then
		rm -rf "$workdir"
		workdir=''
	fi
}

trap cleanup EXIT

# The fixture reproduces the shape of the real defaults/main.yml around the
# version: the Renovate annotation that decides which literal gets bumped, the
# leaf literal itself (which carries no leading `v`, while the tags do), and
# the Jinja-derived image variables that sit next to it. A refactor that made
# the script read one of those derived variables instead of the leaf would
# produce a tag containing `{{` here, and every scenario would fail.
write_defaults() {
	cat > defaults/main.yml <<EOF
headplane_identifier: headplane

# renovate: datasource=docker depName=ghcr.io/tale/headplane versioning=semver
headplane_version: $1
headplane_arch: amd64

headplane_container_image: "{{ headplane_container_image_registry_prefix }}tale/headplane:{{ headplane_container_image_tag }}"
headplane_container_image_tag: "{{ headplane_version }}"
headplane_container_image_registry_prefix: "{{ headplane_container_image_registry_prefix_upstream }}"
EOF
}

# Starts a scenario with a repository at Headplane 0.6.2 which has already seen
# two releases of it (v0.6.2-0 and v0.6.2-1).
scenario() {
	echo "$1"

	cleanup
	workdir="$(mktemp -d)"

	mkdir -p "$workdir/bin" "$workdir/defaults" "$workdir/tasks" "$workdir/templates"
	cp "$script_under_test" "$workdir/bin/"
	cd "$workdir"

	git init -q -b main .
	git config user.email 'test@example.com'
	git config user.name 'Test'
	git config commit.gpgsign false

	write_defaults 0.6.2
	printf 'placeholder\n' > tasks/main.yml
	printf 'placeholder\n' > templates/env.j2
	printf 'placeholder\n' > README.md

	git add -A
	git commit -qm 'Initial commit'

	local release_number
	for release_number in 0 1; do
		git tag "v0.6.2-$release_number"
	done
}

# Applies a change, commits it, and tags whatever the script says it should be.
# Prints the tag, or nothing when the script decided against a release.
merge() {
	local change="$1" tag

	eval "$change"
	git add -A
	git commit -qm 'Merge'

	tag="$(bin/compute-next-tag.sh 2>/dev/null)"

	if [ -n "$tag" ]; then
		git tag "$tag"
	fi

	printf '%s' "$tag"
}

expect() {
	local description="$1" expected="$2" actual="$3"

	if [ "$actual" = "$expected" ]; then
		printf '  ok   | %s -> %s\n' "$description" "${actual:-no release}"
	else
		printf '  FAIL | %s -> expected %s, got %s\n' "$description" "${expected:-no release}" "${actual:-no release}"
		failures=$((failures + 1))
	fi
}

bump_version='write_defaults 0.6.3'
revert_version='write_defaults 0.6.2'
edit_task="printf 'a task\n' >> tasks/main.yml"
edit_template="printf 'a line\n' >> templates/env.j2"
edit_readme="printf 'documentation\n' >> README.md"
edit_script="printf '# a comment\n' >> bin/compute-next-tag.sh"

# The two merge orders below apply the same updates and must each end up with
# every update released exactly once, whichever order they arrive in.

scenario 'A version bump merged before other role changes'
expect 'version bump' v0.6.3-0 "$(merge "$bump_version")"
expect 'task edit'    v0.6.3-1 "$(merge "$edit_task")"
expect 'template'     v0.6.3-2 "$(merge "$edit_template")"

scenario 'A version bump merged after other role changes'
expect 'task edit'    v0.6.2-2 "$(merge "$edit_task")"
expect 'version bump' v0.6.3-0 "$(merge "$bump_version")"

scenario 'Commits that do not affect the role'
expect 'README'   ''        "$(merge "$edit_readme")"
expect 'a script' ''        "$(merge "$edit_script")"
expect 'a task'   v0.6.2-2  "$(merge "$edit_task")"

scenario 'Release numbers past 9'
for release_number in 2 3 4 5 6 7 8 9 10; do
	git tag "v0.6.2-$release_number"
done
expect 'a task' v0.6.2-11 "$(merge "$edit_task")"

scenario 'Reverting to an already released version'
merge "$bump_version" > /dev/null
# The role is now identical to what v0.6.2-1 already published, so there is
# nothing new to release.
expect 'a revert' ''        "$(merge "$revert_version")"

scenario 'Reverting to an already released version, with a change'
merge "$bump_version" > /dev/null
expect 'a revert' v0.6.2-2 "$(merge "$revert_version && $edit_task")"

# Tags of an unrelated version must not be mistaken for releases of the one in
# defaults/main.yml, and neither must a tag whose release part is not a number.
scenario 'Tags that do not belong to the version being released'
git tag 'v0.6.20-7'
git tag 'v0.6.2-rc1'
expect 'a task' v0.6.2-2 "$(merge "$edit_task")"

if [ "$failures" -gt 0 ]; then
	echo >&2 "$failures scenario(s) behaved unexpectedly"
	exit 1
fi

echo 'All scenarios behaved as expected'
