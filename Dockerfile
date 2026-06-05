# syntax=docker/dockerfile:1.7
# Playwright container image using pnpm on debian:stable-slim

# ===========================================
# Base stage - pnpm on debian:stable-slim with Playwright
# ===========================================
FROM ghcr.io/pnpm/pnpm:11 AS base

# Install the specified version of a node runtime globally
# so the node binary is discoverable on PATH in subsequent layers and at runtime.
RUN pnpm runtime set node 24 --global

# Install Playwright using full SHA Hash for playwright@1.60
RUN pnpm add --global @playwright/test#87bb9ddbd78f329df18c2b24847bc9409240cd07

# Install browsers and dependencies
RUN pnpm exec playwright install --with-deps

# ===========================================
# Playwright config & tests stage
# ===========================================
FROM base AS playwright-code

WORKDIR /app

# Copy Playwright config
COPY playwright.config.ts ./

# Create tests folder
RUN mkdir /app/tests

# Ensure correct file permissions are set
RUN chmod 750 /app/tests/playwright

# Copy Playwright tests
COPY tests/playwright /app/tests/playwright

# ===========================================
# Runtime stage - Final production image
# ===========================================
FROM base AS runtime

WORKDIR /app

# Copy built application from build stage with appropriate ownership
COPY --chown=www-data:www-data --from=playwright-code /app /app

# Switch to non-root user for runtime
USER www-data

# Environment variables
ENV BASE_URL='http://localhost'

# Run Playwright tests with HTML reporter
CMD ["pnpm", "exec", "playwright", "test", "--reporter=html"]