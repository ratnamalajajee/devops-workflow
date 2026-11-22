# CI/CD Troubleshooting

Pipelines fail for a handful of recurring reasons, and most of them aren't in your code: the CI server is down, a runner is missing a tool, a secret isn't available on that branch, the environment differs from your laptop, or the registry refuses the push. This guide gives you one method, then real problems and fixes for **Jenkins**, **GitHub Actions** and **GitLab CI**, plus the classics: **"it builds on my machine but not in CI"**, **"it works for dev but not for prod"** and **"unable to push to ECR"**.

> **Note:** For pods failing *after* deployment, see [Kubernetes Troubleshooting](#/tool/k8s-troubleshooting). This guide covers the pipeline up to the push and deploy.

## Start here: the CI/CD troubleshooting method

> **In simple words:** When a pipeline fails, **read the first real error** (not the last line), ask **what changed** since the last green run, and **reproduce it outside the pipeline** with the same inputs. Almost every CI problem is a difference between two environments.

### Watch how it works

```svg Watch it work: walking a failed pipeline link by link, from the trigger and the queue to the runner, a missing secret and a refused push to ECR, then the whole chain green. The animation loops.
<svg viewBox="0 0 600 392" role="img" data-anim="cicd-troubleshooting" data-dur="34" data-starts="0 4.76 9.52 14.28 19.38 24.14 28.9" aria-label="Animated troubleshooting walk for a CI/CD pipeline. A pipeline failed, so instead of guessing you read the first real error, ask what changed since the last green run, and check each link of the chain in order. First link: if nothing ran at all, the trigger never fired, so check the webhook&#x27;s recent deliveries, the branch and path filters, and that the pipeline file is valid YAML. Second link: if the build is stuck in the queue with a message like no nodes with the label, no online agent or runner matches the job&#x27;s label or tags. Third link: if it works on your laptop but fails in CI, the runner is a different machine, with different tools, versions, files or CPU, so reproduce it from a fresh clone. Fourth link: if a secret is empty in CI, it may be a protected variable on an unprotected branch, defined for another environment, or the run came from a fork. Fifth link: if the push to ECR is denied, no basic auth credentials means you must log in again, and not authorized means the IAM policy is missing a permission. Fixed: with each link working, the run goes from the push all the way to ECR and every link is green.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<polyline points="95,50 300,50 505,50 505,160 300,160 95,160" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="300,270 300,160" fill="none" stroke-linejoin="round" stroke="#eab308" stroke-width="1.8" stroke-dasharray="3 3" stroke-opacity=".75"/>
<g><rect x="16" y="20" width="158" height="60" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1" keyTimes="0;0.14;0.85" calcMode="discrete" dur="34s" repeatCount="indefinite"/></rect><rect x="20" y="24" width="150" height="52" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="95" y="46.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Your push</text><text x="95" y="62" text-anchor="middle" font-size="11" class="dg-muted">git push</text></g>
<g><rect x="221" y="20" width="158" height="60" rx="12" fill="#7c3aed" fill-opacity=".18" stroke="#7c3aed" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.14;0.28;0.85" calcMode="discrete" dur="34s" repeatCount="indefinite"/></rect><rect x="225" y="24" width="150" height="52" rx="9" class="dg-box" stroke="#7c3aed" stroke-width="2.2"/><text x="300" y="46.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Trigger</text><text x="300" y="62" text-anchor="middle" font-size="11" class="dg-muted">webhook or on: rules</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.14;0.28" calcMode="discrete" dur="34s" repeatCount="indefinite"/><rect x="225" y="24" width="150" height="52" rx="9" fill="#e11d48"/><text x="300" y="54.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">✕ no run</text></g></g>
<g><rect x="426" y="20" width="158" height="60" rx="12" fill="#0ea5e9" fill-opacity=".18" stroke="#0ea5e9" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.28;0.42;0.85" calcMode="discrete" dur="34s" repeatCount="indefinite"/></rect><rect x="430" y="24" width="150" height="52" rx="9" class="dg-box" stroke="#0ea5e9" stroke-width="2.2"/><text x="505" y="46.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Queue</text><text x="505" y="62" text-anchor="middle" font-size="11" class="dg-muted">waits for a runner</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.28;0.42" calcMode="discrete" dur="34s" repeatCount="indefinite"/><rect x="430" y="24" width="150" height="52" rx="9" fill="#e11d48"/><text x="505" y="54.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">✕ waiting forever</text></g></g>
<g><rect x="426" y="130" width="158" height="60" rx="12" fill="#f59e0b" fill-opacity=".18" stroke="#f59e0b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.42;0.57;0.85" calcMode="discrete" dur="34s" repeatCount="indefinite"/></rect><rect x="430" y="134" width="150" height="52" rx="9" class="dg-box" stroke="#f59e0b" stroke-width="2.2"/><text x="505" y="156.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Agent / runner</text><text x="505" y="172" text-anchor="middle" font-size="11" class="dg-muted">tools + versions</text></g>
<g><rect x="221" y="130" width="158" height="60" rx="12" fill="#0d9488" fill-opacity=".18" stroke="#0d9488" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.42;0.71;0.85" calcMode="discrete" dur="34s" repeatCount="indefinite"/></rect><rect x="225" y="134" width="150" height="52" rx="9" class="dg-box" stroke="#0d9488" stroke-width="2.2"/><text x="300" y="156.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Build</text><text x="300" y="172" text-anchor="middle" font-size="11" class="dg-muted">docker build</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.42;0.57" calcMode="discrete" dur="34s" repeatCount="indefinite"/><rect x="225" y="134" width="150" height="52" rx="9" fill="#e11d48"/><text x="300" y="164.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">✕ fails in CI only</text></g></g>
<g><rect x="16" y="130" width="158" height="60" rx="12" fill="#ff9900" fill-opacity=".18" stroke="#ff9900" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.71" calcMode="discrete" dur="34s" repeatCount="indefinite"/></rect><rect x="20" y="134" width="150" height="52" rx="9" class="dg-box" stroke="#ff9900" stroke-width="2.2"/><text x="95" y="156.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Push to ECR</text><text x="95" y="172" text-anchor="middle" font-size="11" class="dg-muted">login + IAM</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.71;0.85" calcMode="discrete" dur="34s" repeatCount="indefinite"/><rect x="20" y="134" width="150" height="52" rx="9" fill="#e11d48"/><text x="95" y="164.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">✕ push denied</text></g></g>
<g><rect x="221" y="240" width="158" height="60" rx="12" fill="#ca8a04" fill-opacity=".18" stroke="#ca8a04" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.57;0.71;0.85" calcMode="discrete" dur="34s" repeatCount="indefinite"/></rect><rect x="225" y="244" width="150" height="52" rx="9" class="dg-box" stroke="#ca8a04" stroke-width="2.2"/><text x="300" y="266.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Secrets</text><text x="300" y="282" text-anchor="middle" font-size="11" class="dg-muted">CI/CD variables</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.57;0.71" calcMode="discrete" dur="34s" repeatCount="indefinite"/><rect x="225" y="244" width="150" height="52" rx="9" fill="#e11d48"/><text x="300" y="274.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">✕ empty in CI</text></g></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.42;0.57" calcMode="discrete" dur="34s" repeatCount="indefinite"/><circle cx="580" cy="134" r="9.5" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M580,129.5 V134.8 M580,137.6 V137.8" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.85" calcMode="discrete" dur="34s" repeatCount="indefinite"/><circle cx="375" cy="24" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M370.5,24 L374,27.5 L379.5,20.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.85" calcMode="discrete" dur="34s" repeatCount="indefinite"/><circle cx="580" cy="24" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M575.5,24 L579,27.5 L584.5,20.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.85" calcMode="discrete" dur="34s" repeatCount="indefinite"/><circle cx="580" cy="134" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M575.5,134 L579,137.5 L584.5,130.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.85" calcMode="discrete" dur="34s" repeatCount="indefinite"/><circle cx="375" cy="134" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M370.5,134 L374,137.5 L379.5,130.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.85" calcMode="discrete" dur="34s" repeatCount="indefinite"/><circle cx="170" cy="134" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M165.5,134 L169,137.5 L174.5,130.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.85" calcMode="discrete" dur="34s" repeatCount="indefinite"/><circle cx="375" cy="244" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M370.5,244 L374,247.5 L379.5,240.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1484;0.2604" calcMode="discrete" dur="34s" repeatCount="indefinite"/><animateMotion path="M95,50 L300,50" keyPoints="0;0;1;1" keyTimes="0;0.1484;0.2604;1" calcMode="linear" dur="34s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2884;0.4004" calcMode="discrete" dur="34s" repeatCount="indefinite"/><animateMotion path="M300,50 L505,50" keyPoints="0;0;1;1" keyTimes="0;0.2884;0.4004;1" calcMode="linear" dur="34s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.429;0.549" calcMode="discrete" dur="34s" repeatCount="indefinite"/><animateMotion path="M505,50 L505,160 L300,160" keyPoints="0;0;1;1" keyTimes="0;0.429;0.549;1" calcMode="linear" dur="34s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5784;0.6904" calcMode="discrete" dur="34s" repeatCount="indefinite"/><animateMotion path="M300,270 L300,160" keyPoints="0;0;1;1" keyTimes="0;0.5784;0.6904;1" calcMode="linear" dur="34s" repeatCount="indefinite"/><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7184;0.8304" calcMode="discrete" dur="34s" repeatCount="indefinite"/><animateMotion path="M300,160 L95,160" keyPoints="0;0;1;1" keyTimes="0;0.7184;0.8304;1" calcMode="linear" dur="34s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.856;0.985" calcMode="discrete" dur="34s" repeatCount="indefinite"/><animateMotion path="M95,50 L300,50 L505,50 L505,160 L300,160 L95,160" keyPoints="0;0;1;1" keyTimes="0;0.856;0.985;1" calcMode="linear" dur="34s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(20.4,316.5) scale(.8)"><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g><text x="31.8" y="320">your check</text><g transform="translate(111,316.5) scale(.8)"><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g><text x="124" y="320">secret</text><g transform="translate(180,316.5) scale(.8)"><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g><text x="191.4" y="320">the pipeline run</text></g>
<rect x="12" y="332" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="332" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="34s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.14" calcMode="discrete" dur="34s" repeatCount="indefinite"/><circle cx="36" cy="360" r="14" fill="#6366f1"/><text x="36" y="365" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="355" font-size="14" font-weight="800" fill="#6366f1">A pipeline failed: don&#x27;t guess</text><text x="578" y="355" text-anchor="end" font-size="10.5" class="dg-muted">The method · 1/7</text><text x="60" y="376" font-size="12.5" class="dg-text">Read the first real error, ask what changed, then check each link in order.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.14;0.28" calcMode="discrete" dur="34s" repeatCount="indefinite"/><circle cx="36" cy="360" r="14" fill="#d97706"/><text x="36" y="365" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="355" font-size="14" font-weight="800" fill="#d97706">1. Nothing ran at all?</text><text x="578" y="355" text-anchor="end" font-size="10.5" class="dg-muted">Where it breaks · 2/7</text><text x="60" y="376" font-size="12.5" class="dg-text">Check the webhook&#x27;s recent deliveries, branch and path filters, and the YAML.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.28;0.42" calcMode="discrete" dur="34s" repeatCount="indefinite"/><circle cx="36" cy="360" r="14" fill="#d97706"/><text x="36" y="365" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="355" font-size="14" font-weight="800" fill="#d97706">2. Stuck in the queue?</text><text x="578" y="355" text-anchor="end" font-size="10.5" class="dg-muted">Where it breaks · 3/7</text><text x="60" y="376" font-size="12.5" class="dg-text">&#x27;no nodes with the label&#x27;: no online agent or runner matches the job&#x27;s label.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.42;0.57" calcMode="discrete" dur="34s" repeatCount="indefinite"/><circle cx="36" cy="360" r="14" fill="#d97706"/><text x="36" y="365" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="355" font-size="14" font-weight="800" fill="#d97706">3. Works locally, fails in CI?</text><text x="578" y="355" text-anchor="end" font-size="10.5" class="dg-muted">Where it breaks · 4/7</text><text x="60" y="376" font-size="12.5" class="dg-text">The runner isn&#x27;t your laptop: tools, versions, files, CPU. Try a fresh clone.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.57;0.71" calcMode="discrete" dur="34s" repeatCount="indefinite"/><circle cx="36" cy="360" r="14" fill="#d97706"/><text x="36" y="365" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="355" font-size="14" font-weight="800" fill="#d97706">4. Is a secret empty in CI?</text><text x="578" y="355" text-anchor="end" font-size="10.5" class="dg-muted">Where it breaks · 5/7</text><text x="60" y="376" font-size="12.5" class="dg-text">Protected variable on an unprotected branch, another environment, or a fork PR.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.71;0.85" calcMode="discrete" dur="34s" repeatCount="indefinite"/><circle cx="36" cy="360" r="14" fill="#d97706"/><text x="36" y="365" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="355" font-size="14" font-weight="800" fill="#d97706">5. Push to ECR denied?</text><text x="578" y="355" text-anchor="end" font-size="10.5" class="dg-muted">Where it breaks · 6/7</text><text x="60" y="376" font-size="12.5" class="dg-text">&#x27;no basic auth credentials&#x27;: log in again. &#x27;not authorized&#x27;: fix IAM.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.85" calcMode="discrete" dur="34s" repeatCount="indefinite"/><circle cx="36" cy="360" r="14" fill="#059669"/><text x="36" y="365" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="355" font-size="14" font-weight="800" fill="#059669">Fixed: green from end to end</text><text x="578" y="355" text-anchor="end" font-size="10.5" class="dg-muted">Fixed · 7/7</text><text x="60" y="376" font-size="12.5" class="dg-text">Each fix is small once you know which link broke. The image lands in ECR.</text></g>
</svg>
```

```steps
#6366f1 | The method | A pipeline failed: don't guess | Read the first real error, ask what changed, then check each link in order.
#d97706 | Where it breaks | 1. Nothing ran at all? | Check the webhook's recent deliveries, branch and path filters, and the YAML.
#d97706 | Where it breaks | 2. Stuck in the queue? | 'no nodes with the label': no online agent or runner matches the job's label.
#d97706 | Where it breaks | 3. Works locally, fails in CI? | The runner isn't your laptop: tools, versions, files, CPU. Try a fresh clone.
#d97706 | Where it breaks | 4. Is a secret empty in CI? | Protected variable on an unprotected branch, another environment, or a fork PR.
#d97706 | Where it breaks | 5. Push to ECR denied? | 'no basic auth credentials': log in again. 'not authorized': fix IAM.
#059669 | Fixed | Fixed: green from end to end | Each fix is small once you know which link broke. The image lands in ECR.
```

### Five questions, in order

| # | Question | Where to look |
|---|---|---|
| 1 | **Which step failed, and what's the first error?** | The red stage or job. Scroll **up** from the bottom to the first `ERROR`, `denied` or `not found` |
| 2 | **What changed since the last green run?** | Commits (code, Dockerfile, pipeline file), base image, plugin or runner upgrades, secrets rotated, IAM changes |
| 3 | **Is it the code, or the environment?** | Re-run the last green commit. If it fails now too, the **environment** changed, not your code |
| 4 | **Can I reproduce it outside CI?** | Run the same command locally or on the agent, from a **fresh clone**, with the same variables |
| 5 | **Is it consistent or flaky?** | Re-run once. Flaky usually means network, rate limits, test order, or shared state on the agent |

### "What changed?" checklist

```bash
git log --oneline <last-green-sha>..<failing-sha>                  # code changes
git diff <last-green-sha> <failing-sha> -- Dockerfile Jenkinsfile .github/ .gitlab-ci.yml
docker pull <base-image> && docker image inspect <base-image> --format '{{.Created}}'   # did the base image change?
```

### Check yourself

1. Why read the **first** error rather than the last line?
2. The last green commit now fails too. What does that tell you?
3. What's the fastest way to separate "my code" from "the CI environment"?

> **Tip:** Answers: 1) Later errors are usually consequences of the first one. 2) Something in the environment changed: agent, base image, credentials, plugins, network. 3) Reproduce the exact command from a fresh clone on another machine, or re-run the last known-good commit.

