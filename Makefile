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