# GitHub Actions

GitHub Actions is the CI/CD system built into GitHub. There's no server to install: you add a YAML file to `.github/workflows/`, push it, and GitHub runs it on a fresh virtual machine. This guide goes from a "hello world" workflow to testing the sample app, publishing its Docker image, deploying to AWS without stored keys, and handing over to Argo CD.

> **Note:** You need a GitHub account and the **sample app** from [CI/CD Basics](#/tool/cicd-basics) pushed to a repo named `hello-app`.

## Start here: GitHub Actions in simple words

> **In simple words:** GitHub Actions is a robot that lives inside your GitHub repository. You give it a recipe file that says "**when** this happens, **do** these steps", and GitHub runs the steps on a brand-new computer each time.

### How the pieces fit

```text
 Event (push, pull request, schedule, button)
   │ triggers
   ▼
 Workflow  (.github/workflows/ci.yml)
   ├── Job "test"   ── runs on ──▶ Runner (fresh Ubuntu VM from GitHub)
   │     ├── step: checkout code         (an action: actions/checkout)
   │     ├── step: set up Python         (an action: actions/setup-python)
   │     └── step: run: pytest           (a shell command)
   └── Job "build"  (needs: test) ──▶ another fresh runner
```

### Key words

| Word | Simple meaning |
|---|---|
| **Workflow** | One automated process, defined in a YAML file under `.github/workflows/` |
| **Event / trigger** | What starts it: `push`, `pull_request`, `schedule`, `workflow_dispatch` (a button) |
| **Job** | A group of steps that run on one runner. Jobs run **in parallel** unless linked with `needs` |
| **Step** | One command (`run:`) or one ready-made action (`uses:`) |
| **Action** | A reusable building block, like `actions/checkout`, from the GitHub Marketplace |
| **Runner** | The machine that runs a job: GitHub-hosted (fresh each time) or your own |
| **Secret** | An encrypted value such as a token, shown as `***` in logs |
| **Artifact** | A file a workflow saves for later download, such as a test report |

### Check yourself

1. Where do workflow files live?
2. Do two jobs in a workflow run one after another, or at the same time?
3. What's the difference between `run:` and `uses:`?

> **Tip:** Answers: 1) In `.github/workflows/` in the repository. 2) At the same time, unless one says `needs:` the other. 3) `run:` runs shell commands; `uses:` runs a ready-made action.

## Your first workflow

> **In simple words:** Create one small file, push it, and watch GitHub run it in the **Actions** tab.

In `hello-app`, create `.github/workflows/hello.yml`:

```yaml
name: hello

on:
  push:
  workflow_dispatch:        # adds a "Run workflow" button in the Actions tab

jobs:
  greet:
    runs-on: ubuntu-latest
    steps:
      - name: Say hello
        run: |
          echo "Hello from GitHub Actions!"
          echo "Repo: $GITHUB_REPOSITORY  Branch: $GITHUB_REF_NAME  Commit: $GITHUB_SHA"
          echo "Triggered by: ${{ github.actor }} via ${{ github.event_name }}"
      - name: What machine am I on?
        run: |
          uname -a
          nproc && free -h
          docker --version && python3 --version
```

```bash
mkdir -p .github/workflows
# (create hello.yml as above)
git add .github && git commit -m "Add hello workflow" && git push
```

Open your repo on GitHub → **Actions** → **hello** → the latest run → **greet** to read each step's log.

Two kinds of variables appear above:
- `$GITHUB_SHA`: an **environment variable**, read by the shell.
- `${{ github.actor }}`: an **expression**, filled in by GitHub before the step runs. Expressions can read `github`, `env`, `secrets`, `vars`, `inputs`, `matrix`, `needs` and more.

## CI for the sample app

> **In simple words:** Every push and every pull request automatically installs the app and runs its tests on three Python versions. A red ❌ means "don't merge this yet".

Create `.github/workflows/ci.yml`:

