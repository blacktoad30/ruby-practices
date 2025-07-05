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

  def to_s
    @path
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

  def regular_file_size?
    size if file?
  end

  def regular_file_size
    regular_file_size?.to_i
  end

  def exist_non_regular_file?
    exist? && !file?
  end

  def readable_non_directory?
    readable? && !directory?
  end

  def word_count(word_count_types = WordCount::TYPES)
    return { byte: regular_file_size } if word_count_types == %i[byte] && !regular_file_size?.nil?

    open { _1.set_encoding('ASCII-8BIT').word_count(word_count_types, regular_file_size?) }
  end
end
