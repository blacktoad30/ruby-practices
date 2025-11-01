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
  paths = paths.empty? ? ['-'] : paths

  default_digit = paths.any? { exist_non_regular_file?(_1) } ? 7 : 1
  total_bytes_digit = paths.sum { regular_file_size(_1) }.to_s.size

  [default_digit, total_bytes_digit].max
end

def stdin?(path)
  path == '-'
end

def exist_non_regular_file?(path)
  exist?(path) && !file?(path)
end

def exist?(path)
  stdin?(path) || FileTest.exist?(path)
end

def regular_file_size(path)
  file?(path) ? size(path) : 0
end

def file?(path)
  stdin?(path) ? $stdin.stat.file? : FileTest.file?(path)
end

def size(path)
  stdin?(path) ? $stdin.stat.size : FileTest.size(path)
end

def word_count_results(paths, option_chars = DEFAULT_OPTION_CHARS)
  paths = paths.empty? ? ['-'] : paths

  paths.map do |path|
    {
      path:,
      count: word_count(path, option_chars)
    }
  end
end

def word_count(path, option_chars = DEFAULT_OPTION_CHARS)
  arg_path = stdin?(path) ? 0 : path

  lines = File.open(arg_path, encoding: 'ASCII-8BIT', &:readlines)
  word_count = {}

  word_count['l'] = count_newline(lines) if option_chars.include?('l')
  word_count['w'] = count_word(lines) if option_chars.include?('w')
  word_count['c'] = (file?(path) ? size(path) : count_bytesize(lines)) if option_chars.include?('c')

  word_count
end

def count_newline(lines)
  lines.sum { |line| line.count("\n") }
end

def count_word(lines)
  lines.sum do |line|
    num = 0
    line.split { num += 1 if _1.match?(/[[:graph:]]/) }
    num
  end
end

def count_bytesize(lines)
  lines.sum(&:bytesize)
end

def print_word_count_result(format_string, result)
  puts format(format_string, *result[:count].values, result[:path]) unless result[:count].nil?
end

if __FILE__ == $PROGRAM_NAME
  errno = main

  exit(errno)
end
