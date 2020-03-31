--[
--  "Date of death",
--  "Country of death",
--  "Place of death",
--  "Name",
--  "Nationality",
--  "Date of birth",
--  "Age",
--  "Notes"
--]

CREATE TABLE covid_deaths(
	date TEXT NOT NULL,
	country TEXT NOT NULL,
	place TEXT,
	name TEXT NOT NULL,
	nationality TEXT,
	age TEXT,
	notes TEXT,
	batch INT NOT NULL,
	added TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	
	PRIMARY KEY (date, name)
);
