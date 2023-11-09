#!/usr/bin/env bash

IMDC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
MAIN_TEX="${IMDC_DIR}/tex/main.tex"

# Paleta de cores
BLACK="\e[30m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
WHITE="\e[37m"
BOLD="\e[1;37m"
LIGHT="\e[0;37m"

source "${IMDC_DIR}/scripts/parse_yaml.sh"

################################################################################
# Estagio 0: Checar argumentos
################################################################################

while getopts ":hc:t:b:" OPITION; do
   if [ "${OPITION}" == "h" ]; then
      bash "${IMDC_DIR}/scripts/help.sh"
      exit 0
   elif [ "${OPITION}" == "t" ]; then
      TYPE="${OPTARG}"
      [ "${TYPE}" != "artigo" ] && [ "${TYPE}" != "documento" ] &&
      [ "${TYPE}" != "livro" ] && {
         bash "${IMDC_DIR}/scripts/help.sh"
         exit 1
      }
   elif [ "${OPITION}" == "c" ]; then
      [ "${OPTARG}" == "2" ] = TWO_COLUMNS=true
   elif [ "${OPITION}" == "b" ]; then
      TEXLIVE_BIN="${OPTARG}"
   fi
done

################################################################################
# Estagio 1: Checar estrutura dos diretorios
################################################################################

[ -f "informacoes.yml" ] && {
   eval $(parse_yaml informacoes.yml)
} || {
   echo -e "${BOLD}${RED}Erro: Arquivo 'informacoes.yml' não encontrado.${LIGHT}"
   exit 2
}

[ -d "pretextual" ] || {
   echo -e "${BOLD}${RED}Erro: Diretório 'pretextual' não encontrado.${LIGHT}"
   exit 2
}

[ -d "textual" ] || {
   echo -e "${BOLD}${RED}Erro: Diretório 'textual' não encontrado.${LIGHT}"
   exit 2
}

[ -d "postextual" ] || {
   echo -e "${BOLD}${RED}Erro: Diretório 'postextual' não encontrado.${LIGHT}"
   exit 2
}

[ -f "references.bib" ] || {
   echo -e "${BOLD}${RED}Erro: Arquivo 'references.bib' não encontrado.${LIGHT}"
   exit 2
}

[ -d "build" ] && rm -R "build"
mkdir build && cd build

################################################################################
# Estagio 2: Checar integridade do imdc
################################################################################

[ -r "${IMDC_DIR}/tex" ] || [ -d "${IMDC_DIR}/tex" ] || {
   echo -e "${RED}Erro: Não foi possível ler os arquivos do imdc.${LIGHT}"
   exit 2
}

################################################################################
# Estagio 3: Checar presenca do texlive
################################################################################

[ "${TEXLIVE_BIN}" != "" ] && PATH=${TEXLIVE_BIN}:${PATH}

################################################################################
# Estagio 4: Escrever main.tex e compilar
################################################################################

source "${IMDC_DIR}/scripts/utils.sh"

[ "${TYPE}" == "artigo" ] && \
   source "${IMDC_DIR}/scripts/artigo.tex.sh" > "${MAIN_TEX}"

latexmk \
   -r "${IMDC_DIR}/tex/rc" \
   -pdf- \
   -silent -quiet \
   -f -g \
   -logfilewarninglist \
   "${MAIN_TEX}"
latexmk \
   -r "${IMDC_DIR}/tex/rc" \
   -pdflatex \
   -silent -quiet \
   -f -g \
   -logfilewarninglist \
   "${MAIN_TEX}"
[ -r "main.pdf" ] && { cd ..; mv build/main.pdf "${titulo// /_}.pdf"; }
#rm -R build

exit 0
