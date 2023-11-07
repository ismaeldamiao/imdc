
function literate(){
    while IFS='' read -r a; do
        echo "${a//é/e}"
    done < ${1} > ${1}.t
    mv ${1}{.t,}
}