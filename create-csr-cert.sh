#!/bin/bash

set -ex

usage() {
    cat <<EOF
Generate certificate suitable for use with an webhook service.

This script uses k8s' CertificateSigningRequest API to a generate a
certificate signed by k8s CA suitable for use with webhook
services. This requires permissions to create and approve CSR. See
https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster for
detailed explantion and additional instructions.

The server key/cert k8s CA cert are stored in a k8s secret.

usage: ${0} [OPTIONS]

The following flags are required.

       --service          Service name of webhook.
       --namespace        Namespace where webhook service and secret reside.
       --secret           Secret name for CA certificate and server certificate/key pair.
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case ${1} in
        --service)
            service="$2"
            shift
            ;;
        --secret)
            secret="$2"
            shift
            ;;
        --namespace)
            namespace="$2"
            shift
            ;;
        *)
            usage
            ;;
    esac
    shift
done

[ -z ${service} ] && echo "ERROR: --service flag is required" && exit 1
[ -z ${secret} ] && echo "ERROR: --secret flag is required" && exit 1
[ -z ${namespace} ] && namespace=default

if [ ! -x "$(command -v openssl)" ]; then
    echo "openssl not found"
    exit 1
fi

csrName=${service}.${namespace}
tmpdir=$(mktemp -d)
echo "creating certs in tmpdir ${tmpdir} "

cat <<EOF >> ${tmpdir}/csr.conf
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name

[req_distinguished_name]
O = zeng.dev
CN = denyenv.default

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${service}
DNS.2 = ${service}.${namespace}
DNS.3 = ${service}.${namespace}.svc
IP.1 = 192.168.1.10  # change it to your IP address
EOF

openssl genrsa -out ${tmpdir}/server-tls.key 2048
openssl req -new -key ${tmpdir}/server-tls.key -subj "/CN=system:node:fake" -out ${tmpdir}/server.csr -config ${tmpdir}/csr.conf

# clean-up any previously created CSR for our service. Ignore errors if not present.
kubectl delete csr ${csrName} 2>/dev/null || true

# create  server cert/key CSR and  send to k8s API
cat <<EOF | kubectl create -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${csrName}
spec:
  request: $(cat ${tmpdir}/server.csr | base64 | tr -d '\n')
  signerName: zeng.dev/serving
  expirationSeconds: 86400000
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF

# verify CSR has been created
while true; do
    kubectl get csr ${csrName}
    if [ "$?" -eq 0 ]; then
        break
    fi
done

# approve and fetch the signed certificate
kubectl certificate approve ${csrName}

# use self signed CA to issue a certificate for CertificateSigningRequest
kubectl get csr denyenv.default -o jsonpath='{.spec.request}' | base64 --decode | \
  cfssl sign -ca tls.crt -ca-key tls.key -config server-signing-config.json - | \
  cfssljson -bare denyenv-cert

# set status.certificate in certificate
kubectl get csr denyenv.default -o json | \
  jq '.status.certificate = "'$(base64 -i denyenv-cert.pem | tr -d '\n')'"' | \
  kubectl replace --raw /apis/certificates.k8s.io/v1/certificatesigningrequests/denyenv.default/status -f -

# verify certificate has been signed
for x in $(seq 10); do
    serverCert=$(kubectl get csr ${csrName} -o jsonpath='{.status.certificate}')
    if [[ ${serverCert} != '' ]]; then
        break
    fi
    sleep 1
done
if [[ ${serverCert} == '' ]]; then
    echo "ERROR: After approving csr ${csrName}, the signed certificate did not appear on the resource. Giving up after 10 attempts." >&2
    exit 1
fi
echo ${serverCert} | openssl base64 -d -A -out ${tmpdir}/server-tls.crt


# create the secret with CA cert and server cert/key
kubectl create secret tls ${secret} \
        --key="${tmpdir}/server-tls.key" \
        --cert="${tmpdir}/server-tls.crt" \
        --dry-run -o yaml |
    kubectl -n ${namespace} apply -f -
