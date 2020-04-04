#!/usr/bin/env bash

if [[ -n "${__LIB_LOG:-}" ]]; then
  return
fi

declare -ir __LIB_LOG=1

err() {
	local exit_status=$1
	local reason="$2"
	shift 2
	
	printf '%s\n' "Error: $reason" >&2
	if [[ $# -gt 0 ]]; then
		printf "%s\n" "$@" >&2
	fi
	exit "$exit_status"
}