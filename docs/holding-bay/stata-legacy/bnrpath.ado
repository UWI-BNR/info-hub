capture program drop bnrpath
program define bnrpath
    * Change this path if the repo moves
    global BNRROOT "C:/yasuki/Sync/BNR-sandbox/006-dev/github/bnr-analytics"
    cd "$BNRROOT"
    display "BNRROOT global macro = ${BNRROOT}" 
    display as result "BNR working directory: `c(pwd)'"
end
