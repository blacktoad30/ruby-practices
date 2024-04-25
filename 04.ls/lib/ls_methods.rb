# frozen_string_literal: true

def child_files(fpath, reverse_order: false)
  Dir.children(fpath)
     .sort { |a, z| reverse_order ? z <=> a : a <=> z }
     .reject { |child| dot_file?(child) }
end

def dot_file?(fname)
  File.basename(fname).match?(/^\..*/)
end

def table_print(str_list, col)
  return if str_list.empty?

  matrix(str_list, col)
    .map { |cols| cols.map { |elm| elm.to_s.ljust(max_length(cols) + 1) } }
    .transpose
    .each { |line| puts line.join(' ').sub(/[[:space:]]+$/, '') }
end

def matrix(ary, row)
  return ary if ary.empty?

  col, mod = ary.size.divmod(row)
  if mod.positive?
    col += 1
    (row - mod).times { ary.push(nil) }
  end

  ary.each_slice(col).to_a
end

def max_length(str_list)
  str_list.map { |str| monofont_width(str) }.max
end

def monofont_width(str)
  str.to_s.length + str.to_s.grapheme_clusters.count { |c| !c.ascii_only? }
end
