INSERT INTO covid_deaths(date, country, place, name, nationality, age, notes, batch) VALUES("$date", "$country", "$place", "$name", "$nationality", "$age", "$note", "$batch")
ON CONFLICT(date, name) DO UPDATE SET
	country=excluded.country,
	place=excluded.place,
	nationality=excluded.nationality,
	age=excluded.age,
	notes=excluded.notes,
	updated=CURRENT_TIMESTAMP;