## Jenkins controller (master) is down

> **In simple words:** If the Jenkins web page doesn't load, check in this order: **is the process running?** → **what do its logs say?** → **is the disk or memory full?** → **did an upgrade or plugin break it?** The logs almost always name the cause in the first few lines of the error.

### 1. Is it running, and listening?

```bash
# Package install (Ubuntu / Amazon Linux)
sudo systemctl status jenkins
sudo ss -tulpn | grep 8080
curl -sI http://localhost:8080/login | head -1        # HTTP/1.1 200 = Jenkins is up locally

# Docker install
docker ps -a --filter name=jenkins                    # STATUS: Up, or Exited (code)?
docker inspect jenkins --format '{{.State.Status}} exit={{.State.ExitCode}} oom={{.State.OOMKilled}}'
```

If `curl localhost` works but the browser doesn't, the problem is **in front** of Jenkins: reverse proxy, load balancer, security group, DNS or TLS certificate.

### 2. Read the logs

```bash
sudo journalctl -u jenkins -n 200 --no-pager          # package install
docker logs --tail 200 jenkins                        # Docker install
```

Search for `SEVERE`, `Exception`, `OutOfMemoryError` and `Failed to load`.

### 3. Common causes and fixes

| Log or symptom | Cause | Fix |
|---|---|---|
| `No space left on device` | `JENKINS_HOME` disk full (builds, artifacts, workspaces) | `du -sh /var/lib/jenkins/* \| sort -h` (Docker: `/var/jenkins_home`). Delete old builds, set `buildDiscarder` in every job, grow the volume |
| `java.lang.OutOfMemoryError: Java heap space`, or killed with `oom=true` | Heap too small for the number of jobs and plugins | Raise the heap: `sudo systemctl edit jenkins` → `Environment="JAVA_OPTS=-Xmx4g"` (Docker: `-e JAVA_OPTS=-Xmx4g`), and give the host or container more memory |
| `Jenkins requires Java 21 or newer` / `UnsupportedClassVersionError` | Upgraded Jenkins on an old Java | Install Java 21 and point Jenkins at it, or roll back the Jenkins package |
| `Failed to load: <plugin>` and Jenkins won't start | A plugin upgrade is incompatible | Disable it: `touch $JENKINS_HOME/plugins/<plugin>.jpi.disabled`, restart, then update or roll back that plugin |
| `Address already in use` | Another process holds port 8080 | `sudo ss -tulpn \| grep 8080`, stop it, or change `--httpPort` |
| `Unable to read …/config.xml` / XML errors | A config file was corrupted (disk full during a write) | Restore that file from backup (`config.xml`, `jobs/<job>/config.xml`) |
| Starts, then admins are **locked out** | Broken security or authorization settings | Last resort, from the server shell: back up `config.xml`, set `<useSecurity>false</useSecurity>`, restart, fix the settings, and turn security back on **immediately** |
| Container keeps restarting | One of the above. Check `docker logs` | Fix the cause. With `--restart=on-failure`, Docker retries automatically |

