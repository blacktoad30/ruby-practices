#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'logger'
require 'yaml'
require_relative '../lib/wc_methods'

LOGGER_LEVEL =
  Logger::Severity.constants.to_h do |const_sym|
    [const_sym.to_s, Logger::Severity.const_get(const_sym)]
  end

LOGGER = Logger.new($stdout)

LOGGER.level = LOGGER_LEVEL[ARGV[0]] || ARGV[0]&.to_i || Logger::WARN

# TEST_DATA_SETS_DIR = "#{File.dirname(__FILE__)}/data/".freeze

# test 'wc_methods.rb'
class WcMethodsTest < Minitest::Test
  def data_sets_file_path(filename)
    "#{File.dirname(__FILE__)}/data/#{filename}.yaml"
  end

  def test_wc_parse_args
    test_data_sets =
      YAML.load_file(data_sets_file_path(__method__.to_s.gsub(/^test_/, '')))

    test_data_sets.each do |test_data_set|
      args = test_data_set['args']

      LOGGER.debug(__method__) { "args: #{args}" }

      print_opts, operands = wc_parse_args(args)

      LOGGER.debug(__method__) { "print_opts: #{print_opts}" }
      LOGGER.debug(__method__) { "operands: #{operands}" }

      assert_equal(print_opts, test_data_set['print_opts'])
      assert_equal(operands, test_data_set['operands'])
    end
  end

  def test_wc_count_by_type_from_io
    test_data_sets =
      YAML.load_file(data_sets_file_path(__method__.to_s.gsub(/^test_/, '')))

    test_data_sets.each do |test_data_set|
      input = test_data_set['input']

      LOGGER.debug(__method__) { "input: #{input}" }

      io = StringIO.new(input)

      count_by_type = wc_count_by_type_from_io(io)

      LOGGER.debug(__method__) { "count_by_type: #{count_by_type}" }

      assert_equal(count_by_type, test_data_set['count_by_type'])
    end
  end
end
