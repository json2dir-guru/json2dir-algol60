#!/bin/sh
# Builds out/json2dir-eval: GNU MARST translates json2dir.alg to C, gcc compiles it
# against libalgol. Usage: build.sh MARST_PREFIX (default: $JSON2DIR_MARST)
set -eu
marst_prefix=${1:-${JSON2DIR_MARST:?usage: build.sh MARST_PREFIX}}
src=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
mkdir -p "$src/out"
# MARST wraps long string literals across lines and can split an octal escape
# ("\0" "33"); joining the pieces again restores the literal byte for byte.
"$marst_prefix/bin/marst" "$src/json2dir.alg" |
  sed -e ':a' -e '/"$/{N;s/"\n *"//;ta' -e '}' > "$src/out/json2dir.c"
gcc -O2 -w -I"$marst_prefix/include" -o "$src/out/json2dir-eval" "$src/out/json2dir.c" \
  -L"$marst_prefix/lib" -lalgol -lm
