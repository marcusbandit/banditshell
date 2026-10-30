#!/bin/sh
body() {
    sed -n '/-----BEGIN PUBLIC KEY-----/,/-----END PUBLIC KEY-----/{/-----/d;p;}' | tr -d '\n'
}
{
    [ $# -gt 0 ] && find "$@" -maxdepth 0 -type f -size -256k 2>/dev/null
    find "$HOME/Downloads" "$HOME/Documents" -maxdepth 2 -type f \( -iname '*.pem' -o -iname '*.crt' -o -iname '*.cer' -o -iname '*.der' -o -iname '*.p12' -o -iname '*.pfx' -o -iname '*.key' \) -size -256k -printf '%T@\t%p\n' 2>/dev/null | sort -rn | head -n 60 | cut -f2-
} | while IFS= read -r file; do
    printf '\036%s\n' "$file"
    if grep -q -- '-----BEGIN [A-Z ]*PRIVATE KEY-----' "$file" </dev/null 2>/dev/null; then
        echo "private key"
        if grep -q -e '-----BEGIN ENCRYPTED PRIVATE KEY-----' -e '^Proc-Type: 4,ENCRYPTED' "$file" </dev/null 2>/dev/null; then
            echo "locked"
        else
            key=$(openssl pkey -in "$file" -pubout -passin pass: </dev/null 2>/dev/null | body)
            [ -n "$key" ] && echo "key $key"
        fi
    fi
    case "$file" in
    *.[pP]12 | *.[pP][fF][xX])
        cert=$(openssl pkcs12 -in "$file" -nokeys -clcerts -passin pass: </dev/null 2>/dev/null)
        [ -n "$cert" ] || cert=$(openssl pkcs12 -legacy -in "$file" -nokeys -clcerts -passin pass: </dev/null 2>/dev/null)
        if [ -z "$cert" ]; then
            said=$(openssl pkcs12 -in "$file" -nokeys -clcerts -passin pass: </dev/null 2>&1 >/dev/null)
            case "$said" in *"invalid password"* | *"Mac verify error"*) echo "locked" ;; esac
            continue
        fi
        out=$(printf '%s\n' "$cert" | openssl x509 -noout -subject -issuer -enddate -fingerprint -sha256 -ext basicConstraints -pubkey 2>/dev/null)
        ;;
    *)
        out=$(openssl x509 -in "$file" -noout -subject -issuer -enddate -fingerprint -sha256 -ext basicConstraints -pubkey -passin pass: </dev/null 2>/dev/null)
        ;;
    esac
    [ -n "$out" ] || continue
    printf '%s\n' "$out" | sed '/-----BEGIN PUBLIC KEY-----/,/-----END PUBLIC KEY-----/d'
    public=$(printf '%s\n' "$out" | body)
    [ -n "$public" ] && echo "public $public"
done
true
