# Playwright container images - Build & Development.

set dotenv-load := true
set shell := ["bash", "-lc"]
set ignore-comments := true

playwright := "playwright"
app_dir := "app"
repository_default := ''
tag_default := ''
code_dir := "code"
config_dir := "config"
tmp_dir := "tmp"
build_target_default := 'release'
ghcr := "ghcr.io"
empty := ''
cicd := 'CICD'
local := 'local'
true := 'true'
false := 'false'
docker_compose_file := 'test/docker-compose.yml'

[doc('Show all available commands.')]
default:
    @just --list

[arg("env", long="env")]
[arg("push", long="push")]
[arg("repository", long="repository")]
[arg("tag", long="tag")]
[arg("target", long="target")]
[doc('Build Playwright container image.')]
[group('CI/CD')]
[group('local')]
build repository=repository_default tag=tag_default env=local target=build_target_default push=false: (copy repository tag env)
    @echo "🔨 Building image..."
    REPOSITORY={{ repository }} TAG={{ kebabcase(tag) }} docker buildx bake {{ target }} \
        --pull \
        --progress=plain \
        --set="{{ target }}.context={{ app_dir }}/{{ repository }}" \
        {{ if push != false { "--push" } else { "" } }}

[arg("env", long="env")]
[arg("repository", long="repository")]
[arg("tag", long="tag")]
[doc('Copy App codebase if not cached already.')]
[group('internal')]
copy repository=repository_default tag=tag_default env=local:
    @echo "❌ Removing app data, but only if present and the tag has changed..."
    @-tag_previous=$(head -n 1 "{{ app_dir }}/{{ repository }}/{{ config_dir }}/tag.txt") && \
        echo "Previous tag: '$tag_previous', new tag: '{{ tag }}'." && \
        [[ $tag_previous != "{{ tag }}" || "{{ tag }}" == "main" ]] && \
        rm --recursive --force -- {{ app_dir }}/{{ repository }}
    @echo "📁 Preparing directories..."
    @-mkdir --parents {{ app_dir }}/{{ repository }}
    @-mkdir --parents {{ app_dir }}/{{ repository }}/{{ config_dir }}
    @echo "📝 Writing down tag to file..."
    echo "{{ tag }}" > {{ app_dir }}/{{ repository }}/{{ config_dir }}/tag.txt
    @echo "📋 Copying app code..."
    @[ -d "{{ app_dir }}/{{ repository }}/{{ code_dir }}" ] || \
        ( \
            [ "{{ env }}" != "{{ local }}" ] && \
            just copy-cicd --repository={{ repository }} --tag={{ tag }} || \
            just copy-local --repository={{ repository }} --tag={{ tag }} \
        )
    @echo "📋 Copying package.json and pnpm-lock.yaml to app config..."
    cp package.json {{ app_dir }}/{{ repository }}/{{ config_dir }}
    cp pnpm-lock.yaml {{ app_dir }}/{{ repository }}/{{ config_dir }}
    @echo "📋 Copying Dockerfile to app code..."
    cp Dockerfile {{ app_dir }}/{{ repository }}/{{ code_dir }}

[arg("repository", long="repository")]
[arg("tag", long="tag")]
[doc('Copy App codebase using gh repo clone.')]
[group('internal')]
copy-cicd repository=repository_default tag=tag_default:
    @echo "📋 Copying app code with: gh repo clone..."
    gh repo clone {{ repository }} "{{ app_dir }}/{{ repository }}/{{ code_dir }}" -- \
        --no-depth \
        --branch {{ tag }}

[arg("repository", long="repository")]
[arg("tag", long="tag")]
[doc('Copy App codebase using git clone.')]
[group('internal')]
copy-local repository=repository_default tag=tag_default:
    @echo "📋 Copying app code with: git clone..."
    git clone \
        --no-depth \
        --branch {{ tag }} \
        git@github.com:{{ repository }}.git \
        "{{ app_dir }}/{{ repository }}/{{ code_dir }}"

[arg("repository", long="repository")]
[arg("tag", long="tag")]
[doc('Push Playwright container image to ECR.')]
[group('local')]
push-ecr repository=repository_default tag=tag_default: auth-ecr
    @echo "🚀 Publishing image to ECR..."
    docker image tag {{ repository }}:{{ tag }} $SSO_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:{{ tag }}
    docker image push $SSO_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:{{ tag }}
    # @echo "Signing with cosign..."
    # cosign sign --yes $SSO_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:{{ tag }}

