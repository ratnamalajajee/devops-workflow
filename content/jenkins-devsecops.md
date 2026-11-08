# Jenkins DevSecOps Pipeline: Build, Scan, Push to ECR

A complete Jenkins pipeline that builds a Java (Maven) application, runs **security checks at every stage**, and only pushes the Docker image to **Amazon ECR** when the checks pass. It covers secret scanning (Gitleaks), static code analysis (SonarQube), dependency and IaC scanning (Trivy), container image scanning before the push (Trivy), and dynamic testing of the running app (OWASP ZAP). ECR login, build and push are plain commands in the Jenkinsfile, with no extra shell scripts to maintain.

> **Note:** Start with the [Jenkins guide](#/tool/jenkins) (installing Jenkins, credentials, pipelines) and the [ECR guide](#/tool/aws-ecr). This pipeline assumes a Jenkins agent with Docker.

## Start here: DevSecOps in simple words

> **In simple words:** DevSecOps means **security checks are part of the assembly line**, not a separate review weeks later. Every commit is checked automatically for leaked passwords, risky code, vulnerable libraries and insecure containers, so problems are caught while they're still cheap to fix.

### Where each check runs

```text
 git push
   │
   ▼
 ① Secret scan ────── Gitleaks          leaked passwords / keys in the code?
 ② Build + tests ──── Maven
 ③ SAST ───────────── SonarQube         bugs and insecure code patterns? (+ quality gate)
 ④ SCA + IaC ──────── Trivy fs          vulnerable libraries? insecure Dockerfile / K8s / Terraform?
 ⑤ ECR login + docker build
 ⑥ Image scan ─────── Trivy image       vulnerable OS packages in the image?  ✋ blocks the push
 ⑦ DAST ───────────── OWASP ZAP         does the RUNNING app have web vulnerabilities?
 ⑧ Push to ECR ────── only if everything above passed
```

### The security tool types

| Type | Question it answers | When it runs | Tools |
|---|---|---|---|
| **Secret scanning** | Did someone commit a password, token or key? | First, on the source | Gitleaks, TruffleHog |
| **SAST** (Static Application Security Testing) | Does the **source code** have bugs or insecure patterns (SQL injection, weak crypto…)? | After build, on the code | SonarQube, Semgrep, CodeQL |
| **SCA** (Software Composition Analysis) | Do our **third-party libraries** have known vulnerabilities (CVEs)? | On dependency files | Trivy fs, OWASP Dependency-Check, Snyk |
| **IaC scanning** | Are Dockerfiles, Kubernetes YAML or Terraform insecure (running as root, open security groups…)? | On config files | Trivy config, Checkov |
| **Container image scanning** | Does the **final image** contain vulnerable OS packages or libraries? | After `docker build`, **before push** | Trivy image, Grype, Amazon Inspector |
| **DAST** (Dynamic Application Security Testing) | Can the **running** app be attacked from outside (missing security headers, XSS, insecure cookies…)? | Against a running container or test environment | OWASP ZAP, Burp Suite, Nuclei |
| **SBOM** | What exactly is inside the image? | With the image scan | Trivy, Syft |

### Check yourself

1. What's the difference between SAST and DAST?
2. Why scan the image **before** pushing to ECR?
3. Which tool type finds a vulnerable version of a Java library?

> **Tip:** Answers: 1) SAST reads the source code without running it; DAST attacks the running application from outside. 2) So a vulnerable image never reaches the registry, where clusters could pull it. 3) SCA (here: `trivy fs`, or OWASP Dependency-Check).

## What the pipeline does, stage by stage

> **In simple words:** A map of the pipeline: what each stage does, which tool it uses, and whether a finding **stops** the build or is only **reported**.

