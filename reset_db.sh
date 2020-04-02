#!/usr/bin/env bash

sqlite3 covid.db 'DROP TABLE IF EXISTS covid_deaths'

sqlite3 covid.db < ./covid-deaths.sql
