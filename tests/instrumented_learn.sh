#!/bin/bash
# check for errors under valgrind or sanitizers.

error()
{
  echo "instrumented testing failed on line $1"
  exit 1
}
trap 'error ${LINENO}' ERR

# define suitable post and prefixes for testing options
case $1 in
  --valgrind)
    echo "valgrind testing started"
    prefix=''
    exeprefix='valgrind --error-exitcode=42'
    postfix='1>/dev/null'
    threads="1"
  ;;
  --valgrind-thread)
    echo "valgrind-thread testing started"
    prefix=''
    exeprefix='valgrind --error-exitcode=42'
    postfix='1>/dev/null'
    threads="2"
  ;;
  --sanitizer-undefined)
    echo "sanitizer-undefined testing started"
    prefix='!'
    exeprefix=''
    postfix='2>&1 | grep -A50 "runtime error:"'
    threads="1"
  ;;
  --sanitizer-thread)
    echo "sanitizer-thread testing started"
    prefix='!'
    exeprefix=''
    postfix='2>&1 | grep -A50 "WARNING: ThreadSanitizer:"'
    threads="2"

cat << EOF > tsan.supp
race:TTEntry::move
race:TTEntry::depth
race:TTEntry::bound
race:TTEntry::save
race:TTEntry::value
race:TTEntry::eval
race:TTEntry::is_pv

race:TranspositionTable::probe
race:TranspositionTable::hashfull

EOF

    export TSAN_OPTIONS="suppressions=./tsan.supp"

  ;;
  *)
    echo "unknown testing started"
    prefix=''
    exeprefix=''
    postfix=''
    threads="1"
  ;;
esac

mkdir -p training_data_01
mkdir -p training_data_02

# gensfen testing 01
cat << EOF > gensfen01.exp
 set timeout 240
 spawn $exeprefix ./stockfish

 send "uci\n"
 expect "uciok"

 send "setoption name Threads value $threads\n"
 send "setoption name Use NNUE value false\n"
 send "isready\n"
 send "gensfen depth 3 loop 100 use_draw_in_training_data_generation 1 eval_limit 32000 output_file_name training_data_01/training_data.bin use_raw_nnue_eval 0\n"
 expect "gensfen finished."

 send "quit\n"
 expect eof

 # return error code of the spawned program, useful for valgrind
 lassign [wait] pid spawnid os_error_flag value
 exit \$value
EOF

# gensfen testing 02
cat << EOF > gensfen02.exp
 set timeout 240
 spawn $exeprefix ./stockfish

 send "uci\n"
 expect "uciok"

 send "setoption name Threads value $threads\n"
 send "setoption name Use NNUE value true\n"
 send "isready\n"
 send "gensfen depth 3 loop 100 use_draw_in_training_data_generation 1 eval_limit 32000 output_file_name training_data_02/training_data.bin use_raw_nnue_eval 0\n"
 expect "gensfen finished."

 send "quit\n"
 expect eof

 # return error code of the spawned program, useful for valgrind
 lassign [wait] pid spawnid os_error_flag value
 exit \$value
EOF

for exp in gensfen01.exp gensfen02.exp
do

  echo "$prefix expect $exp $postfix"
  eval "$prefix expect $exp $postfix"

  rm $exp

done

rm -f tsan.supp

echo "instrumented learn testing OK"
