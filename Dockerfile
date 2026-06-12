# syntax=docker/dockerfile:1.7
# Playwright container image using pnpm on debian:stable-slim

# ===========================================
# Base stage - node:24.16.0-trixie
# ===========================================
FROM node:24.16.0-trixie AS base

# Patch OS and install common packages
# The following package are required by pnpm: curl, libatomic1
RUN rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl \
        wget \
        libatomic1 \
        git \
        zip \
        unzip \
        ca-certificates \
        default-mysql-client \
    && apt-get upgrade -yq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ===========================================
# Pnpm + node - installation
# ===========================================
FROM base AS pnpm

WORKDIR /app

# Set pnpm environment variables
ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

# Prevent Corepack from prompting for network downloads
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0

# Redirect Corepack to a writeable directory to avoid permission/read-only errors
ENV COREPACK_HOME="/tmp/corepack"

RUN corepack enable pnpm
# RUN corepack use pnpm@11.6.0
# RUN corepack install

# Explicitly define the shell for pnpm to prevent inference errors
# Required by pnpm installation
# ENV SHELL="/bin/sh"

# Switch the default shell to bash and run as a login shell
# SHELL ["/bin/bash", "--login", "-c"]

# ENV PNPM_HOME="/pnpm"
# ENV PATH="$PNPM_HOME:$PATH"

# Install pnpm
# RUN wget -qO- https://get.pnpm.io/install.sh | ENV="$HOME/.shrc" SHELL="$(which sh)" PNPM_VERSION=11.6.0 sh -
# RUN curl -fsSL https://get.pnpm.io/install.sh | env PNPM_VERSION=11.6.0 sh -

# RUN . "/$HOME/.shrc"

# RUN echo "$PATH"

# Start using pnpm
# RUN source /root/.bashrc

# Install the specified version of a node runtime globally
# Making the node binary discoverable on PATH in subsequent layers and at runtime
# RUN pnpm runtime set node 24 --global

# ===========================================
# Playwright - installation
# ===========================================
FROM pnpm AS playwright

WORKDIR /app

# Use hermetic install to place browsers binaries to node_modules/playwright-core/.local-browsers
# @see https://playwright.dev/docs/browsers#hermetic-install
ENV PLAYWRIGHT_BROWSERS_PATH=0

# Copy package.json required to install Playwright
COPY config/package.json .
COPY config/pnpm-lock.yaml .

# Install Playwright defined in package.json
RUN pnpm install --frozen-lockfile

# Install browsers and dependencies
RUN pnpm exec playwright install --with-deps

# ===========================================
# Playwright - Config & tests stage
# ===========================================
FROM playwright AS playwright-code

WORKDIR /app

# Copy Playwright config
COPY code/playwright.config.ts .

# Copy Playwright tests
COPY code/tests/playwright tests/playwright

# Ensure correct file permissions are set
RUN chmod 770 /app/tests
RUN chmod 770 /app/tests/playwright

# ===========================================
# Runtime stage - final production image
# ===========================================
FROM playwright AS runtime

WORKDIR /app

# Copy built application from playwright-code stage with appropriate ownership
COPY --chown=www-data:www-data --from=playwright-code /app /app

# Correct the /app folder ownership
RUN chown www-data:www-data /app

# Switch to non-root user for runtime
USER www-data

# Environment variables
ENV CI=true \
    BASE_URL='http://localhost'

# Basic healthcheck on Playwright command line
HEALTHCHECK --start-period=20s --interval=30s --timeout=5s --retries=3 \
    CMD pnpm exec playwright --version || exit 1

# Run Playwright tests with HTML reporter
CMD ["pnpm", "exec", "playwright", "test", "--project=website-user-tests", "--reporter=html,list"]