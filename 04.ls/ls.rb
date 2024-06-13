#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative './lib/ls_methods'
require 'optparse'

opts = ARGV.getopts('l')

entries = child_files('.')

if opts['l']
  blocks =
    entries.map do |fname|
      fs =
        if File.ftype(fname) == 'link'
          File.lstat(fname)
        else
          File.stat(fname)
        end

      fs.blocks.ceildiv(2)
    end

  puts "total #{blocks.sum}"

  table =
    entries.map { |fname| file_info(fname) }
           .transpose
           .map
           .with_index do |lst, idx|
             case idx
             when 0, 2, 3
               adjust_list(lst)
             when 1, 5
               adjust_list(lst, align: :right)
             when 4
               size_dev =
                 lst.transpose
                    .select { |col| col.compact.size.positive? }

               size_dev.map { |col| adjust_list(col, align: :right) }
                       .transpose
                       .map { |info| info.join(' ') }
             else
               lst
             end
           end
           .transpose
else
  tbl = matrix(entries, 3)
  table =
    tbl.map
       .with_index do |lst, idx|
         if idx < tbl.size - 1
           adjust_list(lst, suffix: ' ')
         else
           lst
         end
       end
       .transpose
end

print_table(table)
