# frozen_string_literal: true

require 'etc'

def child_files(fpath)
  Dir.children(fpath)
     .sort
     .reject { |child| dot_file?(child) }
end

def dot_file?(fname)
  File.basename(fname).match?(/^\..*/)
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

def adjust_list(list, padding = ' ', align: :left, suffix: '')
  width = max_length(list)

  list.map do |elm|
    str =
      case align
      when :left
        elm.to_s.ljust(width, padding)
      when :right
        elm.to_s.rjust(width, padding)
      when :center
        elm.to_s.center(width, padding)
      end

    "#{str}#{suffix}"
  end
end

def max_length(str_list)
  str_list.map { |str| monofont_width(str) }.max
end

def monofont_width(str)
  str.to_s.length + str.to_s.grapheme_clusters.count { |c| !c.ascii_only? }
end

def print_table(table, sep: ' ')
  table.each { |line| puts line.join(sep).strip }
end

def file_info(fname)
  fs = File.lstat(fname)
  fs = File.stat(fname) unless fs.ftype == 'link'
  size_dev =
    if fs.blockdev? || fs.chardev?
      ["#{fs.rdev_major},", fs.rdev_minor]
    else
      [nil, fs.size]
    end
  datetime =
    if file_modified_six_months_ago?(fs.mtime)
      fs.mtime.strftime('%_2b %_2e  %Y')
    else
      fs.mtime.strftime('%_2b %_2e %H:%M')
    end

  [file_mode(fs.ftype, fs.mode), fs.nlink,
   Etc.getpwuid(fs.uid).name, Etc.getgrgid(fs.gid).name,
   size_dev, datetime,
   (fs.ftype == 'link' ? "#{fname} -> #{File.readlink(fname)}" : fname)]
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

def file_modified_six_months_ago?(file_stat_time)
  now_time = Time.now
  six_months_ago = Time.at(now_time.tv_sec - 31_556_952 / 2,
                           now_time.tv_nsec,
                           :nsec)

  file_stat_time < six_months_ago
end
