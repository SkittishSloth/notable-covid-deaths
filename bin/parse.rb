#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'

class Entry
  def initialize(date, country, place, name, nationality, age, notes)
    @date = date
    @country = country
    @place = place
    @name = name
    @nationality = nationality
    @age = age
    @notes = notes
  end
end

doc = Nokogiri::HTML(URI::open("https://en.m.wikipedia.org/wiki/List_of_deaths_from_the_2019%E2%80%9320_coronavirus_pandemic"))
table = doc.at_css('table.wikitable')

rows = table.css('tr')

column_names = rows.shift.css('th').map(&:text)

puts column_names

tables_data = []

table.css('tr')[1..3].each do |tr|

  # collect the cell data and raw names from the remaining rows' cells...
  c = tr.css('td').map(&:text)
  entry = Entry.new(c[0], c[1], c[2], c[3], c[4], c[5], c[6])
  # aggregate it...
  tables_data += [entry]
end
  
puts tables_data[0].inspect