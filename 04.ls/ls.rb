#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative './lib/ls_methods'

table_print(child_files('.'), 3)