| # | Stage | Tool | Security type | On findings |
|---|---|---|---|---|
| 1 | Checkout | Git (Bitbucket deploy key) | | |
| 2 | Secret scan | Gitleaks | Secrets | **Fails** the build |
| 3 | Build & unit tests | Maven + JUnit | | Fails on test failures |
| 4 | SAST | SonarQube | SAST | Analysis uploaded |
| 5 | Quality gate | SonarQube | SAST | **Fails** if the gate fails |
| 6 | SCA & IaC scan | Trivy fs | SCA, IaC | Reported (JSON + table) |
| 7 | ECR login | AWS CLI + Docker | | |
| 8 | Docker build | Docker | | |
| 9 | Image scan + SBOM | Trivy image | Container | **Fails** on `FAIL_ON_SEVERITY` (default HIGH, CRITICAL) |
| 10 | DAST | OWASP ZAP baseline | DAST | Reported; can be made blocking |
| 11 | Push to ECR | Docker | | Only reached if all gates passed |
| post | Archive reports, clean up | Jenkins | | Always runs |

All reports (Gitleaks, Trivy, SBOM, ZAP) are archived on every build under **Build → Artifacts → reports/**.

## Prepare the build agent

> **In simple words:** The Jenkins agent that runs this pipeline needs a few tools installed once: Docker, the AWS CLI, Java with Maven, and Trivy. Gitleaks and ZAP run as Docker containers, so they need no installation.

On an Ubuntu agent:

```bash
# Docker (agent user must be in the docker group)
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker jenkins

# AWS CLI v2
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp && sudo /tmp/aws/install

# Java 21 + Maven
sudo apt-get update && sudo apt-get install -y openjdk-21-jdk maven jq

# Trivy (official apt repository)
sudo apt-get install -y wget gnupg
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
  | sudo tee /etc/apt/sources.list.d/trivy.list
sudo apt-get update && sudo apt-get install -y trivy

# Pre-download the vulnerability database into a persistent cache (as the jenkins user)
sudo -u jenkins trivy image --download-db-only --cache-dir /home/jenkins/.cache/trivy

docker version && aws --version && mvn -v && trivy --version
```

In Jenkins: **Manage Jenkins → Nodes →** your agent → **Labels**, add `docker-build` (the label the Jenkinsfile asks for).

> **Tip:** Keeping the Trivy cache in one folder on the agent means each build downloads only small database updates instead of the full database.

## Set up SonarQube and connect Jenkins

> **In simple words:** SonarQube is a server that receives the code analysis, shows the issues in a dashboard, and decides pass or fail with a **quality gate**. Jenkins sends the analysis, then waits for SonarQube's verdict.

### 1. Run SonarQube (lab setup with Docker)

```bash
sudo sysctl -w vm.max_map_count=524288        # required by SonarQube's search engine on Linux hosts

docker run -d --name sonarqube --restart unless-stopped -p 9000:9000 \
  -v sonarqube_data:/opt/sonarqube/data \
  -v sonarqube_extensions:/opt/sonarqube/extensions \
  -v sonarqube_logs:/opt/sonarqube/logs \
  sonarqube:community

docker logs -f sonarqube      # wait for "SonarQube is operational"
```

Open `http://<host>:9000`, log in as `admin` / `admin`, and set a new password. For a team or production setup, use an external PostgreSQL database and run SonarQube on a proper server or Kubernetes.

### 2. Create a token

**My Account → Security → Generate Tokens →** type **Global Analysis Token**. Copy it.

### 3. Connect Jenkins to SonarQube

1. **Manage Jenkins → Plugins →** install **SonarQube Scanner**.
2. **Manage Jenkins → Credentials →** add **Secret text** with the token, ID `sonarqube-token`.
3. **Manage Jenkins → System → SonarQube servers → Add**: name `sonarqube` (the name the Jenkinsfile uses), server URL `http://<sonarqube-host>:9000`, token credential `sonarqube-token`.

### 4. Webhook for the quality gate

The pipeline's `waitForQualityGate` step waits until SonarQube calls Jenkins back. In SonarQube: **Administration → Configuration → Webhooks → Create**, URL `https://<your-jenkins>/sonarqube-webhook/` (with the trailing slash).

> **Note:** If Jenkins and SonarQube run as containers on the same machine, put them on one Docker network (`docker network connect <network> sonarqube`) and use `http://sonarqube:9000` and `http://jenkins:8080/sonarqube-webhook/` as the URLs.

## Credentials and AWS permissions

> **In simple words:** The pipeline needs three secrets: a Bitbucket key to read the code, AWS access to push to ECR, and the SonarQube token. Store them in Jenkins credentials and refer to them by ID. Never write them in the Jenkinsfile.

| Credential ID | Kind | Used for |
|---|---|---|
| `bitbucket-deploy-key` | SSH Username with private key | Checkout (a **read-only** access key on the repository) |
| `aws-ecr-push` | AWS Credentials (needs the **AWS Credentials** plugin) | ECR login and push |
| `sonarqube-token` | Secret text | SonarQube analysis (set in the SonarQube server config) |

**Prefer an IAM role over access keys.** If the agent runs on EC2 (instance profile) or as an EKS pod (IRSA or Pod Identity), the AWS CLI picks up temporary credentials automatically. Then remove the two `withCredentials(...)` wrappers from the Jenkinsfile and drop `aws-ecr-push`. See the [IAM guide](#/tool/aws-iam).

Minimum IAM permissions to push to one ECR repository:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EcrLogin",
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    },
    {
      "Sid": "PushToAppRepository",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:DescribeImages",
        "ecr:DescribeRepositories"
      ],
      "Resource": "arn:aws:ecr:us-east-1:123456789012:repository/my-service"
    }
  ]
}
```

## The complete Jenkinsfile

> **In simple words:** The whole pipeline in one file. Put it in the root of your repository as `Jenkinsfile`, change the lines marked `CHANGE`, and create a Pipeline job that reads it from Git.

Expected repository layout (change the paths if yours differ):

```text
your-repo/
├── Jenkinsfile
├── pom.xml                      Maven project → builds target/*.jar
└── docker/
    └── my-service/              = CONTAINER_NAME parameter = ECR repository name
        └── Dockerfile           copies the built jar into the image
```

`Jenkinsfile`:

```groovy
pipeline {
    agent { label 'docker-build' }                    // CHANGE: agent with Docker, AWS CLI, Java/Maven, Trivy

    options {
        buildDiscarder(logRotator(daysToKeepStr: '7', numToKeepStr: '20'))
        disableConcurrentBuilds()
        timeout(time: 60, unit: 'MINUTES')
        timestamps()
    }

    parameters {
        string(name: 'APP_VERSION',      defaultValue: 'main-SNAPSHOT', trim: true, description: 'Application version, used as the image tag')
        string(name: 'AWS_ACCOUNT',      defaultValue: '123456789012',  trim: true, description: 'AWS account that owns the ECR repository')   // CHANGE
        string(name: 'AWS_REGION',       defaultValue: 'us-east-1',     trim: true, description: 'AWS region of the ECR repository')
        string(name: 'RELEASE_BRANCH',   defaultValue: 'main',          trim: true, description: 'Branch to build')
        string(name: 'CONTAINER_NAME',   defaultValue: '',              trim: true, description: 'Folder under docker/ with the Dockerfile; also the ECR repository name')
        booleanParam(name: 'TAG_WITH_BUILD_NUMBER', defaultValue: false, description: 'Append the Jenkins build number to the image tag')
        string(name: 'FAIL_ON_SEVERITY', defaultValue: 'CRITICAL,HIGH', trim: true, description: 'Image vulnerabilities at these severities block the push')
        booleanParam(name: 'RUN_DAST',   defaultValue: true,  description: 'Run an OWASP ZAP baseline scan against the built image')
        string(name: 'APP_PORT',         defaultValue: '8080', trim: true, description: 'Port the container listens on (for the DAST scan)')
    }

    environment {
        TRIVY_CACHE_DIR = '/home/jenkins/.cache/trivy'    // persistent vulnerability DB cache on the agent
    }

    stages {
        stage('Checkout') {
            steps {
                checkout([$class: 'GitSCM',
                    branches: [[name: "*/${params.RELEASE_BRANCH}"]],
                    extensions: [[$class: 'WipeWorkspace']],
                    userRemoteConfigs: [[credentialsId: 'bitbucket-deploy-key',
                                         url: 'git@bitbucket.org:your-workspace/your-repo.git']]])   // CHANGE
                script {
                    if (!params.CONTAINER_NAME?.trim()) { error 'CONTAINER_NAME is required' }
                    env.GIT_SHA     = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.REGISTRY    = "${params.AWS_ACCOUNT}.dkr.ecr.${params.AWS_REGION}.amazonaws.com"
                    env.IMAGE_TAG   = params.TAG_WITH_BUILD_NUMBER ? "${params.APP_VERSION}-${env.BUILD_NUMBER}" : params.APP_VERSION
                    env.IMAGE       = "${env.REGISTRY}/${params.CONTAINER_NAME}:${env.IMAGE_TAG}"
                    env.CONTEXT_DIR = "docker/${params.CONTAINER_NAME}"
                    env.RUN_ID      = env.BUILD_TAG.replaceAll('[^A-Za-z0-9_.-]', '-').toLowerCase()
                    currentBuild.description = "${params.CONTAINER_NAME}:${env.IMAGE_TAG} (${env.GIT_SHA})"
                }
                sh 'mkdir -p reports'
            }
        }

        stage('Secret scan: Gitleaks') {
            steps {
                sh '''
                    docker run --rm --user "$(id -u):$(id -g)" -v "$PWD:/repo" ghcr.io/gitleaks/gitleaks:v8.30.1 \
                      git /repo --redact --no-banner \
                      --report-format json --report-path /repo/reports/gitleaks.json
                '''
            }
        }

        stage('Build & unit tests') {
            steps {
                sh 'mvn -B -ntp clean verify'
            }
            post {
                always { junit allowEmptyResults: true, testResults: '**/target/surefire-reports/*.xml' }
            }
        }

        stage('SAST: SonarQube') {
            steps {
                withSonarQubeEnv('sonarqube') {
                    sh """
                        mvn -B -ntp org.sonarsource.scanner.maven:sonar-maven-plugin:5.8.0.7211:sonar \
                          -Dsonar.projectKey=${params.CONTAINER_NAME} \
                          -Dsonar.projectVersion=${env.IMAGE_TAG}
                    """
                }
            }
        }

        stage('Quality gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('SCA & IaC scan: Trivy fs') {
            steps {
                sh '''
                    trivy fs --cache-dir "$TRIVY_CACHE_DIR" --no-progress \
                      --scanners vuln,misconfig,secret \
                      --format json --output reports/trivy-fs.json .
                    trivy fs --cache-dir "$TRIVY_CACHE_DIR" --no-progress --skip-db-update \
                      --scanners vuln,misconfig --severity HIGH,CRITICAL .
                '''
            }
        }

        stage('ECR login') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-ecr-push',
                                  accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    sh '''
                        aws ecr get-login-password --region "$AWS_REGION" \
                          | docker login --username AWS --password-stdin "$REGISTRY"
                        aws ecr describe-repositories --region "$AWS_REGION" --repository-names "$CONTAINER_NAME" > /dev/null \
                          || { echo "ECR repository $CONTAINER_NAME not found in $AWS_REGION. Create it first."; exit 1; }
                    '''
                }
            }
        }

        stage('Docker build') {
            steps {
                sh '''
                    cp target/*.jar "$CONTEXT_DIR/"           # CHANGE: copy your build artifact into the image context
                    docker build --pull \
                      --label org.opencontainers.image.revision="$GIT_SHA" \
                      --label org.opencontainers.image.version="$IMAGE_TAG" \
                      -t "$IMAGE" "$CONTEXT_DIR"
                '''
            }
        }

        stage('Image scan: Trivy') {
            steps {
                sh '''
                    # full report + SBOM (archived), then the gate that blocks the push
                    trivy image --cache-dir "$TRIVY_CACHE_DIR" --no-progress \
                      --format json --output reports/trivy-image.json "$IMAGE"
                    trivy image --cache-dir "$TRIVY_CACHE_DIR" --no-progress --skip-db-update \
                      --format cyclonedx --output reports/sbom.cdx.json "$IMAGE"
                    trivy image --cache-dir "$TRIVY_CACHE_DIR" --no-progress --skip-db-update \
                      --severity "$FAIL_ON_SEVERITY" --ignore-unfixed --exit-code 1 "$IMAGE"
                '''
            }
        }

        stage('DAST: OWASP ZAP baseline') {
            when { expression { params.RUN_DAST } }
            steps {
                sh '''
                    docker network create "dast-$RUN_ID"
                    docker run -d --name "app-$RUN_ID" --network "dast-$RUN_ID" "$IMAGE"

                    # wait up to 60s for the app to answer
                    for i in $(seq 1 30); do
                      docker run --rm --network "dast-$RUN_ID" curlimages/curl:8.10.1 -s -o /dev/null \
                        "http://app-$RUN_ID:$APP_PORT/" && break
                      sleep 2
                    done

                    mkdir -p reports/zap && chmod 777 reports/zap
                    docker run --rm --network "dast-$RUN_ID" -v "$PWD/reports/zap:/zap/wrk:rw" \
                      ghcr.io/zaproxy/zaproxy:stable \
                      zap-baseline.py -t "http://app-$RUN_ID:$APP_PORT" \
                        -r zap-report.html -J zap-report.json -I
                '''
            }
            post {
                always {
                    sh 'docker rm -f "app-$RUN_ID" || true; docker network rm "dast-$RUN_ID" || true'
                }
            }
        }

        stage('Push to ECR') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-ecr-push',
                                  accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    sh '''
                        docker push "$IMAGE"
                        aws ecr describe-images --region "$AWS_REGION" --repository-name "$CONTAINER_NAME" \
                          --image-ids imageTag="$IMAGE_TAG" --query 'imageDetails[0].[imageDigest,imagePushedAt]' --output text
                    '''
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'reports/**', allowEmptyArchive: true
            // needs the HTML Publisher plugin; remove if not installed
            publishHTML(target: [reportDir: 'reports/zap', reportFiles: 'zap-report.html', reportName: 'ZAP DAST report',
                                 allowMissing: true, keepAll: true, alwaysLinkToLastBuild: true])
            sh '''
                [ -n "$IMAGE" ] && docker rmi "$IMAGE" 2>/dev/null || true
                [ -n "$REGISTRY" ] && docker logout "$REGISTRY" 2>/dev/null || true
                docker system prune -f --filter "until=24h"
                # drop only SNAPSHOT dependencies, keep the rest of the Maven cache for faster builds
                find "$HOME/.m2/repository" -type d -name "*-SNAPSHOT" -prune -exec rm -rf {} + 2>/dev/null || true
            '''
            cleanWs()
        }
        success { echo "Pushed ${env.IMAGE}" }
        failure { echo 'Pipeline failed: open the red stage and the archived reports/ to see why.' }
    }
}
```

Plugins used: **Pipeline**, **Git**, **Timestamper**, **JUnit**, **SonarQube Scanner**, **AWS Credentials**, **HTML Publisher**, **Workspace Cleanup**.

## How each stage works

> **In simple words:** What each stage does and why, including what replaced the old `login_ecr.sh`, `build.sh` and `push.sh` scripts.

| Stage | What happens | Notes |
|---|---|---|
| **Checkout** | Clones the branch with the deploy key, then computes the registry, image tag and image name once | `TAG_WITH_BUILD_NUMBER` turns `main-SNAPSHOT` into `main-SNAPSHOT-42` |
| **Secret scan** | Gitleaks scans the code **and its Git history** | Any leak fails the build. `--redact` keeps the secret itself out of logs and reports |
| **Build & unit tests** | `mvn clean verify` compiles, runs tests and packages the jar | Test results appear under **Test Result** on the build page |
| **SAST** | The Sonar Maven plugin analyses the code and uploads it; `withSonarQubeEnv` supplies the server URL and token | Results appear in the SonarQube dashboard under the project key |
| **Quality gate** | Waits for SonarQube's verdict (new bugs, vulnerabilities, coverage…) | Needs the SonarQube → Jenkins webhook |
| **SCA & IaC** | Trivy checks `pom.xml` dependencies, Dockerfiles and Kubernetes/Terraform files | Report-only here. Add `--exit-code 1` to make it blocking |
| **ECR login** | `aws ecr get-login-password \| docker login`, then checks the repository exists | Replaces `login_ecr.sh` |
| **Docker build** | Copies the jar into the Docker context and builds with OCI labels (commit, version) | Replaces `build.sh`. `--pull` always gets the latest patched base image |
| **Image scan** | Trivy writes a full JSON report and a CycloneDX **SBOM**, then fails if fixable HIGH/CRITICAL vulnerabilities exist | Runs **before** the push, so a vulnerable image never reaches ECR |
| **DAST** | Starts the new image on a private Docker network and runs a ZAP **baseline** scan against it | Passive scan, safe and quick (~1–2 minutes). See the next step to make it stricter |
| **Push** | `docker push`, then prints the image digest from ECR | Replaces `push.sh` |
| **post** | Archives reports, removes the local image, logs out of ECR, prunes old Docker data, cleans SNAPSHOT jars | Always runs, even after a failure |

## DAST: going beyond the baseline scan

> **In simple words:** The baseline scan only *looks* at responses, so it's safe to run on every build. Deeper scans actually try attacks, so run them against a **test environment** (never production), and make important findings fail the build.

| ZAP scan | What it does | Where to run |
|---|---|---|
| `zap-baseline.py` | Spiders the site and reports passive issues (headers, cookies, info leaks) | Every build (this pipeline) |
| `zap-full-scan.py` | Adds **active** attacks (XSS, SQL injection…) | Nightly, against a test environment |
| `zap-api-scan.py` | Scans a REST API from its OpenAPI/Swagger definition | APIs, against a test environment |

**Make findings blocking.** Generate a rules file, set the rules you care about to `FAIL`, commit it, and remove `-I`:

```bash
# one-off: generate a config listing every rule (all WARN by default)
docker run --rm -v "$PWD:/zap/wrk:rw" ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py -t https://test.example.internal -g zap-rules.conf
# edit zap-rules.conf: change e.g. "10038 WARN" (CSP header missing) to "10038 FAIL"

