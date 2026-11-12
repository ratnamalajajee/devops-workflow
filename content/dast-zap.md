# DAST: Testing the Running App with OWASP ZAP

DAST (Dynamic Application Security Testing) tests your application **while it runs**, from the outside, the way an attacker would: it sends requests and studies the responses. It doesn't need the source code. This guide lists the common DAST tools, then shows how to install **OWASP ZAP** and use it on your laptop, in **GitLab CI** and in **Jenkins**.

> **Note:** The pipeline steps on this page follow ZAP's documentation and **haven't been run in our pipelines yet**. Practise on the vulnerable demo app below, then try a test environment, in report mode first.

> **Note:** One guide per security tool: [Gitleaks](#/tool/gitleaks) · [SonarQube](#/tool/sonarqube) · [Trivy](#/tool/trivy) · [Snyk](#/tool/snyk) · [DAST with ZAP](#/tool/dast-zap).

## Start here: DAST in simple words

> **In simple words:** SAST reads the **blueprint** of the house. DAST walks around the **finished house** and tries every door and window. It finds what only shows up at run time: missing security headers, cookies without `Secure`, error pages that leak details, and injection holes.

### Passive and active scans

| Scan | What it does | Risk | Where |
|---|---|---|---|
| **Passive** (baseline) | Crawls the site and only **looks** at normal responses | Safe: just browsing | Any environment you're allowed to test, on every deploy |
| **Active** (full, API) | Sends **attack payloads**: SQL injection, XSS, path traversal… | Can create, change or delete data, and load the app | A **test** environment only, never production |

### Key words

| Word | Meaning |
|---|---|
| Target | The base URL you scan, for example `https://my-app.test.example.com` |
| Spider | Follows links to discover pages. The **AJAX spider** uses a real browser for single-page apps |
| Alert | One finding, with a rule ID (for example `10038`, CSP header not set) |
| Risk | High, Medium, Low or Informational |
| Confidence | How sure ZAP is: High, Medium, Low |
| Rules file | Your decision per rule: `IGNORE`, `INFO`, `WARN` or `FAIL` |
| Authenticated scan | A scan that logs in first, to reach the pages behind the login |

### Check yourself

1. Can SonarQube find a missing `Content-Security-Policy` header?
2. Why must active scans never point at production?
3. ZAP finds only the login page and a few 401 responses. Why?

> **Tip:** Answers: 1) No. The header is added at run time (by the app, a proxy or the load balancer), so only a test of the running app sees it. 2) Attack payloads can change real data and slow the service for real users. 3) The scan isn't authenticated, so everything behind the login is invisible to it.

> **Warning:** Only scan applications you own or have **written permission** to test. Scanning someone else's site can be illegal, even with a free tool.

## DAST tools you can use

> **In simple words:** ZAP is the free standard and is what this guide uses. The others are worth knowing by name.

| Tool | Type | Cost | Good to know |
|---|---|---|---|
| **OWASP ZAP** (Zed Attack Proxy) | Full DAST: GUI, Docker scans, API, automation | Free, open source | Baseline, full and API scan scripts made for CI |
| **Burp Suite** | Intercepting proxy + scanner | Community (free, manual), Professional and DAST (paid) | The pentester's favourite for manual testing |
| **Nuclei** (ProjectDiscovery) | Template-based scanner | Free, open source | Thousands of community templates for known CVEs and misconfigurations |
| **Nikto** | Web server scanner | Free | Quick checks for dangerous files and outdated servers |
| **GitLab DAST** | Built into GitLab CI | GitLab **Ultimate** | `include: - template: DAST.gitlab-ci.yml`; results in the MR security widget |
| **StackHawk** | ZAP-based, CI-first | Paid (with a free tier) | Config-as-code DAST for APIs |
| Invicti / Acunetix, Rapid7 InsightAppSec, Qualys WAS | Enterprise DAST | Paid | Scheduled scans, dashboards, compliance reports |

## Install ZAP

> **In simple words:** For pipelines, use the Docker image (nothing to install). For learning and manual testing, install the desktop app.

### Docker (pipelines and quick scans)

```bash
docker pull zaproxy/zap-stable:2.17.0
docker run --rm zaproxy/zap-stable:2.17.0 zap-baseline.py -h       # the options
```

