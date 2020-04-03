#!/usr/bin/env bash

set -o errexit
set -o errtrace
set -o nounset
set -o pipefail

declare __dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly __dir

declare __file
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
readonly __file

declare __base
__base="$(basename "${__file}" .sh)"
readonly __base