```yaml
name: ci

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read            # least privilege: this workflow only reads code

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        python: ["3.11", "3.12", "3.13"]
    steps:
      - uses: actions/checkout@v7

      - uses: actions/setup-python@v7
        with:
          python-version: ${{ matrix.python }}
          cache: pip                    # reuse downloaded packages between runs

      - name: Install
        run: pip install -r requirements-dev.txt

      - name: Test
        run: |
          mkdir -p reports
          pytest -v --junitxml=reports/junit-${{ matrix.python }}.xml

      - name: Upload test report
        if: always()                    # upload even when tests fail
        uses: actions/upload-artifact@v7
        with:
          name: test-report-${{ matrix.python }}
          path: reports/
```

Push it, then open a pull request that breaks a test (for example, change the expected message in `test_app.py`). The PR page shows the failing check. Fix it and push again, and the check turns green.

> **Tip:** Make the check **required**: **Settings → Branches → Add branch ruleset** (or *branch protection rule*) for `main` → **Require status checks to pass** → pick the `test` jobs. Now nobody can merge a red PR.

What's new:

| Feature | What it does |
|---|---|
| `strategy.matrix` | Runs the job once per value: 3 Python versions in parallel |
| `cache: pip` | Speeds up runs by reusing downloaded packages |
| `if: always()` | Run this step even if an earlier step failed |
| `upload-artifact` | Saves files; download them from the run's **Summary** page |
| `permissions` | Limits what the automatic `GITHUB_TOKEN` can do |

## Triggers, conditions and job order

> **In simple words:** Control **when** a workflow runs (which branches, files or times) and **in what order** jobs run.

```yaml
on:
  push:
    branches: [main, "release/**"]
    paths: ["**.py", "requirements*.txt", "Dockerfile"]   # skip runs for README-only changes
  pull_request:
    branches: [main]
  schedule:
    - cron: "0 3 * * 1"          # every Monday 03:00 UTC
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [staging, production]
        default: staging

concurrency:                       # a new push cancels the older, still-running run
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo "testing"

  build:
    needs: test                   # wait for test to pass
    runs-on: ubuntu-latest
    steps:
      - run: echo "building"

  deploy:
    needs: build
    if: github.ref == 'refs/heads/main' && github.event_name != 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - run: echo "deploying to ${{ inputs.environment || 'staging' }}"
```

## Secrets, variables and environments

> **In simple words:** Keep passwords in GitHub's locked safe (**secrets**), plain settings in **variables**, and use **environments** to add rules such as "a person must approve before production".

| Type | Where to set it | Use in YAML | Shown in logs? |
|---|---|---|---|
| **Secret** | Repo → **Settings → Secrets and variables → Actions → Secrets** | `${{ secrets.NAME }}` | No, masked as `***` |
| **Variable** | Same page → **Variables** | `${{ vars.NAME }}` | Yes |
| **Environment** | Repo → **Settings → Environments** | `environment: production` on a job | n/a |

Create an environment named `production`, tick **Required reviewers** and add yourself. Then:

```yaml
jobs:
  deploy-prod:
    runs-on: ubuntu-latest
    environment: production        # pauses until a reviewer approves
    steps:
      - run: ./deploy.sh            # the script reads $MY_KEY; never echo secrets
        env:
          MY_KEY: ${{ secrets.PROD_API_KEY }}    # environment-level secret
```

The run pauses with **Review deployments**. Approve it, and the job continues.

> **Warning:** Secrets are **not** passed to workflows triggered by pull requests from **forks**, for safety. Never use `pull_request_target` together with checking out the PR's code unless you fully understand the risk: it lets untrusted code run with your secrets.

## Build and push the Docker image (GHCR)

> **In simple words:** After the tests pass, build the app's Docker image and publish it to **GitHub Container Registry** (`ghcr.io`), which is free and needs no extra account.

Add a second job to `ci.yml`:

```yaml
  image:
    needs: test
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write              # allow pushing to ghcr.io
    steps:
      - uses: actions/checkout@v7

      - uses: docker/setup-buildx-action@v4

      - uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}     # automatic, no setup needed

      - id: meta
        uses: docker/metadata-action@v6
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=sha,format=short
            type=raw,value=latest,enable={{is_default_branch}}

      - uses: docker/build-push-action@v7
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          build-args: APP_VERSION=${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

After a push to `main`, the image appears under your repo's **Packages**, tagged like `sha-1a2b3c4`. Pull it anywhere:

```bash
docker pull ghcr.io/<you>/hello-app:sha-1a2b3c4
```

> **Tip:** New packages are **private**. To let a cluster pull without credentials, open the package → **Package settings → Change visibility → Public**.

## Deploy to AWS without keys (OIDC)

> **In simple words:** Instead of saving AWS access keys in GitHub, let GitHub prove its identity to AWS and receive **short-lived** credentials for each run. Nothing to leak, and nothing to rotate.

One-time setup in AWS (console: **IAM → Identity providers → Add provider**):
1. **OpenID Connect**, provider URL `https://token.actions.githubusercontent.com`, audience `sts.amazonaws.com`.
2. **IAM → Roles → Create role → Web identity**, pick that provider, audience `sts.amazonaws.com`, **GitHub organization** `<you>`, **repository** `hello-app`, **branch** `main`.
3. Attach permissions, for example `AmazonEC2ContainerRegistryPowerUser`, and name the role `gha-hello-app`.

The role's trust policy will contain a condition like this. It's what stops other repos using your role:

```json
"Condition": {
  "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
  "StringLike":   { "token.actions.githubusercontent.com:sub": "repo:<you>/hello-app:ref:refs/heads/main" }
}
```

Then in a workflow:

```yaml
  push-ecr:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions:
      id-token: write              # REQUIRED for OIDC
      contents: read
    steps:
      - uses: actions/checkout@v7
      - uses: aws-actions/configure-aws-credentials@v6
        with:
          role-to-assume: arn:aws:iam::<ACCOUNT_ID>:role/gha-hello-app
          aws-region: us-east-1
      - id: ecr
        uses: aws-actions/amazon-ecr-login@v2
      - run: |
          IMAGE=${{ steps.ecr.outputs.registry }}/hello-app:${GITHUB_SHA::7}
          docker build -t $IMAGE .
          docker push $IMAGE
      - run: aws sts get-caller-identity     # proves which role the run is using
```

The Terraform version of this setup is in the Capstone project.

## Hand over to Argo CD (GitOps)

> **In simple words:** The CI workflow doesn't touch the cluster. It just writes the new image tag into your GitOps repo, and Argo CD notices and deploys it.

Add a final job that updates a Kustomize file in a separate `gitops` repo. Create a **fine-grained personal access token** with **Contents: Read and write** on the `gitops` repo only, and save it as the secret `GITOPS_TOKEN`.

```yaml
  bump-gitops:
    needs: image
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
        with:
          repository: <you>/gitops
          token: ${{ secrets.GITOPS_TOKEN }}
      - name: Set new image tag
        run: |
          cd apps/hello/overlays/dev
          kustomize edit set image hello-app=ghcr.io/${{ github.repository }}:sha-${GITHUB_SHA::7}
          git config user.name  "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git commit -am "hello-app: deploy sha-${GITHUB_SHA::7}" && git push
```

The `gitops` repo layout and the Argo CD side are in the Argo CD guide's **Sample application flow** step. (`kustomize` is preinstalled on GitHub's Ubuntu runners.)

## Reuse: composite actions and reusable workflows

> **In simple words:** Don't copy the same steps into every repo. Package them once and call them from anywhere.

**Reusable workflow**: a whole workflow other workflows can call. In `.github/workflows/python-ci.yml`:

```yaml
on:
  workflow_call:
    inputs:
      python-version:
        type: string
        default: "3.12"

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-python@v7
        with:
          python-version: ${{ inputs.python-version }}
          cache: pip
      - run: pip install -r requirements-dev.txt && pytest -v
```

Call it from any repo:

```yaml
jobs:
  ci:
    uses: <you>/hello-app/.github/workflows/python-ci.yml@main
    with:
      python-version: "3.13"
```

