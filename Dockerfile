FROM ubuntu:20.04 as common

ARG DEBIAN_FRONTEND=noninteractive
ARG GITHUB_CLI_VERSION=2.42.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    apt-utils \
    software-properties-common \
    apt-transport-https \
    unzip \
    gnupg2 \
    # .NET dependencies
    libc6 \
    libgcc1 \
    libgssapi-krb5-2 \
    libicu66 \
    libssl1.1 \
    libstdc++6 \
    zlib1g \
    liblttng-ust-ctl4 \
    rsync \
    openssh-client \
    sudo \
    python3 \
    cmake \
    xz-utils \
    lbzip2 \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - \
    && curl -fsSL https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    && add-apt-repository "deb [arch=amd64] http://dl.google.com/linux/chrome/deb stable main" \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-buildx-plugin $(apt-cache depends google-chrome-stable | grep Depends | sed -e "s/.*ends:\ //" -e 's/<[^>]*>//') libxss1 libxtst6 libx11-xcb1 \
    # .NET
    && curl -L https://dot.net/v1/dotnet-install.sh -o /dotnet-install.sh \
    && chmod +x /dotnet-install.sh \
    && /dotnet-install.sh --channel 6.0 \
    && /dotnet-install.sh --channel 7.0 \
    && /dotnet-install.sh --channel 8.0 \
    && dotnet tool install -g trx2junit \
    && PATH="$PATH:/root/.dotnet:/root/.dotnet/tools" \
    # GitHub Cli
    && curl -L https://github.com/cli/cli/releases/download/v${GITHUB_CLI_VERSION}/gh_${GITHUB_CLI_VERSION}_linux_amd64.deb -o /tmp/gh_${GITHUB_CLI_VERSION}_linux_amd64.deb \
    && dpkg -i /tmp/gh_${GITHUB_CLI_VERSION}_linux_amd64.deb \
    # Helm    
    && curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    && chmod 700 get_helm.sh \
    && ./get_helm.sh \
    # Kubectl
    && curl -LO https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl \
    && chmod +x ./kubectl \
    && sudo mv ./kubectl /usr/local/bin/kubectl \
    # Cleanup
    && rm -rf /var/lib/apt/lists/*

COPY global.json /global.json

ENV PATH "$PATH:/root/.dotnet"

FROM common as wasm
# Emscripten
RUN mkdir /ems \
    && cd /ems \
    && git clone https://github.com/emscripten-core/emsdk.git \
    && cd /ems/emsdk \
    && ./emsdk install latest \
    && ./emsdk activate latest \
    && dotnet workload install wasm-tools \
