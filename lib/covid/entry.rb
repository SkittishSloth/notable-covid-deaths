require 'anima'
module Covid
  class Entry
   include Anima.new(
     :date,
     :country,
     :place,
     :name,
     :age,
     :notes
   )
  end
end