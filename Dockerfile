# syntax=docker/dockerfile:1.7
# Playwright container image using pnpm on debian:stable-slim

# ===========================================
# Base stage - pnpm on debian:stable-slim with Playwright
# ===========================================
FROM ghcr.io/pnpm/pnpm:11 AS base

WORKDIR /app

# Use hermetic install to place browsers binaries to node_modules/playwright-core/.local-browsers
# @see https://playwright.dev/docs/browsers#hermetic-install
ENV PLAYWRIGHT_BROWSERS_PATH=0

# Install the specified version of a node runtime globally
# so the node binary is discoverable on PATH in subsequent layers and at runtime.
RUN pnpm runtime set node 24 --global

# Copy package.json required to install Playwright
COPY config/package.json .
COPY config/pnpm-lock.yaml .

# Install Playwright defined in package.json
RUN pnpm install --frozen-lockfile

# Install browsers and dependencies
RUN pnpm exec playwright install --with-deps

# ===========================================
# Playwright config & tests stage
# ===========================================
FROM base AS playwright-code

WORKDIR /app

# Copy Playwright config
COPY code/playwright.config.ts .

# Copy Playwright tests
COPY code/tests/playwright tests/playwright

# Ensure correct file permissions are set
RUN chmod 770 /app/tests
RUN chmod 770 /app/tests/playwright

# ===========================================
# Runtime stage - Final production image
# ===========================================
FROM base AS runtime

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

# Run Playwright tests with HTML reporter
CMD ["pnpm", "exec", "playwright", "test", "--reporter=html"]
