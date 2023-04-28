TAG = zengxu/denyenv-validating-admission-webhook:v1

build-load:
	docker buildx build --load -t $(TAG) .
	kind load docker-image $(TAG)

cert:
	./hack/gencert.sh
	./hack/create-csr-cert.sh --service denyenv --namespace default --secret denyenv-tls-secret

deploy:
	./hack/set-kube-ca.sh &
	make cert
	kubectl apply -f ./manifests/k.yaml

clear:
	kubectl delete secret denyenv-tls-secret
	kubectl delete -f ./manifests/k.yaml
	kubectl delete CertificateSigningRequest denyenv.default

deploy-cm: SHELL:=/bin/bash
deploy-cm:
	# ./manifests/cert-manager-1.5.3.yaml was ported from https://github.com/jetstack/cert-manager/releases/download/v1.5.3/cert-manager.yaml
	kubectl apply -f ./manifests/cert-manager-1.5.3.yaml
	# loop until cert-manager pod ready
	for i in {1..30}; do kubectl apply -f ./manifests/k-cert-manager.yaml; if [ $$? -eq 0 ]; then break; else sleep 6; fi; done;
	kubectl apply -f ./manifests/k.yaml

clear-cm:
	kubectl delete -f ./manifests/k.yaml &
	kubectl delete -f ./manifests/cert-manager-1.5.3.yaml &
	kubectl delete -f ./manifests/k-cert-manager.yaml

save-cert:
	kubectl get secret denyenv-tls-secret -o jsonpath={.data.'tls\.crt'} | base64 -d > tls.crt
	kubectl get secret denyenv-tls-secret -o jsonpath={.data.'tls\.key'} | base64 -d > tls.key

install-outcluster:
	./hack/gencert.sh
	@CA=$$(cat ./tls.crt | base64) && \
	sed -e "s/{{.LOCALIP}}/$$LOCALIP/g" -e "s/{{.CA}}/$$CA/g" ./manifests/outcluster-webhook-configuration.yaml | kubectl apply -f -

clear-outcluster:
	kubectl delete -f ./manifests/outcluster-webhook-configuration.yaml

setup-kube-for-outcluster-cm: SHELL:=/bin/bash
setup-kube-for-outcluster-cm:
	# ./manifests/cert-manager-1.5.3.yaml was ported from https://github.com/jetstack/cert-manager/releases/download/v1.5.3/cert-manager.yaml
	kubectl apply -f ./manifests/cert-manager-1.5.3.yaml
	# loop until cert-manager pod ready
	for i in {1..30}; do kubectl apply -f ./manifests/k-cert-manager.yaml; if [ $$? -eq 0 ]; then break; else sleep 6; fi; done;
	kubectl apply -f ./manifests/outcluster-webhook-configuration.yaml
	make save-cert

clear-kube-for-outcluster-cm:
	kubectl delete -f ./manifests/outcluster-webhook-configuration.yaml
	kubectl delete -f ./manifests/cert-manager-1.5.3.yaml
	kubectl delete -f ./manifests/k-cert-manager.yaml
