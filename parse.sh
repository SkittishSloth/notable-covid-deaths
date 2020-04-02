#!/usr/bin/env bash

set -o errexit
set -o errtrace
set -o nounset
set -o pipefail

declare -r __dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r __file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
declare -r __base="$(basename ${__file} .sh)"

declare -r logfile="${__dir}/log.txt"

dbg() {
  :
  echo "$(date): $1" >> "$logfile"
}

clear_log() {
  rm --force "$logfile"
}

count_columns() {
  local table="$1"
  pup "tr:nth-of-type(1)" <<< "$table" | grep --count "<th>"
}

column() {
  local table="$1"
  local col="$2"
  
  pup --charset utf-8 "td:nth-child($col)" <<< "$table"
}

column_cells() {
  local -n __arrays="$1"
  local -r table="$2"
  
  for a in "${!__arrays[@]}"; do
    local -n __array="$a"
    
    local -i column="${__arrays[$a]}"
    
    local cells_str
    cells_str=$(pup --charset utf-8 "td:nth-child($column)" <<< "$table")
    local -i i=0
    
    while read -r line; do
      __array[i]="${__array[i]:-}${line}"$'\n'
      if [ "$line" == "</td>" ]; then
        ((++i))
      fi
    done <<< "$cells_str"
  done
}

decode() {
  # I copied this from somewhere on the web.
  # Very much black magic - no idea how it
  # works, so I don't want to "fix" it.
  # shellcheck disable=2016
  eval "$(printf '%s' "$1" | sed 's/^/printf "/;s/&#0*\([0-9]*\);/\$( [ \1 -lt 128 ] \&\& printf "\\\\$( printf \"%.3o\\201\" \1)" || \$(which printf) \\\\U\$( printf \"%.8x\" \1) )/g;s/$/\\n"/')" | sed "s/$(printf '\201')//g"
}

clean_contents() {
  pup --charset utf-8 'text{}' <<< "$1" | sed --expression='s/&amp;.*gt;//' --expression 's/\[.*\]//' | xargs
}

declare -a dates=()
declare -a countries=()
declare -a places=()
declare -a names=()
declare -a nationalities=()
declare -a ages=()
declare -a notes=()

declare input
input=$(cat)
readonly input

clear_log

dbg "Starting"

declare table
table=$(pup 'table.wikitable' <<< "$input")

declare -i batch
batch=$(sqlite3 covid.db 'select max(batch) from covid_deaths')
if [ -z "$batch" ]; then
  batch=0
fi
((++batch))
readonly batch

declare -i ages_col=6
declare -i notes_col=7

declare -i cols
cols=$(count_columns "$table")
readonly cols
if [ "$cols" -gt 7 ]; then
  ((++ages_col))
  ((++notes_col))
fi
readonly ages_col
readonly notes_col

# This isn't directly referenced, but
# it's used via nameref.
# shellcheck disable=2034
declare -A arrays_columns=(
  ["dates"]=1
  ["countries"]=2
  ["places"]=3
  ["names"]=4
  ["nationalities"]=5
  ["ages"]="$ages_col"
  ["notes"]="$notes_col"
)

column_cells "arrays_columns" "$table"

declare sql_template
sql_template=$(< "$__dir"/insert_template.sql)
readonly sql_template

declare -i r=0

declare -i rows
rows=$(grep --count "<tr>" <<< "$table")
#rows=3
readonly rows

declare -a sql=("BEGIN TRANSACTION;")
while [ $r -lt "$rows" ]; do
  #dbg "Row $r of $rows"
  
  date=$(clean_contents "${dates[$r]}" | cut -d' ' -f1-2)
  #dbg "$date"
  
  sort_date_str=$(printf "%s 2020" "$date")
  sort_date=$(date --date="$sort_date_str" +"%Y%m%d")
  
  country=$(clean_contents "${countries[$r]}")
  #dbg "$country"
  
  place=$(clean_contents "${places[$r]}")
  #dbg "$place"
  
  name=$(clean_contents "${names[$r]}")
  #dbg "$name"
  
  nationality=$(clean_contents "${nationalities[$r]}")
  #dbg "$nationality"
  
  age=$(clean_contents "${ages[$r]}")
  #dbg "$age"
  
  note=$(clean_contents "${notes[$r]}")
  note=$(decode "$note")
  #dbg "$note"
  
  declare -a sed_args=(
    "--expression=s/\"\$date\"/\"$date\"/"
    "--expression=s/\"\$sort_date\"/\"$sort_date\"/"
    "--expression=s/\"\$country\"/\"$country\"/"
    "--expression=s/\"\$place\"/\"$place\"/"
    "--expression=s/\"\$name\"/\"$name\"/"
    "--expression=s@\"\$nationality\"@\"$nationality\"@"
    "--expression=s@\"\$age\"@\"$age\"@"
    "--expression=s/\"\$note\"/\"$note\"/"
    "--expression=s/\"\$batch\"/\"$batch\"/"
  )
  
  populated_sql=$(sed "${sed_args[@]}" <<< "$sql_template")
  sql+=("$populated_sql")
  #dbg "$sql"

  ((++r))
done

sql+=("COMMIT;")

sqlite3 covid.db <<< "${sql[*]}"
