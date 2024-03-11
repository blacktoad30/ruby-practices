# frozen_string_literal: true

def child_files(fpath)
  Dir.children(fpath)
     .sort
     .reject { |child| dot_file?(child) }
end

def dot_file?(fname)
  File.basename(fname).match?(/^\..*/)
end

def ls_pprint(ary, col)
  return if ary.empty?

  matrix(ary, col)
    .map { |cols| ljusts(cols, max_length(cols) + 1) }
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

def ljusts(ary, max_count)
  ary.map { |str| str.to_s.ljust(max_count) }
end

def max_length(ary)
  ary.map { |fname| monofont_width(fname) }.max
end

def monofont_width(str)
  str.to_s.length + str.to_s.grapheme_clusters.count { |c| !c.ascii_only? }
end
