# Playwright Container Images

Building process for **production-ready** [Playwright](https://playwright.dev/) container images to run Playwright tests.

For development/contributing to this repository, see [CONTRIBUTING.md](./CONTRIBUTING.md).

## Quick Start

```bash
just build [repository] [tag]

# Using named parameters.
just build --repository=[repository] --tag=[tag]

# Example.
just build wagov-dtt/myapp v1.0.0

# Example with named parameters
just build --repository="wagov-dtt/myapp" --tag="v1.0.0"
```

## Requirements

- [Docker](https://docs.docker.com/get-docker/) with BuildKit
- [just](https://just.systems/) command runner
- [mise](https://mise.jdx.dev/) (optional, for dev tools)

## Commands

| Command                   | Description                          |
| ------------------------- | ------------------------------------ |
| `just build [repo] [tag]` | Build container image for an app     |
| `just scan`               | Security scan with Trivy + gitleaks  |
| `just scan-image`         | Security scanning of container image |
| `just test [repo] [tag]`  | Test image with docker-compose       |
| `just validate`           | Run lint and format checks           |
| `just clean`              | Remove build artifacts and images    |
| `just --list`             | Show all available commands          |

## Usage

The standard command we want to run at this stage is:

```bash
playwright test --project=website-user-tests --reporter=html,list
```

## Actions

### Scan container image for vulnerabilities

To scan the built container image with [Trivy](https://trivy.dev/) (security scanner) run either:

- `just scan-image --repository="[repository]" --tag="[tag]"`
- `trivy image [image-identifier]`

Examples:

- `just scan-image --repository="some/drupal-application" --tag="v1.0.0"`
- `trivy image docker.io/some/drupal-application:v1.0.0`

The repository contains **Trivy config file**: `trivy.yaml` that is automatically picked up by the `trivy` command mentioned above (when run from root folder of this repository). The configuration includes instructions like `ignore-unfixed: true` (show only vulnerabilities with fixes available).

## Configuration

### Environment Variables

| Variable     | Default            | Description                                                                                         |
| ------------ | ------------------ | --------------------------------------------------------------------------------------------------- |
| `CI`         | `true`             | CI environment indication (used by Playwright configuration).                                       |
| `BASE_URL`   | `http://localhost` | URL of the website to be tested.                                                                    |
| `PW_WORKERS` | 6                  | The maximum number of concurrent worker processes to use for parallelizing tests (when CI enabled). |
| `TEST_TAGS`  | `undefined`        | Tests tagged by usage of `playwright test --grep $TEST_TAGS`                                        |
| `ENV_NAME`   | `undefined`        | Environment name for S3 storage of test report.                                                     |

## Testing Locally

```bash
just build myorg/myapp main
just test myorg/myapp main
```

## Security

See [SECURITY.md](./SECURITY.md) for vulnerability reporting guidance.

## License

**Apache License 2.0** - See [LICENSE](./LICENSE)
