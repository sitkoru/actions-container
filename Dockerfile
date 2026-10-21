ARG DOTNET_SDK_IMAGE=mcr.microsoft.com/dotnet/sdk:10.0-noble
ARG DOCKER_VERSION=29.5.0
ARG BUILDX_VERSION=0.34.0

FROM docker:${DOCKER_VERSION}-cli AS docker-cli
FROM docker/buildx-bin:${BUILDX_VERSION} AS buildx

FROM ${DOTNET_SDK_IMAGE} AS common

ARG DOTNET_8_SDK_VERSION=8.0.426
ARG NBGV_VERSION=3.10.94
ARG HELM_VERSION=3.21.0
ARG KUBECTL_VERSION=1.37.1
ARG TARGETARCH

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git unzip rsync openssh-client \
    && rm -rf /var/lib/apt/lists/*

COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=buildx /buildx /usr/local/lib/docker/cli-plugins/docker-buildx

# Сохраняем хост SDK 10 при добавлении SDK 8 в общий каталог.
RUN curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh \
    && bash /tmp/dotnet-install.sh --version "${DOTNET_8_SDK_VERSION}" \
        --install-dir /usr/share/dotnet --skip-non-versioned-files \
    && rm /tmp/dotnet-install.sh \
    && dotnet tool install nbgv --version "${NBGV_VERSION}" --tool-path /usr/local/bin \
    && rm -rf /root/.nuget/packages /root/.local/share/NuGet/http-cache

RUN curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" -o /tmp/helm.tar.gz \
    && curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz.sha256sum" -o /tmp/helm.sha256sum \
    && cd /tmp \
    && echo "$(cut -d ' ' -f 1 helm.sha256sum)  helm.tar.gz" | sha256sum --check \
    && tar -xzf helm.tar.gz "linux-${TARGETARCH}/helm" \
    && mv "linux-${TARGETARCH}/helm" /usr/local/bin/helm \
    && rm -rf helm.tar.gz helm.sha256sum "linux-${TARGETARCH}"

RUN curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" -o /tmp/kubectl \
    && curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl.sha256" -o /tmp/kubectl.sha256 \
    && cd /tmp \
    && echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check \
    && install -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl kubectl.sha256

COPY global.json /global.json

FROM common AS wasm
RUN apt-get update && apt-get install -y --no-install-recommends python3 && rm -rf /var/lib/apt/lists/*
RUN mkdir /tmp/wasm-sdk \
    && cd /tmp/wasm-sdk \
    && for sdk in "${DOTNET_8_SDK_VERSION}" "${DOTNET_SDK_VERSION}"; do \
        printf '{"sdk":{"version":"%s","rollForward":"disable"}}\n' "$sdk" > global.json; \
        dotnet workload install wasm-tools --skip-manifest-update || exit 1; \
    done \
    && cd / \
    && rm -rf /tmp/wasm-sdk \
    && dotnet nuget locals all --clear
