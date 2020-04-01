#!/bin/bash

logfile="log.txt"

dbg() {
	#:
	echo "$(date): $1" >> "$logfile"
}

clear_log() {
	rm "$logfile"
	#echo "....................." >> "$logfile"
}

join_by_pipe () { 
	dbg "join by pipe called. num args: $#"
	local IFS="|"
	shift
	printf '%s\n' "$*"
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
	
	echo "$table" | pup "td:nth-child($col)"
}

column_cell () {
	#dbg "column_cell called."
	local column="$1"
	local cell="$2"
	echo "$column" | pup ":nth-of-type($cell)"
}

column_cells () {
	dbg "column_cells called. num params: $#."
	local s="$1"
	local a=()
	local i=0
	local IFS="$OIFS"
	while read -r line
	do
		a[i]="${a[i]}${line}"$'\n'
		if [ "$line" == "</td>" ]
		then
			 ((++i))
		fi
	done <<< "$s"
	join_by_pipe "${a[@]}"
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

OIFS="$IFS"
#IFS='|'
dates=$(column "$table" 1)
dates=$(column_cells "$dates")
echo "$dates"
#dbg "IFS 1: ::$IFS::"
pipes=$(echo "$dates" | grep -o "|" | wc -l)
echo "pipes: $pipes"
echo "dates 1: ${#dates[@]}"
IFS='|' read  -d '' <-ra dates <<< "$dates"
echo "dates 2: ${#dates[@]}"
#dbg "IFS 2: ::$IFS::"

countries=$(column "$table" 2)
countries=$(column_cells "$countries")
read -ra countries <<< "$countries"

places=$(column "$table" 3)
places=$(column_cells "$places")
read -ra places <<< "$places"

names=$(column "$table" 4)
names=$(column_cells "$names")
read -ra names <<< "$names"

nationalities=$(column "$table" 5)
nationalities=$(column_cells "$nationalities")
read -ra nationalities <<< "$nationalities"
ages_col=6
notes_col=7

if [ "$cols" -gt 7 ] 
then
	((++ages_col))
	((++notes_col))
fi

dbg "cols: $cols. ages: $ages_col. notes: $notes_col"

ages=$(column "$table" "$ages_col")
ages=$(column_cells "$ages")
read -ra ages <<< "$ages"

notes=$(column "$table" "$notes_col")
notes=$(column_cells "$notes")
read -ra notes <<< "$notes"

r=2
rows=2
while [ $r -le "$rows" ]
do
	#dbg "Row $r of $rows"

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
	
	age=$(echo "${ages[$r]}" | pup 'text{}' | xargs)
	#dbg "$age"
	
	note=$(echo "${notes[$r]}" | pup 'text{}' | sed 's/\[.*\]//' | xargs)
	#dbg "$note"
	
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
	IFS= read -r -d '' sql <<-SQL
INSERT INTO covid_deaths(date, country, place, name, nationality, age, notes, batch) VALUES("$date", "$country", "$place", "$name", "$nationality", "$age", "$note", "$batch")
ON CONFLICT(date, name) DO UPDATE SET
	country=excluded.country,
	place=excluded.place,
	nationality=excluded.nationality,
	age=excluded.age,
	notes=excluded.notes,
	updated=CURRENT_TIMESTAMP;
SQL
	#dbg "$sql"
	#sqlite3 covid.db "$sql"
	((++r))
done
