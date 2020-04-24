#!/bin/ksh
count=1

while IFS='\n' read -r line; do
  printf -- '%04d: %s\n' "${count}" "${line}"
  count=$(( count + 1 ))
done < "${1:-/dev/stdin}"
