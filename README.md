# Write, Deploy and Test Kubernetes Validating Admission Webhooks

Most of the code in main.go was porting from Kelsey's [denyenv](https://github.com/kelseyhightower/denyenv-validating-admission-webhook).
Kelsey's idea is wonderful to demonstrate how admission webhooks in kubernetes: If the new coming Pod contains any ENV variable, deny it and return error message, otherwise accept it.

I rewrite it as Go HTTP server, change the gcloud function deployment way to Kubernetes Deployment and Service.

As Kubernetes apiServer only accept webhooks in HTTPS, I use openssl to generate server CertSignRequest and private key, then leverage Kubernetes CertificateSigningRequest to sign our server certificate.

##  Write, Deploy and Test

You can change the code in main.go, or add some go codes, to accomplish you custom needs.

To deploy and test server in Kubernetes, [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/) is a good choice.
Use `make linux && make load` to build Docker image and load it to Kind cluster, use `make deploy` to apply all Yaml manifest to Kind cluster.
Finally, user `make clear` to do clearing job.

As the image of this server have being push to my docker public repository, you can apply `make deploy` to any Kubernetes cluster, Feeling the magic in several minutes.

## some other place help you learn Kubernetes Admission Webhooks

- [Official Docs](https://kind.sigs.k8s.io/docs/user/quick-start/) really helps.
- [Kubernetes e2e test webhook server](https://github.com/kubernetes/kubernetes/tree/fcdd6d82257f108bdf631ec1daa8cfcd6553b5ad/test/images/agnhost/webhook) have many basic implementations.
- [Kubernetes e2e test webhook deployment](https://github.com/kubernetes/kubernetes/blob/e8462b5b5dc2584fdcd18e6bcfe9f1e4d970a529/test/e2e/apimachinery/webhook.go#L301) may also help to understand the elements for deploying a webhook server. 