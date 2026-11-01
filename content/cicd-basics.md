# CI/CD Basics

CI/CD is how teams turn a code change into a tested, running application automatically, many times a day, without anyone copying files to servers by hand. This guide explains the ideas and the vocabulary, compares the four tools in this section (Jenkins, GitHub Actions, GitLab CI and Argo CD), and sets up the **sample app** that every CI/CD guide uses.

## Start here: CI/CD in simple words

> **In simple words:** CI/CD is an **automatic assembly line for software**. Every time someone saves a change to the code, a robot builds it, tests it and, if everything passes, delivers it to the servers.

### The problem it solves

Without CI/CD, releasing software looks like this: a developer finishes a feature, someone builds it on their laptop, runs a few tests if there's time, copies the files to the server late on a Friday, and hopes nothing breaks. Bugs are found by users, and nobody is sure exactly what is running.

With CI/CD, **every change goes through the same automatic checks, every time**. Problems are caught within minutes, while the developer still remembers the change, and releases become boring, which is exactly what you want.

### A real-life comparison

Think of a **car factory assembly line**. Each car moves through fixed stations: frame, engine, paint, quality check. If a car fails the quality check, it never leaves the factory. Every car is built the same way, no matter who is working that day.

A CI/CD **pipeline** is that assembly line. The stations are steps like *build*, *test*, *security scan* and *deploy*, and a failed check stops the line.

### Key words

| Word | Simple meaning |
|---|---|
| **CI (Continuous Integration)** | Automatically build and test every change as soon as it's pushed |
| **CD (Continuous Delivery)** | Every change that passes is *ready* to release; a human clicks "deploy" |
| **CD (Continuous Deployment)** | Every change that passes is released *automatically*, with no human click |
| **Pipeline** | The full list of automatic steps from code change to release |
| **Stage** | A group of steps in the pipeline, such as *test* or *deploy* |
| **Job** | One task inside a stage, such as "run unit tests" |
| **Trigger** | What starts the pipeline: a push, a pull request, a schedule, or a button |
| **Runner / agent** | The machine that actually runs the jobs |
| **Artifact** | A file the pipeline produces and keeps, such as a test report or a built image |
| **Secret** | A password or token the pipeline needs, stored safely and hidden in logs |
| **Environment** | A place the app runs: *dev*, *staging* or *production* |

### Check yourself

1. What's the difference between Continuous Delivery and Continuous Deployment?
2. What happens on the assembly line if a test fails?
3. What is a runner?

> **Tip:** Answers: 1) Delivery means every change is *ready* to release and a person clicks deploy; Deployment means it's released *automatically*. 2) The pipeline stops, and the change never reaches users. 3) The machine that runs the pipeline's jobs.

## CI, continuous delivery and continuous deployment

> **In simple words:** CI checks every change. Continuous delivery gets every good change ready to ship. Continuous deployment ships it automatically.

```text
  Continuous Integration          Continuous Delivery            Continuous Deployment
 ┌──────────────────────┐      ┌───────────────────────┐      ┌──────────────────────┐
 │ push → build → test  │ ───▶ │ package → deploy to   │ ───▶ │ deploy to production │
 │ (every commit)       │      │ staging → READY       │      │ AUTOMATICALLY        │
 └──────────────────────┘      │ (human approves prod) │      └──────────────────────┘
                               └───────────────────────┘
```

| | What's automated | Who decides to release |
|---|---|---|
| **Continuous Integration** | Build and test on every push | Not a release step yet |
| **Continuous Delivery** | Everything up to a release-ready package, often deployed to staging | A person approves production |
| **Continuous Deployment** | Everything, including production | The pipeline: if all checks pass, it ships |

Most teams start with CI, then add continuous delivery with a manual approval for production. They move to full continuous deployment once their tests are trusted.

## Anatomy of a pipeline

> **In simple words:** A pipeline is a list of steps in order. Each step must pass before the next one starts.

A typical pipeline for a web app:

```text
 git push
    │
    ▼
 1. Checkout   get the code
 2. Build      install dependencies / compile
 3. Test       unit tests, lint (style checks)
 4. Scan       security checks on code and dependencies
 5. Package    build a Docker image, tag it with the version
 6. Publish    push the image to a registry (Docker Hub, GHCR, ECR, GitLab)
 7. Deploy     update staging ── approve ──▶ update production
 8. Verify     smoke test: does the live app answer?
```

Rules that make pipelines trustworthy:

- **Fail fast.** Put quick checks (lint, unit tests) first so mistakes are found in seconds, not minutes.
- **Build once, deploy many times.** Build the image once, then promote **the same image** to staging and production. Don't rebuild for each environment.
- **Version everything.** Tag images with the Git commit SHA or a version number, never just `latest`, so you always know what's running and can roll back.
- **Keep secrets out of code.** Use the tool's secret store, and give the pipeline the least access it needs.
- **The pipeline is code.** Store it in the repo (`Jenkinsfile`, `.github/workflows/*.yml`, `.gitlab-ci.yml`) so changes to it are reviewed too.

