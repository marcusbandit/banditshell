#!/bin/sh
digest() {
    [ -n "$1" ] && printf '%s\n' "$1" | openssl dgst -sha256 -r 2>/dev/null | cut -d' ' -f1
}
find "$HOME/Downloads" "$HOME/Documents" -maxdepth 2 -type f \( -iname '*.pem' -o -iname '*.crt' -o -iname '*.cer' -o -iname '*.der' -o -iname '*.p12' -o -iname '*.pfx' -o -iname '*.key' \) -size -256k -printf '%T@\t%p\n' 2>/dev/null | sort -rn | head -n 60 | cut -f2- | while IFS= read -r file; do
    printf '\036%s\n' "$file"
    if grep -q -- '-----BEGIN [A-Z ]*PRIVATE KEY-----' "$file" </dev/null 2>/dev/null; then
        echo "private key"
        if grep -q -e '-----BEGIN ENCRYPTED PRIVATE KEY-----' -e '^Proc-Type: 4,ENCRYPTED' "$file" </dev/null 2>/dev/null; then
            echo "locked"
        else
            key=$(digest "$(openssl pkey -in "$file" -pubout -passin pass: </dev/null 2>/dev/null)")
            [ -n "$key" ] && echo "key $key"
        fi
    fi
    case "$file" in
    *.[pP]12 | *.[pP][fF][xX])
        cert=$(openssl pkcs12 -in "$file" -nokeys -clcerts -passin pass: </dev/null 2>/dev/null)
        [ -n "$cert" ] || echo "locked"
        ;;
    *)
        cert=$(openssl x509 -in "$file" -passin pass: </dev/null 2>/dev/null)
        ;;
    esac
    [ -n "$cert" ] || continue
    printf '%s\n' "$cert" | openssl x509 -noout -subject -issuer -enddate -fingerprint -sha256 -ext basicConstraints 2>/dev/null
    public=$(digest "$(printf '%s\n' "$cert" | openssl x509 -noout -pubkey 2>/dev/null)")
    [ -n "$public" ] && echo "public $public"
done
true