# in the pipeline: use the config and drop -I
zap-baseline.py -t "http://app-$RUN_ID:$APP_PORT" -c zap-rules.conf -r zap-report.html -J zap-report.json
```

ZAP exit codes: `0` = no issues, `1` = at least one FAIL, `2` = warnings only (ignored with `-I`), `3` = the scan itself failed.

Scan an API in a test environment (a nightly job, for example):

```bash
docker run --rm -v "$PWD/reports/zap:/zap/wrk:rw" ghcr.io/zaproxy/zaproxy:stable \
  zap-api-scan.py -t https://test.example.internal/v3/api-docs -f openapi -r api-report.html -I
```

Docs: [ZAP baseline scan](https://www.zaproxy.org/docs/docker/baseline-scan/) · [ZAP API scan](https://www.zaproxy.org/docs/docker/api-scan/)

## Handling findings

> **In simple words:** A security gate is only useful if the team trusts it. Block on what really matters, fix or document everything else, and give every exception an owner and an expiry date.

| Tool | Tune it with | Example |
|---|---|---|
| Trivy | `FAIL_ON_SEVERITY`, `--ignore-unfixed`, a `.trivyignore` file in the repo | Accept a CVE that isn't reachable, until a fix ships |
| SonarQube | Quality gate in **Quality Gates**; mark false positives in the UI | Gate on **new code** only, so legacy debt doesn't block every build |
| Gitleaks | `.gitleaks.toml` allowlist, or `--baseline-path` for old findings | Ignore test fixtures that contain fake keys |
| ZAP | `zap-rules.conf` (`IGNORE` / `WARN` / `FAIL` per rule) | Fail on missing CSP, warn on everything else |

`.trivyignore` with an expiry date (the exception stops working after that day):

```text
# CVE-2026-12345: library code path not used by our service. Owner: platform team. Ticket: SEC-101
CVE-2026-12345 exp:2026-12-31
```

> **Warning:** If Gitleaks finds a real secret, **rotate it immediately**. Deleting it from the code isn't enough: it stays in the Git history and in every clone.

## Other security tools you can plug in

> **In simple words:** The same pattern works for any scanner: run it as a stage, save its report, and decide whether it blocks. Here are common alternatives and additions.

| Need | Tool | Pipeline step |
|---|---|---|
| SCA with the NVD database | OWASP Dependency-Check | `mvn org.owasp:dependency-check-maven:12.1.0:check -DnvdApiKey=$NVD_API_KEY -DfailBuildOnCVSS=7` |
| IaC deep-dive (Terraform, K8s, Helm) | Checkov | `docker run --rm -v "$PWD:/src" bridgecrew/checkov -d /src --compact` |
| Extra SAST rules | Semgrep | `docker run --rm -v "$PWD:/src" semgrep/semgrep semgrep scan --config auto /src` |
| Commercial SCA, SAST and container scanning | Snyk | `snyk test`, `snyk code test`, `snyk container test $IMAGE` (needs a Snyk token) |
| Registry-side scanning | Amazon ECR / Inspector | `scanOnPush=true` or enhanced scanning (see the [ECR guide](#/tool/aws-ecr)) |
| Prove the image wasn't tampered with | Cosign (Sigstore) | `cosign sign --key awskms:///alias/cosign "$REGISTRY/$CONTAINER_NAME@<digest>"` after the push |

