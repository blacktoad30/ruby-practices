#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'

OPTION_STRING = 'lwc'
DEFAULT_OPTION_CHARS = OPTION_STRING.chars.freeze

def main
  options, paths = parse_commandline_options

  option_chars = extract_option_chars(options)

  format_string = generate_format_string(paths, option_chars)
  results = word_count_results(paths, option_chars)

  results.each { print_word_count_result(format_string, _1) }

  if paths.size >= 2
    init_value_for_total = option_chars.to_h { [_1, 0] }

    count_total = results.each_with_object(init_value_for_total) do |result, total|
      option_chars.each do |option|
        total[option] += result[:count][option]
      end
    end

    print_word_count_result(format_string, { path: 'total', count: count_total })
  end

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

def generate_format_string(paths, option_chars = DEFAULT_OPTION_CHARS)
  enabled_option_count = option_chars.size

  need_padding = enabled_option_count >= 2 || paths.size >= 2

  digit = need_padding ? calc_digit(paths) : 1

  format_string = Array.new(enabled_option_count, "%#{digit}d")

  format_string << '%s' unless paths.empty?

  format_string.join(' ')
end

def calc_digit(paths)
  return 7 if paths.empty?

  paths.sum { FileTest.size(_1) }.to_s.size
end

def word_count_results(paths, option_chars = DEFAULT_OPTION_CHARS)
  return [word_count('', option_chars)] if paths.empty?

  paths.map { word_count(_1, option_chars) }
end

def word_count(path, option_chars = DEFAULT_OPTION_CHARS)
  buf = path.empty? ? $stdin.set_encoding('ASCII-8BIT').read : File.open(path, encoding: 'ASCII-8BIT', &:read)
  word_count = {}

  word_count['l'] = count_newline(buf) if option_chars.include?('l')
  word_count['w'] = count_word(buf) if option_chars.include?('w')
  word_count['c'] = count_bytesize(buf) if option_chars.include?('c')

  { path:, count: word_count }
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

def print_word_count_result(format_string, result)
  puts format(format_string, *result[:count].values, result[:path]) unless result[:count].nil?
end

if __FILE__ == $PROGRAM_NAME
  errno = main

  exit(errno)
end
