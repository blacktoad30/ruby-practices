# frozen_string_literal: true

require 'optparse'
require_relative './word_count'

OPTION_STRING = 'lwc'

OPTION_NAME_TO_WORD_COUNT_TYPE = OPTION_STRING.chars.zip(WordCount::TYPES).to_h.freeze

def main(args)
  displayed_items = parse_args(args)

  wc_paths = args.empty? ? [WordCount::Pathname.new] : args.map { WordCount::Pathname.new(_1) }

  word_count_types = WordCount.extract_types(displayed_items)

  output_format = displayed_output_format(displayed_items, wc_paths)

  results =
    wc_paths.map { _1.word_count_result(word_count_types) }
            .each { print_word_count_result(output_format, _1) }

  if wc_paths.size >= 2
    count_total =
      word_count_types.to_h { [_1, 0] }
                      .merge!(*results.filter_map { _1[:count] }) { |_, total, count| total + count }

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

def displayed_output_format(displayed_items, wc_paths)
  one_type_one_operand = WordCount.extract_types(displayed_items).size == 1 && wc_paths.size == 1

  digit = one_type_one_operand ? 1 : adjust_digit(wc_paths)

  displayed_items.map { output_format_string(_1, digit) }.join(' ')
end

def adjust_digit(wc_paths)
  default_digit = wc_paths.any?(&:exist_non_regular_file?) ? 7 : 1

  total_bytes_digit = wc_paths.sum(&:regular_file_size).to_s.size

  [default_digit, total_bytes_digit].max
end

def output_format_string(displayed_item, digit)
  case displayed_item
  when *WordCount::TYPES
    "%<#{displayed_item}>#{digit}d"
  when :path
    '%<path>s'
  else
    raise ArgumentError, "displayed_item: allow only #{[*WordCount::TYPES, :path].map(&:inspect).join(', ')}"
  end
end

def print_word_count_result(output_format, result)
  warn "wc: #{result[:path]}: #{result[:message]}" if result[:message]

  puts format(output_format, **result[:count], path: result[:path]) unless result[:count].nil?
end
