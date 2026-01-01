FROM alpine:3.20

ARG KUBECTL_VERSION=v1.30.4
ARG HELM_VERSION=v3.15.4
ARG KIND_VERSION=v0.24.0

RUN apk add --no-cache \
    bash curl ca-certificates git jq openssl docker-cli coreutils \
 && update-ca-certificates

# kubectl
RUN curl -fsSL -o /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
 && chmod +x /usr/local/bin/kubectl

# helm
RUN curl -fsSL -o /tmp/helm.tar.gz \
      "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" \
 && tar -xzf /tmp/helm.tar.gz -C /tmp \
 && mv /tmp/linux-amd64/helm /usr/local/bin/helm \
 && chmod +x /usr/local/bin/helm \
 && rm -rf /tmp/helm.tar.gz /tmp/linux-amd64

# kind
RUN curl -fsSL -o /usr/local/bin/kind \
      "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64" \
 && chmod +x /usr/local/bin/kind

ENV PATH="/usr/local/bin:${PATH}"
