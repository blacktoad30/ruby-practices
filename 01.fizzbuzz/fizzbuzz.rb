#!/usr/bin/env ruby

(1..20).each do |i|
  result = ""
  result = "Fizz" if i % 3 == 0
  result += "Buzz" if i % 5 == 0
  result = i if result == ""
  puts result
end
