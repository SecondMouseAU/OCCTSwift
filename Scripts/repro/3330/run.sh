#!/bin/bash
# usage: run.sh <probe> ; prints crash lines and a summary
P=$1
L=${WORK:-.}/list.txt
N=$(wc -l < $L)
start=0; crashes=0; ok=0
while [ $start -lt $N ]; do
  out=$(perl -e 'alarm 3600; exec @ARGV' $P -list $L $start 2>${WORK:-.}/err.txt; echo "rc=$?")
  rc=$(echo "$out" | tail -1)
  done_n=$(echo "$out" | grep -c '^[0-9]')
  ok=$((ok + done_n))
  if [ "$rc" = "rc=0" ]; then break; fi
  cl=$(grep -E 'CRASH|HANG' ${WORK:-.}/err.txt | head -1)
  echo "$rc $cl"
  crashes=$((crashes + 1))
  idx=$(echo "$cl" | awk '{print $2}')
  if [ -z "$idx" ]; then echo "no crash line (hang/timeout?) after start=$start"; idx=$((start + done_n)); fi
  start=$((idx + 1))
done
echo "files=$N completed=$ok crashes=$crashes"
