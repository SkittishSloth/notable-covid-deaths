#!/bin/bash

set -o errexit
set -o errtrace
set -o nounset
set -o pipefail

logfile="log.txt"

dbg() {
	#:
	echo "$(date): $1" >> "$logfile"
}

clear_log() {
	rm "$logfile"
	#echo "....................." >> "$logfile"
}

join_by_pipe2 () { 
	dbg "join by pipe called. num args: $#"
	local IFS="|"
	shift
	printf '%s\n' "$*"
}

join_by_pipe () {
  local str=""
  for arg in "$@"; do
    str+="${arg}|"
  done
  
  echo "$str"
}

count_columns () {
	#dbg "count_columns called."
	local table="$1"
	echo "$table" | pup "tr:nth-of-type(1)" | grep -c "<th>"
}

column () {
	#dbg "column called."
	local table="$1"
	local col="$2"
	
	echo "$table" | pup --charset utf-8 "td:nth-child($col)"
}

column_cell () {
	#dbg "column_cell called."
	local column="$1"
	local cell="$2"
	echo "$column" | pup --charset utf-8 ":nth-of-type($cell)"
}

column_cells () {
	dbg "column_cells called. num params: $#."
	local s="$1"
	local a=()
	local i=0
	
	while read -r line
	do
		a[i]="${a[i]:-}${line}"$'\n'
		if [ "$line" == "</td>" ]
		then
			 ((++i))
		fi
	done <<< "$s"
	join_by_pipe "${a[@]}"
}

clean() {
  local str="$1"
  sed -e 's/\//\\\//' "$str"
}

decode() {
  local str="$1"
  eval "$(printf '%s' "$str" | sed 's/^/printf "/;s/&#0*\([0-9]*\);/\$( [ \1 -lt 128 ] \&\& printf "\\\\$( printf \"%.3o\\201\" \1)" || \$(which printf) \\\\U\$( printf \"%.8x\" \1) )/g;s/$/\\n"/')" | sed "s/$(printf '\201')//g"
}

input=$(cat)

clear_log

dbg "Starting"
nl=$(echo "$input" | wc -l)
dbg "new lines in input: $nl"
table=$(echo "$input" | pup 'table.wikitable')
nl=$(echo "$table" | wc -l)
dbg "new lines in table: $nl"

rows=$(echo "$table" | grep -c "<tr>")
cols=$(count_columns "$table")

declare -i batch
batch=$(sqlite3 covid.db 'select max(batch) from covid_deaths')
if [ -z "$batch" ]; then
	batch=0
fi
batch+=1

dates_str=$(column "$table" 1)
dates_str=$(column_cells "$dates_str")
#pipes=$(echo "$dates_str" | grep -o "|" | wc -l)
#echo "pipes: $pipes"
declare -a dates=()
#cnt=0
while read -rd "|" date; do
	dates+=("$date")
	#((++cnt))
done <<< "$dates_str"
#echo "${#dates[@]}"
#echo "loop coint: $cnt"
#echo "${dates[1]}"
#dbg  "${dates[@]}"

countries_str=$(column "$table" 2)
countries_str=$(column_cells "$countries_str")

declare -a countries=()
while read -rd "|" country; do
	countries+=("$country")
done <<< "$countries_str"

places_str=$(column "$table" 3)
places_str=$(column_cells "$places_str")

declare -a places=()
while read -rd "|" place; do
	places+=("$place")
done <<< "$places_str"

names_str=$(column "$table" 4)
#echo $(echo "$names_str" | grep Carlos)
#echo $(echo "$table" | grep Carlos)
names_str=$(column_cells "$names_str")
#echo $(echo "$names_str" | grep Carlos)

declare -a names=()
while read -rd "|" name; do
  names+=("$name")
done <<< "$names_str"

nationalities_str=$(column "$table" 5)
nationalities_str=$(column_cells "$nationalities_str")

declare -a nationalities=()
while read -rd "|" nationality; do
  nationalities+=("$nationality")
done <<< "$nationalities_str"

ages_col=6
notes_col=7

if [ "$cols" -gt 7 ] 
then
	((++ages_col))
	((++notes_col))
fi

dbg "cols: $cols. ages: $ages_col. notes: $notes_col"

ages_str=$(column "$table" "$ages_col")
ages_str=$(column_cells "$ages_str")

declare -a ages=()
while read -rd "|" age; do
  ages+=("$age")
done <<< "$ages_str"

notes_str=$(column "$table" "$notes_col")
notes_str=$(column_cells "$notes_str")

declare -a notes=()
while read -rd "|" note; do
  notes+=("$note")
done <<< "$notes_str"

#declare sql_template=""
#while read -r line; do
#  sql_template+="${line}\n"
#done < ./insert_template.sql
declare sql_template=$(< ./insert_template.sql)

#echo "$sql_template"

r=0
#rows=3
while [ $r -lt "$rows" ]
do
	dbg "Row $r of $rows"

	IFS="|"
	date=$(echo "${dates[$r]}" | pup 'text{}' | xargs | cut -d' ' -f1-2)
	#echo "$date"
	#date=$(cell $r 1 | cut -d' ' -f1-2)
	country=$(echo "${countries[$r]}" | pup 'text{}' | sed 's/&amp;.*gt;//' | sed 's/\[.*\]//' | xargs)
	#echo "$country"
	
	place=$(echo "${places[$r]}" | pup 'text{}' | xargs)
	#echo "$place"
	
	name=$(echo "${names[$r]}" | pup 'text{}' | xargs)
	dbg "$name"
	#echo "$name"
	
	nationality=$(echo "${nationalities[$r]}" | pup 'text{}' | xargs)
	#dbg "$nationality"
	
	age=$(echo "${ages[$r]}" | pup 'text{}' | sed 's;/;hello;' | xargs)
	#dbg "$age"
	
	note=$(echo "${notes[$r]}" | pup 'text{}' | sed 's/\[.*\]//' | xargs)
	note=$(decode "$note")
	dbg "$note"
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
    args="${sed_args[@]}"
    dbg "$args"
	sql=$(echo "$sql_template" | sed "${sed_args[@]}")
	
	#echo "Date: $date"
	#echo "Country: $country"
	#echo "Place: $place"
	#echo "Name: $name"
	#echo "Nationality: $nationality"
	#echo "DOB: $dob"
	#echo "Age: $age"
	#
	#echo "JSON:"
	#echo "$json"
	
	#IFS= read -r sql <<-SQL
#INSERT INTO covid_deaths(date, country, place, name, nationality, age, notes, batch) VALUES("$date", "$country", "$place", "$name", "$nationality", "$age", "$note", "$batch")
#ON CONFLICT(date, name) DO UPDATE SET
	#country=excluded.country,
	#place=excluded.place,
	#nationality=excluded.nationality,
	#age=excluded.age,
	#notes=excluded.notes,
	#updated=CURRENT_TIMESTAMP;
#SQL
	dbg "$sql"
	sqlite3 covid.db "$sql"
	dbg "sql executed."
	((++r))
done
