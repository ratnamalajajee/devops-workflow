# Snyk: Dependency Checking (SCA)

Snyk checks the **open-source libraries** your application uses (for Python: `requirements.txt`, Poetry, Pipenv) against its vulnerability database, and tells you which upgrade fixes each problem. The same CLI can also scan your code (Snyk Code), container images (Snyk Container) and infrastructure files (Snyk IaC). This guide covers the account, installation, and how to run Snyk on your laptop, in **GitLab CI** and in **Jenkins**. It ends with free alternatives.

> **Note:** The commands on this page follow Snyk's documentation and **haven't been run in our pipelines yet**. Try them on a test branch first, and keep findings in report mode until you trust the results.

> **Note:** One guide per security tool: [Gitleaks](#/tool/gitleaks) · [SonarQube](#/tool/sonarqube) · [Trivy](#/tool/trivy) · [Snyk](#/tool/snyk) · [DAST with ZAP](#/tool/dast-zap).

## Start here: Snyk in simple words

> **In simple words:** Your app is maybe 10% your code and 90% other people's libraries. Snyk is a **recall checker for those libraries**: it reads your dependency list, finds the ones with known security holes, and tells you the version to upgrade to.

A Python app that lists 20 packages in `requirements.txt` really installs 60 or more, because each package pulls in others (transitive dependencies). A vulnerability in any of them is a vulnerability in your app. Snyk builds the full tree and checks every node.

### What Snyk scans

| Product | CLI command | Scans | Type |
|---|---|---|---|
| **Snyk Open Source** | `snyk test` | Dependency files: `requirements.txt`, `poetry.lock`, `Pipfile`, `package.json`, `pom.xml`… | SCA |
| Snyk Code | `snyk code test` | Your source code | SAST (like [SonarQube](#/tool/sonarqube)) |
| Snyk Container | `snyk container test` | A container image and its base image | Image scan (like [Trivy](#/tool/trivy)) |
| Snyk IaC | `snyk iac test` | Terraform, Kubernetes, Helm, CloudFormation | Misconfiguration |

### Key words

| Word | Meaning |
|---|---|
| SCA | Software Composition Analysis: checking third-party libraries for known vulnerabilities |
| Direct / transitive dependency | A package you list yourself / a package that one of your packages needs |
| Snyk ID | Snyk's ID for one vulnerability, for example `SNYK-PYTHON-URLLIB3-1234567`. Often linked to a CVE |
| Upgrade path | The version of your **direct** dependency that brings in a fixed transitive one |
| `snyk test` | Check now and print the results (nothing is stored in Snyk) |
| `snyk monitor` | Upload a snapshot to the Snyk web app. Snyk e-mails you when **new** vulnerabilities affect it later |
| Organization | Your team's space in Snyk: projects, members, settings and the API token's scope |
| `.snyk` | The policy file in the repository: ignores with expiry dates, and language settings |

### Check yourself

1. Your `requirements.txt` doesn't list `urllib3`, yet Snyk reports it. Why?
2. What's the difference between `snyk test` and `snyk monitor`?
3. Snyk vs Trivy: which one would you run on a built image, and which on `requirements.txt` in a merge request?

> **Tip:** Answers: 1) It's a transitive dependency, for example of `requests`. 2) `test` checks now and prints; `monitor` stores a snapshot so Snyk can warn you about vulnerabilities published later. 3) Both can do both. Trivy is free and fast on images. Snyk adds a curated database, upgrade advice and fix merge requests on dependency files.

## Sign up and get a token

> **In simple words:** Create a free Snyk account, then get a token. The CLI on your laptop logs in with a browser; pipelines use the token.

1. Sign up at [app.snyk.io](https://app.snyk.io) (GitHub, GitLab, Google or Microsoft login). The free plan has a monthly limit on tests; check Snyk's plans page for the current numbers.
2. For your laptop, you don't need to copy anything: `snyk auth` opens the browser (next step).
3. For CI, get a token: **Account settings → General → Auth Token** (your personal token), or, on paid plans, **Organization settings → Service accounts** (a token that isn't tied to a person, recommended for pipelines).
4. Note your **organization slug** (in the URL: `app.snyk.io/org/<slug>`). Pass it with `--org=<slug>` when you belong to several organizations.

> **Warning:** The token gives access to your Snyk organization. Store it as a masked CI variable or a Jenkins credential, never in the repository.

## Install the Snyk CLI

> **In simple words:** Pick one way. npm is the most common; the standalone binary needs nothing else; Docker images come with Python already inside.

| System | Command |
|---|---|
| Any, with Node.js | `npm install -g snyk` |
| macOS | `brew tap snyk/tap` then `brew install snyk` |
| Windows (Scoop) | `scoop bucket add snyk https://github.com/snyk/scoop-snyk` then `scoop install snyk` |
| Windows (binary) | Download `snyk-win.exe` from [Snyk's release page](https://github.com/snyk/cli/releases), rename it `snyk.exe`, put it on your `PATH` |
| Linux (binary) | `curl -sSfL https://static.snyk.io/cli/latest/snyk-linux -o snyk && chmod +x snyk && sudo mv snyk /usr/local/bin/` |
| Docker | `snyk/snyk:python-3.11` (CLI + Python 3.11), and other tags such as `snyk/snyk:node` |

Check it and log in:

```bash
snyk --version
snyk auth                       # opens the browser; approve, then come back
```

In a terminal without a browser (a server or CI), set the token instead:

```bash
export SNYK_TOKEN=<your token>            # PowerShell: $env:SNYK_TOKEN = "<your token>"
```

> **Tip:** In CI, pin the CLI version instead of `latest`: for example `npm install -g snyk@<version>` or a versioned binary URL, so a new release can't change your results overnight.

## Scan a Python project locally

> **In simple words:** For Python, Snyk asks `pip` which versions are **really installed**, so first install the requirements into a virtual environment, then run `snyk test` in it.

### 1. Install the dependencies in a virtual environment

Bash:

```bash
cd services/orders-service
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

PowerShell:

```powershell
cd services/orders-service
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### 2. Test the dependencies

```bash
snyk test --file=requirements.txt --package-manager=pip --command=python
```

Useful options:

| Option | What it does |
|---|---|
| `--severity-threshold=high` | Only report (and fail on) high and critical |
| `--fail-on=upgradable` | Fail only when an upgrade fixes the problem |
| `--skip-unresolved` | Skip packages that aren't installed instead of stopping |
| `--all-projects` | Find and test every supported manifest under the folder |
| `--org=<slug>` | Use this Snyk organization |
| `--json-file-output=snyk.json` | Save a JSON report (the screen output stays readable) |
| `--sarif-file-output=snyk.sarif` | Save a SARIF report |

What the result looks like:

```text
Testing services/orders-service...

Tested 64 dependencies for known issues, found 2 issues, 2 vulnerable paths.

Issues to fix by upgrading dependencies:

  Upgrade urllib3@2.7.0 to urllib3@2.8.0 to fix
  ✗ Exposure of Sensitive Information [High Severity][https://security.snyk.io/vuln/SNYK-PYTHON-URLLIB3-…] in urllib3@2.7.0
    introduced by requests@2.32.3 > urllib3@2.7.0
```

The **Upgrade … to fix** line is the action. The **introduced by** line shows the path, so you know which direct dependency to change.

### 3. Exit codes

| Code | Meaning |
|---|---|
| `0` | No vulnerabilities at or above your threshold |
| `1` | Vulnerabilities found |
| `2` | Snyk failed (re-run with `-d` for debug output) |
| `3` | No supported project found (wrong folder or `--file`) |

### 4. Many services in one repository

Each service has its own `requirements.txt`, so test each one in its own environment:

```bash
rc=0
for req in services/*/requirements.txt; do
  svc="$(basename "$(dirname "$req")")"
  python3 -m venv "/tmp/venv-$svc" && . "/tmp/venv-$svc/bin/activate"
  pip install -q -r "$req"
  snyk test --file="$req" --package-manager=pip --command=python \
    --severity-threshold=high --project-name="$svc" --json-file-output="security-reports/snyk-$svc.json" || rc=1
  deactivate
done
exit $rc
```

### 5. The other scans (same login)

```bash
snyk code test                                                   # SAST on the source (turn Snyk Code on in the org settings first)
snyk container test orders-service:local --file=services/orders-service/Dockerfile   # image + base image advice
snyk iac test infra/                                             # Terraform / Kubernetes / Helm files
snyk monitor --file=requirements.txt --package-manager=pip --project-name=orders-service   # keep watching in the web app
```

### 6. An HTML report

```bash
npm install -g snyk-to-html
snyk test --file=requirements.txt --package-manager=pip --command=python --json | snyk-to-html -o snyk-report.html
```

## The .snyk policy file

> **In simple words:** `.snyk` in the repository root holds your **decisions**: which issues are accepted, why, and until when. The CLI and the Snyk web app both read it.

Accept an issue for a limited time (this writes it into `.snyk`):

```bash
snyk ignore --id=SNYK-PYTHON-URLLIB3-1234567 --expiry=2027-01-31 \
  --reason="Not reachable: only used by the CLI tool. Owner: platform team."
```

What the file looks like:

```yaml
# Snyk (https://snyk.io) policy file
version: v1.25.0
ignore:
  SNYK-PYTHON-URLLIB3-1234567:
    - '*':
        reason: 'Not reachable: only used by the CLI tool. Owner: platform team.'
        expires: 2027-01-31T00:00:00.000Z
language-settings:
  python: '3.11'      # the Python version Snyk uses for projects imported from Git
patch: {}
```

> **Tip:** Set `language-settings: python` to your real Python version. Without it, Snyk may resolve dependencies for a different Python version than the one your images run, and report the wrong package versions.

## The Snyk web app and Git integration

> **In simple words:** Besides the CLI, Snyk can connect straight to GitLab or GitHub, scan the repository every day, and open merge requests that upgrade vulnerable packages, with no pipeline changes at all.

1. In Snyk: **Integrations → GitLab** (or GitHub), give it an access token with `api` scope (GitLab) for an account that can read the repositories.
2. **Add projects →** pick the repository. Snyk finds every `requirements.txt` and creates one project per file.
3. **Projects** shows each file's issues, with **Fix this vulnerability** buttons that open a fix merge request.
4. **Reports** (paid plans) gives totals across all projects: by severity, fixable, ageing.

Use both: the Git integration for the daily overview and fix merge requests, the CLI in the pipeline to stop new problems.

## GitLab CI: step by step

> **In simple words:** Add the token as a masked variable, then a job in a Snyk image that has Python inside. The job installs the requirements, runs `snyk test`, and keeps the JSON report.

### 1. Add the token

**Settings → CI/CD → Variables → Add variable:** key `SNYK_TOKEN`, value the token, **Masked and hidden**.

### 2. Add the jobs

```yaml
stages: [security, build, test, deploy]

snyk-deps:
  stage: security
  image:
    name: snyk/snyk:python-3.11
    entrypoint: [""]
  variables:
    SNYK_SEVERITY: "high"
    SNYK_ENFORCE: "false"                     # "true" = findings fail the pipeline
  script:
    - mkdir -p security-reports
    - pip install -q -r services/orders-service/requirements.txt
    - |
      rc=0
      snyk test --file=services/orders-service/requirements.txt --package-manager=pip --command=python \
        --severity-threshold="$SNYK_SEVERITY" --json-file-output=security-reports/snyk.json || rc=$?
      if [ "$rc" -eq 1 ]; then
        echo "Snyk found vulnerabilities: see the log above and the snyk.json artifact."
        if [ "$SNYK_ENFORCE" = "true" ]; then exit 1; fi
        exit 4                                 # report mode: allowed to fail (orange)
      fi
      if [ "$rc" -ne 0 ]; then echo "Snyk could not run (exit $rc)"; exit 1; fi   # 2 or 3: a real error
  allow_failure:
    exit_codes: [4]                            # not 3: Snyk uses 3 for "no project found"
  artifacts:
    when: always
    expire_in: 30 days
    paths: [security-reports/]
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

snyk-monitor:
  stage: security
  image:
    name: snyk/snyk:python-3.11
    entrypoint: [""]
  script:
    - pip install -q -r services/orders-service/requirements.txt
    - snyk monitor --file=services/orders-service/requirements.txt --package-manager=pip --command=python --project-name=orders-service
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

For several services, use `parallel: matrix` with a `SERVICE` variable (see [Faster and cleaner pipelines](#/tool/gitlab-ci/faster-and-cleaner-pipelines)), or the loop from [Scan a Python project locally](#/tool/snyk/scan-a-python-project-locally).

### 3. Test it

On a test branch, lower a pin to an old version with a known problem (for example an old `urllib3` or `pillow`), push, and open a merge request. `snyk-deps` turns orange, and `snyk.json` lists the issue with its fix version. Revert the pin.

## Jenkins: step by step

> **In simple words:** Either run the Snyk CLI yourself (same commands as on your laptop), or use the **Snyk Security** plugin, which installs the CLI and adds a Snyk report page to each build.

### Option A: the CLI in a Docker image

1. **Manage Jenkins → Credentials → Add:** kind **Secret text**, ID `snyk-token`.
2. The stage:

```groovy
stage('SCA: Snyk') {
    steps {
        withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN')]) {
            script {
                def rc = sh(returnStatus: true, script: '''
                    mkdir -p security-reports
                    docker run --rm -e SNYK_TOKEN -v "$WORKSPACE:/project" -w /project snyk/snyk:python-3.11 sh -c '
                      pip install -q -r services/orders-service/requirements.txt &&
                      snyk test --file=services/orders-service/requirements.txt --package-manager=pip --command=python \
                        --severity-threshold=high --json-file-output=security-reports/snyk.json'
                ''')
                if (rc == 1) { unstable 'Snyk found vulnerabilities (report mode): see security-reports/snyk.json' }
                else if (rc != 0) { error "Snyk could not run (exit ${rc})" }
            }
        }
    }
    post {
        always { archiveArtifacts artifacts: 'security-reports/snyk.json', allowEmptyArchive: true }
    }
}
```

To block instead of warn, replace `unstable` with `error`.

### Option B: the Snyk Security plugin

1. **Manage Jenkins → Plugins:** install **Snyk Security**.
2. **Manage Jenkins → Tools → Snyk Installations → Add:** name `snyk-latest`, **Install automatically**.
3. **Manage Jenkins → Credentials → Add:** kind **Snyk API token**, ID `snyk-api-token`.
4. The stage (the agent needs Python and the installed requirements):

```groovy
stage('SCA: Snyk') {
    steps {
        sh 'python3 -m venv .venv && . .venv/bin/activate && pip install -q -r services/orders-service/requirements.txt'
        snykSecurity(
            snykInstallation: 'snyk-latest',
            snykTokenId: 'snyk-api-token',
            targetFile: 'services/orders-service/requirements.txt',
            severity: 'high',
            failOnIssues: false,                   // true = findings fail the build
            additionalArguments: '--package-manager=pip --command=.venv/bin/python'
        )
    }
}
```

Each build then has a **Snyk Security Report** link.

## Free alternatives for dependency checking

> **In simple words:** If you don't have Snyk, three free tools cover most of the same ground. The working project uses OWASP Dependency-Check and Trivy for this.

| Tool | Database | Good for | Command |
|---|---|---|---|
| **OWASP Dependency-Check** | NVD (needs a free [NVD API key](https://nvd.nist.gov/developers/request-an-api-key)) | Audits, HTML reports, many languages | See below |
| **pip-audit** | PyPI advisories / OSV | Fast Python-only checks | `pip install pip-audit && pip-audit -r requirements.txt` |
| **Trivy fs** | Trivy DB | Same tool as your image scan | `trivy fs --scanners vuln .` (see [Trivy](#/tool/trivy/run-it-locally-and-prove-it-works)) |

OWASP Dependency-Check in Docker, for Python `requirements.txt` files (the pip analyzer is marked experimental, so expect some false positives):

```bash
mkdir -p security-reports/dependency-check "$HOME/.cache/dependency-check"
docker run --rm -u "$(id -u):$(id -g)" -e NVD_API_KEY \
  -v "$PWD:/src:ro" -v "$HOME/.cache/dependency-check:/usr/share/dependency-check/data" \
  -v "$PWD/security-reports/dependency-check:/report" \
  owasp/dependency-check:13.0.0 \
  --project my-app --scan /src/services --scan /src/shared-lib \
  --enableExperimental --disablePoetry --disableOssIndex \
  --exclude '**/tests/**' --exclude '**/.venv/**' \
  --format HTML --format JSON --out /report \
  --nvdApiKey "$NVD_API_KEY" --failOnCVSS 7
```

The first run downloads the whole NVD (several minutes); the `~/.cache/dependency-check` folder keeps it for later runs. False positives go into a suppression XML file (`--suppression suppressions.xml`); the HTML report has a **suppress** button that writes the entry for you.

## Troubleshooting

> **In simple words:** Most Snyk problems are authentication, or Python packages that aren't installed where Snyk looks.

| Problem | Fix |
|---|---|
| `Authentication failed` / `MissingApiTokenError` | Run `snyk auth`, or set `SNYK_TOKEN`. In GitLab, check the variable isn't **protected** while the branch isn't |
| `Required packages missing` | Install the requirements first, in the same Python that `--command` points to. Or add `--skip-unresolved` |
| `Could not detect supported target files` (exit 3) | Wrong folder, or pass `--file=` and `--package-manager=pip` |
| Wrong versions reported | Snyk used another Python version. Use `--command=` with the right interpreter, and set `language-settings` in `.snyk` |
| `You have reached your monthly test limit` | The free plan's limit. Test only on merge requests and the default branch, or use `--severity-threshold` and a paid plan |
| Snyk and Trivy disagree | Different databases and matching rules. Check the specific ID on [security.snyk.io](https://security.snyk.io) and in the Trivy JSON |
| Belongs to several organizations | Add `--org=<slug>` |

## Cheat sheet

> **In simple words:** The commands you'll use most.

```bash
snyk --version
snyk auth                                         # log in (browser)
snyk test                                         # test the manifest in this folder
snyk test --file=requirements.txt --package-manager=pip --command=python
snyk test --all-projects --severity-threshold=high
snyk test --json-file-output=snyk.json            # save a report
snyk monitor --project-name=orders-service        # keep watching in the web app
snyk code test                                    # SAST
snyk container test IMAGE --file=Dockerfile       # image + base image advice
snyk iac test infra/                              # Terraform / Kubernetes / Helm
snyk ignore --id=SNYK-… --expiry=2027-01-31 --reason="…"
```

Docs: [Snyk CLI documentation](https://docs.snyk.io/snyk-cli) · [Snyk vulnerability database](https://security.snyk.io)
