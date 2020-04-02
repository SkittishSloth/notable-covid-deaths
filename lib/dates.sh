#!/usr/bin/env bash

set -o errexit
set -o errtrace
set -o nounset
set -o pipefail

# Given differences between BSD's and GNU's date command, it's
# difficult to parse out the date information we get.
# Fortunately our requirements are simple enough that we don't
# need anything too fancy.

declare -rA __month_nums=(
    ["January"]="01"
    ["February"]="02"
    ["March"]="03"
    ["April"]="04"
    ["May"]="05"
    ["June"]="06"
    ["July"]="07"
    ["August"]="08"
    ["September"]="09"
    ["October"]="10"
    ["November"]="11"
    ["December"]="12"
)

parse_sort_date() {
    local -n __date_out="$1"
    local -r date_str="$2"
    local -r year="${3:-2020}"

    read -ra date_parts <<< "$date_str"
    local -r month="${date_parts[0]}"
    local day
    printf -v day "%02g" "${date_parts[1]}"
    readonly day

    local -r month_num="${__month_nums[$month]}"
    __date_out="${year}${month_num}${day}"
}