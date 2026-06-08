#!/bin/bash

# e.g.: _443._tcp.your-domain.net. IN TLSA 0 1 1
# Certificate usage:
#     0: PKIX-TA (CA constraint)
#     1: PKIX-EE (Service certificate constraint)
#     2: DANE-TA (Trust anchor assertion)
#     3: DANE-EE (Domain-issued certificate)
# Selector:
#     0: entire certificate has to match.
#     1: just the public key has to match.
# Matching type:
#     0: entire information selected is present
#     1: SHA-256 hash
#     2: SHA-512 hash
[ -f "${1:?"Missing first parameter certificate-file in PEM format"}" ] \
    && ([ "${1##*.}" == "crt" ] || [ "${1##*.}" == "pem" ]) \
    && openssl x509 -in "${1}" -noout -pubkey \
    | openssl pkey -pubin -outform DER \
    | openssl dgst -sha256 -binary \
    | hexdump -ve '/1 "%02x"' \
    | xargs echo "e.g.: _443._tcp.your-domain.net. IN TLSA 0 1 1"
