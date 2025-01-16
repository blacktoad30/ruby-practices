# frozen_string_literal: true

require 'optparse'

Wc = Data.define(:paths) do
  attr_reader(:errno, :results, :total)

  def initialize(paths:)
    @results, @errno = wc_results_with_errno(paths)

    @total = wc_total(@results)

    super
  end
end

WcResult = Data.define(*%i[path count message]) do
  def initialize(path:, count: nil, message: nil)
    unless count || message
      raise(ArgumentError,
            'missing keywords: count: or message:')
    end

    super
  end
end

WcCount = Data.define(*%i[newline word byte]) do
  def initialize(newline: 0, word: 0, byte: 0)
    super
  end
end

def main(args)
  print_opts, paths = wc_parse_args(args)

  data_wc = Wc.new(paths)

  wc_print(print_opts, data_wc)
end

def wc_parse_args(args)
  copy_args = args.dup

  optarg_by_opt =
    OptionParser.new
                .getopts(copy_args, 'lwc')
                .transform_keys!('l' => :newline, 'w' => :word, 'c' => :byte)

  optarg_by_opt.value?(true) ||
    optarg_by_opt.transform_values! { |_| true }

  optarg_by_opt[:path] = !copy_args.empty?

  print_opts = optarg_by_opt.select { |_, val| val }.keys

  [print_opts, copy_args]
end

def wc_results_with_errno(paths)
  errno = 0

  return [[wc_result('-')], errno] if paths.empty?

  errno = wc_readable_inputs?(paths) ? 0 : 1

  results = wc_results(paths)

  [results, errno]
end

def wc_readable_inputs?(paths)
  paths.all? do |path|
    wc_readable_input?(path)
  rescue SystemCallError
    false
  end
end

def wc_readable_input?(path)
  path == '-' || IO.read(path)
end

def wc_results(paths)
  paths.lazy.map do |path|
    wc_readable_input?(path) && wc_result(path)
  rescue SystemCallError => e
    count = e.is_a?(Errno::EISDIR) ? WcCount.new : nil
    message = e.message.gsub(/ @ .*$/, '')

    WcResult.new(path:, count:, message:)
  end
end

def wc_result(valid_path)
  fd = valid_path == '-' ? $stdin.fileno : IO.sysopen(valid_path.to_s)

  count =
    IO.open(fd) { |io| wc_count_from_io(io.set_encoding('ASCII-8BIT')) }

  WcResult.new(path: valid_path.to_s, count:)
end

def wc_count_from_io(io)
  count_by_type = { newline: 0, word: 0, byte: 0 }

  io.each do |bytes|
    count_by_type[:newline] += bytes.count("\n")
    count_by_type[:word] += bytes.scan(/[[:graph:]]+/).size
    count_by_type[:byte] += bytes.bytesize
  end

  WcCount.new(**count_by_type)
end

def wc_total(results)
  total_count_by_type = { newline: 0, word: 0, byte: 0 }
  counts_by_type = results.filter_map { |result| result.count&.to_h }

  total_count_by_type.merge!(*counts_by_type) do |_key, total, count|
    total + count
  end

  WcResult.new(path: 'total', count: WcCount.new(**total_count_by_type))
end

def wc_print(print_opts, data_wc)
  padding_width = wc_padding_width(print_opts, data_wc)
  data_wc_results = data_wc.results.dup

  data_wc.paths.size >= 2 &&
    data_wc_results = data_wc_results.chain([data_wc.total])

  data_wc_results.each do |data_wc_result|
    wc_warn(**data_wc_result.deconstruct_keys(%i[path message])) if data_wc_result.message

    next unless data_wc_result.count

    puts wc_format_data_wc_result(data_wc_result, print_opts, padding_width)
  end

  data_wc.errno
end

def wc_padding_width(print_opts, data_wc)
  base = 1

  return base if wc_simple_output?(print_opts, data_wc.paths)

  base = 7 if wc_include_non_regular_files?(data_wc.paths)
  total_bytes_digit = data_wc.total.count.byte.to_s.size

  total_bytes_digit >= base ? total_bytes_digit : base
end

def wc_simple_output?(print_opts, paths)
  (print_opts & WcCount.members).size <= 1 && paths.size <= 1
end

def wc_include_non_regular_files?(paths)
  paths.any? do |path|
    path == '-' || FileTest.exist?(path) && !FileTest.file?(path)
  end
end

def wc_warn(path:, message:)
  warn "wc: #{path}: #{message}"
end

def wc_format_data_wc_result(data_wc_result, print_opts, padding_width)
  return if print_opts.empty?

  count_values_for_print =
    data_wc_result.count.deconstruct_keys(print_opts & WcCount.members).values

  padding_width >= 2 &&
    count_values_for_print.map! do |count_value|
      count_value.to_s.rjust(padding_width)
    end

  print_opts.include?(:path) && count_values_for_print << data_wc_result.path

  count_values_for_print.join(' ')
end
