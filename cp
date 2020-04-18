#!/bin/ksh
cat "${1:?No source specified}" > "${2:?No destination specified}"
