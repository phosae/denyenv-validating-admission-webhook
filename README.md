# Write, Deploy and Test Kubernetes Validating Admission Webhooks

Most of the code in main.go was porting from Kelsey's [denyenv](https://github.com/kelseyhightower/denyenv-validating-admission-webhook) repository.
Kelsey's idea is a fantastic way to demonstrate how Admission Webhook works in Kubernetes: If a new Pod contains any ENV variable, it is denied, and an error message is returned. Otherwise, it is accepted.

I've rewrote the HTTP server in Go and  transitioned the deployment method from a Google Cloud Platform function to a Kubernetes Deployment and Service.

Since the Kubernetes apiServer only accepts HTTPS webhooks, I utilized OpenSSL to generate a server CertSignRequest and private key. Subsequently, I used the Kubernetes CertificateSigningRequest feature to sign our server certificate.

As [cert-manager](https://github.com/jetstack/cert-manager) is popular for TLS certificate management in Kubernetes, I have also provided a cert-manager version for deployment.

Additionally, for those interested in local debugging, a method for generating a TLS certificate for your local machine is available.

## Installing tools
You must install [CFSSL](https://github.com/cloudflare/cfssl) for signing CA and issuing a certificate.

```bash
# golang 1.18+ way
go install github.com/cloudflare/cfssl/cmd/...@latest

# Ubuntu
sudo apt-get install -y golang-cfssl
```
##  Write, Deploy and Test

You can modify the code in main.go, or add additional go codes to meet your custom needs.

For deploying and testing the server in a Kubernetes environment, [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/) is an excellent choice.

```bash
kind create cluster --config -<<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    image: kindest/node:v1.26.3
  - role: worker
    image: kindest/node:v1.26.3
  - role: worker
    image: kindest/node:v1.26.3
networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
EOF
```

Quick Start:
- `make build-load`: build Docker image and load it to Kind cluster
- `make deploy`: apply all Yaml manifest (webhook server Deployment/Service, and the ValidatingWebhookConfiguration) to Kind cluster.
- `make clear`: clear manifests

Since the server's image has been pushed to my public Docker repository, you can apply the `make deploy` command to any Kubernetes cluster and experience the magic in just a few seconds.

If you prefer to use cert-manager for TLS certificate management, you can use the `make deploy-cm` command to apply all the necessary YAML manifests to the Kind cluster. You can also use the `make clear-cm` command to clear them.

## local debug or out cluster deploy
If your want to set up the server out of cluster, for testing, debugging, or other purposes, just

```bash
LOCALIP=100.100.32.64 make install-outcluster && CERT_DIR=. go run main.go
```
Please note that you should replace `100.100.32.64` with the IP address of your machine that is reachable from the K8s Cluster(usualy eth0, en0...)

Also, If you prefer to use cert-manager for TLS certificate management, use make deploy-cm to apply all Yaml manifest to Kind cluster, use make clear-cm to clear.

## some other place help you learn Kubernetes Admission Webhooks

- [Official Docs](https://kind.sigs.k8s.io/docs/user/quick-start/) really helps.
- [Kubernetes e2e test webhook server](https://github.com/kubernetes/kubernetes/tree/fcdd6d82257f108bdf631ec1daa8cfcd6553b5ad/test/images/agnhost/webhook) have many basic implementations.
- [Kubernetes e2e test webhook deployment](https://github.com/kubernetes/kubernetes/blob/e8462b5b5dc2584fdcd18e6bcfe9f1e4d970a529/test/e2e/apimachinery/webhook.go#L301) may also help to understand the elements for deploying a webhook server. 
