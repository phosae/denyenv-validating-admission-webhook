#!/usr/bin/env sh

# for Kubernetes 1.20 and after, the `kube-root-ca.crt` ConfigMap is available to every namespace, by default.
# It contains the Cluster Certificate Authority bundle.
set -e
caBundle=$(kubectl -n kube-public get cm kube-root-ca.crt -o jsonpath={.data.'ca\.crt'} | base64 | tr -d '\n')

set +e
# Patch the webhook adding the caBundle. It uses an `add` operation to avoid errors in OpenShift because it doesn't set
# a default value of empty string like Kubernetes. Instead, it doesn't create the caBundle key.
# As the webhook is not created yet (the process should be done manually right after this job is created),
# the job will not end until the webhook is patched.
while true; do
  echo "INFO: Trying to patch webhook adding the caBundle."
  if kubectl patch validatingwebhookconfiguration denyenv --type='json' -p "[{'op': 'add', 'path': '/webhooks/0/clientConfig/caBundle', 'value':'${caBundle}'}]"; then
      break
  fi
  echo "INFO: webhook not patched. Retrying in 5s..."
  sleep 5
done