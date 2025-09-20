#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'

OPTION_STRING = 'lwc'
WORD_COUNT_TYPES = %i[newline word bytesize].freeze

OPTION_NAME_TO_WORD_COUNT_TYPE = OPTION_STRING.chars.zip(WORD_COUNT_TYPES).to_h.freeze

def main(args)
  enabled_options = parse_args(args)

  paths = args.empty? ? [''] : args

  word_count_types = extract_word_count_types(enabled_options)

  output_format = displayed_output_format(enabled_options, paths)

  results =
    paths.map { word_count_result(_1, word_count_types) }
         .each { print_word_count_result(output_format, _1) }

  if paths.size >= 2
    count_total = word_count_sum(results.filter_map { _1[:count] }, word_count_types)

    print_word_count_result(output_format, { path: 'total', count: count_total, message: nil })
  end

  results.any? { _1[:message] } ? 1 : 0
end

def parse_args(args)
  parsed_options = OptionParser.new.getopts(args, OPTION_STRING).transform_keys(OPTION_NAME_TO_WORD_COUNT_TYPE)

  # `wc [file ...]` == `wc -lwc [file ...]`
  parsed_options.transform_values! { |_| true } unless parsed_options.value?(true)

  parsed_options[:path] = !args.empty?

  parsed_options.select { |_, val| val }.keys
end

def extract_word_count_types(types)
  WORD_COUNT_TYPES & types
end

def displayed_output_format(enabled_options, paths)
  one_type_one_operand = extract_word_count_types(enabled_options).size == 1 && paths.size <= 1

  digit = one_type_one_operand ? 1 : adjust_digit(paths)

  enabled_options.map { output_format_string(_1, digit) }.join(' ')
end

def adjust_digit(paths)
  default_digit = paths.any? { exist_non_regular_file?(_1) } ? 7 : 1

  total_bytes_digit = paths.sum { regular_file_size(_1) }.to_s.size

  [default_digit, total_bytes_digit].max
end

def stdin?(path)
  path == '-' || path.empty?
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

def output_format_string(enabled_option, digit)
  case enabled_option
  when *WORD_COUNT_TYPES
    "%<#{enabled_option}>#{digit}d"
  when :path
    "%<#{enabled_option}>s"
  else
    raise ArgumentError, "enabled_option: allow only #{[*WORD_COUNT_TYPES, :path].map(&:inspect).join(', ')}"
  end
end

def word_count_result(path, word_count_types = WORD_COUNT_TYPES)
  display_path = path.empty? ? 'standard input' : path

  return { path: display_path, count: nil, message: exist?(path) ? 'Permission denied' : 'No such file or directory' } unless readable?(path)

  return { path: display_path, count: word_count_types.to_h { [_1, 0] }, message: 'Is a directory' } if directory?(path)

  { path: display_path, count: word_count(path, word_count_types), message: nil }
rescue Errno::EPERM => e
  { path: display_path, count: nil, message: e.message.partition(' @ ').first }
end

def readable?(path)
  stdin?(path) ? $stdin.stat.readable? : FileTest.readable?(path)
end

def directory?(path)
  stdin?(path) ? $stdin.stat.directory? : FileTest.directory?(path)
end

def word_count(path, word_count_types = WORD_COUNT_TYPES)
  return { bytesize: size(path) } if file?(path) && word_count_types == %i[bytesize]

  file_size_is_available = file?(path) && word_count_types.include?(:bytesize)

  types = file_size_is_available ? word_count_types - %i[bytesize] : word_count_types

  counts_each_line = File.open(stdin?(path) ? 0 : path) { |io| io.set_encoding('ASCII-8BIT').map { word_count_for_string(_1, types) } }

  count = word_count_sum(counts_each_line, types)

  file_size_is_available ? { **count, bytesize: size(path) } : count
end

def word_count_for_string(str, word_count_types = WORD_COUNT_TYPES)
  word_count_types.to_h do |word_count_type|
    case word_count_type
    when *WORD_COUNT_TYPES
      [word_count_type, word_count_for_string_per_type(str, word_count_type)]
    else
      raise ArgumentError, "word_count_type: allow only #{WORD_COUNT_TYPES.map(&:inspect).join(', ')}"
    end
  end
end

def word_count_for_string_per_type(str, word_count_type)
  case word_count_type
  when :newline
    str.count("\n")
  when :word
    num = 0
    str.split { num += 1 if _1.match?(/[[:graph:]]/) }
    num
  when :bytesize
    str.bytesize
  end
end

def word_count_sum(counts, word_count_types = WORD_COUNT_TYPES)
  word_count_types.to_h { [_1, 0] }
                  .merge!(*counts) { |_, total, count| total + count }
end

def print_word_count_result(output_format, result)
  warn "wc: #{result[:path]}: #{result[:message]}" if result[:message]

  puts format(output_format, **result[:count], path: result[:path]) unless result[:count].nil?
end

if __FILE__ == $PROGRAM_NAME
  errno = main(ARGV)

  exit(errno)
end
