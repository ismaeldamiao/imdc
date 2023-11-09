#!/usr/bin/env bash

[ "${autor_1}" != "" ] && autores="${autor_1}"
for i in $(seq 2 20); do
   eval autor=\$\{autor_"$i"\}
   [ "${autor}" != "" ] && autores+=" \and ${autor}"
done

cat <<EOF
\documentclass[article]{abntex2}
\input{${IMDC_DIR}/tex/configuracao/configurar_abntex.tex}
\input{${IMDC_DIR}/tex/configuracao/configurar_documento.tex}
\input{${IMDC_DIR}/tex/configuracao/configurar_fontes.tex}
\input{${IMDC_DIR}/tex/configuracao/configurar_utilidades.tex}
\input{${IMDC_DIR}/tex/configuracao/configurar_md.tex}
`
[ "${titulo}" != "" ]      && echo "\titulo{$(utf8_to_tex "${titulo}")}"
[ "${autores}" != "" ]     && echo "\titulo{$(utf8_to_tex "${autores}")}"
[ "${orientador}" != "" ]  && echo "\titulo{$(utf8_to_tex "${orientador}")}"
[ "${instituicao}" != "" ] && echo "\titulo{$(utf8_to_tex "${titulo}")}"
`
\begin{document}
\pretextual
\imprimircapa
\imprimirfolhaderosto
\pretextualpreconfigurado
\pdfbookmark[0]{\contentsname}{toc}
\tableofcontents*
`
[ -r "../pretextual/resumo.md" ] && cat <<EOFF
\begin{resumo}
\input{$(get_tex ../pretextual/resumo.md)}

\vspace{\onelineskip}

\noindent\textbf{Palavras-chave}: $(utf8_to_tex "$palavraschave")
\end{resumo}
EOFF
[ -r "../pretextual/abstract.md" ] && cat <<EOFF
\begin{abstract}
\input{$(get_tex ../pretextual/resumo.md)}

\vspace{\onelineskip}

\noindent\textbf{Keywords}: $(utf8_to_tex "$keywords")
\end{abstract}
EOFF
[ -r "../pretextual/resumen.md" ] && cat <<EOFF
\begin{resumen}
\input{$(get_tex ../pretextual/resumen.md)}

\vspace{\onelineskip}

\noindent\textbf{Palabras llave}: $(utf8_to_tex "$palabrasllave")
\end{resumen}
EOFF
`
\textual
`
for i in $(seq -w 001 999); do
   [ -r "../textual/${i}.md" ] && \
      echo "\input{$(get_tex ../textual/${i}.md)}"
done
`
\postextual
\bibliography{../references.bib}
`
[ -r "../postextual/apendice_01.md" ] && {
   echo "\apendices"
   echo "\input{$(get_tex ../postextual/apendice_01.md)}"
}

for i in $(seq -w 02 99); do
   [ -r "../postextual/apendice_${i}.md" ] && \
      echo "\input{$(get_tex ../postextual/apendice_${i}.md)}"
done
`
\end{document}
EOF