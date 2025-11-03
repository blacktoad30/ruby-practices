#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'

OPTION_STRING = 'lwc'
DEFAULT_OPTION_CHARS = OPTION_STRING.chars.freeze

def main
  options, paths = parse_commandline_options

  option_chars = extract_option_chars(options)
  counts = paths.empty? ? [count_newline_word_bytesize] : paths.map { count_newline_word_bytesize(_1) }

  print_counts(counts, option_chars)

  0
end

def parse_commandline_options
  options = OptionParser.getopts(ARGV, OPTION_STRING)

  [options, ARGV]
end

def extract_option_chars(options)
  option_chars = options.filter_map { |opt, bool| opt if bool }

  # `wc [file ...]` == `wc -lwc [file ...]`
  option_chars.empty? ? DEFAULT_OPTION_CHARS : option_chars
end

def count_newline_word_bytesize(path = '')
  buf = path.empty? ? $stdin.set_encoding('ASCII-8BIT').read : File.open(path, encoding: 'ASCII-8BIT', &:read)
  count = {}

  count['l'] = count_newline(buf)
  count['w'] = count_word(buf)
  count['c'] = count_bytesize(buf)

  { path:, count: }
end

def count_newline(buf)
  buf.count("\n")
end

def count_word(buf)
  num = 0
  buf.split { num += 1 if _1.match?(/[[:graph:]]/) }
  num
end

def count_bytesize(buf)
  buf.bytesize
end

def print_counts(counts, option_chars)
  digit = calc_digit(counts, option_chars)
  need_with_path = !stdin?(counts)

  counts << total_counts(counts) if counts.size >= 2

  counts.each do |result|
    counts = result[:count].values_at(*option_chars).map { _1.to_s.rjust(digit) }

    counts << result[:path] if need_with_path

    puts counts.join(' ')
  end
end

def calc_digit(counts, option_chars)
  need_padding = option_chars.size >= 2 || counts.size >= 2

  return 1 unless need_padding
  return 7 if stdin?(counts)

  counts.sum { _1[:count]['c'] }.to_s.size
end

def stdin?(counts)
  counts.size == 1 && counts.first[:path].empty?
end

def total_counts(counts)
  init_value_for_total = DEFAULT_OPTION_CHARS.to_h { [_1, 0] }

  count_total = counts.each_with_object(init_value_for_total) do |result, total|
    DEFAULT_OPTION_CHARS.each do |option|
      total[option] += result[:count][option]
    end
  end

  { path: 'total', count: count_total }
end

if __FILE__ == $PROGRAM_NAME
  errno = main

  exit(errno)
end
