# Gitleaks: Secret Scanning

Gitleaks finds passwords, API keys and tokens that were committed to Git by mistake. This guide sets it up step by step: first on your laptop, then as a job in **GitLab CI** and as a stage in **Jenkins**. The commands, config files and pinned version are the ones that run in a real Python microservices project, where the scan checks every branch.

> **Note:** One guide per security tool: [Gitleaks](#/tool/gitleaks) · [SonarQube](#/tool/sonarqube) · [Trivy](#/tool/trivy) · [Snyk](#/tool/snyk) · [DAST with ZAP](#/tool/dast-zap). To see all of them in one pipeline, read [Jenkins DevSecOps Pipeline](#/tool/jenkins-devsecops).

## Start here: Gitleaks in simple words

> **In simple words:** Gitleaks is a **metal detector for secrets**. It reads your code (and, if you ask, every old commit) looking for anything shaped like a password, key or token, and tells you the file and the line.

Think of the bag check at the airport. If something forbidden is in your bag, you want it found at the gate, not after take-off. A secret is the same: once it's pushed, everyone with a clone of the repository has it, and deleting it in the next commit doesn't take it back.

### How it finds secrets

- **Rules:** about 200 built-in patterns, for example AWS access keys (`AKIA…`), GitHub and GitLab tokens, Slack tokens, private keys (`-----BEGIN … PRIVATE KEY-----`) and generic `api_key = "…"` lines.
- **Entropy:** random-looking strings score high and plain words score low. A score threshold cuts false positives such as `password = "changeme"`.
- **Keywords:** a rule only runs on lines that contain its keyword, which keeps the scan fast.

### Key words

| Word | Meaning |
|---|---|
| Secret | Anything that grants access: a password, API key, token, private key or connection string |
| Rule | One pattern Gitleaks looks for, with an ID such as `aws-access-token` |
| Finding | One match: the rule, file, line and (for history scans) commit |
| Fingerprint | The unique ID of one finding: `file:rule:line` for a folder scan, `commit:file:rule:line` for a history scan. You use it to accept a finding |
| Redact | Hide the secret value in the log and the reports, so the scan doesn't leak it again |
| Report mode | Findings are listed and the pipeline carries on (shown as a warning) |
| Enforce mode | A finding fails the pipeline |

### Three ways to scan

| Command | What it reads | Use it for |
|---|---|---|
| `gitleaks dir .` | The files as they are now | Every pipeline run. Works on shallow CI clones |
| `gitleaks git .` | Every commit in the history | Once on a full clone, then from time to time |
| `gitleaks git --pre-commit --staged` | The changes you're about to commit | A pre-commit hook on your laptop |

### Check yourself

1. A key was committed, and the next commit deleted it. Is it safe now?
2. Why does the pipeline use `gitleaks dir` and not `gitleaks git`?
3. What does `--redact` do?

> **Tip:** Answers: 1) No. It's still in the Git history and in every clone. Rotate (replace) the key. 2) CI clones are usually shallow (1 to 20 commits), so there's little history to read. `dir` checks exactly what is in the branch. 3) It hides the secret's value in the output and reports.

## How the working setup is organised

> **In simple words:** Two small files in the repository root control Gitleaks. The laptop, GitLab and Jenkins all run the same image with the same files, so a finding looks the same everywhere.

```text
your-repo/
├── .gitleaks.toml          the rules: built-in rules + paths to skip
├── .gitleaksignore         accepted findings, one fingerprint per line
├── .gitignore              contains security-reports/
└── security-reports/       written by the scan (never committed)
    ├── gitleaks.json       every finding, for people and scripts
    └── junit/gitleaks.xml  one failed "test" per finding, for the CI test tab
```

The scan itself is a single command:

```bash
gitleaks dir . --config .gitleaks.toml --redact --no-banner --verbose \
  --exit-code 1 --report-format json --report-path security-reports/gitleaks.json
```

