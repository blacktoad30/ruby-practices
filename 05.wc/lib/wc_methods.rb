# frozen_string_literal: true

require 'optparse'

WordCountData =
  Data.define(:paths) do
    attr_reader(:errno, :results_by_type, :total_count_by_type)

    def initialize(paths:)
      @results_by_type, @errno = wc_results_by_type_with_errno(paths)

      @total_count_by_type = wc_total_count_by_type(@results_by_type)

      super
    end

    def regular_files_only?
      paths.all? { |path| path != '-' && FileTest.file?(path) } &&
        !paths.empty?
    end
  end

def main(args)
  print_opts, paths = wc_parse_args(args)

  word_count_data = WordCountData.new(paths)

  wc_print(print_opts, word_count_data)

  word_count_data.errno
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

def wc_results_by_type_with_errno(paths)
  errno = 0

  return [[wc_count_by_type('-')], errno] if paths.empty?

  results_by_type = paths.map do |path|
    (path == '-' || IO.read(path)) && wc_count_by_type(path)
  rescue Errno::EISDIR => e
    errno = 1
    { newline: 0, word: 0, byte: 0,
      message: "wc: #{path}: #{e.message.gsub(/ @ .*$/, '')}", path: path }
  rescue SystemCallError => e
    errno = 1
    { message: "wc: #{path}: #{e.message.gsub(/ @ .*$/, '')}" }
  end

  [results_by_type, errno]
end

def wc_count_by_type(valid_path)
  fd = valid_path == '-' ? $stdin.fileno : IO.sysopen(valid_path.to_s)

  count_by_type =
    IO.open(fd) { |io| wc_count_by_type_from_io(io.set_encoding('ASCII-8BIT')) }

  count_by_type.merge!({ path: valid_path.to_s })
end

def wc_count_by_type_from_io(io)
  count_by_type = { newline: 0, word: 0, byte: 0 }

  io.each do |bytes|
    count_by_type[:newline] += bytes.count("\n")
    count_by_type[:word] += bytes.scan(/[[:graph:]]+/).size
    count_by_type[:byte] += bytes.bytesize
  end

  count_by_type
end

def wc_total_count_by_type(results_by_type)
  total_count_by_type = { newline: 0, word: 0, byte: 0, path: 'total' }
  counts_by_type = wc_extract_count_values_by_type(results_by_type)

  total_count_by_type.merge!(*counts_by_type) do |_key, total, count|
    total + count
  end
end

def wc_extract_count_values_by_type(results_by_type)
  results_by_type.filter_map do |result_by_type|
    count_by_type = result_by_type.slice(*%i[newline word byte])
    count_by_type.empty? ? nil : count_by_type
  end
end

def wc_print(print_opts, word_count_data)
  padding_width = wc_padding_width(print_opts, word_count_data)
  results_by_type = word_count_data.results_by_type.dup

  word_count_data.paths.size >= 2 &&
    results_by_type.push(word_count_data.total_count_by_type)

  outbuf = wc_make_outbuf(print_opts, results_by_type, padding_width)

  puts outbuf
end

def wc_padding_width(print_opts, word_count_data)
  base = 1

  return base if wc_simple_output?(print_opts, word_count_data.paths)

  base = 7 unless word_count_data.regular_files_only?
  total_bytes_digit = word_count_data.total_count_by_type[:byte].to_s.size

  total_bytes_digit >= base ? total_bytes_digit : base
end

def wc_simple_output?(print_opts, paths)
  (print_opts & %i[newline word byte]).size <= 1 &&
    paths.size <= 1
end

def wc_make_outbuf(print_opts, results_by_type, padding_width)
  results_by_type.inject(+ '') do |buf, result_by_type|
    str = wc_format_count_string(print_opts, result_by_type, padding_width)

    msg = [result_by_type[:message], str].compact.join("\n")

    buf << "#{msg}\n"
  end
end

def wc_format_count_string(print_opts, count_by_type, padding_width)
  count_by_type_for_print = count_by_type.slice(*print_opts)

  return nil if count_by_type_for_print.empty?

  adjust_count_by_type =
    count_by_type_for_print.map do |type, count|
      str = count.to_s

      next str if padding_width <= 1 || type == :path # !print_opts.include?(type)

      str.rjust(padding_width)
    end

  adjust_count_by_type.join(' ')
end