## The four tools compared

> **In simple words:** Jenkins, GitHub Actions and GitLab CI are all assembly lines that **build and test** code. Argo CD is different: it **deploys** to Kubernetes by watching Git.

| | Jenkins | GitHub Actions | GitLab CI/CD | Argo CD |
|---|---|---|---|---|
| **What it is** | Self-hosted automation server | CI/CD built into GitHub | CI/CD built into GitLab | GitOps deployment tool for Kubernetes |
| **Pipeline file** | `Jenkinsfile` (Groovy) | `.github/workflows/*.yml` | `.gitlab-ci.yml` | Kubernetes YAML plus an `Application` resource |
| **Where it runs** | Your own servers | GitHub's runners, or your own | GitLab's runners, or your own | Inside your Kubernetes cluster |
| **Strengths** | Extremely flexible, 1,800+ plugins, works with any Git host | Zero setup for GitHub repos, huge marketplace | All-in-one: Git, CI, registry, environments | Drift detection, easy rollback, cluster pulls changes |
| **You maintain** | The server, plugins, upgrades and backups | Almost nothing | Almost nothing on gitlab.com | Argo CD itself (it's small) |
| **Typical use** | Enterprises with existing Jenkins | Projects hosted on GitHub | Projects hosted on GitLab | The *deploy* half of a Kubernetes pipeline |

### Push vs pull deployment

```text
 PUSH (Jenkins / GitHub Actions / GitLab deploy job)
   CI pipeline ──kubectl apply──▶ cluster        CI needs cluster credentials

 PULL (GitOps with Argo CD)
   CI pipeline ──commit new tag──▶ Git ◀──watches── Argo CD (in cluster) ──▶ applies
                                                   credentials never leave the cluster
```

A very common setup combines them: **Jenkins, GitHub Actions or GitLab CI** builds, tests and pushes the image, then updates the image tag in a GitOps repo. **Argo CD** deploys it. You'll build exactly that flow in the Argo CD guide.

## The sample app used in every CI/CD guide

> **In simple words:** One tiny web app with two tests. Every CI/CD guide builds, tests and ships this same app, so you can compare the tools fairly.

Create the project once:

```bash
mkdir -p ~/code/hello-app && cd ~/code/hello-app
```

`app.py`, a tiny web API:

```python
from flask import Flask
import os, socket

app = Flask(__name__)

@app.get("/")
def index():
    return {"message": "Hello from CI/CD!", "host": socket.gethostname(),
            "version": os.getenv("APP_VERSION", "dev")}

@app.get("/health")
def health():
    return {"status": "ok"}
```

`test_app.py`, the automatic tests the pipelines will run:

```python
from app import app

def test_index_returns_message():
    response = app.test_client().get("/")
    assert response.status_code == 200
    assert response.get_json()["message"] == "Hello from CI/CD!"

def test_health_is_ok():
    response = app.test_client().get("/health")
    assert response.get_json() == {"status": "ok"}
```

`requirements.txt` lists what the app needs to run, and `requirements-dev.txt` adds what's only needed for testing:

```text
flask==3.0.3
gunicorn==23.0.0
```

```text
-r requirements.txt
pytest==8.3.3
```

`Dockerfile`:

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
RUN useradd --create-home appuser
USER appuser
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}
EXPOSE 8000
CMD ["gunicorn", "-b", "0.0.0.0:8000", "app:app"]
```

`.dockerignore` and `.gitignore`:

```text
.git
.venv
__pycache__
.pytest_cache
reports
```

Check it all works **on your machine first**. A pipeline only automates what already works by hand:

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements-dev.txt
pytest -v                                   # 2 passed

docker build -t hello-app:local .
docker run -d --rm --name hello -p 8000:8000 hello-app:local
curl -s localhost:8000/health               # {"status":"ok"}
docker stop hello
```

Put it in Git, then push it to GitHub (and/or GitLab) as a new repository called `hello-app`:

```bash
git init -b main && git add . && git commit -m "Sample app for CI/CD guides"
git remote add origin git@github.com:<you>/hello-app.git
git push -u origin main
```

> **Tip:** No Python or Docker on your laptop? Open the **cloud lab machine** in the [Practice lab](#/lab). It has both.

## Which guide next?

> **In simple words:** Pick the tool your team uses first. The ideas carry over to the others.

| If your team uses… | Start with |
|---|---|
| GitHub to host code | [GitHub Actions](#/tool/github-actions) |
| GitLab to host code | [GitLab CI/CD](#/tool/gitlab-ci) |
| Jenkins (common in large companies) | [Jenkins](#/tool/jenkins) |
| Kubernetes, and wants GitOps deployments | [Argo CD](#/tool/argocd), after one of the CI tools |

Whichever you choose, finish with the Argo CD guide's **Sample application flow** step. It connects your CI tool to Argo CD for a full commit-to-production pipeline.