[arg("repository", long="repository")]
[arg("tag", long="tag")]
[doc('Pull Playwright container image to ECR.')]
[group('local')]
pull-ecr repository=repository_default tag=tag_default: auth-ecr
    @echo "⬇️ Pulling image from ECR..."
    docker pull $SSO_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:{{ tag }}

[doc('Authenticate Docker client to the Amazon ECR registry.')]
[group('local')]
auth-ecr:
    # You have to run aws-sso-login first to authenticate with AWS.
    @echo "🔒 Authenticating with Amazon ECR..."
    # Before removing docker config file there was an error:
    # Error saving credentials: error storing credentials.
    # @see https://stackoverflow.com/questions/42787779/docker-login-error-storing-credentials-write-permissions-error
    docker logout
    aws ecr get-login-password --region $AWS_REGION --profile "$AWS_PROFILE" | docker login \
      --username AWS \
      --password-stdin $SSO_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com

[doc('Login to AWS while creating AWS SSO login profile.')]
[group('local')]
aws-sso-login:
    @echo "🔒 Logging in with AWS SSO..."
    # You have to configure required environment variables first.
    # Copy .env.example file to .env and fill in values.
    aws sts get-caller-identity --profile "$AWS_PROFILE" > /dev/null 2>&1 \
        && echo "Profile '$AWS_PROFILE' is active." \
        || (echo "Configuring AWS profile '$AWS_PROFILE' " && \
        echo -e "$SSO_SESSION\n$SSO_START_URL\n$SSO_REGION\n$SSO_REGISTRATION_SCOPE" | aws configure sso-session && \
        aws configure set sso_session "$SSO_SESSION" --profile "$AWS_PROFILE" && \
        aws configure set sso_account_id "$SSO_ACCOUNT" --profile "$AWS_PROFILE" && \
        aws configure set sso_role_name "$SSO_ROLE" --profile "$AWS_PROFILE" && \
        aws configure set region "$AWS_REGION" --profile "$AWS_PROFILE" && \
        aws configure set output json --profile "$AWS_PROFILE" && \
        echo "Done configuring profile '$AWS_PROFILE'." && \
        aws sso login --use-device-code --profile "$AWS_PROFILE")

[doc('Logout from AWS SSO login profile.')]
[group('local')]
aws-sso-logout:
    @echo "🔒 Logging out of AWS SSO..."
    aws sso logout --profile "$AWS_PROFILE"

[doc('Setup tools.')]
[group('local')]
setup: install-dev
    @echo "🧰 Setting up Tools..."
    # Installation alone does not activated the tools in this just recipe sessions.
    # To activate the newly installed Tools, `just setup` has to be run first as a workaround.
    pre-commit install

[doc('Install PROD Tools with Mise.')]
[group('CI/CD')]
install-prod:
    @echo "🧰 Installing PROD Tools..."
    mise install --env prod

[doc('Install DEV Tools with Mise.')]
[group('local')]
install-dev:
    @echo "🧰 Installing DEV Tools..."
    mise install --env dev

