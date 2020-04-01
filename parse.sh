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

join_by_pipe () {
  local str=""
  for arg in "$@"; do
    str+="${arg}|"
  done
  
  echo "$str"
}

count_columns () {
  local table="$1"
  echo "$table" | pup "tr:nth-of-type(1)" | grep -c "<th>"
}

column () {
  local table="$1"
  local col="$2"
  
  echo "$table" | pup --charset utf-8 "td:nth-child($col)"
}

column_cell () {
  local column="$1"
  local cell="$2"
  echo "$column" | pup --charset utf-8 ":nth-of-type($cell)"
}

column_cells () {
  dbg "column_cells called. num params: $#."
  local s="$1"
  local a=()
  local i=0
  
  while read -r line; do
    a[i]="${a[i]:-}${line}"$'\n'
    if [ "$line" == "</td>" ]; then
      ((++i))
    fi
  done <<< "$s"
  join_by_pipe "${a[@]}"
}

column_cells_globals() {
  local -n array="$1"
  local str="$2"
  local -i i=0
  
  while read -r line; do
    array[i]="${array[i]:-}${line}"$'\n'
    if [ "$line" == "</td>" ]; then
      ((++i))
    fi
  done <<< "$str"
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

input=$(cat)

clear_log

dbg "Starting"

table=$(echo "$input" | pup 'table.wikitable')

rows=$(echo "$table" | grep -c "<tr>")
cols=$(count_columns "$table")

declare -i batch
batch=$(sqlite3 covid.db 'select max(batch) from covid_deaths')
if [ -z "$batch" ]; then
  batch=0
fi
((++batch))

dates_str=$(column "$table" 1)
column_cells_globals "dates" "$dates_str"
echo "${#dates[@]}"
# dates_str=$(column_cells "$dates_str")

# while read -rd "|" date; do
#   dates+=("$date")
# done <<< "$dates_str"

countries_str=$(column "$table" 2)
column_cells_globals "countries" "$countries_str"

# countries_str=$(column_cells "$countries_str")

# while read -rd "|" country; do
#   countries+=("$country")
# done <<< "$countries_str"
echo "${#countries[@]}"

places_str=$(column "$table" 3)
column_cells_globals "places" "$places_str"
# places_str=$(column_cells "$places_str")

# while read -rd "|" place; do
#   places+=("$place")
# done <<< "$places_str"

names_str=$(column "$table" 4)
column_cells_globals "names" "$names_str"
# names_str=$(column_cells "$names_str")

# while read -rd "|" name; do
#   names+=("$name")
# done <<< "$names_str"

nationalities_str=$(column "$table" 5)
column_cells_globals "nationalities" "$nationalities_str"
# nationalities_str=$(column_cells "$nationalities_str")

# while read -rd "|" nationality; do
#   nationalities+=("$nationality")
# done <<< "$nationalities_str"

ages_col=6
notes_col=7

if [ "$cols" -gt 7 ]; then
  ((++ages_col))
  ((++notes_col))
fi

dbg "cols: $cols. ages: $ages_col. notes: $notes_col"

ages_str=$(column "$table" "$ages_col")
column_cells_globals "ages" "$ages_str"
# ages_str=$(column_cells "$ages_str")

# while read -rd "|" age; do
#   ages+=("$age")
# done <<< "$ages_str"

notes_str=$(column "$table" "$notes_col")
column_cells_globals "notes" "$notes_str"
# notes_str=$(column_cells "$notes_str")

# while read -rd "|" note; do
#   notes+=("$note")
# done <<< "$notes_str"

sql_template=$(< ./insert_template.sql)
readonly sql_template;

declare -i r=0
rows=3
readonly rows
while [ $r -lt "$rows" ]; do
  dbg "Row $r of $rows"
  
  IFS="|"
  date=$(echo "${dates[$r]}" | pup 'text{}' | xargs | cut -d' ' -f1-2)
  #dbg "$date"
  
  country=$(echo "${countries[$r]}" | pup 'text{}' | sed 's/&amp;.*gt;//' | sed 's/\[.*\]//' | xargs)
  #dbg "$country"
  
  place=$(echo "${places[$r]}" | pup 'text{}' | xargs)
  #dbg "$place"
  
  name=$(echo "${names[$r]}" | pup 'text{}' | xargs)
  #dbg "$name"
  
  nationality=$(echo "${nationalities[$r]}" | pup 'text{}' | xargs)
  #dbg "$nationality"
  
  age=$(echo "${ages[$r]}" | pup 'text{}' | sed 's;/;hello;' | xargs)
  
  note=$(echo "${notes[$r]}" | pup 'text{}' | sed 's/\[.*\]//' | xargs)
  note=$(decode "$note")
  #dbg "$note"
  
  declare -a sed_args=(
    "-e s/\"\$date\"/\"$date\"/"
    "-e s/\"\$country\"/\"$country\"/"
    "-e s/\"\$place\"/\"$place\"/"
    "-e s/\"\$name\"/\"$name\"/"
    "-e s/\"\$nationality\"/\"$nationality\"/"
    "-e s/\"\$age\"/\"$age\"/"
    "-e s/\"\$note\"/\"$note\"/"
    "-e s/\"\$batch\"/\"$batch\"/"
  )
  
  #args="${sed_args[*]}"
  #dbg "$args"
  
  sql=$(echo "$sql_template" | sed "${sed_args[@]}")
  #dbg "$sql"

  #sqlite3 covid.db "$sql"
  #dbg "sql executed."
  ((++r))
done