| Choice | Value | Why |
|---|---|---|
| Version | `v8.30.1`, pinned | Same results on every machine. Upgrade on purpose, not by surprise |
| Image | `zricethezav/gitleaks:v8.30.1` (also `ghcr.io/gitleaks/gitleaks:v8.30.1`) | Nothing to install on the build agent |
| Target | `dir .` (the branch's files) | CI clones are shallow, so there's no history to scan |
| Mode | Report by default, enforce with `GITLEAKS_ENFORCE=true` | See the findings first, then switch on blocking once the repository is clean |
| Reports | JSON plus JUnit | JSON to read, JUnit for the test tab in GitLab and Jenkins |

## Install Gitleaks on your laptop

> **In simple words:** Pick one way. Docker needs no installation. The native binary is faster for daily use and for the pre-commit hook.

### Windows

```powershell
# Option 1: Scoop
scoop install gitleaks

# Option 2: Chocolatey (in an admin PowerShell)
choco install gitleaks

gitleaks version
```

Or download `gitleaks_8.30.1_windows_x64.zip` from the [Gitleaks releases page](https://github.com/gitleaks/gitleaks/releases), unzip it, and put `gitleaks.exe` in a folder that is on your `PATH`.

### macOS

```bash
brew install gitleaks
gitleaks version
```

### Linux (pinned version, checksum verified)

```bash
VERSION=8.30.1
cd /tmp
curl -sSfLO "https://github.com/gitleaks/gitleaks/releases/download/v${VERSION}/gitleaks_${VERSION}_linux_x64.tar.gz"
curl -sSfLO "https://github.com/gitleaks/gitleaks/releases/download/v${VERSION}/gitleaks_${VERSION}_checksums.txt"
grep " gitleaks_${VERSION}_linux_x64.tar.gz$" "gitleaks_${VERSION}_checksums.txt" | sha256sum -c -
sudo tar -xzf "gitleaks_${VERSION}_linux_x64.tar.gz" -C /usr/local/bin gitleaks
gitleaks version
```

### Docker (no installation)

```bash
docker pull zricethezav/gitleaks:v8.30.1
docker run --rm zricethezav/gitleaks:v8.30.1 version
```

> **Tip:** The checksum line must print `OK`. Security tools are a favourite target for supply-chain attacks, so always pin an exact version and verify what you download.

## Add the config files to your repository

> **In simple words:** `.gitleaks.toml` says **what to look for and where not to look**. `.gitleaksignore` lists the findings someone has checked and accepted.

`.gitleaks.toml` in the repository root:

```toml
# Gitleaks configuration: the built-in rules, plus paths that are never source.
# Never allowlist a real secret here. Rotate it, remove it, and if the file must
# stay (a test fixture), add that finding's Fingerprint to .gitleaksignore.
title = "my-app"

[extend]
useDefault = true            # keep all built-in rules

[[allowlists]]
description = "Generated, vendored and scanner-output paths"
paths = [
  '''(^|/)\.git/''',
  '''(^|/)node_modules/''',
  '''(^|/)\.venv/''',
  '''(^|/)security-reports/''',
]
```

Need a rule for your company's own token format? Add it to the same file:

```toml
[[rules]]
id = "myco-api-key"
description = "MyCo internal API key"
regex = '''myco_[a-z0-9]{32}'''
keywords = ["myco_"]
```

Create an empty `.gitleaksignore` (you'll fill it in [Handling findings](#/tool/gitleaks/handling-findings)), and keep reports out of Git:

```bash
touch .gitleaksignore
echo "security-reports/" >> .gitignore
git add .gitleaks.toml .gitleaksignore .gitignore
git commit -m "Add Gitleaks configuration"
```

## Run it locally and prove it works

> **In simple words:** Run a clean scan, then plant a **fake** key on purpose and watch Gitleaks catch it. That proves the scanner and your config work before you trust them in CI.

### 1. Scan the working tree

Linux, macOS, WSL or Git Bash:

```bash
mkdir -p security-reports
gitleaks dir . --config .gitleaks.toml --redact --no-banner --verbose \
  --report-format json --report-path security-reports/gitleaks.json
echo "exit code: $?"          # 0 = nothing found, 1 = secrets found
```

PowerShell:

```powershell
New-Item -ItemType Directory -Force security-reports | Out-Null
gitleaks dir . --config .gitleaks.toml --redact --no-banner --verbose --report-format json --report-path security-reports/gitleaks.json
"exit code: $LASTEXITCODE"
```

With Docker instead of the binary (Linux, macOS, WSL):

```bash
docker run --rm -u "$(id -u):$(id -g)" -v "$PWD:/repo" -w /repo zricethezav/gitleaks:v8.30.1 \
  dir . --config .gitleaks.toml --redact --no-banner --verbose \
  --report-format json --report-path security-reports/gitleaks.json
```

With Docker from PowerShell:

```powershell
docker run --rm -v "${PWD}:/repo" -w /repo zricethezav/gitleaks:v8.30.1 dir . --config .gitleaks.toml --redact --no-banner --verbose --report-format json --report-path security-reports/gitleaks.json
```

> **Note:** In **Git Bash** on Windows, Docker paths such as `/repo` get rewritten to `C:/Program Files/Git/repo`. Put `MSYS_NO_PATHCONV=1` in front of the `docker run` command, or use PowerShell.

### 2. Plant a fake key

The key is generated at random when you run the command, so it's never a real one (and this page doesn't contain one).

Bash:

```bash
echo "aws_access_key_id = AKIA$(LC_ALL=C tr -dc 'A-Z2-7' </dev/urandom | head -c 16)" > leak-test.txt
gitleaks dir . --config .gitleaks.toml --redact --no-banner --verbose
```

PowerShell:

```powershell
$k = -join ((65..90) + (50..55) | Get-Random -Count 16 | ForEach-Object { [char]$_ })
"aws_access_key_id = AKIA$k" | Set-Content leak-test.txt
gitleaks dir . --config .gitleaks.toml --redact --no-banner --verbose
```

You should see a finding like this, and exit code 1:

```text
Finding:     aws_access_key_id = REDACTED
Secret:      REDACTED
RuleID:      aws-access-token
Entropy:     3.62
File:        leak-test.txt
Line:        1
Fingerprint: leak-test.txt:aws-access-token:1

WRN leaks found: 1
```

### 3. Clean up

```bash
rm leak-test.txt            # PowerShell: Remove-Item leak-test.txt
```

Never commit the test file. If you do commit it on a test branch, it's fake, so there's nothing to rotate. Just drop the commit.

### 4. Scan the whole history once

CI only sees the latest files. Run a full history scan once on a full clone, and again from time to time:

```bash
git clone https://gitlab.example.com/team/my-app.git my-app-full    # CHANGE: your repository
cd my-app-full
gitleaks git . --config .gitleaks.toml --redact --no-banner --verbose \
  --report-format json --report-path ../gitleaks-history.json
```

To scan only the commits on your branch that are not on `main` yet, add `--log-opts="origin/main..HEAD"`.

## Stop secrets before they are committed

> **In simple words:** A Git **pre-commit hook** runs Gitleaks on your staged changes every time you type `git commit`. A secret then never even reaches your local history.

### Option A: the pre-commit framework (shared with the team)

`.pre-commit-config.yaml` in the repository root:

```yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.30.1
    hooks:
      - id: gitleaks
```

```bash
pip install pre-commit
pre-commit install                       # once per clone
pre-commit run gitleaks --all-files      # test it now
```

### Option B: a plain Git hook (just your clone)

Save this as `.git/hooks/pre-commit`:

```bash
#!/usr/bin/env bash
exec gitleaks git --pre-commit --staged --redact --no-banner --verbose
```

```bash
chmod +x .git/hooks/pre-commit
```

> **Warning:** Anyone can skip a hook with `git commit --no-verify`. A hook is a seatbelt for developers, not a control. The CI scan is the control.

## GitLab CI: step by step

> **In simple words:** Add one job to `.gitlab-ci.yml`. It runs the same image and command as your laptop, saves the reports, and lists each finding in the merge request's **Tests** tab. A variable switches it between warning (report mode) and failing (enforce mode).

### 1. Commit the config files

`.gitleaks.toml`, `.gitleaksignore` (it may be empty) and `security-reports/` in `.gitignore`, as in the steps above.

### 2. Add the job

```yaml
stages: [security, build, test, deploy]

gitleaks:
  stage: security
  image:
    name: zricethezav/gitleaks:v8.30.1
    entrypoint: [""]                 # the image starts gitleaks by default; GitLab needs a shell
  variables:
    GITLEAKS_ENFORCE: "false"        # "true" = a finding fails the pipeline
  script:
    - mkdir -p security-reports/junit
    - |
      rc=0
      gitleaks dir . --config .gitleaks.toml --redact --no-banner --verbose \
        --exit-code 1 --report-format json --report-path security-reports/gitleaks.json || rc=$?
      # JUnit copy for the Tests tab (one failed test per finding)
      gitleaks dir . --config .gitleaks.toml --redact --no-banner --exit-code 0 \
        --report-format junit --report-path security-reports/junit/gitleaks.xml >/dev/null 2>&1 || true
      if [ "$rc" -ne 0 ]; then
        echo "Gitleaks found secrets: see the log above and the gitleaks.json artifact."
        if [ "$GITLEAKS_ENFORCE" = "true" ]; then exit 1; fi
        exit 3                       # report mode: allowed to fail (orange), see allow_failure
      fi
  allow_failure:
    exit_codes: [3]
  artifacts:
    when: always
    expire_in: 30 days
    paths: [security-reports/]
    reports:
      junit: security-reports/junit/gitleaks.xml
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

How the two modes look:

| Result | Report mode (`GITLEAKS_ENFORCE=false`) | Enforce mode (`true`) |
|---|---|---|
| No secrets | ✅ green | ✅ green |
| Secrets found | ⚠️ orange: job "allowed to fail", pipeline continues | ❌ red: pipeline stops |
| Scan error (bad config) | ❌ red | ❌ red |

### 3. Switch to enforce mode

Once the default branch scans clean, go to **Settings → CI/CD → Variables → Add variable**: key `GITLEAKS_ENFORCE`, value `true`. That overrides the `false` in the YAML for every pipeline. To try it once first: **Build → Pipelines → Run pipeline**, then add the variable for that run only.

### 4. Test it

1. Create a branch, plant a fake key as in [Run it locally](#/tool/gitleaks/run-it-locally-and-prove-it-works), commit and push.
2. Open a merge request. The `gitleaks` job turns orange (report mode) or red (enforce mode).
3. Open the job log, the MR's **Tests** tab, and the `gitleaks.json` artifact (**Browse** on the job page).
4. Delete the branch.

### Optional: scan only the new commits of a merge request

This reads the history of the MR's commits, so it also catches a secret that was added and then deleted inside the MR:

```yaml
gitleaks-mr-commits:
  stage: security
  image:
    name: zricethezav/gitleaks:v8.30.1
    entrypoint: [""]
  variables:
    GIT_DEPTH: "0"                   # full history, so the base commit is there
  script:
    - git config --global --add safe.directory "$CI_PROJECT_DIR"
    - |
      gitleaks git . --config .gitleaks.toml --redact --no-banner --verbose         --log-opts="$CI_MERGE_REQUEST_DIFF_BASE_SHA..$CI_COMMIT_SHA"
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
```

> **Note:** GitLab also ships its own **Secret Detection** template, built on Gitleaks: `include: - template: Jobs/Secret-Detection.gitlab-ci.yml`. It runs on every tier, but the findings appear in the MR security widget only on **Ultimate**. The job above works the same on every tier and uses your own config.

## Jenkins: step by step

> **In simple words:** Add one stage to your `Jenkinsfile`. The agent runs the Gitleaks Docker image on the workspace, Jenkins lists the findings under **Tests**, and a build parameter decides whether a finding makes the build **UNSTABLE** (report mode) or **FAILED** (enforce mode).

### 1. Prepare the agent

- A Linux agent with Docker, and the agent user in the `docker` group (`sudo usermod -aG docker jenkins`, then restart the agent).
- Plugins: **Pipeline**, **Git**, **JUnit** (installed with the suggested plugins).
- No Gitleaks installation needed: the stage runs the pinned Docker image.

### 2. Add the stage

`Jenkinsfile` (a complete pipeline with only this scan; copy the stage into your own pipeline):

```groovy
pipeline {
    agent { label 'docker-build' }                    // CHANGE: an agent with Docker

    parameters {
        booleanParam(name: 'GITLEAKS_ENFORCE', defaultValue: false,
                     description: 'Fail the build when Gitleaks finds a secret')
    }

    environment {
        GITLEAKS_IMAGE = 'zricethezav/gitleaks:v8.30.1'
    }

    stages {
        stage('Checkout') {
            steps { checkout scm }
        }

        stage('Secret scan: Gitleaks') {
            steps {
                sh 'mkdir -p security-reports/junit'
                script {
                    def rc = sh(returnStatus: true, script: '''
                        docker run --rm -u "$(id -u):$(id -g)" -v "$WORKSPACE:/repo" -w /repo "$GITLEAKS_IMAGE" \
                          dir . --config .gitleaks.toml --redact --no-banner --verbose \
                          --exit-code 1 --report-format json --report-path security-reports/gitleaks.json
                    ''')
                    sh '''
                        docker run --rm -u "$(id -u):$(id -g)" -v "$WORKSPACE:/repo" -w /repo "$GITLEAKS_IMAGE" \
                          dir . --config .gitleaks.toml --redact --no-banner --exit-code 0 \
                          --report-format junit --report-path security-reports/junit/gitleaks.xml >/dev/null 2>&1 || true
                    '''
                    if (rc != 0) {
                        if (params.GITLEAKS_ENFORCE) {
                            error 'Gitleaks found secrets (enforce mode): see security-reports/gitleaks.json'
                        }
                        unstable 'Gitleaks found secrets (report mode): see security-reports/gitleaks.json'
                    }
                }
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'security-reports/junit/gitleaks.xml'
                    archiveArtifacts artifacts: 'security-reports/**', allowEmptyArchive: true
                }
            }
        }
    }
}
```

### 3. Create the job and run it

1. **New Item →** name it, choose **Pipeline** (or **Multibranch Pipeline** to scan every branch) → **OK**.
2. **Pipeline → Definition:** *Pipeline script from SCM*, **SCM:** Git, your repository URL and credentials, **Script Path:** `Jenkinsfile`. Save.
3. **Build Now.** The first run reads the `parameters` block; after that you get **Build with Parameters**.
4. Open the stage log, **Tests** (one failed test per finding) and **Artifacts → security-reports/gitleaks.json**.

### 4. Test it

Push a branch with a fake key (as in [Run it locally](#/tool/gitleaks/run-it-locally-and-prove-it-works)) and build it. The build turns **yellow (UNSTABLE)**. Build again with `GITLEAKS_ENFORCE` ticked and it turns **red (FAILED)**.

### Without Docker

Install the binary on the agent (the Linux steps in [Install Gitleaks](#/tool/gitleaks/install-gitleaks-on-your-laptop)) and call `gitleaks dir . --config .gitleaks.toml ...` directly, without the `docker run ... "$GITLEAKS_IMAGE"` part.

> **Tip:** Jenkins clones the full history by default, so a Jenkins stage can also run `gitleaks git .` to scan every commit.

## Handling findings

> **In simple words:** A real secret is an **incident**: rotate it first, then clean up. A false positive gets a written, reviewed exception, never a silent one.

| Situation | What to do |
|---|---|
| **Real secret** | 1) **Rotate or revoke it now** where it was issued (AWS IAM, GitLab, the database…). 2) Remove it from the code and read it from an environment variable or a secret store (AWS Secrets Manager, Vault, CI variables). 3) Optionally rewrite history with `git filter-repo`. Rotation is what makes you safe, because clones keep the old history |
| Test fixture or fake value | Add the finding's **Fingerprint** to `.gitleaksignore`, with a comment saying why |
| Folder that never holds real secrets (generated, vendored) | Add the path to the `[[allowlists]]` in `.gitleaks.toml` |
| One line in the code | End the line with the comment `gitleaks:allow` (for example `# gitleaks:allow` in Python) |
| Many old findings when you first switch it on | Make a baseline once, then only new findings count: `gitleaks dir . --report-path gitleaks-baseline.json`, then add `--baseline-path gitleaks-baseline.json` to the scan |

`.gitleaksignore` example:

```text
# Fake token in a unit-test fixture. Reviewed by the platform team 2026-11-12. Look again 2027-05-01.
services/auth/tests/fixtures/token.txt:generic-api-key:4
```

> **Warning:** Never put a real secret on an allowlist because "it's only dev". Dev credentials often open more doors than you think.

## Troubleshooting

> **In simple words:** Most problems are about paths (which folder the container sees), Git history depth, or the config file not being found.

| Problem | Fix |
|---|---|
| `config file not found` / `open .gitleaks.toml: no such file` | Run from the repository root, or with `-w /repo` in Docker. Check the file is committed |
| Gitleaks finds nothing, but you planted a key | Check the `scanned ~N bytes` line: if it's tiny, the container is looking at the wrong folder. Check the `-v` and `-w` options |
| `fatal: detected dubious ownership in repository` | The repository belongs to another user ID. Run the container with `-u "$(id -u):$(id -g)"`, or run `git config --global --add safe.directory "$PWD"` |
| Git Bash: `the working directory 'C:/Program Files/Git/repo' is invalid` | Put `MSYS_NO_PATHCONV=1` in front of `docker run`, or use PowerShell |
| GitLab job prints the Gitleaks help instead of running the script | Add `entrypoint: [""]` under `image:` |
| `gitleaks git` finds nothing in GitLab | The clone is shallow. Set `GIT_DEPTH: "0"` |
| Findings in `node_modules/`, `.venv/` or build output | Add the folder to `[[allowlists]] paths` |
| Same finding keeps coming back after you added it to `.gitleaksignore` | The fingerprint includes the line number. If the line moved, copy the new fingerprint from the latest report |
| Jenkins: `permission denied … /var/run/docker.sock` | The agent user isn't in the `docker` group. Add it and restart the agent |

## Cheat sheet

> **In simple words:** The commands and options you'll use every week.

```bash
gitleaks version
gitleaks dir .                                   # files as they are now (CI)
gitleaks git .                                   # every commit (needs a full clone)
gitleaks git . --log-opts="origin/main..HEAD"    # only this branch's new commits
gitleaks git --pre-commit --staged               # what you are about to commit

# common options
#   --config .gitleaks.toml     rules and allowlists
#   --redact                    hide secret values in output and reports
#   --no-banner --verbose       no logo; print every finding
#   --report-format json        or junit, sarif, csv
#   --report-path FILE          where to write the report
#   --exit-code 0               never fail (report only)
#   --baseline-path old.json    ignore findings already in old.json

# Docker, from the repository root
docker run --rm -u "$(id -u):$(id -g)" -v "$PWD:/repo" -w /repo zricethezav/gitleaks:v8.30.1 dir . --redact -v
```

Docs: [Gitleaks on GitHub](https://github.com/gitleaks/gitleaks) · [Default rules](https://github.com/gitleaks/gitleaks/blob/master/config/gitleaks.toml)
