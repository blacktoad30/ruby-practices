# frozen_string_literal: true

require_relative './word_count'

class WcPathname
  USE_FILETEST_MODULE_FUNCTIONS = %i[directory? file? readable? size].freeze

  private_constant :USE_FILETEST_MODULE_FUNCTIONS

  def initialize(path)
    @path = path
  end

  def stdin?
    @path == '-'
  end

  def inspect
    "#<#{self.class}:#{@path}>"
  end

  def open(mode = 'r', perm = 0o0666, &block)
    return block&.call($stdin) || $stdin if stdin?

    File.open(@path, mode, perm, &block)
  end

  def exist?
    stdin? || FileTest.exist?(@path)
  end

  USE_FILETEST_MODULE_FUNCTIONS.each do |method|
    define_method(method) { stdin? ? $stdin.stat.public_send(method) : FileTest.public_send(method, @path) }
  end

  def regular_file_size
    file? ? size : 0
  end

  def exist_non_regular_file?
    exist? && !file?
  end

  def readable_non_directory?
    readable? && !directory?
  end

  def word_count_result(word_count_types = WordCount::TYPES)
    path = @path

    return { path:, count: nil, message: exist? ? 'Permission denied' : 'No such file or directory' } unless readable?

    return { path:, count: word_count_types.to_h { [_1, 0] }, message: 'Is a directory' } if directory?

    { path:, count: word_count(word_count_types), message: nil }
  end

  private

  def word_count(word_count_types)
    return open { _1.set_encoding('ASCII-8BIT').word_count(word_count_types) } unless file? && word_count_types.include?(:byte)

    return { byte: size } if word_count_types == %i[byte]

    counts = open { _1.set_encoding('ASCII-8BIT').word_count(word_count_types - %i[byte]) }

    { **counts, byte: size }
  end
end
