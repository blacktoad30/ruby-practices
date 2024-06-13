#!/bin/sh
set -eu

usage() {
  cat <<-EOF
Usage: ${0} [OPTION] ...

  -v         \`set -v\`
  -x         \`set -x\`
  -V         verbose output
  -a         list all entries
  -r         reverse list order
  -w[WIDTH]  adjust output width, default is 0 (ignore with '-l')
  -l         list in long format
EOF
  exit ${1:-0}
}

opts='vxVarlw:'
verbose=0

while
  getopts "${opts}" opt
do
  case "$opt" in
  (v|x) set -${opt};;
  (V) verbose=1;;
  (a|r|l) ls_opts="${ls_opts:+$ls_opts }-$opt";;
  (w) ext_width="$OPTARG";;
  (?) usage;;
  esac
  case "$opt" in
  (l) ls_islongfmt=1;;
  esac
done
shift $(($OPTIND - 1))

max_width() {
  awk 'length > max { max = length } END { print max + ext_width }' ext_width="${1:-0}"
}

proj_root="$(cd $(dirname $0)/../..; echo $PWD)"

test_dir="/tmp/.test_ruby_ls"

clean() {
  set -- ${1:-$?}
  trap '' EXIT HUP INT QUIT PIPE ALRM TERM
  test -d "$test_dir" && rm -dr "$test_dir"
  trap - EXIT HUP INT QUIT PIPE ALRM TERM
  exit $1
}

trap 'clean' EXIT HUP INT QUIT PIPE ALRM TERM

mkdir "$test_dir"

cmd_ls="ls${ls_opts:+ ${ls_opts}}"
cmd_ruby_ls="${proj_root}/04.ls/ls.rb${ls_opts:+ ${ls_opts}}"

(exit $verbose) || echo "# cwd: ${PWD}" 1>&2

case ${ls_islongfmt:-0} in
(0)
  mkfifo "$test_dir/.ruby-ls.0.fifo" "$test_dir/.ruby-ls.1.fifo"

  ${cmd_ruby_ls} |
    if
      ! (exit $verbose)
    then
      tee "$test_dir/.ruby-ls.0.fifo" "$test_dir/.ruby-ls.1.fifo" 1>&2 &
    else
      tee "$test_dir/.ruby-ls.0.fifo" "$test_dir/.ruby-ls.1.fifo" >/dev/null &
    fi

  LC_ALL=C ${cmd_ls} -C -w$(max_width 1 <"$test_dir/.ruby-ls.1.fifo") |
    expand -t8 |
    diff -u - "$test_dir/.ruby-ls.0.fifo"
  ;;
(*)
  mkfifo "$test_dir/.ls.0.fifo" "$test_dir/.ls.1.fifo" "$test_dir/.ruby-ls.0.fifo"

  tee "$test_dir/.ls.1.fifo" <"$test_dir/.ls.0.fifo" >/dev/null &

  ${cmd_ruby_ls} |
    if
      ! (exit $verbose)
    then
      tee "$test_dir/.ruby-ls.0.fifo" 1>&2 &
    else
      tee "$test_dir/.ruby-ls.0.fifo" >/dev/null &
    fi

  LC_ALL=C ls -l |
    tee "$test_dir/.ls.0.fifo" |
    if
      grep -Eq '^[-[:alpha:]]{10}[^ ]'
    then
      sed -nE 's/([-[:alpha:]]{10})./\1/; p;' <"$test_dir/.ls.1.fifo"
    else
      cat "$test_dir/.ls.1.fifo"
    fi |
    diff -u - "$test_dir/.ruby-ls.0.fifo"
  ;;
esac
