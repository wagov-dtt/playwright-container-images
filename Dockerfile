# syntax=docker/dockerfile:1.7
# Playwright container image using pnpm on debian:stable-slim

# ===========================================
# Base stage - node:24.16.0-trixie
# ===========================================
FROM node:24.16.0-trixie AS base

# Patch OS and install common packages
RUN rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        git \
        zip \
        unzip \
        curl \
        ca-certificates \
        wget \
    && apt-get upgrade -yq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2 - required by entrypoint.sh to upload reports to S3
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws

# ===========================================
# Pnpm - installation
# ===========================================
FROM base AS pnpm

WORKDIR /app

# Prevent Corepack from prompting for network downloads
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0

# Redirect Corepack to a writeable directory to avoid permission/read-only errors
ENV COREPACK_HOME="/tmp/corepack"

# Install pnpm
RUN corepack enable pnpm

# ===========================================
# Playwright - installation
# ===========================================
FROM pnpm AS playwright

WORKDIR /app

# Set a global path for Playwright browsers
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers

# Copy package.json required to install Playwright
COPY config/package.json .
COPY config/pnpm-lock.yaml .

# Copy entrypoint.sh required for running playwright in runtime
COPY config/entrypoint.sh .

# Ensure correct file permissions are set
RUN chmod +x /app/entrypoint.sh

# Install Playwright defined in package.json
RUN pnpm install --frozen-lockfile

# Install browsers and dependencies
RUN pnpm exec playwright install --with-deps

# Grant permissions to Playwright browsers binaries
# Switching to a non-root user later on
RUN chmod -R 755 /opt/playwright-browsers

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

ENTRYPOINT ["/app/entrypoint.sh"]