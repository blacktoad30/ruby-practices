#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative './lib/ls_methods'
require 'optparse'

opts = ARGV.getopts('r')

table_print(child_files('.', reverse_order: opts['r']), 3)
