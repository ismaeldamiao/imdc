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

# Preambulo

source "${IMDC_DIR}/scripts/utils.sh"

if [ "${TYPE}" == "artigo" ]; then
   echo "\documentclass[article]{abntex2}" > "${MAIN_TEX}"
elif [ "${TYPE}" == "documento" ] || [ "${TYPE}" == "livro" ]; then
   echo "\documentclass{abntex2}" > "${MAIN_TEX}"
fi

cat >> "${MAIN_TEX}" <<EOF
\input{${IMDC_DIR}/tex/configuracao/configurar_abntex.tex}
\input{${IMDC_DIR}/tex/configuracao/configurar_documento.tex}
\input{${IMDC_DIR}/tex/configuracao/configurar_fontes.tex}
\input{${IMDC_DIR}/tex/configuracao/configurar_utilidades.tex}
\input{${IMDC_DIR}/tex/configuracao/configurar_md.tex}
EOF

[ "${titulo}" != "" ] && {
   TITULO=$(utf8_to_tex "${titulo}")
   echo "\titulo{${TITULO}}" >> "${MAIN_TEX}"
}

[ "${autor_1}" != "" ] && autores="${autor_1}"
for i in $(seq 2 20); do
   eval autor=\$\{autor_"$i"\}
   [ "${autor}" != "" ] && autores+=" and ${autor}"
done
[ "${autores}" != "" ] && \
   echo "\autor{${autores}}" >> "${MAIN_TEX}"

[ "${orientador}" != "" ] && \
   echo "\autor{${orientador}}" >> "${MAIN_TEX}"

[ "${instituicao}" != "" ] && \
   echo "\autor{${instituicao}}" >> "${MAIN_TEX}"

# Elementos pretextuais

cat >> "${MAIN_TEX}" <<EOF
\begin{document}
\pretextual
EOF

[ "${TYPE}" == "artigo" ] && echo "\maketitle" >> "${MAIN_TEX}"

if [ "${TYPE}" == "documento" ] || [ "${TYPE}" == "livro" ]; then
cat >> "${MAIN_TEX}" <<EOF
\imprimircapa
\imprimirfolhaderosto
\pretextualpreconfigurado
\pdfbookmark[0]{\contentsname}{toc}
\tableofcontents*
EOF
fi

# Elementos textuais
echo "\textual" >> "${MAIN_TEX}"

for i in $(seq -w 001 999); do
   [ -r "../textual/${i}.md" ] && \
      echo "\input{$(get_tex ../textual/${i}.md)}" >> "${MAIN_TEX}"
done

# Elementos postextuais

cat >> "${MAIN_TEX}" <<EOF
\postextual
%\bibliography{../references.bib}
EOF

for i in $(seq -w 01 99); do
   [ -r "../postextual/apendice_${i}.md" ] && \
      echo "\input{$(get_tex ../postextual/apendice_${i}.md)}" >> "${MAIN_TEX}"
done

cat >> "${MAIN_TEX}" <<EOF
\end{document}
EOF

#-r "${IMDC_DIR}/tex/.latexmkrc" \
latexmk \
   -pdflatex \
   -cd- \
   -l- \
   -new-viewer- \
   -view=none \
   -bibtex-cond \
   -silent -quiet \
   -f -g \
   -logfilewarninglist \
   "${MAIN_TEX}"
[ -r "main.pdf" ] && { cd ..; mv build/main.pdf "${titulo// /_}.pdf"; }
#rm -R build

exit 0
