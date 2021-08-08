FROM alpine:3.14

COPY ./bin/denyenv-validating-admission-webhook .

CMD ["./denyenv-validating-admission-webhook"]