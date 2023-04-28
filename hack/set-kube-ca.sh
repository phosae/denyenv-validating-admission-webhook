#!/usr/bin/env sh
set +e

caBundle=$(cat tls.crt | base64)

kubectl patch validatingwebhookconfiguration denyenv --type='json' -p "[{'op': 'add', 'path': '/webhooks/0/clientConfig/caBundle', 'value':'${caBundle}'}]"