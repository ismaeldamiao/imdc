#!/usr/bin/env bash

function replace() {
   echo -E "${3//${1}/${2}}"
}

function utf8_to_tex() {
   STR=${1}
   STR=$(replace "á" "\\'{a}" "${STR}")
   STR=$(replace "ã" "\\~{a}" "${STR}")
   STR=$(replace "â" "\\^{a}" "${STR}")
   STR=$(replace "à" "\\\`{a}" "${STR}")
   STR=$(replace "é" "\\'{e}" "${STR}")
   STR=$(replace "í" "\\'{i}" "${STR}")
   STR=$(replace "ó" "\\'{o}" "${STR}")
   STR=$(replace "ú" "\\'{u}" "${STR}")
   STR=$(replace "ç" "\\c{c}" "${STR}")
   echo "${STR}"
}

function get_tex() {
   cp "${IMDC_DIR}/scripts/markdown.lua" ./
   TEX=$(texlua "${IMDC_DIR}/scripts/markdown-cli.lua" texMathDollars=true texMathSingleBackslash=true -- "${1}")
   TEX="${TEX#*./}"
   TEX="${TEX%\}\\relax}"
   TEXT=$(cat "${TEX}")
   TEXT=$(utf8_to_tex "${TEXT}")
   echo "${TEXT}" > "${TEX}"
   mv "${TEX}" "$(basename ${1%.*}).tex"
   TEX="$(basename ${1%.*}).tex"
   echo "${TEX}"
}
