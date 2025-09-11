# frozen_string_literal: true

module WordCount
  TYPES = %i[newline word bytesize].freeze

  def extract_types(types)
    TYPES & types
  end

  module_function :extract_types
end

class WordCount::Pathname
  USE_FILETEST_MODULE_FUNCTIONS = %i[directory? file? readable? size].freeze

  private_constant :USE_FILETEST_MODULE_FUNCTIONS

  def initialize(path = nil)
    @path = path.to_s
  end

  def to_path
    return '-' if @path.empty?

    @path
  end

  def stdin?
    to_path == '-'
  end

  def inspect
    "#<#{self.class}:#{to_path}>"
  end

  def open(mode = 'r', perm = 0o0666, &block)
    return block&.call($stdin) || $stdin if stdin?

    File.open(to_path, mode, perm, &block)
  end

  def exist?
    stdin? || FileTest.exist?(to_path)
  end

  USE_FILETEST_MODULE_FUNCTIONS.each do |method|
    define_method(method) { stdin? ? $stdin.stat.public_send(method) : FileTest.public_send(method, to_path) }
  end

  def regular_file_size
    file? ? size : 0
  end

  def exist_non_regular_file?
    exist? && !file?
  end

  def word_count_result(word_count_types = WordCount::TYPES)
    path = @path.empty? ? 'standard input' : @path

    return { path:, count: nil, message: exist? ? 'Permission denied' : 'No such file or directory' } unless readable?

    return { path:, count: word_count_types.to_h { [_1, 0] }, message: 'Is a directory' } if directory?

    { path:, count: word_count(word_count_types), message: nil }
  rescue Errno::EPERM => e
    { path:, count: nil, message: e.message.partition(' @ ').first }
  end

  private

  def word_count(word_count_types)
    return open { _1.set_encoding('ASCII-8BIT').word_count(word_count_types) } unless file? && word_count_types.include?(:bytesize)

    return { bytesize: size } if word_count_types == %i[bytesize]

    counts = open { _1.set_encoding('ASCII-8BIT').word_count(word_count_types - %i[bytesize]) }

    { **counts, bytesize: size }
  end
end

module WordCount::IO
  BUFFER_SIZE = 16 * 1024

  private_constant :BUFFER_SIZE

  def word_count(word_count_types = WordCount::TYPES, bufsize: BUFFER_SIZE)
    each_buffer(bufsize).inject(:<<).to_s.word_count(word_count_types)
  end

  def each_buffer(limit = BUFFER_SIZE)
    return to_enum(__callee__, limit) unless block_given?

    loop do
      yield readpartial(limit)
    rescue EOFError
      break
    end

    self
  end
end

module WordCount::String
  def word_count(word_count_types = WordCount::TYPES)
    word_count_types.to_h { [_1, word_count_per_type(_1)] }
  end

  private

  def word_count_per_type(word_count_type)
    case word_count_type
    when :newline
      count("\n")
    when :word
      num = 0

      split { num += 1 if _1.match?(/[[:graph:]]/) }

      num
    when :bytesize
      bytesize
    else
      raise(ArgumentError, "word_count_type: allow only #{WordCount::TYPES.map(&:inspect).join(', ')}")
    end
  end
end

class IO
  include WordCount::IO
end

class String
  include WordCount::String
end
