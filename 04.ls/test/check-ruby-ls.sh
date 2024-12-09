#!/bin/sh
set -eu

usage() {
  cat <<-EOF
Usage: ${0##*/} [-P LS_OPTS] [-W COL_NUM] [-V] ...

Options:

  -P LS_OPTS  'ls' command options string
  -W COL_NUM  increase output width by COL_NUM (ignore by '-l')
  -V          verbose output
EOF
  exit ${1:-0}
}

clean() {
  errno=$?
  trap '' EXIT HUP INT QUIT PIPE ALRM TERM
  test -d "$1" && rm -dr "$1"
  trap - EXIT HUP INT QUIT PIPE ALRM TERM
  exit $errno
}

max_width() {
  awk '
  length > max { max = length }
  END { print max + 1 + ext_width }
  ' ext_width="${1:-0}"
}

while
  getopts P:W:V opt
do
  case "$opt" in
  (P) ls_opts="${ls_opts:+$ls_opts }$OPTARG";;
  (W) ext_width="$OPTARG";;
  (V) verbose=1;;
  (?) usage 1;;
  esac
done

shift $(($OPTIND - 1))

: "${ls_opts:=}" "${ext_width:=0}" "${verbose:=0}"

case "$ls_opts" in
("${ls_opts##*l}") ls_islongfmt=0;;
(*) ls_islongfmt=1;;
esac

proj_root="$(cd $(dirname $0)/../..; echo $PWD)"
test_dir="/tmp/.test_ruby_ls"

trap "clean '$test_dir'" EXIT HUP INT QUIT PIPE ALRM TERM

mkdir "$test_dir"

cmd_ls="ls${ls_opts:+ ${ls_opts}}"
cmd_ruby_ls="${proj_root}/04.ls/ls.rb${ls_opts:+ ${ls_opts}}"

case $verbose in
(0) :;;
(*) echo "# cwd: ${PWD}" 1>&2;;
esac

case $ls_islongfmt in
(0)
  mkfifo "$test_dir/.ruby-ls.0.fifo" "$test_dir/.ruby-ls.1.fifo"

  ${cmd_ruby_ls} |
    case $verbose in
    (0) tee "$test_dir/.ruby-ls.0.fifo" "$test_dir/.ruby-ls.1.fifo" >/dev/null &;;
    (*) tee "$test_dir/.ruby-ls.0.fifo" "$test_dir/.ruby-ls.1.fifo" 1>&2 &;;
    esac

  LC_ALL=C ${cmd_ls} -C -w$(max_width "$ext_width" <"$test_dir/.ruby-ls.1.fifo") |
    expand -t8 |
    diff -u - "$test_dir/.ruby-ls.0.fifo"
  ;;
(*)
  mkfifo "$test_dir/.ls.0.fifo" "$test_dir/.ls.1.fifo" "$test_dir/.ruby-ls.0.fifo"

  tee "$test_dir/.ls.1.fifo" <"$test_dir/.ls.0.fifo" >/dev/null &

  ${cmd_ruby_ls} |
    case $verbose in
    (0) tee "$test_dir/.ruby-ls.0.fifo" >/dev/null &;;
    (*) tee "$test_dir/.ruby-ls.0.fifo" 1>&2 &;;
    esac

  LC_ALL=C ${cmd_ls} |
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
