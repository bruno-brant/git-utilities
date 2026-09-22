#!/usr/bin/env bash
# Repeatedly resolves conflicts with the default per-type strategies and
# continues the in-progress rebase until it finishes or hits an error that
# can't be auto-resolved.
#
# Usage: git resolve-rebase

# Don't open the editor on `git rebase --continue`.
export GIT_EDITOR=true

is_rebasing() {
	git status | grep -q "rebase in progress;"
}

while is_rebasing; do
	echo "Resolving issues..."
	git resolve-all

	output=$(git rebase --continue 2>&1)
	rc=$?
	printf '%s\n' "$output"

	if [ "$rc" -ne 0 ]; then
		if printf '%s' "$output" | grep -q "Could not apply"; then
			continue
		else
			echo "Rebase failed"
			break
		fi
	fi
done
