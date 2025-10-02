FROM mcr.microsoft.com/devcontainers/base:noble

ARG DEBIAN_FRONTEND=noninteractive
ARG USER="root"
ARG HOME="/home/${USER}"

# Install essential packages for Python/FastAPI development
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    libffi-dev \
    libsqlite3-dev \
    libssl-dev \
    zlib1g-dev \
    jq \
    yq \
    # *** Add additional linux packages here ***
    && rm -rf /var/lib/apt/lists/*

# Install Google Cloud SDK (commented out - uncomment if needed)
# RUN apt-get update && apt-get install -y apt-transport-https ca-certificates gnupg \
#     && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
#     && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - \
#     && apt-get update && apt-get install -y google-cloud-sdk

# Set working directory
WORKDIR /workspace

# Set environment variables
ENV PATH="${HOME}/.local/bin:$PATH"

# Install UV package manager and ruff
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && uv tool install ruff
