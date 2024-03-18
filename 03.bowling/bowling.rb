#!/usr/bin/env ruby
# frozen_string_literal: true

MAX_PINS = 10
shots = ARGV[0].split(',').flat_map do |s|
  s == 'X' ? [MAX_PINS, nil] : s.to_i
end
last_frame = shots.slice(2 * 9, shots.size).compact.each_slice(2).to_a
# 最終フレームに3投目が無くても、each_consメソッドでのスコア処理を可能にする。
last_frame.push([0]) if last_frame.size == 1
scores = (shots.take(2 * 9).each_slice(2).map(&:compact) + last_frame).each_cons(3).map do |trio|
  trio.first == [MAX_PINS] || trio.first.sum == MAX_PINS ? trio.flatten.take(3) : trio.first
end + last_frame

puts scores.flatten.sum
