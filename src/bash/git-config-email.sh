#!/usr/bin/env bash
# Sets git user.name / user.email for the current repo, and can remember the
# identity in ~/.git-config-email.json for reuse.
#
# Usage:
#   git config-email --init
#   git config-email [--name "Full Name"] --email <address> [--save]
#
# Options:
#   --init          Create ~/.git-config-email.json if it doesn't exist, then exit.
#   --name NAME     Name to set (default: "Bruno Brant").
#   --email EMAIL   Email to set (required unless --init).
#   --save          Also record the name/email in the identities file.
#   -h, --help      Show this help.
set -u

IDENTITIES="$HOME/.git-config-email.json"
DEFAULT_NAME="Bruno Brant"

usage() {
	awk 'NR==1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
	exit "${1:-0}"
}

# Emit one entry per line for the given JSON array key.
read_list() {
	key="$1"
	[ -f "$IDENTITIES" ] || return 0
	if command -v jq >/dev/null 2>&1; then
		jq -r --arg k "$key" '(.[$k] // [])[]' "$IDENTITIES" 2>/dev/null
	else
		tr -d '\n' < "$IDENTITIES" \
			| sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p" \
			| tr ',' '\n' \
			| sed -e 's/^[[:space:]]*"//' -e 's/"[[:space:]]*$//' \
			| sed '/^[[:space:]]*$/d'
	fi
}

# Read lines on stdin, emit them as the body of a JSON array.
json_array_body() {
	first=1
	while IFS= read -r item; do
		[ -n "$item" ] || continue
		item=$(printf '%s' "$item" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
		if [ "$first" -eq 1 ]; then
			printf '\n    "%s"' "$item"
			first=0
		else
			printf ',\n    "%s"' "$item"
		fi
	done
	[ "$first" -eq 1 ] || printf '\n  '
}

write_identities() {
	names_body=$(printf '%s\n' "$1" | json_array_body)
	emails_body=$(printf '%s\n' "$2" | json_array_body)
	printf '{\n  "names": [%s],\n  "emails": [%s]\n}\n' "$names_body" "$emails_body" > "$IDENTITIES"
}

init=0
save=0
name="$DEFAULT_NAME"
email=""

while [ $# -gt 0 ]; do
	case "$1" in
		--init) init=1; shift ;;
		--name) name="$2"; shift 2 ;;
		--name=*) name="${1#*=}"; shift ;;
		--email) email="$2"; shift 2 ;;
		--email=*) email="${1#*=}"; shift ;;
		--save) save=1; shift ;;
		-h|--help) usage 0 ;;
		*) echo "Unknown option: $1" >&2; usage 1 ;;
	esac
done

if [ "$init" -eq 1 ]; then
	if [ -f "$IDENTITIES" ]; then
		echo "Identities file already exists at $IDENTITIES"
	else
		write_identities "" ""
		echo "Created identities file at $IDENTITIES"
	fi
	exit 0
fi

if [ -z "$email" ]; then
	echo "error: --email is required" >&2
	usage 1
fi

if [ "$save" -eq 1 ]; then
	names=$(read_list names)
	emails=$(read_list emails)
	printf '%s\n' "$names" | grep -qxF "$name"  || names=$(printf '%s\n%s' "$names" "$name")
	printf '%s\n' "$emails" | grep -qxF "$email" || emails=$(printf '%s\n%s' "$emails" "$email")
	write_identities "$names" "$emails"
fi

git config user.name "$name"
git config user.email "$email"
