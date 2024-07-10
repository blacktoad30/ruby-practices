# frozen_string_literal: true

require 'optparse'
require 'etc'

def main(argv)
  opts = argv.getopts('l')
  files = child_files('.')
  table = opts['l'] ? file_infos(files) : tabulate_file_names(files, 3)

  puts "total #{total_blocks(files)}" if opts['l']
  print_table(table)
end

def child_files(fpath)
  Dir.children(fpath)
     .sort
     .reject { |child| child.match?(/^\..*/) }
end

def tabulate_file_names(entries, column)
  table = matrix(entries, column)

  table.map
       .with_index do |col, i|
         if i < col.size - 1
           adjust_list(col, suffix: ' ')
         else
           col
         end
       end
       .transpose
end

def matrix(ary, row)
  return ary if ary.empty?

  col, mod = ary.size.divmod(row)
  if mod.positive?
    col += 1
    ary.concat Array.new((row - mod))
  end

  ary.each_slice(col).to_a
end

def adjust_list(list, align: :left, suffix: '')
  width = list.map { |elm| monofont_width(elm.to_s) }.max

  list.map do |elm|
    str =
      case align
      when :left
        elm.to_s.ljust(width, ' ')
      when :right
        elm.to_s.rjust(width, ' ')
      end

    "#{str}#{suffix}"
  end
end

def monofont_width(str)
  str.to_s.length + str.to_s.grapheme_clusters.count { |c| !c.ascii_only? }
end

def print_table(table)
  table.each { |line| puts line.join(' ').strip }
end

def total_blocks(entries)
  entries.map.sum do |fname|
    fs =
      if File.ftype(fname) == 'link'
        File.lstat(fname)
      else
        File.stat(fname)
      end

    fs.blocks.ceildiv(2)
  end
end

def file_infos(entries)
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
end

def file_info(fname)
  fs = File.lstat(fname)

  [file_mode(fs.ftype, fs.mode),
   fs.nlink.to_s,
   Etc.getpwuid(fs.uid).name,
   Etc.getgrgid(fs.gid).name,
   file_rdev_or_size(fs),
   file_modified_date_time(fs.mtime),
   file_path_name(fs.ftype, fname)]
end

def file_mode(ftype, fmode)
  file_type = entry_type(ftype)
  file_perm = entry_perm(fmode)

  "#{file_type}#{file_perm}"
end

def entry_type(ftype)
  case ftype
  when 'file' then '-'
  when 'fifo' then 'p'
  when 'unknown' then '?'
  else
    ftype.slice(0)
  end
end

MOD_X = [%w[- x S s], %w[- x S s], %w[- x T t]].freeze

def entry_perm(fmode)
  fm = fmode.to_s(8).slice(/[0-7]{4}$/)
  st_prot = fm[0].to_i
  fperm =
    fm[1..3].chars.map.with_index do |mod, idx|
      m = mod.to_i

      [(m[2].zero? ? '-' : 'r'),
       (m[1].zero? ? '-' : 'w'),
       (MOD_X[idx]["#{st_prot[2 - idx]}#{m[0]}".to_i(2)])]
    end

  fperm.join
end

def file_rdev_or_size(file_stat)
  if file_stat.blockdev? || file_stat.chardev?
    ["#{file_stat.rdev_major},", file_stat.rdev_minor.to_s]
  else
    [nil, file_stat.size.to_s]
  end
end

TIME_NOW = Time.now
# AVERAGE_SECONDS_IN_A_GREGORIAN_YEAR =
#   (365 + 97r / 400) * 24 * 60 * 60 # => (31556952/1)
SIX_MONTHS_AGO =
  Time.at(TIME_NOW.tv_sec - 31_556_952 / 2, TIME_NOW.tv_nsec, :nsec)

def file_modified_date_time(modified_time)
  if modified_time < SIX_MONTHS_AGO
    modified_time.strftime('%_2b %_2e  %Y')
  else
    modified_time.strftime('%_2b %_2e %H:%M')
  end
end

def file_path_name(file_type, path)
  if file_type == 'link'
    "#{File.basename(path)} -> #{File.readlink(path)}"
  else
    File.basename(path)
  end
end
