cell () {
	local row=$1
	local col=$2
	echo $(echo "$table" | pup "tr:nth-of-type($row) td:nth-child($col) text{}" | xargs)
}

function join_by { local IFS="$1"; shift; echo "$*"; }

input=$(cat)

table=$(echo "$input" | pup 'table.wikitable')
header=$(echo "$table" | pup 'tr:nth-of-type(1) json{}' | jq -r '[.[].children[].text]')
header=$(echo "$header" | jq -r '{"date": .[0], "country": .[1], "place": .[2], "name": .[3], "nationality": .[4], "dob": .[5], "age": .[6]}')
#echo "$header"
rows=$(echo "$table" | grep -c "<tr>")
#echo $rows

declare -a output
output+=("$header")

declare -i batch
batch=$(sqlite3 covid.db 'select max(batch) from covid_deaths')
if [ -z "$batch" ]; then
	batch=0
fi
batch+=1

for r in $(seq 2 $rows)
do
	#ddate=$(echo "$table" | pup "tr:nth-of-type($r) td:nth-child(1) text{}" | xargs)
	
# "Date of death" 
# "Country of death", 
# "Place of death",
# "Name", 
# "Nationality",
# "Date of birth", 
# "Age", 
# "Notes"]
	date=$(cell $r 1 | cut -d' ' -f1-2)
	country=$(cell $r 2)
	country=$(echo "$country" | sed 's/&amp;lt;.*&amp;gt;//' | xargs)
	place=$(cell $r 3)
	name=$(cell $r 4)
	nationality=$(cell $r 5)
	dob=$(cell $r 6)
	age=$(cell $r 7)
	
	json=$(jq -rn "{\"date\": \"$date\", \"country\":\"$country\", \"place\": \"$place\", \"name\": \"$name\", \"nationality\": \"$nationality\", \"dob\": \"$dob\", \"age\": \"$age\"}")
	
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
INSERT INTO covid_deaths(date, country, place, name, nationality, dob, age, batch) VALUES("$date", "$country", "$place", "$name", "$nationality", "$dob", "$age", "$batch")
ON CONFLICT(date, name) DO UPDATE SET
	country=excluded.country,
	place=excluded.place,
	nationality=excluded.nationality,
	dob=excluded.dob,
	age=excluded.age,
	updated=CURRENT_TIMESTAMP;
SQL
	sqlres=$(sqlite3 covid.db "$sql")
	output+=("$json")
done
#echo ".........."

#echo "${output[@]}" | jq -r --slurp . | jq -r '.[] | [.date, .country, .place, .name, .nationality, .dob, .age] | @csv'

#joined=$(join_by , ${output[@]})
#echo "${#output[@]}"

#X=("hello world" "goodnight moon")
#printf '%s\n' "${output[@]}" #| jq -R . | jq -s .


#X=("hello world" "goodnight moon")
#echo "${output[@]}" | jq -R . | jq -s .
