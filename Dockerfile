FROM ubuntu:24.04 AS common

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    lsb-release \
    apt-transport-https \
    unzip \
    gnupg2 \
    rsync \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Docker CLI
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
RUN echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" >> /etc/apt/sources.list.d/docker.list
RUN apt-get update && apt-get install -y --no-install-recommends docker-ce-cli docker-buildx-plugin && rm -rf /var/lib/apt/lists/*

# Chrome deps
RUN curl -fsSL https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
RUN echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list
RUN apt-get update && apt-get install -y --no-install-recommends $(apt-cache depends google-chrome-stable | grep Depends | sed -e "s/.*ends:\ //" -e 's/<[^>]*>//') libxss1 libxtst6 libx11-xcb1 && rm -rf /var/lib/apt/lists/*

# .NET
RUN apt-get update && apt-get install -y --no-install-recommends \
    libc6 \
    libgcc-s1 \
    libicu74 \
    libssl3t64 \
    libstdc++6 \
    tzdata \
    tzdata-legacy \
    zlib1g \
    && rm -rf /var/lib/apt/lists/*
RUN curl -L https://dot.net/v1/dotnet-install.sh -o /dotnet-install.sh && chmod +x /dotnet-install.sh
RUN /dotnet-install.sh --channel 8.0
RUN /root/.dotnet/dotnet tool install -g trx2junit

COPY global.json /global.json

ENV PATH "$PATH:/root/.dotnet:/root/.dotnet/tools"
ENV DOTNET_ROOT "/root/.dotnet"
    
# Helm    
RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && chmod 700 get_helm.sh
RUN ./get_helm.sh
    
# Kubectl
RUN curl -LO https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl \
    && chmod +x ./kubectl \
    && mv ./kubectl /usr/local/bin/kubectl

FROM common AS wasm
# wasm-tool
RUN apt-get update && apt-get install -y --no-install-recommends python3 && rm -rf /var/lib/apt/lists/*
RUN dotnet workload install wasm-tools
