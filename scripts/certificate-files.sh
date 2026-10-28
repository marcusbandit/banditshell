#!/bin/sh
find "$HOME/Downloads" "$HOME/Documents" -maxdepth 2 -type f \( -iname '*.pem' -o -iname '*.crt' -o -iname '*.cer' -o -iname '*.der' -o -iname '*.p12' -o -iname '*.pfx' -o -iname '*.key' \) -size -256k -printf '%T@\t%p\n' 2>/dev/null | sort -rn | head -n 60 | cut -f2- | while IFS= read -r file; do
    printf '\036%s\n' "$file"
    if grep -q -- '-----BEGIN [A-Z ]*PRIVATE KEY-----' "$file" </dev/null 2>/dev/null; then
        echo "private key"
    fi
    openssl x509 -in "$file" -noout -subject -issuer -ext basicConstraints -passin pass: </dev/null 2>/dev/null
done
true
