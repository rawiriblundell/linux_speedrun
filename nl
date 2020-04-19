#!/bin/ksh
count=1
if [ -r "${1}" ]; then
  while IFS='\n' read -r line; do
    printf -- '%04d: %s\n' "${count}" "${line}"
    count=$(( count + 1 ))
  done < "${1}"
else
  while IFS='\n' read -r line; do
    printf -- '%04d: %s\n' "${count}" "${line}"
    count=$(( count + 1 ))
  done
fi
