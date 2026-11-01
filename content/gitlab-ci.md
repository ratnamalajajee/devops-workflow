# GitLab CI/CD

GitLab is an all-in-one DevOps platform: Git hosting, CI/CD pipelines, a container registry, environments and security scanning, in one product. Pipelines are defined in a single `.gitlab-ci.yml` file at the root of the repository. This guide uses free **gitlab.com**, builds a full pipeline for the sample app, then shows how to run your own runner.

> **Note:** You need a free account at [gitlab.com](https://gitlab.com) and the **sample app** from [CI/CD Basics](#/tool/cicd-basics).

## Start here: GitLab CI/CD in simple words

> **In simple words:** You add one file, `.gitlab-ci.yml`, to your project. Every time you push, GitLab reads it and runs the jobs it lists, stage by stage, on machines called **runners**, and shows the result as a pipeline diagram.

### How the pieces fit

```text
 git push
    │
    ▼
 .gitlab-ci.yml ──▶ Pipeline
                      ├── stage: test     ── job: unit-tests ──┐
                      │                   ── job: lint ────────┤ jobs in the same stage run in parallel
                      ├── stage: build    ── job: docker-image │ next stage starts when the previous one passes
                      └── stage: deploy   ── job: deploy-prod  (manual ▶ button)
                                     │
                              runs on Runners (GitLab's shared runners, or your own)
```

### Key words

| Word | Simple meaning |
|---|---|
| **`.gitlab-ci.yml`** | The pipeline recipe file, at the root of the repo |
| **Pipeline** | One full run of all jobs for a commit |
| **Stage** | A group of jobs; stages run in order (`build` → `test` → `deploy`) |
| **Job** | One task with a `script` of shell commands |
| **Runner** | The machine (or container) that runs jobs |
| **Executor** | How a runner runs jobs: in Docker containers, in a shell, on Kubernetes… |
| **Artifact** | Files a job saves for later jobs or for download |
| **Cache** | Files reused between pipelines to save time, like downloaded packages |
| **CI/CD variable** | A setting or secret given to jobs; can be **masked** and **protected** |
| **Environment** | A deploy target (`staging`, `production`) with a history of deployments |

### Check yourself

1. Where does the pipeline definition live?
2. Do jobs in the same stage run one at a time or together?
3. What's the difference between an artifact and a cache?

> **Tip:** Answers: 1) In `.gitlab-ci.yml` at the root of the repository. 2) Together, in parallel. 3) An artifact is a job's *output*, passed to later jobs or downloaded; a cache is a *speed-up*, reusing files like downloaded packages between runs.

## Set up the project on GitLab

> **In simple words:** Create an empty project on gitlab.com and push the sample app into it.

1. On gitlab.com: **New project → Create blank project**, named `hello-app`, with **Initialize repository with a README** *unticked*.
2. Add your SSH key: **avatar → Edit profile → SSH Keys** (the same `~/.ssh/id_ed25519.pub` from Workstation Setup).
3. Push the sample app:

```bash
cd ~/code/hello-app
git remote add gitlab git@gitlab.com:<your-username>/hello-app.git
git push -u gitlab main
```

> **Note:** New gitlab.com accounts may have to **verify identity** (phone or card) before using GitLab's shared runners. That's an anti-abuse check, and you won't be charged. If you can't, use your own runner (see **Runners** below).

> **Tip:** Want GitLab on your own server? The `gitlab/gitlab-ce` Docker image runs a complete self-managed GitLab, but it needs **4+ GB of RAM**. For learning, gitlab.com is much easier.

## Your first pipeline

> **In simple words:** Create `.gitlab-ci.yml`, push it, and open **Build → Pipelines** to watch it run.

```yaml
stages:
  - hello
  - info

say-hello:
  stage: hello
  image: alpine:3.20
  script:
    - echo "Hello from GitLab CI!"
    - echo "Project $CI_PROJECT_PATH, branch $CI_COMMIT_BRANCH, commit $CI_COMMIT_SHORT_SHA"

machine-info:
  stage: info
  image: alpine:3.20
  script:
    - uname -a
    - cat /etc/os-release
    - echo "Pipeline $CI_PIPELINE_ID triggered by $GITLAB_USER_LOGIN via $CI_PIPELINE_SOURCE"
```

