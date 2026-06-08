# Contributing

Development guide for working on this repository.

## Setup

1. Install [mise](https://mise.jdx.dev/)
2. Run setup:
   ```bash
   just setup
   ```

Tools are separated by environment:

| Environment                 | Tools                                 |
| --------------------------- | ------------------------------------- |
| **Base** (all)              | none                                  |
| **Dev** (`mise.dev.toml`)   | gh, gitleaks, pnpm, pre-commit, trivy |
| **Prod** (`mise.prod.toml`) | (none)                                |

CI/CD uses `just install-prod` for production builds.

## Architecture

### Build System

- **Dockerfile** - Multi-stage build with [ghcr.io/pnpm/pnpm](ghcr.io/pnpm/pnpm) base (on top of `debian:stable-slim`)
- **docker-bake.hcl** - Build configurations for different targets
- **justfile** - Command orchestration

### Dockerfile Stages

1. `base` - pnpm + Playwright + config files
2. `playwright-code` - Copy Playwright tests + config
3. `runtime` - Final production image

### Key Files

| File                      | Purpose                          |
| ------------------------- | -------------------------------- |
| `Dockerfile`              | Multi-stage container build      |
| `docker-bake.hcl`         | Build targets and caching        |
| `package.json`            | Playwright defined as dependency |
| `test/docker-compose.yml` | Local testing                    |

## Commands

```bash
just --list          # Show all commands
just validate        # Run all validations
just scan            # Security scan with trivy + gitleaks
just build [repo] [tag] # Build an image
just test [repo] [tag]  # Test an image
```

## Development Workflow

1. Make changes
2. Run `just validate` to check justfile, mise
3. Run `just scan` for security issues
4. Build with `just build [repo] [tag]`
5. Test with `just test [repo] [tag]`
6. Commit (pre-commit hooks run automatically)

## Code Style

- Pre-commit hooks enforce:
  - Secret detection (gitleaks)
  - Vulnerability scanning (trivy)

## CI/CD

- GitHub Actions for automated builds
- Build targets defined in `docker-bake.hcl`:
  - `test` - Local development
  - `build-test` - Test build
  - `release` - Production release

## Testing

The test setup uses docker-compose:

```bash
just build myorg/myapp test
just test myorg/myapp test
```

Environment is configured via `test/docker-compose.yml`.
