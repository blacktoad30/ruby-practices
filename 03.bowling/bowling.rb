#!/usr/bin/env ruby
# frozen_string_literal: true

MAX_PINS = 10
shots = ARGV[0].split(',').flat_map do |s|
  s == 'X' ? [MAX_PINS, nil] : s.to_i
end
scores = shots.slice(2 * 9, shots.size).compact.each_slice(2).to_a
scores.push([0]) if scores.size == 1
frames = shots.take(2 * 9).each_slice(2).map(&:compact) + scores
scores = frames.each_cons(3).map do |trio|
  trio.first == [MAX_PINS] || trio.first.sum == MAX_PINS ? trio.flatten.take(3) : trio.first
end + scores

puts scores.flatten.sum
