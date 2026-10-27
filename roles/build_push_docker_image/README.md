# Ansible Role: `build_push_docker_image`

This Ansible role:
*  creates or updates an ECR
*  optionally builds a Docker image
*  pushes the Docker image into the ECR
*  tags the image

## Parameters

| Param                     |  Mandatory  |  Type   | Default                       | Description                                                                                                                                                                                                                    |
|:--------------------------|:-----------:|:-------:|:------------------------------|:-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `ecr_repository_name`     |     Yes     |   str   | -                             | Name of the ECR repository to be created/updated. e.g. '{{ env }}-{{ project_id }}-crawler-cli'                                                                                                                                |
| `enable_lifecycle_rules`  |     No      | boolean | `true`                        | Enable ECR repository lifecycle rules. Enabled by default.                                                                                                                                                                     |
| `workspace_path`          |     No      |   str   | -                             | A temporary folder as the `chdir` folder to run docker build, normally no need to specify as Ansible role `init_workspace`set its value already                                                                                |
| `code_path`               |     No      |   str   | `'{{ playbook_dir }}/../app'` | Where to find Dockerfile                                                                                                                                                                                                       |
| `prebuilt_image_supplied` |     No      | boolean | `false`                       | Set to `true` will ignore docker build process and take the existing image for ECR publishing                                                                                                                                  |
| `adhoc_deploy`            |     No      | boolean | `false`                       | Ignored when `prebuilt_image_supplied` is truthy. When `adhoc_deploy` is truthy, use the docker image repo digest as the version to tag Docker image. Otherwise, use `{{ project_version }} as the version for image tagging.` |
| `share_with_org_unit`     |     No      |   str   | `''`                          | Set to the OU path like `o-xxxxxxxxxx/*/ou-xxxx-xxxxxxxx/*` to permit the readonly access to the image from all AWS accounts within the organization unit.                                                                     |
| `build_multi_arch`        |     No      | boolean | `false`                       | If truthy, this role builds the multi-arch image for amd64 and arm64                                                                                                                                                           |
| `extra_buildx_build_args` |     No      |   str   | `''`                          | Extra command line parameters to pass over to `docker buildx build`                                                                                                                                                            |
| `build_cache`             |     No      | boolean | `false`                       | Ignored when `prebuilt_image_supplied` is truthy. If truthy, the build reads and writes a layer cache in S3. Read [Build cache](#build-cache) before turning it on.                                                         |
| `build_cache_bucket`      |     No      |   str   | `''`                          | S3 bucket for the build cache. Defaults to the infrastructure bucket (output `InfrastructureCodeS3Bucket` of the `<env>-<project_id>-basis` stack).                                                                         |
| `build_cache_prefix`      |     No      |   str   | `'buildkit-cache/'`           | Key prefix of the build cache in the bucket. The bucket's lifecycle rule for this prefix decides how long unused layers are kept.                                                                                              |
| `buildx_platform_param`   |     No      |   str   | -                             | Target platform. If not set it will be determined from the repository settings. Valid values are: `''`, `'linux/amd64'`, `'linux/arm64'`, or `'linux/amd64,linux/arm64'`.                                                      |
| `docker_build_args`       | Conditional |  dict   | `{}`                          | Mandatory when `prebuilt_image_supplied` is falsy. Key-value pairs of the values to supply for `docker build --build-arg ...`                                                                                                  |
| `prebuilt_image_tag`      | Conditional |   str   | `''`                          | Mandatory when `prebuilt_image_supplied` is truthy. Tag of the prebuilt docker image for ECR publishing.                                                                                                                       |

## Outputs

| Ansible variable                        | Type | Description                                                                                                                                                                                                                                                                                                                        |
|:----------------------------------------|:-----|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `docker_image_full_name_and_tag`        | str  | ECR-specific tag for the published Docker image. e.g. `965749599769.dkr.ecr.eu-west-1.amazonaws.com/dev-scmi-crawler-cli:0.3.8.`                                                                                                                                                                                                   |
| `docker_image_digest`                   | str  | Empty when `prebuilt_image_supplied` is truthy. Otherwise the digest of the pushed image as reported by the build, e.g. `sha256:6d2b…`. For a multi-arch image, this is the digest of the manifest list.                                                                                                                       |
| `docker_image_full_name_and_tag_<arch>` | str  | In case `adhoc_deploy` is truthy, these variables will be set to the SHA256 hash of the specific architecture. e.g. `docker_image_full_name_and_tag_arm64` = `180132115366.dkr.ecr.eu-central-1.amazonaws.com/dev-alloy-vectorizer-grafana-metrics-update@sha256:6d2b97ccacb063b2cf098a4c1932d5112d8742d6eb04aa5e26f7ce2c1b9e2078` |

## Build cache

With `build_cache: true`, `docker buildx build` imports its layer cache from S3 before the build and exports it after (`mode=max`, so the layers of builder stages are cached too). A fresh builder, such as every CodeBuild run, then skips the steps whose inputs have not changed.

- **Where:** `s3://<infrastructure bucket>/buildkit-cache/`. Each image has one manifest under `manifests/<ecr_repository_name>`. The layers are stored once under `blobs/` and shared by all images, so a common base image is stored once.
- **Retention:** the bucket needs a lifecycle rule that expires the prefix after a few days. Each export refreshes the timestamp of the layers it still uses (`touch_refresh=24h`), so the rule only removes layers that no recent build has used.
- **Failures:** a failed export never fails the build (`ignore-error=true`). A missing cache, e.g. on an image's first build, only makes the build slower.
- **Credentials:** buildx passes the caller's AWS credentials (SSO profile or CodeBuild role) to the builder. The caller needs read and write access to the prefix and the bucket's KMS key.
- **Builder:** the S3 cache needs BuildKit v0.11 or later in the `rcplus` builder. The role reuses an existing builder, so if a laptop has one from before 2023 (`docker buildx inspect rcplus` shows the version), remove it with `docker buildx rm rcplus` and the role recreates it.

Before a repository turns it on, check two things in each of its Dockerfiles:

1. **No secrets in layers.** With `mode=max`, every builder-stage layer lands in the bucket. Tokens and keys must reach the build through `RUN --mount=type=secret` or `RUN --mount=type=ssh`, never through `ARG` (build args are also recorded in the build metadata) or a file written in a `RUN` step.
2. **Dependencies before the source.** Copy the lock files and install the dependencies (`uv sync --no-install-project`, `npm ci`) before copying the source. Otherwise every code change invalidates the dependency layer, and the cache saves little.

To limit the cost to where builds are frequent, turn it on for dev only:

```ansible
- include_role:
    name: 'ringier.aws_cicd.build_push_docker_image'
  vars:
    ecr_repository_name: '{{ env }}-{{ project_id }}-estimations-api'
    adhoc_deploy: true
    build_cache: "{{ env == 'dev' }}"
```

## Examples

```ansible
- name: 'push the pre-built Docker image into ECR'
- include_role:
    name: 'ringier.aws_cicd.build_push_docker_image'
  vars:
    ecr_repository_name: '{{ env }}-{{ project_id }}-rambler'
    prebuilt_image_supplied: true
    prebuilt_image_tag: 'rambler:5.2.0'   # this image must exist locally, or available publicly (accessible via docker pull)

- name: 'show result'
  debug:
    msg: '{{ docker_image_full_name_and_tag }}'

#> 965749599769.dkr.ecr.eu-west-1.amazonaws.com/dev-scmi-rambler:5.2.0

- name: 'build and push the Docker image to ECR'
  # note that we take the default {{ playbook_dir }}/../app/Dockerfile to build the image  
  include_role:
    name: 'ringier.aws_cicd.build_push_docker_image'
  vars:
    ecr_repository_name: '{{ env }}-{{ project_id }}-database-test'

- name: 'build and push the Docker image to ECR'
  include_role:
    name: 'ringier.aws_cicd.build_push_docker_image'
  vars:
    ecr_repository_name: '{{ env }}-{{ project_id }}-database-test'
    code_path: '{{ playbook_dir }}/../src'    # we run Docker build using '{{ playbook_dir }}/../src/Dockerfile'
    share_with_org_unit: 'o-umabch1ai4/*/ou-d3mj-k351defg/*'
    build_multi_arch: true
    docker_build_args:
      HTTP_PROXY: 'https://10.20.30.2:1234'    # results in docker build --build-arg HTTP_PROXY=https://10.20.30.2:1234

- name: 'show result'
  debug:
    msg: '{{ docker_image_full_name_and_tag }}'

#> 965749599769.dkr.ecr.eu-west-1.amazonaws.com/dev-scmi-database-test:0.4.14
```
