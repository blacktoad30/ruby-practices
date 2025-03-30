# frozen_string_literal: true

require 'optparse'

WcData = Data.define(:paths) do
  attr_reader(*%i[errno results total])

  def initialize(paths:)
    @errno = readable_files?(paths) ? 0 : 1
    @results = wc_results(paths).freeze

    @total = wc_results_total(@results)

    super
  end
end

WcResult = Data.define(*%i[path count message]) do
  def initialize(path:, count: nil, message: nil)
    count, message = wc_count_with_message(path) unless count || message

    super
  end
end

WcCount = Data.define(*%i[newline word byte]) do
  def initialize(newline: 0, word: 0, byte: 0)
    super
  end
end

def main(args)
  print_opts, paths = parse_args(args)

  wc_data = WcData.new(paths)

  print_wc_data(print_opts, wc_data)
end

def parse_args(args)
  copy_args = args.dup
  optsym_by_opt = { 'l' => :newline, 'w' => :word, 'c' => :byte }

  optarg_by_opt = OptionParser.new.getopts(copy_args, 'lwc')

  optarg_by_opt.transform_keys!(optsym_by_opt)
  optarg_by_opt.value?(true) || optarg_by_opt.transform_values! { |_| true }

  optarg_by_opt[:path] = !copy_args.empty?

  print_opts = optarg_by_opt.select { |_, val| val }.keys

  [print_opts, copy_args]
end

def readable_files?(paths)
  paths.all? do |path|
    path == '-' || FileTest.readable?(path) && !FileTest.directory?(path)
  end
end

def wc_results(paths)
  return [WcResult.new(path: '-')] if paths.empty?

  paths.map { |path| WcResult.new(path) }
end

def wc_count_with_message(path)
  path == '-' || IO.read(path)
rescue SystemCallError => e
  count = e.is_a?(Errno::EISDIR) ? WcCount.new : nil
  message = e.message.gsub(/ @ .*$/, '')

  [count, message]
else
  [wc_count_for_valid_path(path), nil]
end

def wc_count_for_valid_path(valid_path)
  fd = valid_path == '-' ? $stdin.fileno : IO.sysopen(valid_path.to_s)

  IO.open(fd) { |io| wc_count_for_io(io.set_encoding('ASCII-8BIT')) }
end

def wc_count_for_io(io)
  count_by_type = { newline: 0, word: 0, byte: 0 }

  io.each do |str|
    count_by_type[:newline] += str.count("\n")
    count_by_type[:word] += str.scan(/[[:graph:]]+/).size
    count_by_type[:byte] += str.bytesize
  end

  WcCount.new(**count_by_type)
end

def wc_results_total(wc_results)
  total_count_by_type = { newline: 0, word: 0, byte: 0 }
  counts_by_type = wc_results.filter_map { |result| result.count&.to_h }

  total_count_by_type.merge!(*counts_by_type) do |_key, total, count|
    total + count
  end

  WcResult.new(path: 'total', count: WcCount.new(**total_count_by_type))
end

def print_wc_data(print_opts, wc_data)
  padding_width = padding_width(print_opts, wc_data)
  wc_results = wc_data.results.dup

  wc_results << wc_data.total if wc_data.paths.size >= 2

  wc_results.each do |wc_result|
    print_warn(wc_result)

    next if wc_result.count.nil?

    puts format_wc_result(wc_result, print_opts, padding_width)
  end

  wc_data.errno
end

def padding_width(print_opts, wc_data)
  return 1 if simple_output?(print_opts, wc_data.paths)

  base_digit = include_non_regular_files?(wc_data.paths) ? 7 : 1
  total_bytes_digit = wc_data.total.count.byte.to_s.size

  [base_digit, total_bytes_digit].max
end

def simple_output?(print_opts, paths)
  (print_opts & WcCount.members).size <= 1 && paths.size <= 1
end

def include_non_regular_files?(paths)
  paths.empty? || paths.any? do |path|
    path == '-' || FileTest.exist?(path) && !FileTest.file?(path)
  end
end

def print_warn(wc_result)
  return if wc_result.message.nil?

  path, message = wc_result.deconstruct_keys(%i[path message]).values

  warn "wc: #{path}: #{message}"
end

def format_wc_result(wc_result, print_opts, padding_width)
  raise(ArgumentError, 'empty array: print_opts') if print_opts.empty?

  print_counts =
    wc_result.count.deconstruct_keys(print_opts & WcCount.members).values

  padding_width >= 2 &&
    print_counts.map! do |count_value|
      count_value.to_s.rjust(padding_width)
    end

  print_opts.include?(:path) &&
    print_counts << wc_result.path

  print_counts.join(' ')
end
