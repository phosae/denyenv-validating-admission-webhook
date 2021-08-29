TAG = zengxu/denyenv-validating-admission-webhook:v0

linux:
	GOARCH=amd64 GOOS=linux go build -o ./bin/denyenv-validating-admission-webhook
	docker image rm $(TAG)
	docker build -t $(TAG) .

load:
	kind load docker-image $(TAG)

cert:
	sh ./webhook-create-signed-cert.sh --service denyenv --namespace default --secret denyenv-tls-secret

deploy:
	sh ./set-kube-ca.sh &
	make cert
	kubectl apply -f ./k.yaml

clear:
	kubectl delete secret denyenv-tls-secret
	kubectl delete -f ./k.yaml

deploy-cm: SHELL:=/bin/bash
deploy-cm:
	# ./cert-manager-1.5.3.yaml was ported from https://github.com/jetstack/cert-manager/releases/download/v1.5.3/cert-manager.yaml
	kubectl apply -f ./cert-manager-1.5.3.yaml
	# loop until cert-manager pod ready
	for i in {1..30}; do kubectl apply -f ./k-cert-manager.yaml; if [ $$? -eq 0 ]; then break; else sleep 6; fi; done;
	kubectl apply -f ./k.yaml

clear-cm:
	kubectl delete -f ./k.yaml &
	kubectl delete -f ./cert-manager-1.5.3.yaml &
	kubectl delete -f ./k-cert-manager.yaml