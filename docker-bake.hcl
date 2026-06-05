group "default" {
  targets = ["test"]
}

group "ci" {
  targets = ["release"]
}

function "platform" {
  params = [arch]
  result = "linux/${arch}"
}

variable "DATE" {
  default = ""
}

# The ${REPOSITORY} value is expected to be something like: 'organization/project'.
variable "REPOSITORY" {
  default = ""
}

variable "TAG" {
  default = "latest"
}

variable "REPOSITORY_DESCRIPTION" {
  default = ""
}

variable "REPOSITORY_NAMESPACE" {
  default = "${split("/", REPOSITORY)[0]}"
}

variable "REPOSITORY_NAME" {
  default = "${split("/", REPOSITORY)[1]}"
}

variable "IMAGE_NAME" {
  default = "${REPOSITORY}"
}

variable "TAGS" {
  default = "${REPOSITORY_NAME}:latest"
}

function "tags" {
  params = [tags_string]
  result = [for tag in split("\n", tags_string) : trim(tag, " \t") if trim(tag, " \t") != ""]
}

function "release_tags" {
  params = []
  result = compact([
    "${IMAGE_NAME}-playwright:${TAG}"
  ])
}

variable "ARCH" {
  default = "amd64"
}

target "base" {
  args = {
    DATE = "${DATE}"
  }
  labels = {
    "org.opencontainers.image.title" = "${REPOSITORY_NAMESPACE} ${REPOSITORY_NAME}"
    "org.opencontainers.image.description" = "${REPOSITORY_DESCRIPTION}"
    "org.opencontainers.image.vendor" = "${REPOSITORY_NAMESPACE}"
  }
  context    = "."
  dockerfile = "Dockerfile"
  secret     = ["id=GITHUB_TOKEN,env=GITHUB_TOKEN"]
}

# Local development - native platform only
target "test" {
  inherits = ["base"]
  tags     = ["${REPOSITORY_NAME}:test"]
}

# CI matrix builds - single platform for testing and caching
target "build-test" {
  inherits   = ["base"]
  platforms  = [platform(ARCH)]
  tags       = notequal(TAGS, "${REPOSITORY_NAME}:latest") && notequal(TAGS, "") ? tags(TAGS) : ["${REPOSITORY_NAME}:test"]
  cache-from = ["type=gha,scope=${ARCH}"]
  cache-to   = ["type=gha,mode=max,scope=${ARCH}"]
}

# CI release - multi-platform with cache from native builds
target "release" {
  inherits   = ["base"]
  platforms  = [platform("amd64")]
  tags       = notequal(TAGS, "${REPOSITORY_NAME}:latest") ? tags(TAGS) : release_tags()
  # CRITICAL: Disable attestations that break AWS ECR.
  provenance = false
  sbom = false
  # Disable the metadata attestations forcing the Image Index wrapper.
  attest = [
    "type=provenance,disabled=true",
    "type=sbom,disabled=true"
  ]
  # Force Docker V2 manifest format instead of OCI, required by AWS ECR.
  output = ["type=image,oci-mediatypes=false"]
  cache-from = [
    "type=gha,scope=amd64"
  ]
}