A **composite action** (`action.yml` with `runs: using: composite`) packages a few *steps* instead of whole jobs. Use it for small shared snippets, such as "log in and set up our tools".

## Runners

> **In simple words:** GitHub lends you a fresh computer for every job. You can also connect your own machine when you need special hardware, private network access, or more minutes.

| | GitHub-hosted | Self-hosted |
|---|---|---|
| Setup | None: `runs-on: ubuntu-latest` | Install the runner app on your machine |
| Clean? | Brand-new VM every job | Reused; you must clean up |
| Cost | Free minutes for public repos; a monthly quota for private ones | Your own hardware |
| Reaches private networks? | No | Yes |

Add a self-hosted runner: repo → **Settings → Actions → Runners → New self-hosted runner**, then copy the commands GitHub shows (download, `./config.sh --url … --token …`, `./run.sh`). Target it with `runs-on: self-hosted`.

> **Warning:** Never attach self-hosted runners to **public** repos. Anyone could open a pull request that runs code on your machine.

## Security best practices

> **In simple words:** A workflow can read your code and use your secrets, so treat workflow files like production code.

- Set `permissions:` at the top of every workflow, starting from `contents: read`, and add only what each job needs.
- Prefer **OIDC** over long-lived cloud keys.
- **Pin third-party actions** to a full commit SHA (`uses: owner/action@<40-char-sha>`), not a moving tag. Let **Dependabot** propose updates: add `.github/dependabot.yml` with `package-ecosystem: github-actions`.
- Use **environments with required reviewers** for production.
- Never `echo` secrets, and don't build commands from untrusted input such as PR titles: `run: echo "${{ github.event.pull_request.title }}"` can be abused. Pass the value through `env:` instead.

## Troubleshooting

> **In simple words:** Open the failed run, expand the red step, and read the first error. Most problems are YAML indentation, permissions or a wrong path.

| Problem | Fix |
|---|---|
| Workflow doesn't appear | The file must be in `.github/workflows/` on the default branch, ending in `.yml` or `.yaml` |
| `Invalid workflow file` | YAML indentation: use spaces, not tabs. Validate with the editor's YAML extension |
| `Resource not accessible by integration` | The `GITHUB_TOKEN` lacks a permission. Add it under `permissions:` |
| `denied: permission_denied` pushing to ghcr.io | Add `packages: write`; the image name must match `ghcr.io/<owner>/<repo>` |
| OIDC: `Not authorized to perform sts:AssumeRoleWithWebIdentity` | Missing `id-token: write`, or the trust policy's `sub` doesn't match the repo or branch |
| Secret is empty | Wrong name, set in a different environment, or the run came from a fork |
| Job skipped | Its `if:` was false, or a job it `needs` failed |
| Want to debug interactively | Re-run with **Enable debug logging**, or test locally with [`act`](https://github.com/nektos/act) |

## Lab: complete GitHub Actions pipeline

> **In simple words:** Practice time: build the full pipeline for the sample app on your own.

1. Add `ci.yml` with a **matrix** test job on 3 Python versions and a test-report artifact.
2. Protect `main` so a PR can't merge unless tests pass, then prove it with a breaking PR.
3. Add an `image` job that pushes `ghcr.io/<you>/hello-app:sha-<short>` only from `main`.
4. Add a `workflow_dispatch` input `environment` and a `deploy` job that uses the matching GitHub **environment**, with a required reviewer for `production`.
5. Set up AWS **OIDC** and push the same image to ECR with no stored AWS keys.
6. Bonus: add the `bump-gitops` job and complete the Argo CD **Sample application flow**.

### Cheat sheet

| Task | YAML |
|---|---|
| Run on push to main | `on: { push: { branches: [main] } }` |
| Manual button | `on: workflow_dispatch` |
| Job order | `needs: test` |
| Condition | `if: github.ref == 'refs/heads/main'` |
| Use a secret | `${{ secrets.NAME }}` |
| Parallel versions | `strategy: { matrix: { python: ["3.12","3.13"] } }` |
| Allow OIDC | `permissions: { id-token: write }` |