### 4. Restart safely, and restore

```bash
sudo systemctl restart jenkins         # or: docker restart jenkins
# from the UI, when it's up: http://<jenkins>/safeRestart  (waits for running builds)

# restore everything from a backup of JENKINS_HOME (Docker volume example)
docker stop jenkins
docker run --rm -v jenkins_home:/data -v "$PWD":/backup alpine sh -c "rm -rf /data/* && tar xzf /backup/jenkins-home.tgz -C /data"
docker start jenkins
```

**Prevent the next outage:** back up `JENKINS_HOME` daily, alert on disk above 80% and on `/login` not returning 200, discard old builds, keep plugins few and current, upgrade on a test instance first, and keep the controller's own executors at **0** so builds run on agents.

## Jenkins agents offline and builds stuck in the queue

> **In simple words:** The controller is fine, but builds wait forever. Either **no agent matches** the job's label, the agents are **offline**, or every executor is **busy**. The queue tooltip tells you which.

| Symptom (hover over the queued build) | Cause | Fix |
|---|---|---|
| `Waiting for next available executor on 'docker-build'` | All executors with that label are busy, or none are online | Add executors or agents; check **Manage Jenkins → Nodes** |
| `There are no nodes with the label 'xyz'` | Label typo in the Jenkinsfile, or the label was removed from the agent | Match `agent { label '…' }` with the node's labels |
| Agent shows **offline**: `Connection was broken` | Network or firewall blocks the inbound port (50000) or WebSocket, or the agent process died | Check the agent log; open port 50000 or switch the agent to WebSocket mode; restart the agent service |
| `Agent went offline … disk space is too low` | Agent disk full (workspaces, Docker images) | `docker system prune -af --filter until=72h`, delete old workspaces, raise the threshold or the disk |
| Agent rejects connection after an upgrade | Agent `remoting.jar` or Java version doesn't match the controller | Download a fresh `agent.jar` from `http://<jenkins>/jnlpJars/agent.jar`; use Java 21 on agents |
| Kubernetes agents: pod `Pending` / `ImagePullBackOff` | Not enough cluster capacity, or a wrong agent image | `kubectl get pods -n jenkins`, then see [Kubernetes Troubleshooting](#/tool/k8s-troubleshooting) |
| A build hangs forever | A step waits for input, or a test or process never exits | Add `timeout(time: 30, unit: 'MINUTES')` in `options`; abort from the build page (**Abort** → **Force kill**) |

## Jenkins pipeline errors

> **In simple words:** The pipeline itself fails: a missing plugin, a credential that doesn't exist, a Groovy restriction, or Git can't check out. The console log names it, and this table maps each message to the fix.

| Error message | Cause | Fix |
|---|---|---|
| `No such DSL method 'xyz' found` | The plugin providing that step isn't installed | Install it (e.g. `withSonarQubeEnv` → SonarQube Scanner, `publishHTML` → HTML Publisher) |
| `Scripts not permitted to use method …` | Sandbox blocks a Groovy method | **Manage Jenkins → In-process Script Approval** (approve only what you understand), or move the logic into a shared library |
| `ERROR: Could not find credentials entry with ID 'aws-key'` | Wrong credential ID, or the credential lives in a folder the job can't see | Check the ID and scope (global vs folder) |
| `Host key verification failed` / `Permission denied (publickey)` | Git over SSH: unknown host key or wrong deploy key | **Manage Jenkins → Security → Git Host Key Verification**: add the host key; check the deploy key's access in Bitbucket or GitHub |
| `java.io.NotSerializableException` | Non-serializable object kept across steps in a scripted pipeline | Move it into a `@NonCPS` method, or don't store it in a variable between steps |
| `docker: permission denied … docker.sock` | Agent user not in the `docker` group | `sudo usermod -aG docker jenkins`, then restart the agent |
| `docker: not found` / `aws: not found` / `trivy: not found` | Tool missing on **this** agent (works on another) | Install it on every agent with that label, or run the step in a container (`agent { docker { image … } }`) |
| `Library … expected to contain at least one of src or vars directories` | Shared library misconfigured | Check the repository URL and branch in **Global Pipeline Libraries** |
| `Timeout has been exceeded` | A step ran longer than its `timeout` | Find the slow step (Stage View timings); raise the timeout only if the slowness is expected |

## GitHub Actions issues

> **In simple words:** In GitHub Actions, the common problems are a workflow that **doesn't start**, a job that **waits for a runner**, a token or secret that **lacks permission or is empty**, and **AWS OIDC** that refuses the role.

| Symptom | Cause | Fix |
|---|---|---|
| Workflow doesn't run at all | File not in `.github/workflows/` on the **default branch**, `on:` filters (branches or paths) don't match, or the workflow is disabled | **Actions** tab → check the workflow is enabled; fix the `branches:` / `paths:` filters |
| Scheduled workflow stopped running | Scheduled workflows in public repos are disabled after 60 days without repository activity | Re-enable it in the **Actions** tab |
| A push made by a workflow doesn't trigger the next workflow | Events created with `GITHUB_TOKEN` intentionally don't start new workflow runs | Use a GitHub App token or a fine-grained PAT for that push, or call the next workflow with `workflow_call` |
| `Waiting for a runner to pick up this job…` | `runs-on` labels match no online runner; self-hosted runner offline; concurrency limit | Fix the labels; check **Settings → Actions → Runners**; check the `concurrency:` group |
| `Resource not accessible by integration` | `GITHUB_TOKEN` lacks a permission | Add it under `permissions:` (e.g. `packages: write`, `pull-requests: write`) |
| Secret is empty | The run came from a **fork** PR (no secrets), the secret is defined on another **environment**, or the name is misspelled | Check where it's defined: repo, environment or organisation, and that the job sets `environment:` |
| `Could not assume role with OIDC: Not authorized to perform sts:AssumeRoleWithWebIdentity` | Missing `permissions: id-token: write`, or the role's trust policy `sub` doesn't match `repo:<org>/<repo>:ref:refs/heads/<branch>` | Add the permission; fix the trust condition (tags, environments and PRs have different `sub` values) |
| `fatal: No names found` / version script can't find tags | `actions/checkout` does a **shallow** clone by default | `with: fetch-depth: 0` |
| Cache never hits | Cache key changes every run, or a different OS or path | Base the key on lock files (`hashFiles('**/requirements*.txt')`) |
| `Node.js 20 actions are deprecated` warnings | An action version runs on an old Node runtime | Update to the action's current major version |

## GitLab CI issues

> **In simple words:** In GitLab, the classics are **no pipeline is created**, a job **stuck pending** with no runner, **Docker-in-Docker** can't connect, and a **variable is empty** because it's protected.

| Symptom | Cause | Fix |
|---|---|---|
| No pipeline appears | The file isn't exactly `.gitlab-ci.yml` at the root, it has invalid YAML, or `workflow: rules` exclude this push | **Build → Pipeline editor → Validate**; check `workflow:rules` |
| Job skipped | Its `rules:` didn't match, or a job it `needs:` didn't run | Check the rules order (first match wins) and `needs:` |
| `This job is stuck because you don't have any active runners online … with any of these tags` | No runner matches the job's `tags`, shared runners are off, or the account isn't verified | Match `tags:` to a runner; enable shared runners; register a project runner |
| Job pending only on feature branches | The runner is **protected**, so it only runs protected branches or tags | Unprotect the runner, or use another runner for feature branches |
| `Cannot connect to the Docker daemon at tcp://docker:2375` / `docker:2376` | DinD service missing, a TLS mismatch, or the runner isn't privileged | `services: [docker:29-dind]`, `DOCKER_TLS_CERTDIR: "/certs"`, runner `privileged = true` with the `/certs/client` volume |
| Variable empty | It's **protected** and the branch isn't; or the environment scope doesn't match | Protect the branch or tag, or unprotect the variable; fix the environment scope |
| `ERROR: Job failed: exit code 137` | The job ran out of memory on the runner | Bigger runner, or less parallel work (e.g. `mvn -T 1`, fewer test workers) |
| `Job failed: execution took longer than 1h0m0s` | Job or project timeout | Speed it up (caching), or raise the timeout in **Settings → CI/CD** |
| Cache "works", but the next stage can't find build output | Cache is a best-effort speed-up; **artifacts** pass files between jobs | Use `artifacts:` for build output, `cache:` for downloaded dependencies |

## Docker build works locally but fails in CI

> **In simple words:** Your laptop and the CI runner are **different computers**: different CPU, operating system, files, network, cached images and logins. When a build works locally and fails in CI, one of those differences is the cause. Rebuilding **from a fresh clone, with no cache** almost always reproduces it.

### Reproduce CI on your machine

```bash
rm -rf /tmp/ci-repro && git clone <repo-url> /tmp/ci-repro && cd /tmp/ci-repro   # only committed files
git checkout <failing-commit>
docker build --no-cache --pull --platform linux/amd64 --progress=plain -t repro:test .
```

- **Fresh clone:** no untracked or ignored files that exist only on your laptop.
- **`--no-cache --pull`:** no old cached layers or base images.
- **`--platform linux/amd64`:** the CPU architecture most CI runners use.
- **`--progress=plain`:** full output, so you see exactly which step fails.

### The usual differences

| Difference | Symptom in CI | Fix |
|---|---|---|
| **Files that exist only locally** (untracked, in `.gitignore`, generated) | `COPY failed: file not found`, missing `.env`, missing built assets | Commit them, or generate them in the pipeline (or in a multi-stage Dockerfile) |
| **`.dockerignore`** excludes something the build needs | `COPY` finds nothing; build output missing | Check `.dockerignore`; build output often lives in `target/` or `dist/`, which people ignore |
| **CPU architecture** (Apple Silicon arm64 vs CI amd64) | `exec format error`, `no match for platform`, native modules failing | Build with `--platform`, or multi-arch with `buildx` |
| **Old cached base image locally** | CI pulls a newer base image whose packages changed | Pin the base image tag (or digest); use `--pull` locally too |
| **Not logged in to a private registry for the base image** | `pull access denied` / `unauthorized` on `FROM` | Log in to that registry in CI **before** `docker build` |
| **Network / proxy / mirrors** | `pip`/`npm`/`mvn` downloads time out; `Could not resolve host` | Configure the company proxy or package mirror in CI (`--build-arg HTTP_PROXY=…`, `settings.xml`, `.npmrc`) |
| **Windows line endings (CRLF)** in shell scripts | `/bin/sh^M: bad interpreter` / `exec ./entrypoint.sh: no such file or directory` | Add `.gitattributes` with `*.sh text eol=lf`, and re-commit the scripts |
| **Lost executable bit** (committed from Windows) | `permission denied` running a script | `git update-index --chmod=+x script.sh`, or `RUN chmod +x` in the Dockerfile |
| **Case-sensitive file names** (Linux) | `COPY Config/app.yaml` works on Mac or Windows, fails on Linux | Match the exact case of file and folder names |
| **Missing build args or build secrets** | Empty values, failed `RUN` steps needing tokens | Pass `--build-arg` / `--secret` in CI the same way as locally |
| **Old Docker, or BuildKit off** | `the --mount option requires BuildKit`, unknown Dockerfile flags | Use a current Docker with BuildKit (`DOCKER_BUILDKIT=1`, or `docker buildx build`) |
| **Disk full or Docker Hub rate limit on the runner** | `no space left on device`, `toomanyrequests` | Prune the runner; log in to Docker Hub or use a mirror (e.g. ECR pull-through cache) |

## Works for dev, fails for prod

> **In simple words:** When the same pipeline passes for dev and fails for prod, the code is usually fine. Something **environment-specific** differs: a secret, a permission, a registry, a runner, a build setting or a stricter gate. Compare the two runs side by side, setting by setting.

### Compare the two runs

| Compare | How |
|---|---|
| Parameters and variables | Build parameters page (Jenkins), the **Variables** of each job (GitLab), the inputs and environment (GitHub). Print **non-secret** values at the start of the job |
| Which agent or runner ran it | Jenkins console header `Running on …`; GitLab job log `Running with gitlab-runner … on …`; GitHub job **Set up job** step |
| Image name, tag and registry | The `docker build` / `docker push` lines in each log |
| Commit and branch | Same commit? A prod tag pipeline may build a different ref |
| Rendered config | `diff <(helm template … -f values-dev.yaml) <(helm template … -f values-prod.yaml)` |

### The usual causes

| Cause | Symptom | Fix |
|---|---|---|
| **Secret or variable only available for dev** | Empty variable, `unauthorized` in prod | GitLab: the variable is **protected** but the prod pipeline runs on an unprotected ref (or the reverse), or has the wrong **environment scope**. GitHub: the secret is on the `dev` environment only. Jenkins: the credential is in a different folder |
| **Prod is another AWS account or Region** | `name unknown` / `denied` on push or deploy | The prod ECR repository doesn't exist there, or the CI role lacks permission. Check the registry URL and role per environment |
| **Immutable tags in the prod repository** | `tag invalid: … already exists … immutable` | Don't reuse tags like `latest` or `main-SNAPSHOT` for prod. Use the Git SHA or release version |
| **Different build target or args** | Prod image fails to build or start | `--target prod` or `NODE_ENV=production` skips dev dependencies the build actually needs; prod config file not committed |
| **Stricter security gate for prod** | Trivy, SonarQube or ZAP fails only for prod | Expected: fix the findings, or record a dated exception (see the DevSecOps guide) |
| **Prod job runs on a different runner or agent** | `docker: not found`, a different architecture, or no network to the prod registry | Align the labels or tags, install the tools, open the network path |
| **Branch protection and approvals** | Prod job waits or is skipped | Required reviewers or environment approval pending; a protected-branch rule blocks the merge |
| **Kubernetes deploy differs** | `Forbidden` / `Unauthorized` deploying to the prod cluster | The CI role has no EKS access entry on the prod cluster, or the wrong kubeconfig context or namespace |

## Unable to push images to ECR

> **In simple words:** A push to ECR needs four things to line up: **valid login** (a token under 12 hours old, for the right account and Region), **IAM permission**, a **repository that exists** in that account and Region, and a **network path**. The error message tells you which one is missing.

### First, check the basics

```bash
aws sts get-caller-identity                                    # which AWS identity is CI really using?
echo "$REGISTRY"                                               # <account>.dkr.ecr.<region>.amazonaws.com
aws ecr describe-repositories --region <region> --repository-names <repo> \
  --query 'repositories[0].[repositoryUri,imageTagMutability]' --output text
docker images | grep <repo>                                    # is the image tagged with the FULL ECR URI?
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin "$REGISTRY"
```

### Error message → cause → fix

| Error message | Cause | Fix |
|---|---|---|
| `no basic auth credentials` | Not logged in, the 12-hour token expired, or logged in to a **different** registry (account or Region) | Run `get-login-password \| docker login` for the exact registry, right before the push |
| `denied: requested access to the resource is denied` (pushing to `docker.io/…`) | The image wasn't tagged with the ECR URI, so Docker pushes to Docker Hub | `docker tag app:1.0 <account>.dkr.ecr.<region>.amazonaws.com/app:1.0` |
| `denied: User: arn:… is not authorized to perform: ecr:InitiateLayerUpload` (or `PutImage`, `CompleteLayerUpload`) | The identity lacks push permissions | Attach a push policy for that repository (see the ECR or DevSecOps guide), or `AmazonEC2ContainerRegistryPowerUser` |
| `… with an explicit deny in a service control policy` / `permissions boundary` | An organisation guardrail blocks it | Ask the platform or security team. IAM allows can't override an explicit deny |
| `name unknown: The repository with name 'app' does not exist in the registry with id '…'` | Repository missing, or wrong **Region** or **account** in the URI | Create it (or via Terraform), or fix the URI |
| `tag invalid: The image tag '1.0' already exists … cannot be overwritten because the repository is immutable` | Tag reuse in an immutable repository | Push a new tag (Git SHA, build number) |
| `denied: Your authorization token has expired` | Login happened more than 12 hours ago (long builds, cached `config.json`) | Log in again just before pushing |
| `dial tcp … i/o timeout` / `connection reset` | Runner in a private subnet with no route to ECR | NAT gateway, or VPC endpoints: `com.amazonaws.<region>.ecr.api`, `ecr.dkr`, and an **S3 gateway** endpoint (layers are stored in S3) |
| `error getting credentials … docker-credential-desktop: executable file not found` | `~/.docker/config.json` on the agent points at a credential helper that isn't installed | Remove `"credsStore"` from the agent's `config.json`, or install the helper |
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` (before the push) | CI OIDC role trust policy doesn't match this repo, branch or environment | Fix the `sub` condition (see the GitHub Actions guide) |
| `Signature expired` / `SignatureDoesNotMatch` | The runner's clock is wrong | Enable time sync (chrony / NTP) on the runner |
| Push fails right after the repository was re-created with a KMS key | The KMS key is disabled or scheduled for deletion | Check the key state in KMS ([KMS guide](#/tool/aws-kms)) |

Check permissions without pushing:

```bash
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::<account>:role/<ci-role> \
  --action-names ecr:InitiateLayerUpload ecr:PutImage \
  --resource-arns arn:aws:ecr:<region>:<account>:repository/<repo> \
  --query 'EvaluationResults[].[EvalActionName,EvalDecision]' --output table
```

## Other real issues

> **In simple words:** A grab bag of problems every team hits sooner or later: slow builds, full disks, flaky tests, secrets in logs, Git authentication and scanners that suddenly fail.

| Problem | Cause | Fix |
|---|---|---|
| **Builds got slow** | No layer cache on fresh runners; dependencies downloaded every time; `COPY . .` before installing dependencies | Order Dockerfile layers (dependencies first); use `buildx` cache (`--cache-from/--cache-to type=registry` or `type=gha`); cache `~/.m2`, `~/.npm`, pip |
| **Agent or runner disk full** | Old images, volumes, workspaces | Scheduled `docker system prune -af --filter until=72h`, workspace clean-up, and disk alerts |
| **Flaky tests** | Order-dependent tests, shared state, real network calls, timing | Fix or **quarantine** them with an owner; never silently `retry: 3` everything |
| **A secret appeared in the log** | `set -x`, `echo`, or a tool printing its config | Rotate it **now**. Then remove `set -x` around secrets, and rely on masking (masking hides exact values only) |
| `fatal: could not read Username for 'https://github.com'` | HTTPS clone without credentials | Use the CI's checkout step, or SSH with a deploy key |
| **SonarQube quality gate step hangs** | The SonarQube → Jenkins webhook is missing or can't reach Jenkins | Configure `https://<jenkins>/sonarqube-webhook/` in SonarQube |
| **Trivy: `failed to download vulnerability DB … toomanyrequests`** | Registry rate limit on the DB download | Cache the DB between runs (`--cache-dir`); use a mirror: `--db-repository public.ecr.aws/aquasecurity/trivy-db` |
| **Docker Hub `toomanyrequests`** | Anonymous pull limit | `docker login` with a Docker Hub account, or pull through ECR's pull-through cache |
| **`kubectl` in CI: `Unauthorized` / `Forbidden`** | The CI role has no access to the cluster or namespace | Add an EKS access entry for the CI role with a namespace-scoped policy |
| **Pipeline green, but nothing deployed** | The deploy job was skipped by rules or conditions, or Argo CD didn't sync | Check the job conditions; check the Argo CD app's sync status and the GitOps commit |

## Practice lab: break the pipeline on purpose

> **In simple words:** Cause the classic failures yourself in a test repository and fix each one by reading the error. That's the quickest way to recognise them in real life.

Use the sample app and any of the CI guides ([Jenkins](#/tool/jenkins), [GitHub Actions](#/tool/github-actions), [GitLab](#/tool/gitlab-ci)):

1. **Push without the registry prefix:** tag the image `hello-app:1.0` and push it. Read the `denied … docker.io` error, then fix the tag.
2. **Expired or missing login:** remove the `docker login` step and push. Read `no basic auth credentials`.
3. **Immutable tag:** turn on tag immutability in ECR and push the same tag twice.
4. **Missing file in CI:** add a file your Dockerfile copies, but list it in `.gitignore`. The build works locally and fails in CI. Explain why.
5. **CRLF script:** commit an `entrypoint.sh` with Windows line endings (`unix2dos entrypoint.sh`). Read the error, then fix it with `.gitattributes`.
6. **Dev vs prod:** make a variable available only to the dev environment (GitHub environment secret, or GitLab protected or scoped variable) and watch the prod job fail. Fix the scope.
7. **Jenkins:** stop the agent service and watch builds queue. Read the queue tooltip, then bring it back.

### Cheat sheet

| Situation | First command |
|---|---|
| Jenkins down | `systemctl status jenkins` / `docker logs jenkins` |
| Jenkins disk | `du -sh $JENKINS_HOME/* \| sort -h` |
| Disable a broken plugin | `touch $JENKINS_HOME/plugins/<name>.jpi.disabled` |
| Reproduce CI build | Fresh clone + `docker build --no-cache --pull --platform linux/amd64 --progress=plain .` |
| Which AWS identity | `aws sts get-caller-identity` |
| ECR login | `aws ecr get-login-password --region R \| docker login --username AWS --password-stdin ACCT.dkr.ecr.R.amazonaws.com` |
| Does the repo exist | `aws ecr describe-repositories --region R --repository-names NAME` |
| Can this role push | `aws iam simulate-principal-policy --policy-source-arn ROLE --action-names ecr:PutImage --resource-arns REPO_ARN` |
| Free runner disk | `docker system df` then `docker system prune -af --filter until=72h` |
