#!/usr/bin/env bash

IMDC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/.."
source "${IMDC_DIR}/scripts/parse_yaml.sh"
source "${IMDC_DIR}/scripts/tex2pdf.sh"

# ******************
# Paleta de cores
# ******************
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
   echo -e "${RED}Erro: Arquivo 'informacoes.yml' não encontrado.${LIGHT}"
   exit 2
}

[ -d "pretextual" ] || {
   echo -e "${RED}Erro: Diretório 'pretextual' não encontrado.${LIGHT}"
   exit 2
}

[ -d "textual" ] || {
   echo -e "${RED}Erro: Diretório 'textual' não encontrado.${LIGHT}"
   exit 2
}

[ -d "postextual" ] || {
   echo -e "${RED}Erro: Diretório 'postextual' não encontrado.${LIGHT}"
   exit 2
}

[ -f "references.bib" ] || {
   echo -e "${RED}Erro: Arquivo 'references.bib' não encontrado.${LIGHT}"
   exit 2
}

[ -d "build" ] && rm "build"

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

[ "${TYPE}" == "artigo" ] && cat > "${IMDC_DIR}/tex/main.tex" <<EOF
\documentclass[article]{abntex2}
EOF

[ "${TYPE}" != "artigo" ] && cat > "${IMDC_DIR}/tex/main.tex" <<EOF
\documentclass{abntex2}
EOF


cat >> "${IMDC_DIR}/tex/main.tex" <<EOF
\input{${IMDC_DIR}/tex/configuracao/configurar_abntex.tex}
\input{${IMDC_DIR}/tex/configuracao/configurar_documento.tex}
\input{${IMDC_DIR}/tex/configuracao/configurar_fontes.tex}
\input{${IMDC_DIR}/tex/configuracao/configurar_utilidades.tex}
\input{${IMDC_DIR}/tex/configuracao/configurar_md.tex}
EOF

[ "${autor_1}" != "" ] && autores+="${autor_1}"

for i in $(seq 2 20); do
   eval autor=\$\{autor_"$i"\}
   [ "${autor}" != "" ] && autores+=" and ${autor}"
done

for i in $(seq -w 01 99); do
   [ -r "postextual/apendice_${i}.md" ] && {
      apendices+=`cat postextual/apendice_${i}.md`
      apendices+=`printf "\n\n"`
   }
done

[ "${titulo}" != "" ] && cat >> "${IMDC_DIR}/tex/main.tex" <<EOF
\titulo{${titulo}}
EOF

[ "${autores}" != "" ] && cat >> "${IMDC_DIR}/tex/main.tex" <<EOF
\autor{${autores}}
EOF

[ "${orientador}" != "" ] && cat >> "${IMDC_DIR}/tex/main.tex" <<EOF
\autor{${orientador}}
EOF

[ "${instituicao}" != "" ] && cat >> "${IMDC_DIR}/tex/main.tex" <<EOF
\autor{${instituicao}}
EOF

# Elementos pretextuais

cat >> "${IMDC_DIR}/tex/main.tex" <<EOF
\begin{document}
\maketitle
EOF

# Elementos textuais
cat >> "${IMDC_DIR}/tex/main.tex" <<EOF
\textual
EOF

for i in $(seq -w 001 999); do
[ -r "textual/${i}.md" ] && cat >> "${IMDC_DIR}/tex/main.tex" <<EOF
\markdownInput{../textual/${i}.md}
EOF
done

# Elementos postextuais

cat >> "${IMDC_DIR}/tex/main.tex" <<EOF
\postextual
\bibliography{../references.bib}
EOF

for i in $(seq -w 01 99); do
[ -r "postextual/apendice_${i}.md" ] && cat >> "${IMDC_DIR}/tex/main.tex" <<EOF
\markdownInput{../postextual/apendice_${i}.md}
EOF
done

cat >> "${IMDC_DIR}/tex/main.tex" <<EOF
\end{document}
EOF

mkdir build; cd build
ARGS="-pdflua "
ARGS+="-cd- "
ARGS+="-bibtex-cond "
latexmk ${ARGS} "${IMDC_DIR}/tex/main.tex"
cd ..; mv build/main.pdf "${titulo// /_}.pdf"
rm -R build

exit 0
