FROM --platform=$BUILDPLATFORM golang:1.18-bullseye as builder
ARG TARGETOS TARGETARCH
WORKDIR /workspace

ENV GOPROXY=https://goproxy.cn,direct

COPY go.mod go.mod
COPY go.sum go.sum
COPY main.go main.go

RUN --mount=type=cache,target=/go/pkg/mod \
  --mount=type=cache,target=/root/.cache/go-build go mod download

RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -a -o webhook-$TARGETARCH main.go


FROM ubuntu:18.04
ARG TARGETARCH
COPY --from=builder /workspace/webhook-$TARGETARCH /denyenv-validating-admission-webhook
ENTRYPOINT ["/denyenv-validating-admission-webhook"]