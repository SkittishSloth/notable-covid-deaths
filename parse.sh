#!/bin/bash

set -o errexit
set -o errtrace
set -o nounset
set -o pipefail

logfile="log.txt"

dbg() {
  :
  #echo "$(date): $1" >> "$logfile"
}

dbg_fn() {
  "$@"
}

clear_log() {
  rm --force "$logfile"
}

count_columns () {
  local table="$1"
  pup "tr:nth-of-type(1)" <<< "$table" | grep -c "<th>"
}

column () {
  local table="$1"
  local col="$2"
  
  pup --charset utf-8 "td:nth-child($col)" <<< "$table"
}

column_cells_globals() {
  local -n array="$1"
  local -r column="$2"
  local -r table="$3"
  
  local -r cells_str=$(pup --charset utf-8 "td:nth-child($column)" <<< "$table")
  
  local -i i=0
  
  while read -r line; do
    array[i]="${array[i]:-}${line}"$'\n'
    if [ "$line" == "</td>" ]; then
      ((++i))
    fi
  done <<< "$cells_str"
}

decode() {
  local str="$1"
  # shellcheck disable=2016
  eval "$(printf '%s' "$str" | sed 's/^/printf "/;s/&#0*\([0-9]*\);/\$( [ \1 -lt 128 ] \&\& printf "\\\\$( printf \"%.3o\\201\" \1)" || \$(which printf) \\\\U\$( printf \"%.8x\" \1) )/g;s/$/\\n"/')" | sed "s/$(printf '\201')//g"
}

declare -a dates=()
declare -a countries=()
declare -a places=()
declare -a names=()
declare -a nationalities=()
declare -a ages=()
declare -a notes=()

declare -r input=$(cat)

clear_log

dbg "Starting"

declare table=$(echo "$input" | pup 'table.wikitable')

declare -i batch
batch=$(sqlite3 covid.db 'select max(batch) from covid_deaths')
if [ -z "$batch" ]; then
  batch=0
fi
((++batch))

# dates_str=$(column "$table" 1)
column_cells_globals "dates" 1 "$table"

# countries_str=$(column "$table" 2)
column_cells_globals "countries" 2 "$table"

# places_str=$(column "$table" 3)
column_cells_globals "places" 3 "$table"

# names_str=$(column "$table" 4)
column_cells_globals "names" 4 "$table"

# nationalities_str=$(column "$table" 5)
column_cells_globals "nationalities" 5 "$table"

declare -i ages_col=6
declare -i notes_col=7

declare -ir cols=$(count_columns "$table")
if [ "$cols" -gt 7 ]; then
  ((++ages_col))
  ((++notes_col))
fi
readonly ages_col
readonly notes_col

# ages_str=$(column "$table" "$ages_col")
column_cells_globals "ages" "$ages_col" "$table"

# notes_str=$(column "$table" "$notes_col")
column_cells_globals "notes" "$notes_col" "$table"

sql_template=$(< ./insert_template.sql)
readonly sql_template;

declare -i r=0
declare -ir rows=$(grep -c "<tr>" <<< "$table")

declare -a sql=("BEGIN TRANSACTION;")
#declare -ir rows=3
while [ $r -lt "$rows" ]; do
  dbg "Row $r of $rows"
  
  date=$(pup 'text{}' <<< "${dates[$r]}"| xargs | cut -d' ' -f1-2)
  #dbg "$date"
  
  country=$(pup 'text{}' <<< "${countries[$r]}" | sed 's/&amp;.*gt;//' | sed 's/\[.*\]//' | xargs)
  #dbg "$country"
  
  place=$(pup 'text{}' <<< "${places[$r]}" | xargs)
  #dbg "$place"
  
  name=$(pup 'text{}' <<< "${names[$r]}" | xargs)
  #dbg "$name"
  
  nationality=$(pup 'text{}' <<< "${nationalities[$r]}" | xargs)
  #dbg "$nationality"
  
  age=$(pup 'text{}' <<< "${ages[$r]}" | xargs)
  
  note=$(pup 'text{}' <<< "${notes[$r]}" | sed 's/\[.*\]//' | xargs)
  note=$(decode "$note")
  #dbg "$note"
  
  declare -a sed_args=(
    "-e s/\"\$date\"/\"$date\"/"
    "-e s/\"\$country\"/\"$country\"/"
    "-e s/\"\$place\"/\"$place\"/"
    "-e s/\"\$name\"/\"$name\"/"
    "-e s/\"\$nationality\"/\"$nationality\"/"
    "-e s@\"\$age\"@\"$age\"@"
    "-e s/\"\$note\"/\"$note\"/"
    "-e s/\"\$batch\"/\"$batch\"/"
  )
  
  #args="${sed_args[*]}"
  #dbg "$args"
  
  sql+=($(sed "${sed_args[@]}" <<< "$sql_template"))
  #dbg "$sql"

  #sqlite3 covid.db "$sql"
  #dbg "sql executed."
  ((++r))
done

sql+=("COMMIT;")

sqlite3 covid.db <<< "${sql[*]}"
