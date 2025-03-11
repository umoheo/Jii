# Telegram @cleverestech
# Openssl need

set -e

# ======================
# Configuration
# ======================
readonly TARGET_DEVICE_ID="Device-$(openssl rand -hex 8)"
readonly SECURITY_TAG="TEE"
readonly VALIDITY_CA=3650   # 10-year validity for CA
readonly VALIDITY_DEV=365   # 1-year validity for device cert

# ======================
# File Names
# ======================
readonly CERT_AUTHORITY_PRIVATE="ca.key"
readonly ROOT_CERTIFICATE="ca.crt"
readonly DEVICE_PRIVATE_KEY="device.key"
readonly DEVICE_CSR_FILE="device.csr"
readonly DEVICE_CERT_FILE="device.crt"
readonly KEYBOX_FILE="keybox.xml"

# ======================
# Security Functions
# ======================
generate_ca_credentials() {
    echo "Generating elliptic curve private key for certificate authority..."
    openssl genpkey -algorithm ec -pkeyopt ec_paramgen_curve:P-256 -out "${CERT_AUTHORITY_PRIVATE}"
    
    echo "Creating self-signed root certificate..."
    openssl req -key "${CERT_AUTHORITY_PRIVATE}" -new -x509 -days "${VALIDITY_CA}" \
        -subj "/CN=cleverestech/title=${SECURITY_TAG}" -out "${ROOT_CERTIFICATE}"
}

generate_device_credentials() {
    echo "Generating device elliptic curve key pair..."
    openssl genpkey -algorithm ec -pkeyopt ec_paramgen_curve:P-256 -out "${DEVICE_PRIVATE_KEY}"

    echo "Creating certificate signing request..."
    openssl req -new -key "${DEVICE_PRIVATE_KEY}" \
        -subj "/CN=cleverestech/title=${SECURITY_TAG}" -out "${DEVICE_CSR_FILE}"
}

sign_device_certificate() {
    echo "Issuing device certificate with CA signature..."
    openssl x509 -req -in "${DEVICE_CSR_FILE}" -CA "${ROOT_CERTIFICATE}" \
        -CAkey "${CERT_AUTHORITY_PRIVATE}" -CAcreateserial -days "${VALIDITY_DEV}" \
        -out "${DEVICE_CERT_FILE}"
}

# ======================
# XML Generation
# ======================
create_attestation_xml() {
    echo "Building attestation document..."
    
    local formatted_privkey=$(sed 's/^/                    /' "${DEVICE_PRIVATE_KEY}")
    local formatted_cert=$(sed 's/^/                        /' "${DEVICE_CERT_FILE}")

    cat > "${KEYBOX_FILE}" <<-EOF
<?xml version="1.0"?>
<AndroidAttestation>
    <NumberOfKeyboxes>1</NumberOfKeyboxes>
    <Keybox DeviceID="${TARGET_DEVICE_ID}">
        <Key algorithm="ecdsa">
            <PrivateKey format="pem">
${formatted_privkey}
            </PrivateKey>
            <CertificateChain>
                <NumberOfCertificates>1</NumberOfCertificates>
                <Certificate format="pem">
${formatted_cert}
                </Certificate>
            </CertificateChain>
        </Key>
    </Keybox>
</AndroidAttestation>
EOF
}

# ======================
# Main Execution
# ======================
main() {
    echo "=== Cryptographic Material Generation ==="
    generate_ca_credentials
    generate_device_credentials
    sign_device_certificate
    
    echo "=== Assembling Security Package ==="
    create_attestation_xml
    
    echo "=== Operation Summary ==="
    echo "Security package created:"
    echo " - Root CA: ${ROOT_CERTIFICATE}"
    echo " - Device credentials: ${DEVICE_PRIVATE_KEY}, ${DEVICE_CERT_FILE}"
    echo " - Attestation record: ${KEYBOX_FILE}"
    echo "Associated Device Identifier: ${TARGET_DEVICE_ID}"
}

main
