#!/usr/bin/env bash

[ "${autor_1}" != "" ] && {
   [ "${autor_1_1}" != "" ] && \
      autores="${autor_1}\thanks{${autor_1_1}}" || \
      autores="${autor_1}"
}
for i in $(seq 2 20); do
   [ "$(eval echo \$autor_${i})" != "" ] && {
      [ "${autor_1_1}" != "" ] && {
         autores+="\and $(eval echo \$autor_${i})\thanks{$(eval echo \$autor_${i}_1)}"
      } || \
      autores+="\and $(eval echo \$autor_${i})"
   }
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
[ "${autores}" != "" ]     && echo "\autor{$(utf8_to_tex "${autores}")}"
[ "${orientador}" != "" ]  && echo "\orientador{$(utf8_to_tex "${orientador}")}"
[ "${instituicao}" != "" ] && echo "\instituicao{$(utf8_to_tex "${titulo}")}"
`
\begin{document}
\pretextual
\maketitle
`
[ -r "../pretextual/resumo.md" ] && cat <<EOFF
\begin{resumo}[Resumo]
\input{$(get_tex ../pretextual/resumo.md)}

\vspace{\onelineskip}

\noindent\textbf{Palavras-chave}: $(utf8_to_tex "$palavraschave")
\end{resumo}
EOFF
[ -r "../pretextual/abstract.md" ] && cat <<EOFF
\begin{resumo}[Abstract]
\begin{otherlanguage*}{english}
\input{$(get_tex ../pretextual/abstract.md)}

\vspace{\onelineskip}

\noindent\textbf{Keywords}: $(utf8_to_tex "$keywords")
\end{otherlanguage*}
\end{resumo}
EOFF
[ -r "../pretextual/resumen.md" ] && cat <<EOFF
\begin{resumo}[Resumen]
\begin{otherlanguage*}{spanish}
\input{$(get_tex ../pretextual/resumen.md)}

\vspace{\onelineskip}

\noindent\textbf{Palabras clave}: $(utf8_to_tex "$palabrasclave")
\end{otherlanguage*}
\end{resumo}
EOFF
[ -r "../pretextual/resume.md" ] && cat <<EOFF
\begin{resumo}[R\'{e}sume\'{e}]
\begin{otherlanguage*}{french}
\input{$(get_tex ../pretextual/resume.md)}

\vspace{\onelineskip}

\noindent\textbf{Mots-cle\'{e}}: $(utf8_to_tex "$motsclee")
\end{otherlanguage*}
\end{resumo}
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