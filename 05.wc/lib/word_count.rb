# frozen_string_literal: true

module WordCount
  TYPES = %i[newline word byte].freeze

  def extract_types(types)
    TYPES & types
  end

  module_function :extract_types
end

module WordCount::IO
  BUFFER_SIZE = 16 * 1024

  private_constant :BUFFER_SIZE

  def word_count(word_count_types = WordCount::TYPES)
    counts = []

    loop do
      str = readpartial(BUFFER_SIZE)

      count = str.word_count(word_count_types)

      counts << count
    rescue EOFError
      break
    end

    word_count_types.to_h { [_1, 0] }
                    .merge!(*counts) { |_, total, count| total + count }
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
      split.size
    when :byte
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