[doc('Clean up coppied codebases and built images.')]
[group('local')]
clean:
    @echo "🧹 Cleaning up..."
    # Remove containers.
    # Check first if there are any app subdirectories.
    @-find "{{ app_dir }}"/*/ -maxdepth 0 -empty -type d && \
        for entry in "{{ app_dir }}"/*/; do docker container remove --force `basename "$entry"`; done
    # Remove images.
    # Check first if there are any app subdirectories.
    @-find "{{ app_dir }}"/*/ -maxdepth 0 -empty -type d && \
        for entry in "{{ app_dir }}"/*/; do docker image rm --force `basename "$entry"`; done
    # Remove unused Docker data.
    docker system prune -f
    # Remove all app artifacts (sub-direcitories) in app directory.
    rm --recursive --force -- {{ app_dir }}/*/

[doc('Run validations.')]
[group('local')]
validate:
    @echo "🔍 Validate justfile..."
    just --fmt --check --unstable
    @echo "🔍 Validate Caddyfile..."
    @echo "Run \`caddy fmt --help\` to understand the validation output and options."
    caddy fmt --diff conf/Caddyfile
    @echo "🔍 Validate mise..."
    mise doctor
    @echo "Run manually pre-commit hooks on all files."
    pre-commit run --all-files

# Authenticate docker with GHRC using $GITHUB_TOKEN from 1Password. The command should be run from outside of devcontainer on HOST.
auth-1password:
    @echo "🔒 Authenticating with GHCR using 1password..."
    op run --env-file=".env.local" --no-masking -- just auth-devcontainer

# Inject docker authentication into Dev Container.
auth-devcontainer:
    devcontainer exec \
      --workspace-folder . \
      --remote-env GITHUB_TOKEN=$GITHUB_TOKEN \
      --remote-env GITHUB_USER=$(gh api user --jq .login) \
      -- just auth

# Run in devcontainer with 1Password secrets.
devcontainer:
    op run --env-file=".env.local" -- devcontainer up

[arg("target", long="target")]
[doc('Security scan with Trivy.')]
[group('local')]
scan target=".":
    @echo "🛡️ Security scanning..."
    gitleaks git
    trivy repo --config trivy.yaml {{ target }}

[arg("repository", long="repository")]
[arg("tag", long="tag")]
scan-image repository=repository_default tag=tag_default:
    @echo "🛡️ Security scanning of container image..."
    trivy image docker.io/{{ repository }}:{{ tag }}

[arg("repository", long="repository")]
[arg("tag", long="tag")]
[doc('Test Playwright container image.')]
[group('local')]
test repository=repository_default tag=tag_default: (docker-compose-up repository tag)
    @echo "☑️ Testing container image..."

[arg("repository", long="repository")]
[arg("tag", long="tag")]
[doc('Clean Testing artifacts.')]
[group('local')]
test-clean repository=repository_default tag=tag_default: (docker-compose-down repository tag)
    @echo "❌ Cleaning test artifacts..."

[arg("repository", long="repository")]
[arg("tag", long="tag")]
[doc('Docker composer up.')]
[private]
docker-compose-up repository=repository_default tag=tag_default:
    @echo "🏃‍♂️ Docker compose up..."
    PLAYWRIGHT_IMAGE_NAME="{{ repository }}-{{playwright}}" \
        PLAYWRIGHT_IMAGE_TAG={{ kebabcase(tag) }} \
        docker compose --file {{ docker_compose_file }} up --detach --wait

[arg("repository", long="repository")]
[arg("tag", long="tag")]
[doc('Docker composer down.')]
[private]
docker-compose-down repository=repository_default tag=tag_default:
    @echo "🏃‍♂️ Docker compose down..."
    PLAYWRIGHT_IMAGE_NAME="{{ repository }}-{{playwright}}" \
        PLAYWRIGHT_IMAGE_TAG={{ kebabcase(tag) }} \
        docker compose --file {{ docker_compose_file }} down --remove-orphans --volumes > /dev/null 2>&1;

[arg("repository", long="repository")]
[arg("tag", long="tag")]
[doc('Docker composer cli.')]
[private]
docker-compose-cli repository=repository_default tag=tag_default +COMMAND='':
    @echo "🏃‍♂️ Docker compose cli..."
    PLAYWRIGHT_IMAGE_NAME={{ repository }}-{{playwright}}" \
        PLAYWRIGHT_IMAGE_TAG={{ kebabcase(tag) }} \
        docker compose --file {{ docker_compose_file }} exec --no-tty drupal bash -c "{{ COMMAND }}"

[arg("repository", long="repository")]
[arg("tag", long="tag")]
[doc('Docker composer cli interactive.')]
[private]
docker-compose-cli-interactive repository=repository_default tag=tag_default:
    @echo "🏃‍♂️ Docker compose cli interactive..."
    DRUPAL_IMAGE_NAME={{ repository }}-{{playwright}}" \
        DRUPAL_IMAGE_TAG={{ tag }} \
        docker compose --file {{ docker_compose_file }} exec drupal bash

[arg("repository", long="repository")]
[arg("tag", long="tag")]
[doc('Run drush command inside drupal container.')]
[private]
drush repository=repository_default tag=tag_default +COMMAND='':
    @echo "🏃‍♂️ Running drush command..."
    just docker-compose-cli --repository={{ repository }} --tag={{ tag }} \
        "drush {{ COMMAND }}"
