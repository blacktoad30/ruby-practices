#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative './lib/ls_methods'
require 'optparse'

opts = ARGV.getopts('a')

table_print(child_files('.', export_all: opts['a']), 3)
