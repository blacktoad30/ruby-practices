# frozen_string_literal: true

require 'pathname'

WORD_COUNT_TYPES = %i[newline word byte].freeze

IO_BUFFER_SIZE = 16 * 1024

class WcPathname < Pathname
  def initialize(path)
    super(path)

    @pathname_or_stat = stdin? ? $stdin.stat : self
  end

  def stdin?
    @path == '-'
  end

  def regular_file?
    @pathname_or_stat.file?
  end

  def regular_file_size?
    @pathname_or_stat.size if regular_file?
  end

  def regular_file_size
    regular_file_size?.to_i
  end

  def exist_non_regular_file?
    return !regular_file? if stdin?

    exist? && !file?
  end

  def readable_non_directory?
    @pathname_or_stat.readable? && !@pathname_or_stat.directory?
  end

  def word_count(word_count_types = WORD_COUNT_TYPES)
    return { byte: regular_file_size } if word_count_types == %i[byte] && !regular_file_size?.nil?

    return word_count_for_io($stdin.set_encoding('ASCII-8BIT'), word_count_types, regular_file_size?) if stdin?

    open { word_count_for_io(_1.set_encoding('ASCII-8BIT'), word_count_types, regular_file_size?) }
  end
end

def word_count_for_io(io, word_count_types = WORD_COUNT_TYPES, file_size = nil)
  counts = []

  loop do
    str = io.readpartial(IO_BUFFER_SIZE)

    count = word_count_for_string(str, word_count_types, file_size)

    counts << count
  rescue EOFError
    break
  end

  word_count_types.to_h { [_1, _1 == :byte ? file_size.to_i : 0] }
                  .merge!(*counts) { |_, total, count| total + count }
end

def word_count_for_string(str, word_count_types = WORD_COUNT_TYPES, file_size = nil)
  word_count_types.to_h { [_1, _1 == :byte && !file_size.nil? ? 0 : word_count_for_string_per_type(str, _1)] }
end

def word_count_for_string_per_type(str, word_count_type)
  case word_count_type
  when :newline
    str.count("\n")
  when :word
    str.split.size
  when :byte
    str.bytesize
  else
    raise(ArgumentError, "invalid or not symbol: word_count_type ==> #{word_count_type}")
  end
end
