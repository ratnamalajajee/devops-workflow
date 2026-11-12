# SonarQube: Static Code Analysis (SAST)

SonarQube reads your source code **without running it** and reports bugs, security vulnerabilities, security hotspots and code smells. A **quality gate** then gives one clear answer: pass or fail. This guide runs a SonarQube server, then analyses a Python repository step by step: from your laptop, from **GitLab CI** and from **Jenkins**. The settings are the ones that work in a real Python microservices project.

> **Note:** One guide per security tool: [Gitleaks](#/tool/gitleaks) · [SonarQube](#/tool/sonarqube) · [Trivy](#/tool/trivy) · [Snyk](#/tool/snyk) · [DAST with ZAP](#/tool/dast-zap). The [Jenkins DevSecOps Pipeline](#/tool/jenkins-devsecops) shows SonarQube for a Java (Maven) project.

## Start here: SonarQube in simple words

> **In simple words:** SonarQube is a **code reviewer that never gets tired**. It reads every line of every change and points at bugs and risky code. The quality gate is the pass mark: below it, the change isn't ready.

Think of the spelling and grammar checker in a word processor: it underlines mistakes as you write, long before an editor sees the text. SonarQube does that for code, with rules for Python, Java, JavaScript and about 30 other languages.

### Two parts: the scanner and the server

```text
 your code ──► sonar-scanner ─────────► SonarQube server ──► dashboard + quality gate
               (runs in the pipeline     (stores results,          │
                or on your laptop)        applies the rules)        │
                                                                    ▼
 pipeline ◄──────────────────── PASSED / FAILED ────────────────────┘
```

### Key words

| Word | Meaning |
|---|---|
| Server | The SonarQube web app and database. It keeps the history and decides the quality gate |
| Scanner | The command-line tool (`sonar-scanner`) that reads the code and uploads the analysis |
| Project key | The project's unique ID on the server, for example `my-app` |
| Token | The password the scanner uses. A **project analysis token** starts with `sqp_` |
| Bug | Code that is probably wrong (it will break at run time) |
| Vulnerability | Code that can be attacked (for example SQL built from user input) |
| Security hotspot | Security-sensitive code that a **person must review** (for example a hard-coded password or `shell=True`) |
| Code smell | Code that works but is hard to maintain |
| Quality gate | The pass/fail conditions, for example "no new issues, all new hotspots reviewed" |
| New code | The changes since a reference point. Gates usually judge only new code ("clean as you code") |

### Editions

| Edition | Cost | Good to know |
|---|---|---|
| **Community Build** | Free | Analyses the **main branch only**. No merge request decoration |
| Server: Developer, Enterprise | Paid | Branch and merge request analysis, results shown in the MR |
| SonarQube Cloud (was SonarCloud) | Free for public projects, paid for private | Hosted for you: no server to run |

### Check yourself

1. Does SonarQube run your application?
2. What's the difference between a vulnerability and a security hotspot?
3. Why does the gate look at new code only?

> **Tip:** Answers: 1) No, it only reads the source (that's what "static" means). DAST, such as [ZAP](#/tool/dast-zap), tests the running app. 2) A vulnerability is almost certainly a problem. A hotspot might be fine, so a person reviews it. 3) So old code doesn't block every change, while every new change is clean.

## How the working setup is organised

> **In simple words:** One properties file in the repository says what to analyse. The pipeline gets two settings: the server URL and a token. The scanner waits for the quality gate, and its exit code is the result.

```text
your-repo/
├── sonar-project.properties    what to analyse: folders, language version, exclusions
├── services/                   one folder per Python service
│   ├── orders-service/
│   └── billing-service/
└── shared-lib/
```

| Setting | Where it lives | Example |
|---|---|---|
| `SONAR_HOST_URL` | CI variable | `https://sonarqube.example.com` |
| `SONAR_TOKEN` | CI **secret** (masked) | `sqp_…` project analysis token |
| `-Dsonar.qualitygate.wait=true` | Scanner argument | The scanner waits for the gate and exits `1` if it fails |
| Scanner image | Pinned | `sonarsource/sonar-scanner-cli:12.3.1.4302_8.3.1` |
| Mode | Report by default, `SONAR_ENFORCE=true` to block | A failed gate first shows as a warning, later fails the pipeline |

> **Warning:** Store **only** the token value (`sqp_…`). A common mistake is pasting the whole line SonarQube shows, such as `Analyze "my-app": sqp_…`. The label and spaces make the token invalid, and the scanner may print the bad value in its error message.

## Run a SonarQube server

> **In simple words:** To learn and test, run SonarQube in Docker on your laptop. For a team, run it on a server or Kubernetes with a PostgreSQL database, so the results survive restarts and upgrades.

### On your laptop (Docker)

Linux, macOS, WSL:

```bash
docker run -d --name sonarqube -p 9000:9000 \
  -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
  -v sonarqube_data:/opt/sonarqube/data \
  -v sonarqube_extensions:/opt/sonarqube/extensions \
  -v sonarqube_logs:/opt/sonarqube/logs \
  sonarqube:community

docker logs -f sonarqube        # wait for "SonarQube is operational", then Ctrl+C
```

PowerShell (one line):

```powershell
docker run -d --name sonarqube -p 9000:9000 -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true -v sonarqube_data:/opt/sonarqube/data -v sonarqube_extensions:/opt/sonarqube/extensions -v sonarqube_logs:/opt/sonarqube/logs sonarqube:community
docker logs -f sonarqube
```

Open `http://localhost:9000`, log in as `admin` / `admin`, and set a new password. SonarQube needs about 2–4 GB of free memory; give Docker Desktop enough.

> **Note:** `SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true` skips the search engine's start-up checks. Use it on a laptop only. On a Linux server, set the kernel limits instead (below) and leave the variable out.

### On a Linux server (Docker Compose with PostgreSQL)

```bash
# Kernel limits required by SonarQube's search engine (once, as root)
echo -e "vm.max_map_count=524288\nfs.file-max=131072" | sudo tee /etc/sysctl.d/99-sonarqube.conf
sudo sysctl --system
```

`docker-compose.yml`:

```yaml
services:
  sonarqube:
    image: sonarqube:community
    depends_on: [db]
    ports: ["9000:9000"]
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://db:5432/sonar
      SONAR_JDBC_USERNAME: sonar
      SONAR_JDBC_PASSWORD: ${SONAR_DB_PASSWORD}      # from a .env file that is not committed
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs
  db:
    image: postgres:17
    environment:
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD: ${SONAR_DB_PASSWORD}
      POSTGRES_DB: sonar
    volumes:
      - postgresql:/var/lib/postgresql/data

volumes:
  sonarqube_data:
  sonarqube_extensions:
  sonarqube_logs:
  postgresql:
```

```bash
echo "SONAR_DB_PASSWORD=$(openssl rand -base64 24)" > .env
docker compose up -d
```

Put HTTPS in front of it (a load balancer or a reverse proxy), and make sure your **CI runners can reach the URL**.

### On Kubernetes (Helm, as on EKS)

The SonarQube Helm chart with an external PostgreSQL (for example Amazon RDS) and an internal ALB:

```bash
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo update
kubectl create namespace sonarqube
kubectl -n sonarqube create secret generic sonarqube-db --from-literal=password='<database password>'
kubectl -n sonarqube create secret generic sonarqube-monitoring --from-literal=passcode="$(openssl rand -hex 16)"
helm upgrade --install sonarqube sonarqube/sonarqube -n sonarqube -f sonarqube-values.yaml
```

`sonarqube-values.yaml`:

```yaml
community:
  enabled: true                          # the free Community Build
monitoringPasscodeSecretName: sonarqube-monitoring
monitoringPasscodeSecretKey: passcode    # keep the passcode in a Secret, not in this file
jdbcOverwrite:
  enabled: true
  jdbcUrl: jdbc:postgresql://<rds-endpoint>:5432/sonarqube    # CHANGE
  jdbcUsername: sonar
  jdbcSecretName: sonarqube-db
  jdbcSecretPasswordKey: password
persistence:
  enabled: true
  size: 10Gi
resources:
  requests: { cpu: 500m, memory: 4Gi }
  limits:   { cpu: "2",  memory: 4Gi }
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internal
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS": 443}]'
    alb.ingress.kubernetes.io/certificate-arn: <acm certificate arn>   # CHANGE
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /api/system/status
  hosts:
    - name: sonarqube.example.internal   # CHANGE
      path: /
      pathType: Prefix                   # the chart's default makes the ALB match "/" only
```

See [Helm per environment](#/tool/helm-environments) and [Load balancers](#/tool/aws-elb) for the pieces around it.

## Create the project and a token

> **In simple words:** Tell SonarQube about your project once, and create the token the scanner will use to log in. One project per repository.

1. **Projects → Create project → Local project.** Display name `my-app`, project key `my-app`, main branch `main`. **Next**.
2. **New code:** choose *Use the global setting* (or *Previous version*). **Create project**.
3. **Analysis method:** *Locally*. SonarQube offers to create a token: name it `ci-my-app`, pick an expiry, **Generate**, and copy the `sqp_…` value. You'll also use this token for GitLab or Jenkins.
4. **Quality gate:** the default **Sonar way** checks new code. If you don't import test coverage yet, copy the gate (**Quality Gates → Sonar way → Copy**), remove the coverage condition, and set the copy on your project (**Project settings → Quality Gate**).

| Token type | Prefix | Can do | Use it for |
|---|---|---|---|
| Project analysis token | `sqp_` | Analyse **one** project | CI pipelines (safest) |
| Global analysis token | `sqa_` | Analyse any project | A shared CI that scans many projects |
| User token | `squ_` | Anything the user can do | Your own API scripts. Avoid it in CI |

> **Warning:** A token is a password. Keep it in a CI secret or your shell, never in `sonar-project.properties` or the repository.

## Add sonar-project.properties

> **In simple words:** This file tells the scanner which folders are code, which are tests, and what to skip. The scanner reads it from the folder it runs in, so put it in the repository root.

```ini
# SonarQube analysis settings. The server URL and token come from the CI
# (SONAR_HOST_URL and SONAR_TOKEN), never from this file.
sonar.projectKey=my-app
sonar.projectName=my-app
sonar.sourceEncoding=UTF-8
sonar.python.version=3.11

# The Python application: the services and the shared library.
sonar.sources=services,shared-lib
sonar.tests=services,shared-lib
sonar.inclusions=**/*.py
sonar.test.inclusions=**/tests/**/*.py,**/test_*.py

# Tests are analysed as tests, not as source. Skip virtualenvs and tools.
sonar.exclusions=**/tests/**,**/test_*.py,**/.venv/**,**/migrations/**

# Coverage (optional, see the step "Add test coverage"):
# sonar.python.coverage.reportPaths=services/*/coverage.xml
```

## Analyse from your laptop

> **In simple words:** Run the scanner in Docker against your server, wait for the quality gate, then open the dashboard link it prints.

### 1. Set the token and URL for this terminal

Bash:

```bash
read -rsp "SonarQube token: " SONAR_TOKEN && export SONAR_TOKEN && echo
export SONAR_HOST_URL=http://localhost:9000
```

PowerShell:

```powershell
$env:SONAR_TOKEN = Read-Host "SonarQube token"
$env:SONAR_HOST_URL = "http://localhost:9000"
```

### 2. Run the scanner

The scanner container must reach the server. With **Docker Desktop** (Windows, macOS), `localhost` inside a container is the container itself, so use `host.docker.internal`. On **Linux**, use `--network host`.

PowerShell (Docker Desktop):

```powershell
docker run --rm -e SONAR_HOST_URL="http://host.docker.internal:9000" -e SONAR_TOKEN -v "${PWD}:/usr/src" sonarsource/sonar-scanner-cli:12.3.1.4302_8.3.1 -Dsonar.qualitygate.wait=true
```

macOS (Docker Desktop):

```bash
docker run --rm -e SONAR_HOST_URL="http://host.docker.internal:9000" -e SONAR_TOKEN \
  -v "$PWD:/usr/src" sonarsource/sonar-scanner-cli:12.3.1.4302_8.3.1 -Dsonar.qualitygate.wait=true
```

Linux:

```bash
docker run --rm --network host -e SONAR_HOST_URL -e SONAR_TOKEN \
  -v "$PWD:/usr/src" sonarsource/sonar-scanner-cli:12.3.1.4302_8.3.1 -Dsonar.qualitygate.wait=true
```

The end of the log tells you the result. Exit code `0` means the gate passed, `1` means it failed (or the analysis broke):

```text
INFO  ANALYSIS SUCCESSFUL, you can find the results at: http://localhost:9000/dashboard?id=my-app
INFO  QUALITY GATE STATUS: PASSED - View details on http://localhost:9000/dashboard?id=my-app
```

### 3. Without Docker

Download the SonarScanner CLI zip for your system from the [SonarScanner CLI downloads](https://binaries.sonarsource.com/?prefix=Distribution/sonar-scanner-cli/) (the `windows-x64`, `linux-x64` and `macosx` zips include Java), unzip it, add its `bin` folder to `PATH`, and run from the repository root:

```bash
sonar-scanner -Dsonar.qualitygate.wait=true
```

### 4. Read the results

| Tab | What to look at |
|---|---|
| **Overview** | Gate status, and new issues, hotspots, coverage and duplication on new code |
| **Issues** | Filter by **Type** (Vulnerability, Bug) and **Severity**. Each issue explains why and how to fix it |
| **Security Hotspots** | Review each one: **Safe**, **Fixed** or **Acknowledged**. Unreviewed hotspots fail the Sonar way gate |
| **Code** | Browse files with the issues shown on the lines |

### 5. Prove the gate works

The first analysis sets the baseline. Then add risky code on purpose (for example in a new file `services/demo/risky.py`), analyse again, and watch the gate fail:

```python
import subprocess

db_password = "admin123"                 # hard-coded credential: security hotspot

def run(cmd):
    return subprocess.call(cmd, shell=True)   # OS command from input: security hotspot
```

The **Overview** now shows new security hotspots and **QUALITY GATE STATUS: FAILED**. Delete the file and analyse again to get back to green.

## Add test coverage (optional)

> **In simple words:** SonarQube doesn't run your tests. Your pipeline runs them with `pytest-cov`, writes `coverage.xml`, and the scanner uploads it, so the gate can check that new code is tested.

```bash
pip install pytest pytest-cov
cd services/orders-service
pytest --cov=. --cov-report=xml:coverage.xml
cd -
```

Then, in `sonar-project.properties`:

```ini
sonar.python.coverage.reportPaths=services/*/coverage.xml
```

The file paths inside `coverage.xml` must match the repository's paths. If the tests run inside a Docker build, copy `coverage.xml` out of the image first, or run them in the CI job before the scanner.

## GitLab CI: step by step

> **In simple words:** Store the server URL and token as CI/CD variables, add one job that runs the scanner image, and the quality gate decides whether the job warns (report mode) or fails (enforce mode).

### 1. Add the variables

**Settings → CI/CD → Variables → Add variable:**

| Key | Value | Settings |
|---|---|---|
| `SONAR_HOST_URL` | `https://sonarqube.example.com` | Visible |
| `SONAR_TOKEN` | `sqp_…` (the bare token) | **Masked and hidden**. Tick **Protect** only if the job runs on protected branches only |

> **Note:** A **protected** variable is only given to pipelines on protected branches and tags. If the job runs on a feature branch, the token is empty and the scanner fails with `Not authorized`.

### 2. Make sure the runner can reach the server

GitLab.com shared runners come from the internet. If your SonarQube is private (inside a VPC), use a **self-managed runner** in the same network. See [Runners](#/tool/gitlab-ci/runners-gitlab-s-or-your-own).

### 3. Add the job

```yaml
stages: [security, build, test, deploy]

sonarqube:
  stage: security
  image:
    name: sonarsource/sonar-scanner-cli:12.3.1.4302_8.3.1
    entrypoint: [""]                       # GitLab needs a shell, not the image's entrypoint
  variables:
    GIT_DEPTH: "0"                         # full history: blame data and new-code detection
    SONAR_USER_HOME: "${CI_PROJECT_DIR}/.sonar"
    SONAR_ENFORCE: "false"                 # "true" = a failed gate fails the pipeline
  cache:
    key: sonar-cache
    paths: [.sonar/cache]
  script:
    - |
      rc=0
      sonar-scanner -Dsonar.qualitygate.wait=true -Dsonar.qualitygate.timeout=600 || rc=$?
      if [ "$rc" -ne 0 ]; then
        echo "Quality gate failed or analysis error: see the log above and the dashboard link."
        if [ "$SONAR_ENFORCE" = "true" ]; then exit 1; fi
        exit 3                             # report mode: allowed to fail (orange)
      fi
  allow_failure:
    exit_codes: [3]
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

### 4. Branches and merge requests

| Edition | What to do |
|---|---|
| **Community Build** | Analyse the **default branch only** (the `rules` above). Each analysis replaces the project's result, so a feature-branch scan would overwrite `main`. To check a branch anyway, give it its own project key: `-Dsonar.projectKey=my-app-${CI_COMMIT_REF_SLUG}` |
| **Developer and above** | Add `- if: $CI_PIPELINE_SOURCE == "merge_request_event"` to `rules`. The scanner detects GitLab's MR variables and the result appears in the merge request |

### 5. Test it

1. Run a pipeline on the default branch. The job log ends with `QUALITY GATE STATUS: PASSED`.
2. Push the risky file from [Prove the gate works](#/tool/sonarqube/analyse-from-your-laptop) to the default branch of a test project. The job turns orange (report mode), or red with `SONAR_ENFORCE=true`.
3. Remove the file again.

## Jenkins: step by step

> **In simple words:** Two ways. **A:** run the scanner's Docker image and let it wait for the gate (the working setup; no plugin, no webhook). **B:** use the SonarQube plugin, which adds a dashboard link to the job page but needs a webhook from SonarQube back to Jenkins.

### Option A: Docker scanner (recommended)

1. **Manage Jenkins → Credentials → (global) → Add Credentials:** kind **Secret text**, secret `sqp_…`, ID `sonarqube-token`.
2. Add the stage to your `Jenkinsfile`:

```groovy
pipeline {
    agent { label 'docker-build' }                             // CHANGE: an agent with Docker

    parameters {
        booleanParam(name: 'SONAR_ENFORCE', defaultValue: false,
                     description: 'Fail the build when the quality gate fails')
    }

    environment {
        SONAR_HOST_URL = 'https://sonarqube.example.com'       // CHANGE
        SONAR_IMAGE    = 'sonarsource/sonar-scanner-cli:12.3.1.4302_8.3.1'
    }

    stages {
        stage('Checkout') {
            steps { checkout scm }
        }

        stage('SAST: SonarQube') {
            steps {
                withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONAR_TOKEN')]) {
                    script {
                        def rc = sh(returnStatus: true, script: '''
                            mkdir -p "$HOME/.cache/sonar"
                            docker run --rm -u "$(id -u):$(id -g)" -e SONAR_TOKEN -e SONAR_HOST_URL \
                              -v "$WORKSPACE:/usr/src" -v "$HOME/.cache/sonar:/tmp/sonar-cache" -w /usr/src \
                              "$SONAR_IMAGE" \
                              -Dsonar.userHome=/tmp/sonar-cache -Dsonar.working.directory=/tmp/scannerwork \
                              -Dsonar.qualitygate.wait=true -Dsonar.qualitygate.timeout=600
                        ''')
                        if (rc != 0) {
                            if (params.SONAR_ENFORCE) {
                                error 'SonarQube quality gate failed (enforce mode): open the dashboard link in the log'
                            }
                            unstable 'SonarQube quality gate failed (report mode): open the dashboard link in the log'
                        }
                    }
                }
            }
        }
    }
}
```

3. Create a Pipeline job from SCM (as in the [Gitleaks guide](#/tool/gitleaks/jenkins-step-by-step)) and **Build Now**. The stage log ends with the gate status and the dashboard link.

> **Note:** `-Dsonar.working.directory=/tmp/scannerwork` keeps the scanner's temporary files out of the workspace, and the cache folder on the agent makes later runs faster.

### Option B: SonarQube Scanner plugin

1. **Manage Jenkins → Plugins:** install **SonarQube Scanner**.
2. **Manage Jenkins → System → SonarQube servers → Add:** name `sonarqube`, URL, token credential `sonarqube-token`.
3. **Manage Jenkins → Tools → SonarQube Scanner installations → Add:** name `sonar-scanner`, **Install automatically**.
4. In SonarQube: **Administration → Configuration → Webhooks → Create**, URL `https://<your-jenkins>/sonarqube-webhook/` (keep the trailing slash).
5. The stages:

```groovy
stage('SAST: SonarQube') {
    steps {
        script {
            def scannerHome = tool 'sonar-scanner'
            withSonarQubeEnv('sonarqube') {
                sh "${scannerHome}/bin/sonar-scanner"
            }
        }
    }
}
stage('Quality gate') {
    steps {
        timeout(time: 10, unit: 'MINUTES') {
            script {
                def qg = waitForQualityGate()
                if (qg.status != 'OK') {
                    if (params.SONAR_ENFORCE) { error "Quality gate: ${qg.status}" }
                    unstable "Quality gate: ${qg.status}"
                }
            }
        }
    }
}
```

## Handling findings

> **In simple words:** Fix real problems in the code. For everything else, record a decision in SonarQube with a comment, so the next person knows why.

| Finding | What to do |
|---|---|
| Vulnerability or bug | Fix the code (each issue has a "Why is this an issue?" and "How can I fix it?" tab), then analyse again |
| Security hotspot | **Security Hotspots** tab: review it and mark it **Safe** (with a comment why), **Fixed** or **Acknowledged** |
| False positive | Open the issue → change its status to **False positive**, with a comment. Needs the *Administer Issues* permission |
| Accepted risk | Change the status to **Accept**, with a comment and a ticket |
| Old code floods the results | Keep the gate on **new code** (the default). Fix old code as you touch it |
| Folder that isn't your code | Add it to `sonar.exclusions` |
| One line | `# NOSONAR` at the end of the line. Use it rarely: it hides every rule on that line |

## Troubleshooting

> **In simple words:** Most failures are the token, the network path from the scanner to the server, or the folders in `sonar-project.properties`.

| Problem | Fix |
|---|---|
| `Not authorized. Analyzing this project requires authentication` | Token missing, wrong or expired. In GitLab: a **protected** variable on an unprotected branch. Check that the secret holds only the `sqp_…` value |
| `You're not authorized to analyze this project or the project doesn't exist` | Wrong `sonar.projectKey`, or a project token from another project |
| `SonarQube server [http://localhost:9000] can not be reached` (from Docker) | Use `host.docker.internal` (Docker Desktop) or `--network host` (Linux) |
| Waiting for the quality gate times out | The server is busy. Check **Administration → Projects → Background Tasks**, and raise `sonar.qualitygate.timeout` |
| Server container stops: `max virtual memory areas vm.max_map_count [65530] is too low` | On a laptop, add `-e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true`. On a server, set `vm.max_map_count=524288` |
| `0 files indexed` or empty results | `sonar.sources` paths are wrong, or the scanner didn't run from the repository root |
| Warning `Shallow clone detected` | Set `GIT_DEPTH: "0"` in GitLab, or turn off shallow clone in Jenkins |
| Main branch result replaced by a branch scan | Community Build keeps one branch per project key. Scan only the default branch, or use one key per branch |
| Jenkins `waitForQualityGate` never returns | The webhook is missing, or SonarQube can't reach the Jenkins URL |
| `AccessDeniedException` on `.scannerwork` | Run with `-Dsonar.working.directory=/tmp/scannerwork` and a writable `sonar.userHome` |

## Cheat sheet

> **In simple words:** The commands and settings you'll reach for most.

```bash
# start a laptop server
docker run -d --name sonarqube -p 9000:9000 -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true sonarqube:community

# analyse the current folder (Linux; on Docker Desktop use host.docker.internal)
docker run --rm --network host -e SONAR_HOST_URL -e SONAR_TOKEN -v "$PWD:/usr/src" \
  sonarsource/sonar-scanner-cli:12.3.1.4302_8.3.1 -Dsonar.qualitygate.wait=true

# useful -D options
#   -Dsonar.projectKey=my-app              override the key
#   -Dsonar.qualitygate.wait=true          wait for the gate; exit 1 if it fails
#   -Dsonar.qualitygate.timeout=600        seconds to wait
#   -Dsonar.exclusions=**/generated/**     skip folders
#   -Dsonar.verbose=true                   debug logging

# ask the server for a project's gate status
curl -s -u "$SONAR_TOKEN:" "$SONAR_HOST_URL/api/qualitygates/project_status?projectKey=my-app"
```

Docs: [SonarQube Server documentation](https://docs.sonarsource.com/sonarqube-server/) · [Python rules](https://rules.sonarsource.com/python/)