The same images are on GitHub's registry: `ghcr.io/zaproxy/zaproxy:stable`. Pin a version tag in CI.

### Desktop app

| System | How |
|---|---|
| Windows | Download the Windows installer from [zaproxy.org/download](https://www.zaproxy.org/download/) and run it |
| macOS | `brew install --cask zap`, or the macOS package from the download page |
| Linux | `sudo snap install zaproxy --classic`, or the Linux installer from the download page |

ZAP needs Java 17 or later; the download page says which packages include it.

## Practise safely on a vulnerable demo app

> **In simple words:** **OWASP Juice Shop** is a web shop built to be insecure, for practice. Run it on your laptop and scan it as much as you like: nobody else is affected.

### 1. Start Juice Shop and a private network

```bash
docker network create zapnet
docker run -d --name juice-shop --network zapnet -p 3000:3000 bkimminich/juice-shop
```

Open `http://localhost:3000` to see the shop.

### 2. Run a baseline (passive) scan

Linux, macOS, WSL (ZAP runs as user `zap` in the container, so the report folder must be writable):

```bash
mkdir -p zap-reports && chmod 777 zap-reports
docker run --rm --network zapnet -v "$PWD/zap-reports:/zap/wrk:rw" zaproxy/zap-stable:2.17.0 \
  zap-baseline.py -t http://juice-shop:3000 -m 2 -r baseline.html -J baseline.json -I
```

PowerShell:

```powershell
New-Item -ItemType Directory -Force zap-reports | Out-Null
docker run --rm --network zapnet -v "${PWD}/zap-reports:/zap/wrk:rw" zaproxy/zap-stable:2.17.0 zap-baseline.py -t http://juice-shop:3000 -m 2 -r baseline.html -J baseline.json -I
```

Open `zap-reports/baseline.html`. Each alert shows the risk, the URLs where it was seen, a description and the fix.

### 3. Try an active (full) scan, on Juice Shop only

```bash
docker run --rm --network zapnet -v "$PWD/zap-reports:/zap/wrk:rw" zaproxy/zap-stable:2.17.0 \
  zap-full-scan.py -t http://juice-shop:3000 -m 2 -r full.html -I
```

This takes 10 to 30 minutes and finds more (for example injection problems). Compare `full.html` with `baseline.html`.

### 4. Clean up

```bash
docker rm -f juice-shop && docker network rm zapnet
```

## The three scan scripts and their options

> **In simple words:** ZAP's Docker image has three ready-made scripts: **baseline** (passive), **full** (active) and **API** (active, driven by an OpenAPI file). They share most options.

| Script | Does | Use it |
|---|---|---|
| `zap-baseline.py` | Spider for `-m` minutes, then passive checks only | Every deploy to a test environment |
| `zap-full-scan.py` | Spider, then **active** attacks | Nightly, test environment only |
| `zap-api-scan.py` | Imports an OpenAPI/Swagger, SOAP or GraphQL definition, then **active** attacks on every operation | APIs, test environment only |

| Option | Meaning |
|---|---|
| `-t URL` | Target (for the API scan: the OpenAPI URL or file) |
| `-f openapi` | API scan: the definition format (`openapi`, `soap`, `graphql`) |
| `-O host:port` | API scan: send requests to this host, whatever servers the definition lists |
| `-m 5` | Spider for up to 5 minutes |
| `-j` | Also use the AJAX spider (for JavaScript-heavy single-page apps) |
| `-c rules.tsv` | Rules file (next step) |
| `-g rules.tsv` | Generate a rules file listing every rule |
| `-r file.html` `-J file.json` `-w file.md` `-x file.xml` | Reports, written to `/zap/wrk` |
| `-I` | Don't fail on warnings (only `FAIL` rules set the exit code) |
| `-z "..."` | Extra ZAP options |

Exit codes: `0` nothing to report, `1` at least one `FAIL`, `2` warnings only (`-I` turns this into `0`), `3` the scan itself failed (for example the target is unreachable).

API scan example (test environment):

```bash
docker run --rm -v "$PWD/zap-reports:/zap/wrk:rw" zaproxy/zap-stable:2.17.0 \
  zap-api-scan.py -t https://api.test.example.com/openapi.json -f openapi -r api.html -J api.json -I
```

## Decide what fails: the rules file

> **In simple words:** Out of the box ZAP only **warns**. A rules file turns the alerts you care about into failures, and quiets the ones that don't apply to your app, each with a short reason.

Generate a file that lists every rule, then edit it:

```bash
docker run --rm -v "$PWD/zap-reports:/zap/wrk:rw" zaproxy/zap-stable:2.17.0 \
  zap-baseline.py -t http://juice-shop:3000 -g zap-rules.tsv
```

The format is **tab-separated**: rule ID, action, and the rule name in brackets. An example for a JSON API behind a gateway, where browser-page checks don't apply:

```text
# OWASP ZAP alert rules (passed to ZAP with -c). Format: <id><TAB><IGNORE|INFO|WARN|FAIL><TAB>(<name>)
#   IGNORE  false positive: not reported
#   FAIL    always fails the scan
# Rule IDs: https://www.zaproxy.org/docs/alerts/
10020	INFO	(Missing Anti-clickjacking Header)
10021	WARN	(X-Content-Type-Options Header Missing)
10038	INFO	(Content Security Policy (CSP) Header Not Set)
10049	INFO	(Non-Storable Content)
40012	FAIL	(Cross Site Scripting (Reflected))
40018	FAIL	(SQL Injection)
```

Commit it (for example as `security/zap-rules.tsv`) and pass it with `-c zap-rules.tsv`, after copying it into the folder mounted on `/zap/wrk`.

> **Tip:** Make sure your editor keeps the **tabs**. Spaces instead of tabs make ZAP skip the line silently.

## Scan an app that needs a login

> **In simple words:** Most of an app is behind a login. Give ZAP a token and it adds it to every request, so it can test those pages too.

For APIs that use a bearer token (for example from Keycloak or another OAuth server), ZAP's Docker scripts read three environment variables:

| Variable | Value |
|---|---|
| `ZAP_AUTH_HEADER_VALUE` | The header value, for example `Bearer eyJ…` |
| `ZAP_AUTH_HEADER` | The header name (default `Authorization`) |
| `ZAP_AUTH_HEADER_SITE` | Send it only to this host, for example `api.test.example.com` |

Get a token for a **dedicated test client** (OAuth client credentials) and pass it in:

```bash
TOKEN="$(curl -fsS -X POST "https://auth.test.example.com/realms/my-realm/protocol/openid-connect/token" \
  --data-urlencode grant_type=client_credentials \
  --data-urlencode client_id=dast-scanner \
  --data-urlencode "client_secret=$DAST_CLIENT_SECRET" | jq -r .access_token)"

docker run --rm -e ZAP_AUTH_HEADER_VALUE="Bearer $TOKEN" -e ZAP_AUTH_HEADER_SITE=api.test.example.com \
  -v "$PWD/zap-reports:/zap/wrk:rw" zaproxy/zap-stable:2.17.0 \
  zap-baseline.py -t https://api.test.example.com -r auth-baseline.html -I
```

> **Note:** The token must stay valid for the whole scan, so give the test client a longer access-token lifetime. For login forms and browser sessions, use ZAP's **Automation Framework** with an authentication context: see [ZAP authentication](https://www.zaproxy.org/docs/authentication/).

## ZAP desktop for manual testing

> **In simple words:** The desktop app is the best way to learn: you see every request ZAP sends and every response it gets.

1. Start ZAP. When it asks about session persistence, choose *No, I do not want to persist this session* for a quick test.
2. **Quick Start → Automated Scan.** URL to attack: `http://localhost:3000` (Juice Shop). Tick **Use traditional spider**; tick **Use AJAX spider** for single-page apps. **Attack**.
3. Watch the **Sites** tree fill up, then open the **Alerts** tab. Click an alert to see the request and response that triggered it.
4. **Manual Explore:** opens a browser that goes through ZAP. Click through the app (log in, add to basket…) so ZAP learns pages the spider can't find, then run **Active Scan** on that site.
5. **Report → Generate Report** for an HTML report.

## GitLab CI: step by step

> **In simple words:** Run ZAP **after** the deploy to a test environment. A baseline scan on every deploy, and optionally a full or API scan on a nightly schedule.

### 1. Commit the rules file

`security/zap-rules.tsv`, as in [Decide what fails](#/tool/dast-zap/decide-what-fails-the-rules-file).

### 2. Add the job after your deploy job

```yaml
stages: [security, build, test, deploy, dast]

dast-zap-baseline:
  stage: dast
  image:
    name: zaproxy/zap-stable:2.17.0
    entrypoint: [""]
  variables:
    DAST_TARGET_URL: "https://my-app.test.example.com"   # CHANGE: a TEST environment, never production
    ZAP_ENFORCE: "false"                                 # "true" = a FAIL rule fails the pipeline
  needs: [deploy-test]                                   # CHANGE: your deploy job
  script:
    - mkdir -p /zap/wrk zap-reports
    - cp security/zap-rules.tsv /zap/wrk/
    - |
      rc=0
      zap-baseline.py -t "$DAST_TARGET_URL" -m 5 -c zap-rules.tsv \
        -r zap-report.html -J zap-report.json -I || rc=$?
      cp /zap/wrk/zap-report.* zap-reports/ || true
      if [ "$rc" -eq 3 ]; then echo "ZAP could not run the scan (is the target reachable?)"; exit 1; fi
      if [ "$rc" -eq 1 ]; then
        echo "ZAP: a FAIL rule was hit. Open zap-report.html in the job artifacts."
        if [ "$ZAP_ENFORCE" = "true" ]; then exit 1; fi
        exit 4                                           # report mode: allowed to fail (orange)
      fi
  allow_failure:
    exit_codes: [4]
  artifacts:
    when: always
    expire_in: 30 days
    expose_as: "ZAP report"
    paths: [zap-reports/]
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

### 3. Nightly full scan (optional)

Copy the job as `dast-zap-full`, use `zap-full-scan.py` instead of `zap-baseline.py`, drop `needs`, and run it only from a schedule (`- if: $CI_PIPELINE_SOURCE == "schedule"`). Create the schedule in **Build → Pipeline schedules**.

### 4. Authenticated scan (optional)

Store the test client's secret as a masked variable `DAST_CLIENT_SECRET`, fetch a token in the script (as in [Scan an app that needs a login](#/tool/dast-zap/scan-an-app-that-needs-a-login)), and `export ZAP_AUTH_HEADER_VALUE` and `ZAP_AUTH_HEADER_SITE` before `zap-baseline.py`. The ZAP image may not include `jq`; read the token with `python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])'` instead.

