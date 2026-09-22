#!/usr/bin/env bash
# Interactive picker to delete local git branches.
#
#   Up/Down   move the cursor
#   Space     toggle selection
#   Enter     confirm and delete selected branches
#   q or Esc  quit without doing anything
#
# The currently checked-out branch is shown but cannot be selected.
#
# Usage: git remove-branches [--force]
#
# Options:
#   --force     Use 'git branch -D' (force) instead of the safe 'git branch -d'.
#   -h, --help  Show this help.
set -u

usage() {
	awk 'NR==1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
	exit "${1:-0}"
}

force=0
while [ $# -gt 0 ]; do
	case "$1" in
		--force|-f) force=1; shift ;;
		-h|--help) usage 0 ;;
		*) echo "Unknown option: $1" >&2; usage 1 ;;
	esac
done

if [ "$(git rev-parse --is-inside-work-tree 2>/dev/null || true)" != "true" ]; then
	echo "Not inside a git repository." >&2
	exit 1
fi

current=$(git rev-parse --abbrev-ref HEAD)

branches=()
while IFS= read -r b; do
	[ -n "$b" ] || continue
	branches+=("$b")
done < <(git branch --format='%(refname:short)')

count=${#branches[@]}
if [ "$count" -eq 0 ]; then
	echo "No local branches found."
	exit 0
fi

# Parallel array of 0/1 selection flags (bash 3.2 has no associative arrays).
selected=()
i=0
while [ "$i" -lt "$count" ]; do
	selected+=(0)
	i=$((i + 1))
done

index=0
ESC=$(printf '\033')

render() {
	printf '\033[H'
	printf '\033[36mSelect branches to delete\033[0m\033[K\n'
	printf '\033[90m  Up/Down move | Space toggle | Enter confirm | q/Esc quit\033[0m\033[K\n'
	if [ "$force" -eq 1 ]; then
		printf '\033[31m  Mode: FORCE delete (git branch -D)\033[0m\033[K\n'
	else
		printf '\033[90m  Mode: safe delete (git branch -d)\033[0m\033[K\n'
	fi
	printf '\033[K\n'

	local i line cursor box label
	i=0
	while [ "$i" -lt "$count" ]; do
		if [ "$i" -eq "$index" ]; then cursor='>'; else cursor=' '; fi
		if [ "${selected[$i]}" -eq 1 ]; then box='[x]'; else box='[ ]'; fi
		label="${branches[$i]}"
		if [ "$label" = "$current" ]; then label="$label  (current - cannot delete)"; fi
		line=" $cursor $box $label"

		if [ "$i" -eq "$index" ]; then
			printf '\033[7m%s\033[0m\033[K\n' "$line"
		elif [ "${selected[$i]}" -eq 1 ]; then
			printf '\033[32m%s\033[0m\033[K\n' "$line"
		elif [ "${branches[$i]}" = "$current" ]; then
			printf '\033[90m%s\033[0m\033[K\n' "$line"
		else
			printf '%s\033[K\n' "$line"
		fi
		i=$((i + 1))
	done
}

saved_stty=$(stty -g 2>/dev/null || true)
restore() {
	printf '\033[?25h'
	[ -n "$saved_stty" ] && stty "$saved_stty" 2>/dev/null || true
}
trap restore EXIT INT TERM

printf '\033[?25l'
printf '\033[2J'

cancelled=0
while true; do
	render

	IFS= read -rsn1 key || { cancelled=1; break; }

	if [ "$key" = "$ESC" ]; then
		# An arrow key's remaining bytes are already buffered, so this returns
		# immediately; only a bare Esc waits out the timeout.
		rest=""
		IFS= read -rsn2 -t 1 rest || true
		case "$rest" in
			'[A') key=up ;;
			'[B') key=down ;;
			*)    key=escape ;;
		esac
	fi

	case "$key" in
		up)   index=$(((index - 1 + count) % count)) ;;
		down) index=$(((index + 1) % count)) ;;
		' ')
			if [ "${branches[$index]}" != "$current" ]; then
				if [ "${selected[$index]}" -eq 1 ]; then
					selected[$index]=0
				else
					selected[$index]=1
				fi
			fi
			;;
		'')       break ;;
		escape)   cancelled=1; break ;;
		q|Q)      cancelled=1; break ;;
	esac
done

printf '\033[?25h'
printf '\033[%d;1H' $((count + 6))

if [ "$cancelled" -eq 1 ]; then
	echo "Cancelled."
	exit 0
fi

to_delete=()
i=0
while [ "$i" -lt "$count" ]; do
	if [ "${selected[$i]}" -eq 1 ]; then to_delete+=("${branches[$i]}"); fi
	i=$((i + 1))
done

if [ "${#to_delete[@]}" -eq 0 ]; then
	echo "No branches selected. Nothing to delete."
	exit 0
fi

echo "The following branches will be deleted:"
for b in "${to_delete[@]}"; do echo "  - $b"; done
echo

printf 'Proceed? (y/N) '
read -r confirm
case "$confirm" in
	[Yy]*) ;;
	*) echo "Cancelled."; exit 0 ;;
esac

if [ "$force" -eq 1 ]; then flag=-D; else flag=-d; fi
for b in "${to_delete[@]}"; do
	if git branch "$flag" "$b"; then
		echo "Deleted $b"
	else
		echo "Failed to delete $b (use --force for unmerged branches)" >&2
	fi
done
