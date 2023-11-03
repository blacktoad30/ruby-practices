#!/usr/bin/env ruby
# frozen_string_literal: true

shots = ARGV[0].split(',').flat_map do |s|
  s == 'X' ? [10, nil] : s.to_i
end
scores = shots.slice(2 * 9, shots.size).compact.each_slice(2).to_a
scores.push([0]) if scores.size == 1
frames = shots.take(2 * 9).each_slice(2).map(&:compact) + scores
scores = frames.each_cons(3).map do |trio|
  trio.first == [10] || trio.first.sum == 10 ? trio.flatten.take(3) : trio.first
end + scores

puts scores.flatten.sum
