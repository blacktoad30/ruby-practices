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

def child_files(path)
  Dir.children(path)
     .reject { |file| file.match?(/^\..*/) }
     .sort
end

def tabulate_file_names(files, column)
  table = split_list_into_rows(files, column)

  table.shift(table.size - 1)
       .map { |col| adjust_list(col, suffix: ' ') }
       .push(*table)
       .transpose
end

def split_list_into_rows(list, row)
  return list if list.empty?

  col = list.size.quo(row).ceil
  pad = row * col - list.size

  (list + Array.new(pad)).each_slice(col).to_a
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
  table.each { |row| puts row.join(' ').strip }
end

def total_blocks(files)
  files.map(&File.method(:lstat)).sum(&:blocks).ceildiv(2)
end

FileInfo = Data.define(:mode,
                       :nlink,
                       :owner,
                       :group,
                       :rdev_major,
                       :rdev_minor,
                       :date_time,
                       :path_name)

def file_infos(files)
  infos = files.map { |file| file_info(file) }

  table =
    Enumerator.new do |y|
      FileInfo.members.each do |info_type|
        col = infos.map(&info_type)

        next if col.none?

        case info_type
        when :mode, :owner, :group
          y << adjust_list(col)
        when :nlink, :date_time, :rdev_major, :rdev_minor
          y << adjust_list(col, align: :right)
        when :path_name
          y << col
        end
      end
    end

  table.to_a.transpose
end

def file_info(path)
  stat = File.lstat(path)

  FileInfo.new(file_mode(stat.ftype, stat.mode),
               stat.nlink.to_s,
               Etc.getpwuid(stat.uid).name,
               Etc.getgrgid(stat.gid).name,
               *file_rdev_or_size(stat),
               file_modified_date_time(stat.mtime),
               file_path_name(stat.ftype, path))
end

def file_mode(file_type, file_mode)
  type = file_type_char(file_type)
  permission = file_permission(file_mode)

  "#{type}#{permission}"
end

def file_type_char(file_type)
  case file_type
  when 'file' then '-'
  when 'fifo' then 'p'
  when 'unknown' then '?'
  else
    file_type.slice(0)
  end
end

FILE_MODE_EXEC = [%w[- x S s], %w[- x S s], %w[- x T t]].freeze

def file_permission(file_mode)
  octal_mode = file_mode.to_s(8).slice(/[0-7]{4}$/).chars.map(&:to_i)
  protect_bits = octal_mode.shift

  octal_mode.each_with_index.inject('') do |result, (mode, i)|
    exec_type = "#{protect_bits[2 - i]}#{mode[0]}".to_i(2)

    result +
      (mode[2].zero? ? '-' : 'r') +
      (mode[1].zero? ? '-' : 'w') +
      (FILE_MODE_EXEC[i][exec_type])
  end
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
