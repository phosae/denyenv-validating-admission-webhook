#!/usr/bin/env sh

kubectl run ca-copier --grace-period=1 --image alpine:3.14 -- sleep 120

kubectl wait --for=condition=ready pod ca-copier

set +e
# use a temp container to extract the kubernetes CA
i=1
while [ "$i" -ne 20 ]
do
  caBundle=$(kubectl exec ca-copier -- cat /run/secrets/kubernetes.io/serviceaccount/ca.crt | base64 | tr -d '\n')
  if [ "${caBundle}" != '' ]; then
      break
  fi
  sleep 6
  i=$((i + 1))
done

set -e
kubectl delete pod ca-copier --wait=false

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