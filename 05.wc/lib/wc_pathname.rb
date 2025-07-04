# frozen_string_literal: true

require 'pathname'
require_relative './word_count'

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

  def word_count(word_count_types = WordCount::TYPES)
    return { byte: regular_file_size } if word_count_types == %i[byte] && !regular_file_size?.nil?

    return $stdin.set_encoding('ASCII-8BIT').word_count(word_count_types, regular_file_size?) if stdin?

    open { _1.set_encoding('ASCII-8BIT').word_count(word_count_types, regular_file_size?) }
  end
end
