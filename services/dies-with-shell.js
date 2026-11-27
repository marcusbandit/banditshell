const MARK = "BANDITSHELL_HELPER";
const TIE = `export ${MARK}=1; command -v setpriv >/dev/null 2>&1 && exec setpriv --pdeathsig TERM -- "$@"; exec "$@"`;

function command(argv) {
    return ["sh", "-c", TIE, "sh"].concat(argv);
}
