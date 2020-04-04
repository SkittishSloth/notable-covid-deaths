#!/usr/bin/env bash

if [[ -n "${__LIB_ENV:-}" ]]; then
  return
fi

declare -ir __LIB_ENV=1

exists() {
  command -v "$1" >/dev/null 2>&1
}