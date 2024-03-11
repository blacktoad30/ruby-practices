#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative './lib/ls_methods'

ls_pprint(child_files('.'), 3)
