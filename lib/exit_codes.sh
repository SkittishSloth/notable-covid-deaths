#!/usr/bin/env bash

if [[ -n "${__LIB_EXIT_CODES:-}" ]]; then
  return
fi

declare -ri __LIB_EXIT_CODES=1

declare -ri EX_MISSING_CMD=3
declare -ri EX_UNKNOWN_OPT=4
declare -ri EX_MISSING_OUTPUT_FILE=5
declare -ri EX_FORCE_NO_OUTPUT=6
declare -ri EX_OUTPUT_FILE_DIRECTORY=7
declare -ri EX_OUTPUT_FILE_EXISTS_NO_OW=8

declare -ri EX_MISSING_INPUT_FILE=9
declare -ri EX_INPUT_FILE_NOT_FOUND=10
declare -ri EX_INPUT_FILE_DIRECTORY=11

declare -ri EX_FILE_AMBIGUITY=12