# frozen_string_literal: true

require 'optparse'
require_relative './wc_pathname'

OPTION_STRING = 'lwc'

OPTION_NAME_TO_WORD_COUNT_TYPE = OPTION_STRING.chars.zip(WordCount::TYPES).to_h.freeze

def main(args)
  displayed_items = parse_args(args)

  wc_paths = args.empty? ? [WcPathname.new('-')] : args.map { WcPathname.new(_1) }

  word_count_types = WordCount.extract_types(displayed_items)

  output_format = displayed_output_format(displayed_items, wc_paths)

  counts =
    word_count_results(word_count_types, wc_paths).each { print_word_count_result(output_format, _1) }
                                                  .filter_map { _1[:count] }

  if wc_paths.size >= 2
    count_total =
      word_count_types.to_h { [_1, 0] }
                      .merge!(*counts) { |_, total, count| total + count }

    print_word_count_result(output_format, { path: 'total', count: count_total, message: nil })
  end

  wc_paths.all?(&:readable_non_directory?) ? 0 : 1
end

def parse_args(args)
  parsed_options = OptionParser.new.getopts(args, OPTION_STRING).transform_keys(OPTION_NAME_TO_WORD_COUNT_TYPE)

  # `wc [file ...]` == `wc -lwc [file ...]`
  parsed_options.transform_values! { |_| true } unless parsed_options.value?(true)

  parsed_options[:path] = !args.empty?

  parsed_options.select { |_, val| val }.keys
end

def displayed_output_format(displayed_items, wc_paths)
  one_type_one_operand = WordCount.extract_types(displayed_items).size == 1 && wc_paths.size == 1

  digit = one_type_one_operand ? 1 : adjust_digit(wc_paths)

  { newline: "%<newline>#{digit}d",
    word: "%<word>#{digit}d",
    byte: "%<byte>#{digit}d",
    path: '%<path>s' }.values_at(*displayed_items).join(' ')
end

def adjust_digit(wc_paths)
  default_digit = wc_paths.any?(&:exist_non_regular_file?) ? 7 : 1

  total_bytes_digit = wc_paths.sum(&:regular_file_size).to_s.size

  [default_digit, total_bytes_digit].max
end

def word_count_results(word_count_types, wc_paths)
  wc_paths.map do |wc_path|
    count = wc_path.word_count(word_count_types)
    message = wc_path.word_count_message

    { path: wc_path.to_s, count:, message: }.freeze
  end
end

def print_word_count_result(output_format, result)
  warn "wc: #{result[:path]}: #{result[:message]}" if result[:message]

  puts format(output_format, **result[:count], path: result[:path]) unless result[:count].nil?
end
