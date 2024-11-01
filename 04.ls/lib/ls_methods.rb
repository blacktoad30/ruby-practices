# frozen_string_literal: true

require 'optparse'
require 'etc'

FileInfo =
  Data.define(:mode, :nlink, :owner, :group, :rdev_major, :rdev_minor,
              :date_time, :path_name)

FILE_MODE_EXEC = [%w[- x S s], %w[- x S s], %w[- x T t]].freeze

TIME_NOW = Time.now
# AVERAGE_SECONDS_IN_A_GREGORIAN_YEAR =
#   (365 + 97r / 400) * 24 * 60 * 60 # => (31556952/1)
SIX_MONTHS_AGO =
  Time.at(TIME_NOW.tv_sec - 31_556_952 / 2, TIME_NOW.tv_nsec, :nsec)

def main(args)
  opts = args.getopts('alr')
  files = child_files('.', all: opts['a'], reverse: opts['r'])
  table = opts['l'] ? file_infos(files) : tabulate_file_names(files, 3)

  puts "total #{total_blocks(files)}" if opts['l']
  print_table(table)
end

def child_files(path, all: false, reverse: false)
  filenames =
    if all
      Dir.children(path).unshift('.', '..')
    else
      Dir.children(path).delete_if { |file| file.match?(/^\..*/) }
    end

  if reverse
    filenames.sort!.reverse!
  else
    filenames.sort!
  end
end

def tabulate_file_names(files, column_size)
  table = tabulate_list_by_row_size(files, column_size)

  table.shift(table.size - 1)
       .map { |column_fields| adjust_strings(column_fields, suffix: ' ') }
       .push(*table)
       .transpose
end

def tabulate_list_by_row_size(list, row_size)
  return list if list.empty?

  column_size = list.size.quo(row_size).ceil
  padding_size = row_size * column_size - list.size

  (list + Array.new(padding_size)).each_slice(column_size).to_a
end

def adjust_strings(strings, align: :left, suffix: '')
  width = strings.map { |str| monofont_width(str.to_s) }.max

  strings.map do |str|
    str =
      case align
      when :left
        str.to_s.ljust(width, ' ')
      when :right
        str.to_s.rjust(width, ' ')
      end

    "#{str}#{suffix}"
  end
end

def monofont_width(str)
  str.to_s.length + str.to_s.grapheme_clusters.count { |c| !c.ascii_only? }
end

def print_table(table)
  table.each { |row_fields| puts row_fields.join(' ').strip }
end

def total_blocks(files)
  files.map(&File.method(:lstat)).sum(&:blocks).ceildiv(2)
end

def file_infos(files)
  infos = files.map { |file| file_info(file) }

  table =
    Enumerator.new do |y|
      FileInfo.members.each do |info_type|
        each_info_type_values = infos.map(&info_type)

        next if each_info_type_values.none?

        case info_type
        when :mode, :owner, :group
          y << adjust_strings(each_info_type_values)
        when :nlink, :date_time, :rdev_major, :rdev_minor
          y << adjust_strings(each_info_type_values, align: :right)
        when :path_name
          y << each_info_type_values
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
