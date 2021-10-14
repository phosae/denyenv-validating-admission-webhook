# Write, Deploy and Test Kubernetes Validating Admission Webhooks

Most of the code in main.go was porting from Kelsey's [denyenv](https://github.com/kelseyhightower/denyenv-validating-admission-webhook).
Kelsey's idea is wonderful to demonstrate how admission webhooks in kubernetes: If the new coming Pod contains any ENV variable, deny it and return error message, otherwise accept it.

I rewrite it as Go HTTP server, change the gcloud function deployment way to Kubernetes Deployment and Service.

As Kubernetes apiServer only accept webhooks in HTTPS, I use openssl to generate server CertSignRequest and private key, then leverage Kubernetes CertificateSigningRequest to sign our server certificate.

As [cert-manager](https://github.com/jetstack/cert-manager) is also a popular choice for TLS certificate management, I also offer a cert-manager version for deployment.

##  Write, Deploy and Test

You can change the code in main.go, or add some go codes, to accomplish you custom needs.

To deploy and test server in Kubernetes, [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/) is a good choice.
Use `make linux && make load` to build Docker image and load it to Kind cluster, use `make deploy` to apply all Yaml manifest to Kind cluster.
Finally, use `make clear` to do clearing job.

As the image of this server have being push to my docker public repository, you can apply `make deploy` to any Kubernetes cluster, Feeling the magic in several minutes.

If you prefer to use cert-manager for  TLS certificate management,  use `make deploy-cm` to apply all Yaml manifest to Kind cluster,
use `make clear-cm` to clear.

## local debug or out cluster deploy
If your want to set up server out of cluster, for testing/debug, or other purpose, specific your machine ip address in `webhook-create-signed-cert.sh`(kube-signed-cert), or `k-cert-manager.yaml`(cert-manager).

For kube-signed-cert, use `make setup-kube-for-outcluster` to set up kubernetes environment, use `make clear-kube-for-outcluster` to clear.
For cert-manager way, use `make setup-kube-for-outcluster-cm` to set up kubernetes environment, use `make clear-kube-for-outcluster-cm` to clear.

Most importantly, use `make save-cert` to get the TLS cert/key, put it in some directory your want, finally start the server with CERT_DIR environment variable. 

## some other place help you learn Kubernetes Admission Webhooks

- [Official Docs](https://kind.sigs.k8s.io/docs/user/quick-start/) really helps.
- [Kubernetes e2e test webhook server](https://github.com/kubernetes/kubernetes/tree/fcdd6d82257f108bdf631ec1daa8cfcd6553b5ad/test/images/agnhost/webhook) have many basic implementations.
- [Kubernetes e2e test webhook deployment](https://github.com/kubernetes/kubernetes/blob/e8462b5b5dc2584fdcd18e6bcfe9f1e4d970a529/test/e2e/apimachinery/webhook.go#L301) may also help to understand the elements for deploying a webhook server. 