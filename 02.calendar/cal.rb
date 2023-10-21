#!/usr/bin/env ruby

require 'optparse'
require 'date'

params = ARGV.getopts("m:y:")
#p params
year = params["y"].to_i
month = params["m"].to_i
#p month, year

today = Date.today
if year.zero? || month.zero?
  at_year = if year.zero? then today.year else year end
  at_month = if month.zero? then today.month else month end
end
this_monthp = if at_year == today.year && at_month == today.month \
              then true else false end
#p today, at_month, at_year
exit 1 unless (at_month.between?(1, 12) && at_year.between?(1970, 2100))
at_first_wday = Date.new(at_year, at_month, 1).wday
at_last_day = Date.new(at_year, at_month, -1).day
mdays = Array.new(6) { Array.new(7, "  ") }
dayc = 1
mdays.size.times do |weekc|
  next if dayc > at_last_day
  mdays[weekc].size.times do |wd|
    if weekc == 0 && wd >= at_first_wday || weekc > 0 && dayc <= at_last_day
      if this_monthp && dayc == today.day
        mdays[weekc][wd] = "\e[7m" + dayc.to_s.rjust(2) + "\e[m"
      else
        mdays[weekc][wd] = dayc.to_s.rjust(2)
      end
      dayc += 1
    end
  end
end
#p mdays

puts "#{at_month}月 #{at_year}".center(20).delete_suffix!(" ")
puts "日 月 火 水 木 金 土"
mdays.each do |week|
  puts week.join(" ")
end
