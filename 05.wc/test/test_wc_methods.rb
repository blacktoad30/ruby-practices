#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'logger'
require 'yaml'
require_relative '../lib/wc_methods'

LOGGER = Logger.new($stdout)
LOGGER.level = Logger::DEBUG

# test 'wc_methods.rb'
class WcMethodsTest < Minitest::Test
  def test_wc_parse_args
    test_data_sets =
      YAML.load_file("#{File.dirname(__FILE__)}/data/wc_parse_args.yaml")

    test_data_sets.each do |test_data_set|
      args = test_data_set['args']

      LOGGER.debug(__method__) { "args: #{args}" }

      print_opts, operands = wc_parse_args(args)

      LOGGER.debug(__method__) { "print_opts: #{print_opts}" }

      assert_equal(print_opts, test_data_set['print_opts'])

      LOGGER.debug(__method__) { "operands: #{operands}" }

      assert_equal(operands, test_data_set['operands'])
    end
  end

  # def test_parse_operands
  #   test_data_sets =
  #     YAML.load_file("#{File.dirname(__FILE__)}/data/parse_operands.yaml")

  #   test_data_sets.each do |test_data_set|
  #     args = test_data_set['args'].dup

  #     operands = parse_operands(args)

  #     assert_equal(operands, test_data_set['operands'])
  #   end
  # end
end
