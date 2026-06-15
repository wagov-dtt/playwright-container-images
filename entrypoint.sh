#!/bin/bash
set -euo pipefail

TEST_EXIT_CODE=0

PLAYWRIGHT_ARGS=()
if [ -n "${TEST_TAGS:-}" ]; then
    GREP_PATTERN=$(echo "$TEST_TAGS" | sed 's/ /|/g')
    PLAYWRIGHT_ARGS+=("--grep" "$GREP_PATTERN")
fi

pnpm exec playwright test --reporter=html,list "${PLAYWRIGHT_ARGS[@]}" || TEST_EXIT_CODE=$?

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
S3_PREFIX="reports/${ENV_NAME}/${TIMESTAMP}"

aws s3 cp playwright-report/ "s3://${REPORTS_BUCKET}/${S3_PREFIX}/html/" --recursive || true
aws s3 cp results.xml "s3://${REPORTS_BUCKET}/${S3_PREFIX}/results.xml" || true

echo "Reports uploaded to: s3://${REPORTS_BUCKET}/${S3_PREFIX}/"

exit ${TEST_EXIT_CODE}