```bash
git add .gitlab-ci.yml && git commit -m "First pipeline" && git push gitlab main
```

In GitLab: **Build → Pipelines** → click the pipeline → click a job to see its log.

> **Tip:** Use **Build → Pipeline editor** to edit `.gitlab-ci.yml` in the browser. It **validates** the file as you type and shows a visual preview of the stages.

`CI_PROJECT_PATH`, `CI_COMMIT_SHORT_SHA` and friends are **predefined variables** GitLab gives every job. The full list is in the docs: [Predefined CI/CD variables](https://docs.gitlab.com/ci/variables/predefined_variables/).

## CI for the sample app

> **In simple words:** On every push, run the tests in a Python container, keep downloaded packages between runs, and show test results right inside merge requests.

Replace `.gitlab-ci.yml` with:

```yaml
stages:
  - test
  - build
  - deploy

default:
  image: python:3.12-slim

variables:
  PIP_CACHE_DIR: "$CI_PROJECT_DIR/.cache/pip"

unit-tests:
  stage: test
  cache:
    key:
      files: [requirements-dev.txt]     # new cache only when dependencies change
    paths: [.cache/pip]
  script:
    - pip install -r requirements-dev.txt
    - mkdir -p reports
    - pytest -v --junitxml=reports/junit.xml
  artifacts:
    when: always                         # keep the report even if tests fail
    reports:
      junit: reports/junit.xml           # shows results in pipelines and merge requests
    paths: [reports/]
    expire_in: 1 week

lint:
  stage: test
  script:
    - pip install ruff
    - ruff check .
  allow_failure: true                    # report problems but don't block the pipeline
```

Push it. `unit-tests` and `lint` run **in parallel** because they're in the same stage. Open the pipeline's **Tests** tab to see each test.

Now create a **merge request** that breaks a test. The MR shows the failed pipeline and which test failed. To block merging, go to **Settings → Merge requests → Pipelines must succeed**.

## Variables, secrets and rules

> **In simple words:** **Variables** feed settings and secrets to jobs. **Rules** decide *when* a job runs: on which branch, for merge requests, for tags, or only when someone clicks a button.

### CI/CD variables

Set them under **Settings → CI/CD → Variables → Add variable**:

| Option | Meaning |
|---|---|
| **Masked** | Hidden as `[MASKED]` in job logs |
| **Protected** | Only given to pipelines on **protected** branches and tags (like `main`), so feature branches can't read production secrets |
| **Type: File** | GitLab writes the value to a temporary file and the variable holds its **path**, which is handy for kubeconfigs and certificates |
| **Environment scope** | Only for jobs deploying to a matching environment, such as `production` |

### Rules

```yaml
workflow:                                     # when to create a pipeline at all
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    - if: $CI_COMMIT_TAG

deploy-staging:
  stage: deploy
  script: echo "deploy to staging"
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH       # only from main

deploy-production:
  stage: deploy
  script: echo "deploy to production"
  rules:
    - if: $CI_COMMIT_TAG                                # only for tags like v1.2.0
      when: manual                                      # someone must click ▶
```

`rules` are checked top to bottom, and the first match wins. If none match, the job is skipped.

## Build and push to the GitLab Container Registry

> **In simple words:** Every GitLab project includes a free private Docker registry. This job builds the app's image and pushes it there, using login details GitLab provides automatically.

Add to `.gitlab-ci.yml`:

```yaml
docker-image:
  stage: build
  image: docker:29
  services:
    - docker:29-dind                     # a Docker engine running next to the job
  variables:
    DOCKER_TLS_CERTDIR: "/certs"
    IMAGE: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA
  before_script:
    - echo "$CI_REGISTRY_PASSWORD" | docker login -u "$CI_REGISTRY_USER" --password-stdin "$CI_REGISTRY"
  script:
    - docker build --build-arg APP_VERSION=$CI_COMMIT_SHORT_SHA -t $IMAGE .
    - docker run -d --name smoke $IMAGE
    - docker run --rm --network container:smoke curlimages/curl:8.10.1 -sf --retry 10 --retry-connrefused --retry-delay 1 http://localhost:8000/health
    - docker push $IMAGE
    - |
      if [ "$CI_COMMIT_BRANCH" = "$CI_DEFAULT_BRANCH" ]; then
        docker tag $IMAGE $CI_REGISTRY_IMAGE:latest
        docker push $CI_REGISTRY_IMAGE:latest
      fi
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    - if: $CI_COMMIT_TAG
```

After it runs: **Deploy → Container Registry** lists `hello-app:<short-sha>` and `latest`.

| Predefined variable | Value |
|---|---|
| `CI_REGISTRY` | `registry.gitlab.com` |
| `CI_REGISTRY_IMAGE` | `registry.gitlab.com/<you>/hello-app` |
| `CI_REGISTRY_USER` / `CI_REGISTRY_PASSWORD` | A short-lived login valid only for this job |

> **Note:** **Docker-in-Docker** (`docker:dind`) needs a runner in **privileged** mode. GitLab's shared Linux runners support it; on your own runner, set `privileged = true` (see **Runners**). Without privileged mode, use a daemonless builder such as Buildah.

## Environments and deployments

> **In simple words:** Tell GitLab *where* a job deploys. GitLab then keeps a history of what went where, shows a link to the live app, and lets you re-deploy an older version with one click.

```yaml
deploy-staging:
  stage: deploy
  image: alpine:3.20
  script:
    - echo "Deploying $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA to staging"
  environment:
    name: staging
    url: https://staging.example.com
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

deploy-production:
  stage: deploy
  image: alpine:3.20
  script:
    - echo "Deploying $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA to production"
  environment:
    name: production
    url: https://www.example.com
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      when: manual
  resource_group: production             # never run two production deploys at once
```

Open **Operate → Environments**: each environment lists its deployments. **Re-deploy** on an older one is a one-click rollback. Protect production under **Settings → CI/CD → Protected environments** so only chosen people can click ▶.

## Faster and cleaner pipelines

> **In simple words:** Tricks to make pipelines quicker (start jobs early, split tests) and shorter to write (reuse config instead of copy-pasting).

### `needs`: start jobs as soon as their inputs are ready

```yaml
docker-image:
  stage: build
  needs: [unit-tests]          # don't wait for lint; start right after unit-tests
```

### `parallel: matrix`: one job definition, several runs

```yaml
unit-tests:
  stage: test
  image: python:${PY}-slim
  parallel:
    matrix:
      - PY: ["3.11", "3.12", "3.13"]
  script:
    - pip install -r requirements-dev.txt && pytest -q
```

### `extends`, anchors and `include`: don't repeat yourself

```yaml
.python-job:                    # a hidden "template" job (starts with a dot)
  image: python:3.12-slim
  before_script:
    - pip install -r requirements-dev.txt

unit-tests:
  extends: .python-job
  stage: test
  script: [pytest -q]

include:
  - template: Jobs/SAST.gitlab-ci.yml          # GitLab's built-in security scanning
  - project: my-group/ci-templates             # shared templates from another repo
    file: /python.yml
```

## Runners: GitLab's or your own

> **In simple words:** A runner is the worker that executes jobs. gitlab.com lends you shared runners; you can also install a runner on your own machine, which gives you no minute limits, private network access and your own tools.

| | GitLab-hosted (shared) | Your own (self-managed) |
|---|---|---|
| Setup | None | Install and register `gitlab-runner` |
| Limits | Monthly compute minutes on the free tier | Your hardware |
| Privileged Docker | Supported | You decide (`privileged = true`) |

Run your own runner in Docker:

1. In GitLab: **Settings → CI/CD → Runners → New project runner**. Tick **Run untagged jobs**, then **Create runner**. Copy the token, which starts with `glrt-`.
2. Start the runner and register it:

```bash
docker volume create gitlab-runner-config
docker run -d --name gitlab-runner --restart always \
  -v gitlab-runner-config:/etc/gitlab-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gitlab/gitlab-runner:alpine

docker exec -it gitlab-runner gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.com/" \
  --token "glrt-REPLACE_ME" \
  --executor "docker" \
  --docker-image "alpine:3.20" \
  --docker-privileged \
  --description "my-laptop-runner"
```

3. Back on the Runners page, your runner shows a green dot. To force jobs onto it, disable shared runners for the project, or add tags (`tags: [laptop]`) to the runner and the jobs.

```bash
docker exec gitlab-runner gitlab-runner list        # registered runners
docker logs -f gitlab-runner                        # what it's doing
```

Official docs: [Registering runners](https://docs.gitlab.com/runner/register/)

> **Warning:** `--docker-privileged` and the Docker socket give jobs full control of that machine. Only use such a runner for projects you trust.

## Hand over to Argo CD (GitOps)

> **In simple words:** As in the other CI tools, GitLab builds and pushes the image, then writes the new tag into a GitOps repo. Argo CD deploys it.

Create a **project access token** on your `gitops` project (**Settings → Access tokens**, role *Developer*, scope `write_repository`). Save it in `hello-app` as a **masked, protected** variable named `GITOPS_TOKEN`. Then:

```yaml
bump-gitops:
  stage: deploy
  image: alpine:3.20
  needs: [docker-image]
  before_script:
    - apk add --no-cache git kustomize
  script:
    - git clone "https://oauth2:${GITOPS_TOKEN}@gitlab.com/<you>/gitops.git"
    - cd gitops/apps/hello/overlays/dev
    - kustomize edit set image hello-app=$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA
    - git config user.name "gitlab-ci" && git config user.email "gitlab-ci@example.com"
    - git commit -am "hello-app: deploy $CI_COMMIT_SHORT_SHA" && git push
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

See the Argo CD guide's **Sample application flow** for the `gitops` repo layout. If the image registry is private, the cluster also needs a **deploy token** with `read_registry` as an image pull secret.

## Troubleshooting

> **In simple words:** Open the failed job, read the log from the first error, and check the **Pipeline editor** for YAML mistakes.

| Problem | Fix |
|---|---|
| No pipeline runs at all | The file must be named exactly `.gitlab-ci.yml` at the repo root; check `workflow: rules` |
| Job stuck: *"pending… no runners"* | Shared runners disabled or account not verified, or job `tags` match no runner |
| `yaml invalid` | Use **Pipeline editor → Validate**. Indentation must be spaces |
| `Cannot connect to the Docker daemon` | Missing `services: [docker:29-dind]`, missing `DOCKER_TLS_CERTDIR`, or runner not privileged |
| Variable is empty on a branch | It's **protected**, and the branch isn't protected |
| `denied: access forbidden` pushing image | Log in with `$CI_REGISTRY_USER`/`$CI_REGISTRY_PASSWORD` to `$CI_REGISTRY`, and the image path must start with `$CI_REGISTRY_IMAGE` |
| Job skipped | Its `rules` didn't match, or a job it `needs` failed |

## Lab: complete GitLab pipeline

> **In simple words:** Practice time: build the whole pipeline for the sample app on GitLab.

1. Push `hello-app` to GitLab and add `unit-tests` (with JUnit report) and `lint` jobs.
2. Turn on **Pipelines must succeed** and prove it blocks a broken merge request.
3. Add `docker-image` to build, smoke-test and push to the GitLab Container Registry.
4. Add `deploy-staging` (automatic) and `deploy-production` (manual, tags only) with environments.
5. Run the Python tests on 3 versions with `parallel: matrix`.
6. Register your own runner with Docker and run a pipeline on it.
7. Bonus: add `bump-gitops` and complete the Argo CD **Sample application flow**.

### Cheat sheet

| Task | YAML |
|---|---|
| Order of stages | `stages: [test, build, deploy]` |
| Container for a job | `image: python:3.12-slim` |
| Only on main | `rules: [{ if: '$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH' }]` |
| Manual button | `when: manual` |
| Save files | `artifacts: { paths: [dist/] }` |
| Speed up installs | `cache: { paths: [.cache/pip] }` |
| Start early | `needs: [unit-tests]` |