> **Note:** The runner must reach the test environment. For an internal URL, use a self-managed runner inside that network.

## Jenkins: step by step

> **In simple words:** A stage that runs the ZAP Docker image against the test environment after the deploy, publishes the HTML report on the build page, and marks the build yellow or red when a `FAIL` rule is hit.

### 1. Prepare

- An agent with Docker that can reach the test environment.
- Plugins: **Pipeline**, **HTML Publisher** (to show the report on the build page).

### 2. The stage

```groovy
pipeline {
    agent { label 'docker-build' }                                   // CHANGE

    parameters {
        string(name: 'DAST_TARGET_URL', defaultValue: 'https://my-app.test.example.com', trim: true,
               description: 'A TEST environment, never production')  // CHANGE
        booleanParam(name: 'ZAP_ENFORCE', defaultValue: false, description: 'Fail the build when a FAIL rule is hit')
    }

    stages {
        stage('Checkout') {
            steps { checkout scm }
        }

        stage('DAST: ZAP baseline') {
            steps {
                sh '''
                    rm -rf zap-reports && mkdir -p zap-reports && chmod 777 zap-reports
                    cp security/zap-rules.tsv zap-reports/
                '''
                script {
                    def rc = sh(returnStatus: true, script: '''
                        docker run --rm -v "$WORKSPACE/zap-reports:/zap/wrk:rw" zaproxy/zap-stable:2.17.0 \
                          zap-baseline.py -t "$DAST_TARGET_URL" -m 5 -c zap-rules.tsv \
                          -r zap-report.html -J zap-report.json -I
                    ''')
                    if (rc == 3) { error 'ZAP could not run the scan (is the target reachable?)' }
                    if (rc == 1) {
                        if (params.ZAP_ENFORCE) { error 'ZAP: a FAIL rule was hit' }
                        unstable 'ZAP: a FAIL rule was hit (report mode): see the ZAP report'
                    }
                }
            }
            post {
                always {
                    publishHTML(target: [reportDir: 'zap-reports', reportFiles: 'zap-report.html',
                                         reportName: 'ZAP DAST report', allowMissing: true,
                                         keepAll: true, alwaysLinkToLastBuild: true])
                    archiveArtifacts artifacts: 'zap-reports/zap-report.*', allowEmptyArchive: true
                }
            }
        }
    }
}
```

