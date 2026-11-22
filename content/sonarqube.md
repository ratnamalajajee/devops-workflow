# SonarQube: Static Code Analysis (SAST)

SonarQube reads your source code **without running it** and reports bugs, security vulnerabilities, security hotspots and code smells. A **quality gate** then gives one clear answer: pass or fail. This guide runs a SonarQube server, then analyses a Python repository step by step: from your laptop, from **GitLab CI** and from **Jenkins**. The settings are the ones that work in a real Python microservices project, including SonarQube installed in its own namespace on Kubernetes (EKS) and the scan script that AWS CodeBuild runs.

> **Note:** One guide per security tool: [Gitleaks](#/tool/gitleaks) · [SonarQube](#/tool/sonarqube) · [Trivy](#/tool/trivy) · [Snyk](#/tool/snyk) · [DAST with ZAP](#/tool/dast-zap). The [Jenkins DevSecOps Pipeline](#/tool/jenkins-devsecops) shows SonarQube for a Java (Maven) project.

## Start here: SonarQube in simple words

> **In simple words:** SonarQube is a **code reviewer that never gets tired**. It reads every line of every change and points at bugs and risky code. The quality gate is the pass mark: below it, the change isn't ready.

### Watch how it works

```svg Watch it work: the scanner uploading an analysis with a token, the quality gate answering FAILED, report or enforce mode, and the fix that makes it pass. The animation loops.
<svg viewBox="0 0 600 386" role="img" data-anim="sonarqube" aria-label="Animated SonarQube flow. Analyse: the scanner runs in the CI pipeline, or through the script sonarqube-scan.sh. It reads sonar-project.properties in the repository root, which says to analyse the services and shared-lib folders. It gets its token from a masked CI variable called SONAR_TOKEN, or from the AWS Secrets Manager secret security/sonarqube-token, and only the bare sqp_ value is stored. It uploads the analysis over HTTPS to the SonarQube server at SONAR_HOST_URL. Quality gate: the server applies its rules and finds that a new file, risky.py, adds two security hotspots that nobody has reviewed: a hard-coded password and shell=True. The Sonar way quality gate wants every new hotspot reviewed, so it says FAILED. Because of sonar.qualitygate.wait=true, the scanner was waiting for this answer, and it exits 1. In report mode the pipeline carries on: the GitLab job exits 3 and turns orange, and the script exits 0 and prints the result in the log. In enforce mode, with SONAR_ENFORCE=true, the job exits 1 and turns red, and the pipeline stops. Fix it: you open the dashboard link from the log, where the Issues and Security Hotspots tabs show each problem, its line and how to fix it. After the fix, the next analysis passes the gate and the scanner exits 0.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<rect x="404" y="8" width="192" height="290" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="5 4"/>
<polyline points="90,162 297,162 500,162" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="90,60 260,60 260,136" fill="none" stroke-linejoin="round" stroke="#eab308" stroke-width="1.8" stroke-dasharray="3 3" stroke-opacity=".75"/>
<polyline points="500,162 500,60" fill="none" stroke-linejoin="round" stroke="#0ea5e9" stroke-width="1.8" stroke-dasharray="2 3" stroke-opacity=".75"/>
<polyline points="500,60 334,60 334,136" fill="none" stroke-linejoin="round" stroke="#0ea5e9" stroke-width="1.8" stroke-dasharray="2 3" stroke-opacity=".75"/>
<polyline points="297,162 297,264" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="297,264 500,264" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<rect x="410" y="14" width="102.4" height="16" rx="5" class="dg-box"/><text x="414" y="24" font-size="11" class="dg-muted">SonarQube server</text>
<g><rect x="8" y="30" width="164" height="60" rx="12" fill="#ca8a04" fill-opacity=".18" stroke="#ca8a04" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1032;0.2143" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/></rect><rect x="12" y="34" width="156" height="52" rx="9" class="dg-box" stroke="#ca8a04" stroke-width="2.2"/><text x="90" y="56.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Secrets Manager</text><text x="90" y="72" text-anchor="middle" font-size="11" class="dg-muted">security/sonarqube-token</text></g>
<g><rect x="8" y="132" width="164" height="60" rx="12" fill="#f97316" fill-opacity=".18" stroke="#f97316" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1032" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/></rect><rect x="12" y="136" width="156" height="52" rx="9" class="dg-box" stroke="#f97316" stroke-width="2.2"/><text x="90" y="158.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Your repo</text><text x="90" y="174" text-anchor="middle" font-size="11" class="dg-muted">sonar-project.properties</text></g>
<g><rect x="218" y="132" width="158" height="60" rx="12" fill="#6366f1" fill-opacity=".18" stroke="#6366f1" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1;0;1;0;1" keyTimes="0;0.3175;0.4365;0.5476;0.6587;0.7698;0.881" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/></rect><rect x="222" y="136" width="150" height="52" rx="9" class="dg-box" stroke="#6366f1" stroke-width="2.2"/><text x="297" y="158.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Scanner</text><text x="297" y="174" text-anchor="middle" font-size="11" class="dg-muted">sonar-scanner in CI</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5476;0.6587" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><rect x="222" y="136" width="150" height="52" rx="9" fill="#d97706"/><text x="297" y="166.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">⚠ report mode</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6587;0.7698" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><rect x="222" y="136" width="150" height="52" rx="9" fill="#e11d48"/><text x="297" y="166.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">✕ exit 1 · red</text></g></g>
<rect x="222" y="238" width="150" height="52" rx="9" class="dg-box"/><g opacity="1"><animate attributeName="opacity" values="1;0.28;1" keyTimes="0;0.6587;0.7698" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><rect x="218" y="234" width="158" height="60" rx="12" fill="#10b981" fill-opacity=".18" stroke="#10b981" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5476;0.6587" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/></rect><rect x="222" y="238" width="150" height="52" rx="9" class="dg-box" stroke="#10b981" stroke-width="2.2"/><text x="297" y="260.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Pipeline</text><text x="297" y="276" text-anchor="middle" font-size="11" class="dg-muted">build · test · deploy</text></g>
<g><rect x="412" y="30" width="176" height="60" rx="12" fill="#d97706" fill-opacity=".18" stroke="#d97706" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.3175;0.4365;0.881" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/></rect><rect x="416" y="34" width="168" height="52" rx="9" class="dg-box" stroke="#d97706" stroke-width="2.2"/><text x="500" y="56.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Quality gate</text><text x="500" y="72" text-anchor="middle" font-size="11" class="dg-muted">Sonar way, new code</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3175;0.881" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><rect x="416" y="34" width="168" height="52" rx="9" fill="#e11d48"/><text x="500" y="64.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">✕ FAILED</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.881" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><rect x="416" y="34" width="168" height="52" rx="9" fill="#059669"/><text x="500" y="64.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">✓ PASSED</text></g></g>
<g><rect x="412" y="132" width="176" height="60" rx="12" fill="#0891b2" fill-opacity=".18" stroke="#0891b2" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2143;0.4365" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/></rect><rect x="416" y="136" width="168" height="52" rx="9" class="dg-box" stroke="#0891b2" stroke-width="2.2"/><text x="500" y="158.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Analysis</text><text x="500" y="174" text-anchor="middle" font-size="11" class="dg-muted">issues, hotspots, coverage</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3175;0.4365" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><rect x="416" y="136" width="168" height="52" rx="9" fill="#d97706"/><text x="500" y="166.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">⚠ 2 new hotspots</text></g></g>
<g><rect x="412" y="234" width="176" height="60" rx="12" fill="#7c3aed" fill-opacity=".18" stroke="#7c3aed" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7698;0.881" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/></rect><rect x="416" y="238" width="168" height="52" rx="9" class="dg-box" stroke="#7c3aed" stroke-width="2.2"/><text x="500" y="260.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Dashboard</text><text x="500" y="276" text-anchor="middle" font-size="11" class="dg-muted">Issues · Hotspots tabs</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6587;0.7698" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="297" cy="213" r="9.5" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M293,209 L301,217 M301,209 L293,217" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.881" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="372" cy="136" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M367.5,136 L371,139.5 L376.5,132.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0062;0.0887" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M90,162 L297,162" keyPoints="0;0;1;1" keyTimes="0;0.0062;0.0887;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1098;0.1987" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M90,60 L260,60 L260,136 L297,162" keyPoints="0;0;1;1" keyTimes="0;0.1098;0.1987;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2205;0.303" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M297,162 L500,162" keyPoints="0;0;1;1" keyTimes="0;0.2205;0.303;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3532;0.4127" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M500,162 L500,60" keyPoints="0;0;1;1" keyTimes="0;0.3532;0.4127;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4432;0.5321" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M500,60 L334,60 L334,136 L297,162" keyPoints="0;0;1;1" keyTimes="0;0.4432;0.5321;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><g><circle r="7" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M0,-3.5 V1 M0,3.2 V3.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5754;0.6432" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M297,162 L297,264" keyPoints="0;0;1;1" keyTimes="0;0.5754;0.6432;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7765;0.8654" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M297,264 L500,264" keyPoints="0;0;1;1" keyTimes="0;0.7765;0.8654;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8857;0.919" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M297,162 L500,162" keyPoints="0;0;1;1" keyTimes="0;0.8857;0.919;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.9238;0.9524" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M500,162 L500,60" keyPoints="0;0;1;1" keyTimes="0;0.9238;0.9524;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.9571;0.9929" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M500,60 L334,60 L334,136 L297,162" keyPoints="0;0;1;1" keyTimes="0;0.9571;0.9929;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(21.2,310.5) scale(.8)"><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g><text x="33.4" y="314">code / analysis</text><g transform="translate(140.6,310.5) scale(.8)"><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g><text x="153.6" y="314">token</text><g transform="translate(204,310.5) scale(.8)"><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g><text x="215.4" y="314">gate check</text><g transform="translate(293.8,310.5) scale(.8)"><g><circle r="7" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M0,-3.5 V1 M0,3.2 V3.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/></g></g><text x="305.2" y="314">FAILED</text><g transform="translate(361.2,310.5) scale(.8)"><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g><text x="372.6" y="314">PASSED</text><g transform="translate(428.6,310.5) scale(.8)"><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g><text x="440" y="314">next stage</text><g transform="translate(518.4,310.5) scale(.8)"><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g><text x="529.8" y="314">you open it</text></g>
<rect x="12" y="326" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="326" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="25.2s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1032" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#6366f1"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="349" font-size="14" font-weight="800" fill="#6366f1">The scanner reads your code</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">Analyse · 1/9</text><text x="60" y="370" font-size="12.5" class="dg-text">sonar-project.properties says what to read: services and shared-lib.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1032;0.2143" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#6366f1"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="349" font-size="14" font-weight="800" fill="#6366f1">It gets the token</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">Analyse · 2/9</text><text x="60" y="370" font-size="12.5" class="dg-text">A masked CI variable SONAR_TOKEN, or the secret: just the sqp_… value.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2143;0.3175" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#6366f1"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="349" font-size="14" font-weight="800" fill="#6366f1">It uploads the analysis</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">Analyse · 3/9</text><text x="60" y="370" font-size="12.5" class="dg-text">Over HTTPS to SONAR_HOST_URL, for example https://sonarqube.example.com</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3175;0.4365" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#e11d48"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="349" font-size="14" font-weight="800" fill="#e11d48">The server checks the new code</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">Quality gate · 4/9</text><text x="60" y="370" font-size="12.5" class="dg-text">risky.py adds 2 unreviewed hotspots, so the Sonar way gate is FAILED.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4365;0.5476" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#e11d48"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="349" font-size="14" font-weight="800" fill="#e11d48">The waiting scanner gets the answer</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">Quality gate · 5/9</text><text x="60" y="370" font-size="12.5" class="dg-text">sonar.qualitygate.wait=true: the answer is FAILED, so it exits 1.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5476;0.6587" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#e11d48"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="349" font-size="14" font-weight="800" fill="#e11d48">Report mode: the pipeline goes on</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">Quality gate · 6/9</text><text x="60" y="370" font-size="12.5" class="dg-text">GitLab job: exit 3, orange. The script: exit 0, result in the log.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6587;0.7698" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#e11d48"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="349" font-size="14" font-weight="800" fill="#e11d48">Enforce mode: the pipeline stops</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">Quality gate · 7/9</text><text x="60" y="370" font-size="12.5" class="dg-text">With SONAR_ENFORCE=true the job exits 1 and turns red.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7698;0.881" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#059669"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="349" font-size="14" font-weight="800" fill="#059669">You open the dashboard</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">Fix it · 8/9</text><text x="60" y="370" font-size="12.5" class="dg-text">The log links to /dashboard?id=my-app: each issue, its line, the fix.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.881" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#059669"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">9</text><text x="60" y="349" font-size="14" font-weight="800" fill="#059669">Fix it, and the gate passes</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">Fix it · 9/9</text><text x="60" y="370" font-size="12.5" class="dg-text">Fix the code and analyse again: QUALITY GATE STATUS: PASSED, exit 0.</text></g>
</svg>
```

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
├── sonar-project.properties        what to analyse: folders, language version, exclusions
├── cicd/
│   ├── buildspec-sonarqube.yml     AWS CodeBuild: runs the script
│   └── security/
│       └── sonarqube-scan.sh       the scan: token, scanner, quality gate, report or enforce
├── services/                       one folder per Python service
│   ├── orders-service/
│   └── billing-service/
└── shared-lib/
```

| Setting | Where it lives | Example |
|---|---|---|
| Server | Helm release in its own namespace on EKS, opened on an HTTPS URL through an ALB | `https://sonarqube.example.com` |
| Runner | An AWS CodeBuild project that runs `cicd/security/sonarqube-scan.sh` (the same script runs in GitLab, Jenkins and on a laptop) | `aws codebuild start-build --project-name my-app-sonarqube` |
| `SONAR_HOST_URL` | CI variable | `https://sonarqube.example.com` |
| `SONAR_TOKEN` | CI **secret** (masked), or AWS Secrets Manager | `sqp_…` project analysis token, in secret `security/sonarqube-token` |
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

### On Kubernetes (the team setup)

Install it in its own namespace with Helm and open it on an HTTPS URL: see the next step, [Run SonarQube on Kubernetes and open it on a URL](#/tool/sonarqube/run-sonarqube-on-kubernetes-and-open-it-on-a-url).

## Run SonarQube on Kubernetes and open it on a URL

> **In simple words:** This is the team setup used in the real project. SonarQube runs in its **own namespace** on the EKS cluster, is installed with Helm, keeps its data in Amazon RDS (PostgreSQL), and everyone opens it on one HTTPS URL through an AWS load balancer (ALB).

```text
 browser / CI runner ──HTTPS──► ALB (ACM certificate) ──► Service sonarqube-sonarqube:9000 ──► Pod sonarqube-sonarqube-0
 https://sonarqube.example.com   created from the Ingress       (namespace "sonarqube")                  │
                                                                                                           ▼
                                                                          Amazon RDS PostgreSQL, database "sonarqube"
```

### 1. Check what you need first

| Need | Check with |
|---|---|
| An EKS cluster, and `kubectl` pointing at it | `kubectl get nodes` |
| Helm 3 | `helm version` |
| The AWS Load Balancer Controller (turns an Ingress into an ALB) | `kubectl -n kube-system get deploy aws-load-balancer-controller` |
| A default StorageClass for the data volume (EBS CSI driver) | `kubectl get storageclass` |
| An ACM certificate for the host name, for example `sonarqube.example.com` | `aws acm list-certificates` |
| A node with about 4 GB of free memory | `kubectl top nodes` |
| A PostgreSQL database the cluster can reach (RDS) | the next step |

See the [EKS guide](#/tool/eks-cluster), [Load balancers](#/tool/aws-elb) and [RDS](#/tool/aws-rds) for these pieces.

### 2. Create the database and a user for SonarQube

From a temporary pod in the cluster (it can reach RDS when the RDS security group allows the nodes on port 5432):

```bash
kubectl run psql --rm -it --image=postgres:17 --restart=Never -- \
  psql "host=<rds-endpoint> user=<admin user> dbname=postgres sslmode=require"
```

```sql
CREATE USER sonar WITH PASSWORD '<strong password>';
CREATE DATABASE sonarqube OWNER sonar;
```

> **Tip:** Give SonarQube its own database user instead of the RDS admin user. If SonarQube's password ever leaks, only the SonarQube database is exposed.

### 3. Create the namespace and the secrets

```bash
kubectl create namespace sonarqube
read -rsp "Database password for user sonar: " DBPW && echo
kubectl -n sonarqube create secret generic sonarqube-db --from-literal=password="$DBPW"
unset DBPW
kubectl -n sonarqube create secret generic sonarqube-monitoring --from-literal=passcode="$(openssl rand -hex 16)"
```

### 4. Write the values file

`sonarqube-values.yaml` (no passwords in it, so it can live in Git):

```yaml
community:
  enabled: true                          # the free Community Build
monitoringPasscodeSecretName: sonarqube-monitoring
monitoringPasscodeSecretKey: passcode    # the passcode stays in a Secret, not in this file
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
    alb.ingress.kubernetes.io/scheme: internal              # only reachable inside the VPC (or over VPN)
    # To share an ALB that already exists, instead of creating a new one:
    # alb.ingress.kubernetes.io/group.name: <the other Ingress's group name>
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS": 443}]'
    alb.ingress.kubernetes.io/certificate-arn: <acm certificate arn>   # CHANGE
    alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS13-1-2-2021-06
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/backend-protocol: HTTP
    alb.ingress.kubernetes.io/healthcheck-path: /api/system/status
  hosts:
    - name: sonarqube.example.com        # CHANGE
      path: /
      pathType: Prefix                   # the chart's default makes the ALB match "/" only
```

### 5. Install it with Helm

```bash
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo update
helm search repo sonarqube/sonarqube --versions | head -5     # pick a chart version, and pin it
helm upgrade --install sonarqube sonarqube/sonarqube -n sonarqube \
  -f sonarqube-values.yaml --version <chart version>
```

### 6. Watch it start

```bash
kubectl -n sonarqube get pods -w          # sonarqube-sonarqube-0: Init → Running → READY 1/1 (2 to 5 minutes)
kubectl -n sonarqube logs -f sonarqube-sonarqube-0 -c sonarqube   # wait for "SonarQube is operational"
```

The chart starts a small privileged init container that sets `vm.max_map_count` on the node, so you don't have to.

### 7. Open it on the URL

The Ingress creates an ALB. Find its address:

```bash
kubectl -n sonarqube get ingress
```

The `ADDRESS` column shows the ALB's DNS name (for an internal ALB it starts with `internal-k8s-…elb.amazonaws.com`). Point your host name at it: in **Route 53 → Hosted zones →** your zone **→ Create record**, name `sonarqube`, **Alias** on, **Alias to Application Load Balancer**, your region, then that ALB. (If ExternalDNS runs in the cluster, it creates the record for you.)

Check it from a machine in the VPC (or on the VPN):

```bash
curl -s https://sonarqube.example.com/api/system/status
# {"id":"…","version":"…","status":"UP"}
```

Then open `https://sonarqube.example.com` in the browser, log in as `admin` / `admin`, and set a new password straight away.

> **Note:** An **internal** ALB is only reachable from inside the VPC: your laptop needs the VPN, and the CI runners must run in the VPC too (a CodeBuild project with VPC settings, a self-managed GitLab runner, or a Jenkins agent in the VPC).

### 8. No URL yet? Use a port-forward

```bash
kubectl -n sonarqube port-forward svc/sonarqube-sonarqube 9000:9000
```

Open `http://localhost:9000` while the command runs. Good for a first look, not for CI.

### 9. Look after it

| Task | How |
|---|---|
| Upgrade | Take an RDS snapshot, read the release notes, then `helm upgrade` with the new `--version`. If SonarQube says it's under maintenance, open `https://<your URL>/setup` to upgrade the database |
| Backup | The data is in RDS: use RDS automated backups. The volume only holds search indexes that SonarQube rebuilds from the database |
| Logs | `kubectl -n sonarqube logs sonarqube-sonarqube-0 -c sonarqube` |
| Restart | `kubectl -n sonarqube rollout restart statefulset sonarqube-sonarqube` |

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

## Script integration with AWS CodeBuild (the working setup)

> **In simple words:** In the real project the scan isn't written into each pipeline. It's **one script in the repository**. An AWS CodeBuild project runs it and reads the token from **AWS Secrets Manager**, and the same script also runs on a laptop, in GitLab and in Jenkins. One place to change, the same result everywhere.

```text
 aws codebuild start-build ──► CodeBuild project (privileged, inside the VPC)
                                  │  buildspec: sh cicd/security/sonarqube-scan.sh
                                  ▼
                       sonarqube-scan.sh ──── reads the token ────► AWS Secrets Manager: security/sonarqube-token
                                  │
                                  ├── docker run sonar-scanner-cli ──HTTPS──► SonarQube on EKS (internal ALB)
                                  │            waits for the quality gate ◄─────────────┘
                                  ▼
                       PASS / FINDINGS / ERROR ──► exit 0 (report mode) or exit 1 (SONAR_ENFORCE=true)
```

### 1. Add the script to the repository

Save this as `cicd/security/sonarqube-scan.sh`. It's plain POSIX `sh`, so it also runs in small images without bash:

```bash
#!/bin/sh
# =============================================================================
# cicd/security/sonarqube-scan.sh — SAST: SonarQube analysis + quality gate.
#
# One script for every runner: your laptop, AWS CodeBuild, GitLab CI, Jenkins.
# It analyses the repository root with sonar-project.properties, then waits
# for the quality gate. Run it with: sh cicd/security/sonarqube-scan.sh
#
# Settings (environment variables):
#   SONAR_HOST_URL      the server, e.g. https://sonarqube.example.com ("" = skipped)
#   SONAR_TOKEN         the analysis token (sqp_...), or instead:
#   SONAR_TOKEN_SECRET  an AWS Secrets Manager secret holding it: the plain token,
#                       or JSON {"token": "..."} (needs the aws CLI; jq for JSON)
#   SONAR_PROJECT_KEY   overrides sonar.projectKey
#   SONAR_ENFORCE       "true" = a failed gate fails the run (exit 1).
#                       Default: report mode (the result is printed, exit 0).
#   SONAR_GATE_TIMEOUT  seconds to wait for the gate (default 600)
#   SONAR_IMAGE         scanner image, used when sonar-scanner isn't installed
#   SONAR_DOCKER_ARGS   extra "docker run" options, e.g. "--network host"
#   AWS_REGION          region of SONAR_TOKEN_SECRET (default us-east-1)
# Extra arguments go to the scanner, e.g. -Dsonar.verbose=true
# =============================================================================
set -eu

IMAGE="${SONAR_IMAGE:-sonarsource/sonar-scanner-cli:12.3.1.4302_8.3.1}"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

log() { echo "[sonarqube] $*"; }

# finish <PASS|SKIPPED|FINDINGS|ERROR> <detail>: print the result and exit.
finish() {
  log "$1: $2"
  case "$1" in PASS|SKIPPED) exit 0 ;; esac
  if [ "${SONAR_ENFORCE:-false}" = "true" ]; then exit 1; fi
  log "Report mode: the run continues. Set SONAR_ENFORCE=true to fail it instead."
  exit 0
}

[ -n "${SONAR_HOST_URL:-}" ] || finish SKIPPED "SONAR_HOST_URL is not set"

# --- The token: from SONAR_TOKEN, or from AWS Secrets Manager ---
if [ -z "${SONAR_TOKEN:-}" ] && [ -n "${SONAR_TOKEN_SECRET:-}" ]; then
  value="$(aws secretsmanager get-secret-value --region "${AWS_REGION:-us-east-1}" \
             --secret-id "$SONAR_TOKEN_SECRET" --query SecretString --output text 2>/dev/null)" \
    || finish ERROR "cannot read the secret ${SONAR_TOKEN_SECRET} (does it exist? may this role read it?)"
  case "$value" in
    "{"*) value="$(printf '%s' "$value" | jq -r '.token // empty')" \
            || finish ERROR "the secret is JSON: install jq, or store only the token" ;;
  esac
  # A pasted value often has spaces or line breaks around it.
  SONAR_TOKEN="$(printf '%s' "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
fi
[ -n "${SONAR_TOKEN:-}" ] || finish ERROR "no token: set SONAR_TOKEN or SONAR_TOKEN_SECRET"
# A token is one word (sqp_...). Anything else is rejected here, because the
# scanner prints a malformed token in full in its error message.
case "$SONAR_TOKEN" in
  *[!A-Za-z0-9_]*) finish ERROR "the token is not a bare token (spaces, quotes or a label?): store only the sqp_... value" ;;
esac
export SONAR_TOKEN SONAR_HOST_URL

# --- Scanner arguments: yours first, then the quality-gate settings ---
set -- "$@" -Dsonar.qualitygate.wait=true "-Dsonar.qualitygate.timeout=${SONAR_GATE_TIMEOUT:-600}"
if [ -n "${SONAR_PROJECT_KEY:-}" ]; then set -- "$@" "-Dsonar.projectKey=${SONAR_PROJECT_KEY}"; fi

cd "$REPO_ROOT"
rc=0
if command -v sonar-scanner >/dev/null 2>&1; then
  log "Analysing ${REPO_ROOT} for ${SONAR_HOST_URL} (installed sonar-scanner)"
  sonar-scanner "$@" || rc=$?
else
  cache="${SONAR_CACHE_DIR:-$HOME/.cache/sonar}"
  mkdir -p "$cache"
  log "Analysing ${REPO_ROOT} for ${SONAR_HOST_URL} (${IMAGE})"
  # SONAR_DOCKER_ARGS is unquoted on purpose: it is a list of options.
  docker run --rm ${SONAR_DOCKER_ARGS:-} -u "$(id -u):$(id -g)" -e SONAR_TOKEN -e SONAR_HOST_URL \
    -v "$REPO_ROOT:/usr/src" -v "$cache:/tmp/sonar-cache" -w /usr/src "$IMAGE" \
    -Dsonar.userHome=/tmp/sonar-cache -Dsonar.working.directory=/tmp/scannerwork "$@" || rc=$?
fi

# The dashboard link is in the scanner's log above.
[ "$rc" -ne 0 ] || finish PASS "quality gate passed"
finish FINDINGS "quality gate failed, or the analysis failed (scanner exit ${rc}; see the log above)"
```

What it does, in order:

| Step | What happens |
|---|---|
| 1 | No `SONAR_HOST_URL`: prints SKIPPED and stops (exit 0) |
| 2 | Gets the token from `SONAR_TOKEN`, or reads it from Secrets Manager (`SONAR_TOKEN_SECRET`) and trims spaces around it |
| 3 | Refuses a token that isn't one word, such as a pasted label `Analyze "my-app": sqp_…`, before the scanner can print it |
| 4 | Runs the scanner: the installed `sonar-scanner` if there is one (GitLab's scanner image), otherwise the pinned Docker image |
| 5 | `-Dsonar.qualitygate.wait=true`: the scanner waits for the gate and exits 1 if it fails |
| 6 | Prints PASS, FINDINGS or ERROR. Report mode exits 0; `SONAR_ENFORCE=true` exits 1 on FINDINGS or ERROR |

Keep Unix line endings on scripts, or they fail with `$'\r': command not found` when the repository was committed from Windows:

```bash
echo '*.sh text eol=lf' >> .gitattributes
git add .gitattributes cicd/security/sonarqube-scan.sh
git commit -m "Add the SonarQube scan script"
```

### 2. Try it from your laptop

Linux, macOS or WSL (on Windows, use WSL), from anywhere inside the repository:

```bash
export SONAR_HOST_URL=https://sonarqube.example.com      # your URL (VPN on, if it's internal)
read -rsp "SonarQube token: " SONAR_TOKEN && export SONAR_TOKEN && echo

sh cicd/security/sonarqube-scan.sh                       # report mode
SONAR_ENFORCE=true sh cicd/security/sonarqube-scan.sh    # a failed gate exits 1

# or read the token from AWS Secrets Manager (needs AWS credentials)
unset SONAR_TOKEN
SONAR_TOKEN_SECRET=security/sonarqube-token sh cicd/security/sonarqube-scan.sh
```

For a server on your own Linux machine (`http://localhost:9000`), add `SONAR_DOCKER_ARGS="--network host"`.

The end of the output:

```text
INFO  QUALITY GATE STATUS: PASSED - View details on https://sonarqube.example.com/dashboard?id=my-app
[sonarqube] PASS: quality gate passed
```

### 3. Store the token in AWS Secrets Manager

```bash
read -rsp "SonarQube token (only the sqp_... value): " T && echo
aws secretsmanager create-secret --name security/sonarqube-token --secret-string "$T"
unset T
```

To replace it later (a new token, or an expired one), use the same `read` line, then `aws secretsmanager put-secret-value --secret-id security/sonarqube-token --secret-string "$T"`.

### 4. Let the CodeBuild role read it

Add this policy to the CodeBuild project's service role (CHANGE the region and account ID):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadSecurityScanSecrets",
      "Effect": "Allow",
      "Action": "secretsmanager:GetSecretValue",
      "Resource": "arn:aws:secretsmanager:us-east-1:123456789012:secret:security/*"
    }
  ]
}
```

```bash
aws iam put-role-policy --role-name my-codebuild-role \
  --policy-name read-security-secrets --policy-document file://read-security-secrets.json
```

If the secret is encrypted with your own KMS key, the role also needs `kms:Decrypt` on that key. See the [IAM guide](#/tool/aws-iam) and the [Secrets Manager guide](#/tool/aws-secrets).

### 5. Add the buildspec

`cicd/buildspec-sonarqube.yml`:

```yaml
version: 0.2

# SAST: SonarQube analysis + quality gate (cicd/security/sonarqube-scan.sh).
# SONAR_HOST_URL is set on the project. SONAR_ENFORCE=true makes a failed gate fail the build.
env:
  shell: bash
  variables:
    SONAR_TOKEN_SECRET: security/sonarqube-token
    SONAR_ENFORCE: "false"
    SONAR_CACHE_DIR: /root/.cache/sonar

phases:
  pre_build:
    commands:
      - sed -i 's/\r$//' cicd/security/*.sh       # in case of Windows line endings
  build:
    commands:
      - sh cicd/security/sonarqube-scan.sh

cache:
  paths:
    - '/root/.cache/sonar/**/*'
```

CodeBuild sets `AWS_REGION` for you, and its standard image already has the AWS CLI, `jq` and Docker.

### 6. Create the CodeBuild project

In the console: **CodeBuild → Build projects → Create build project**.

| Section | Setting |
|---|---|
| Project name | `my-app-sonarqube` |
| Source | Your Git provider (GitLab, GitHub or Bitbucket, through a connection), the repository, branch `main` |
| Environment | Managed image, **Amazon Linux**, runtime **Standard**, the latest image |
| Privileged | **On**: the script runs the scanner in Docker |
| Service role | The role from step 4 |
| Environment variables | `SONAR_HOST_URL` = `https://sonarqube.example.com` |
| VPC (under Additional configuration) | Needed when the SonarQube URL is internal: the cluster's VPC, **private** subnets with a NAT gateway (for Git, Docker Hub and AWS APIs), and a security group that the ALB's security group allows on 443 |
| Buildspec | **Use a buildspec file**: `cicd/buildspec-sonarqube.yml` |
| Logs | CloudWatch Logs on |

> **Note:** With VPC settings, the service role also needs the EC2 network-interface permissions that CodeBuild uses inside a VPC. The console adds them when it creates the role for you; for an existing role, see "Allow CodeBuild to access AWS services required to create a VPC network interface" in the CodeBuild documentation.

### 7. Run it and read the result

```bash
aws codebuild start-build --project-name my-app-sonarqube

# another branch, with a failed gate failing the build
aws codebuild start-build --project-name my-app-sonarqube --source-version feature/login \
  --environment-variables-override name=SONAR_ENFORCE,value=true,type=PLAINTEXT
```

Open the build in the console (or `aws logs tail` on its log group). The last lines show the gate status, the dashboard link and `[sonarqube] PASS`, `FINDINGS` or `ERROR`.

> **Warning:** On the **Community Build**, scanning a branch replaces the project's `main` result. For a branch scan, also override `SONAR_PROJECT_KEY` (for example `my-app-feature-login`).

### 8. The same script in GitLab and Jenkins

GitLab (the scanner image has `sonar-scanner`, so the script uses it directly; `SONAR_HOST_URL` and `SONAR_TOKEN` come from CI/CD variables):

```yaml
sonarqube:
  stage: security
  image:
    name: sonarsource/sonar-scanner-cli:12.3.1.4302_8.3.1
    entrypoint: [""]
  variables:
    GIT_DEPTH: "0"
    SONAR_USER_HOME: "${CI_PROJECT_DIR}/.sonar"
  cache:
    key: sonar-cache
    paths: [.sonar/cache]
  script:
    - sh cicd/security/sonarqube-scan.sh
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

Jenkins (the agent needs Docker; the token comes from the `sonarqube-token` credential):

```groovy
stage('SAST: SonarQube') {
    environment {
        SONAR_HOST_URL = 'https://sonarqube.example.com'          // CHANGE
    }
    steps {
        withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONAR_TOKEN')]) {
            withEnv(["SONAR_ENFORCE=${params.SONAR_ENFORCE}"]) {
                sh 'sh cicd/security/sonarqube-scan.sh'
            }
        }
    }
}
```

If the Jenkins agent runs on EC2 with an IAM role, drop the credential and set `SONAR_TOKEN_SECRET=security/sonarqube-token` instead: the script reads the token from Secrets Manager, as in CodeBuild.

> **Note:** In report mode the script exits 0, so the job stays green and the result is in the log. Set `SONAR_ENFORCE=true` (a CI/CD variable in GitLab, the build parameter in Jenkins) to make a failed gate fail the job.

> **Tip:** In the real project, this is one of five scans (`gitleaks`, `sonarqube`, `dependency-check`, `trivy`, `zap`), each with its own script, behind a small runner `run.sh <scan>` in **one** CodeBuild security project. A `SECURITY_SCAN` variable picks the scan for each run, and every run ends with a results table and a Microsoft Teams message. The SonarQube part works exactly like the script above.

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
| Kubernetes: pod `sonarqube-sonarqube-0` stays `Pending` | No node with about 4 GB free, or the volume can't be created (no default StorageClass or EBS CSI driver). Run `kubectl -n sonarqube describe pod sonarqube-sonarqube-0` and read the events |
| Kubernetes: pod restarts, the log says it can't connect to the database | The RDS security group doesn't allow the nodes on 5432, the JDBC URL is wrong, or the password in secret `sonarqube-db` is wrong |
| Kubernetes: the Ingress has no `ADDRESS` | The AWS Load Balancer Controller isn't installed, or it rejected the Ingress: read the events in `kubectl -n sonarqube describe ingress` (certificate ARN, subnet tags) |
| The URL opens, but other pages return 404 | `pathType: Prefix` is missing: the chart's default makes the ALB match `/` only |
| The ALB returns 502 or 503 for a few minutes | SonarQube is still starting. The target turns healthy when `/api/system/status` says `UP` |
| CodeBuild: the scanner `can not be reached` or times out | The SonarQube URL is internal and the project has no VPC settings, or its security group isn't allowed by the ALB's |
| CodeBuild: `Cannot connect to the Docker daemon` | Turn **Privileged** on in the project's environment |
| `[sonarqube] ERROR: cannot read the secret` | The secret is missing, in another region, or the role lacks `secretsmanager:GetSecretValue` (step 4 of the script integration) |
| `$'\r': command not found` or `set: Illegal option -` | The script has Windows line endings. Add `*.sh text eol=lf` to `.gitattributes`, or strip them with `sed -i 's/\r$//'` |

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

# SonarQube on Kubernetes
kubectl -n sonarqube get pods,svc,ingress
kubectl -n sonarqube logs -f sonarqube-sonarqube-0 -c sonarqube
kubectl -n sonarqube port-forward svc/sonarqube-sonarqube 9000:9000
curl -s https://sonarqube.example.com/api/system/status

# the scan script (laptop, CodeBuild, GitLab, Jenkins)
SONAR_HOST_URL=https://sonarqube.example.com SONAR_TOKEN_SECRET=security/sonarqube-token sh cicd/security/sonarqube-scan.sh
aws codebuild start-build --project-name my-app-sonarqube
```

Docs: [SonarQube Server documentation](https://docs.sonarsource.com/sonarqube-server/) · [Python rules](https://rules.sonarsource.com/python/)