> **Note:** OWASP Dependency-Check downloads the NVD database. Without a free **NVD API key**, the first run can take a very long time. Store the key as a Jenkins secret.

## Troubleshooting

> **In simple words:** Open the red stage in the Stage View, read its log from the first error, and check the archived reports.

| Problem | Fix |
|---|---|
| `permission denied … /var/run/docker.sock` | The agent user isn't in the `docker` group. Re-login or restart the agent after `usermod -aG docker jenkins` |
| Gitleaks fails on a fake test key | Add an allowlist entry in `.gitleaks.toml`. If it's real, rotate it first |
| Gitleaks: `fatal: detected dubious ownership` | Run the container with `--user "$(id -u):$(id -g)"` (as in the Jenkinsfile) |
| `waitForQualityGate` times out | The SonarQube webhook to `/sonarqube-webhook/` is missing or can't reach Jenkins |
| Sonar `Not authorized` | Token missing or wrong in **Manage Jenkins → System → SonarQube servers** |
| SonarQube container exits on start | `vm.max_map_count` too low. Run `sudo sysctl -w vm.max_map_count=524288` |
| Trivy is slow on every build | No persistent cache. Check `TRIVY_CACHE_DIR` exists and is owned by the agent user |
| Image scan fails on a CVE with no fix | `--ignore-unfixed` skips those. For others, update the base image or add a dated `.trivyignore` entry |
| `cp: cannot stat 'target/*.jar'` | The build produces a different artifact path (multi-module, war). Adjust the copy line |
| ZAP can't reach the app | Wrong `APP_PORT`, or the app needs a database or config to start. Point DAST at a test environment instead |
| `no basic auth credentials` on push | The ECR login expired or failed. Check the **ECR login** stage and the AWS credential or role |
| `tag invalid … cannot be overwritten` | The repository has immutable tags. Enable `TAG_WITH_BUILD_NUMBER` or tag with the Git SHA |

## Lab: secure your own pipeline

> **In simple words:** Practice time: build the pipeline step by step and prove each gate really stops a bad change.

1. Prepare an agent with Docker, AWS CLI, Maven and Trivy, and run SonarQube with Docker.
2. Create the job from this Jenkinsfile and get one green build that pushes to ECR.
3. **Secret gate:** commit a fake AWS key (`AKIA…`) on a branch. Gitleaks stops the build. Remove it and use an allowlist for test fixtures.
4. **Quality gate:** add an obvious bug (for example an unclosed resource). SonarQube fails the gate.
5. **Image gate:** change the base image to an old version (for example `eclipse-temurin:11-jre` from years ago). Trivy blocks the push.
6. **DAST:** read the ZAP HTML report, then make one rule `FAIL` and watch it block.
7. Add a `.trivyignore` entry with an expiry date and explain in the comment why it's acceptable.
8. Download the SBOM (`reports/sbom.cdx.json`) and find your app's main libraries in it.