> **Tip:** To scan a freshly built image **before** it's deployed anywhere, start it on a private Docker network next to ZAP. The [Jenkins DevSecOps Pipeline](#/tool/jenkins-devsecops/the-complete-jenkinsfile) has that stage ready to copy.

## Where DAST fits in the release

> **In simple words:** DAST is the last check before production: build, scan the code and the image, deploy to test, then attack the test deployment.

```text
 commit ─► Gitleaks ─► SonarQube ─► build ─► Trivy (gate) ─► push ─► deploy to TEST
                                                                         │
                                         ZAP baseline on every deploy ◄──┤
                                         ZAP full / API scan nightly ◄───┘
                                                                         │
                                          no FAIL alerts ──► promote to production
```

| Scan | When | Blocks? |
|---|---|---|
| Baseline | Every deploy to test | Start in report mode; block on a few `FAIL` rules once tuned |
| Full or API | Nightly | Report; triage the next morning |
| Manual (desktop or Burp) | Before major releases, or a yearly pentest | Findings become tickets |

## Troubleshooting

> **In simple words:** Most DAST problems are reachability, permissions on the report folder, or a scan that can't see past the login.

| Problem | Fix |
|---|---|
| Exit code 3, `Failed to access`, connection refused | The container can't reach the target. From Docker Desktop use `host.docker.internal`; for another container use a shared Docker network; in CI check the runner's network |
| `Permission denied` writing reports | ZAP runs as user `zap` (UID 1000). Make the mounted folder writable: `chmod 777 zap-reports` |
| Only the login page, 401s and health checks are found | Unauthenticated scan. Add a token ([Scan an app that needs a login](#/tool/dast-zap/scan-an-app-that-needs-a-login)) |
| A single-page app shows almost no pages | Add `-j` (AJAX spider), or use the API scan with the OpenAPI definition |
| A rule in `zap-rules.tsv` has no effect | The line has spaces instead of tabs, or the file wasn't copied into `/zap/wrk` |
| Full scan takes hours | Limit the spider (`-m`), scan the API definition instead, and run it nightly, not on every commit |
| The test environment slows down or data changes | Expected with active scans. Use a dedicated test environment and test accounts |

## Cheat sheet

> **In simple words:** The commands you'll use most.

```bash
IMG=zaproxy/zap-stable:2.17.0
# passive scan, report in ./zap-reports
docker run --rm -v "$PWD/zap-reports:/zap/wrk:rw" $IMG zap-baseline.py -t https://test.example.com -r report.html -I
# active scan (TEST environments only)
docker run --rm -v "$PWD/zap-reports:/zap/wrk:rw" $IMG zap-full-scan.py -t https://test.example.com -r full.html -I
# API scan from an OpenAPI definition
docker run --rm -v "$PWD/zap-reports:/zap/wrk:rw" $IMG zap-api-scan.py -t https://test.example.com/openapi.json -f openapi -r api.html -I
# generate a rules file, then use it
docker run --rm -v "$PWD/zap-reports:/zap/wrk:rw" $IMG zap-baseline.py -t https://test.example.com -g zap-rules.tsv
docker run --rm -v "$PWD/zap-reports:/zap/wrk:rw" $IMG zap-baseline.py -t https://test.example.com -c zap-rules.tsv -r report.html
# exit codes: 0 clean, 1 FAIL rule hit, 2 warnings (0 with -I), 3 scan error
```

Docs: [ZAP baseline scan](https://www.zaproxy.org/docs/docker/baseline-scan/) · [ZAP full scan](https://www.zaproxy.org/docs/docker/full-scan/) · [ZAP API scan](https://www.zaproxy.org/docs/docker/api-scan/) · [ZAP alert rules](https://www.zaproxy.org/docs/alerts/)
