# Snyk: Dependency Checking (SCA)

Snyk checks the **open-source libraries** your application uses (for Python: `requirements.txt`, Poetry, Pipenv) against its vulnerability database, and tells you which upgrade fixes each problem. The same CLI can also scan your code (Snyk Code), container images (Snyk Container) and infrastructure files (Snyk IaC). This guide covers the account, installation, and how to run Snyk on your laptop, in **GitLab CI** and in **Jenkins**. It ends with free alternatives.

> **Note:** The commands on this page follow Snyk's documentation and **haven't been run in our pipelines yet**. Try them on a test branch first, and keep findings in report mode until you trust the results.

> **Note:** One guide per security tool: [Gitleaks](#/tool/gitleaks) · [SonarQube](#/tool/sonarqube) · [Trivy](#/tool/trivy) · [Snyk](#/tool/snyk) · [DAST with ZAP](#/tool/dast-zap).

## Start here: Snyk in simple words

> **In simple words:** Your app is maybe 10% your code and 90% other people's libraries. Snyk is a **recall checker for those libraries**: it reads your dependency list, finds the ones with known security holes, and tells you the version to upgrade to.

### Watch how it works

```svg Watch it work: snyk test checking the dependency tree, the upgrade that fixes an issue, an ignore in .snyk, the CI gate, and snyk monitor e-mailing you later. The animation loops.
<svg viewBox="0 0 600 392" role="img" data-anim="snyk" data-dur="34.34" data-starts="0 4.76 9.86 14.62 19.38 24.48 29.24" aria-label="Animated Snyk flow. snyk test: you install requirements.txt with pip first, because Snyk asks pip which versions are really installed. snyk test then builds the full dependency tree: you list requests, and urllib3 comes with it, 64 dependencies in all. Snyk checks every package and version in the tree against its vulnerability database. It reports an issue: urllib3 2.7.0 has a High severity vulnerability, introduced by requests, and upgrading to urllib3 2.8.0 fixes it. Because an issue is left, snyk test exits 1. In report mode the GitLab job exits 4, which is allowed to fail, so it turns orange, and Jenkins marks the build UNSTABLE; in enforce mode the job fails. You fix it by raising the pin, or accept it for a while with snyk ignore, which writes the reason and an expiry date into the .snyk file. The next run exits 0 and passes. snyk monitor: on the default branch, snyk monitor uploads a snapshot of the tree to the Snyk web app as the project orders-service. Later, when a new vulnerability is published that affects a package in the snapshot, Snyk e-mails you, without a new build.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<rect x="420" y="8" width="176" height="196" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="5 4"/>
<polyline points="90,60 300,60" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="300,60 510,60" fill="none" stroke-linejoin="round" stroke="#0d9488" stroke-width="1.8" stroke-dasharray="6 3" stroke-opacity=".7"/>
<polyline points="300,60 300,166 300,272" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="90,166 300,166" fill="none" stroke-linejoin="round" stroke="#0ea5e9" stroke-width="1.8" stroke-dasharray="2 3" stroke-opacity=".75"/>
<polyline points="378,76 405,76 405,166 432,166" fill="none" stroke-linejoin="round" stroke="#0d9488" stroke-width="1.8" stroke-dasharray="6 3" stroke-opacity=".7"/>
<polyline points="510,60 510,166" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="1.6" stroke-opacity=".8"/>
<polyline points="510,166 510,272" fill="none" stroke-linejoin="round" stroke="#db2777" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<rect x="426" y="14" width="78.8" height="16" rx="5" class="dg-box"/><text x="430" y="24" font-size="11" class="dg-muted">Snyk service</text>
<g><rect x="8" y="30" width="164" height="60" rx="12" fill="#f97316" fill-opacity=".18" stroke="#f97316" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1386" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/></rect><rect x="12" y="34" width="156" height="52" rx="9" class="dg-box" stroke="#f97316" stroke-width="2.2"/><text x="90" y="56.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">requirements.txt</text><text x="90" y="72" text-anchor="middle" font-size="11" class="dg-muted">installed with pip</text></g>
<g><rect x="218" y="30" width="164" height="60" rx="12" fill="#6366f1" fill-opacity=".18" stroke="#6366f1" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.2871" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/></rect><rect x="222" y="34" width="156" height="52" rx="9" class="dg-box" stroke="#6366f1" stroke-width="2.2"/><text x="300" y="56.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">snyk test</text><text x="300" y="72" text-anchor="middle" font-size="11" class="dg-muted">builds the full tree</text></g>
<g><rect x="428" y="30" width="164" height="60" rx="12" fill="#7c3aed" fill-opacity=".18" stroke="#7c3aed" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.1386;0.2871;0.8515" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/></rect><rect x="432" y="34" width="156" height="52" rx="9" class="dg-box" stroke="#7c3aed" stroke-width="2.2"/><text x="510" y="56.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Vulnerability DB</text><text x="510" y="72" text-anchor="middle" font-size="11" class="dg-muted">known issues + fixes</text></g>
<g><rect x="8" y="136" width="164" height="60" rx="12" fill="#ca8a04" fill-opacity=".18" stroke="#ca8a04" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5644;0.7129" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/></rect><rect x="12" y="140" width="156" height="52" rx="9" class="dg-box" stroke="#ca8a04" stroke-width="2.2"/><text x="90" y="162.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">.snyk</text><text x="90" y="178" text-anchor="middle" font-size="11" class="dg-muted">ignore + expiry date</text></g>
<g><rect x="218" y="136" width="164" height="60" rx="12" fill="#0891b2" fill-opacity=".18" stroke="#0891b2" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2871;0.4257" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/></rect><rect x="222" y="140" width="156" height="52" rx="9" class="dg-box" stroke="#0891b2" stroke-width="2.2"/><text x="300" y="162.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Result</text><text x="300" y="178" text-anchor="middle" font-size="11" class="dg-muted">upgrade urllib3 → 2.8.0</text></g>
<g><rect x="428" y="136" width="164" height="60" rx="12" fill="#db2777" fill-opacity=".18" stroke="#db2777" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7129;0.8515" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/></rect><rect x="432" y="140" width="156" height="52" rx="9" class="dg-box" stroke="#db2777" stroke-width="2.2"/><text x="510" y="162.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Snyk web app</text><text x="510" y="178" text-anchor="middle" font-size="11" class="dg-muted">snapshot: orders-service</text></g>
<g><rect x="218" y="242" width="164" height="60" rx="12" fill="#10b981" fill-opacity=".18" stroke="#10b981" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4257;0.7129" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/></rect><rect x="222" y="246" width="156" height="52" rx="9" class="dg-box" stroke="#10b981" stroke-width="2.2"/><text x="300" y="268.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">CI gate</text><text x="300" y="284" text-anchor="middle" font-size="11" class="dg-muted">exit 0 clean, 1 issues</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4257;0.5644" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/><rect x="222" y="246" width="156" height="52" rx="9" fill="#d97706"/><text x="300" y="276.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">⚠ exit 1 · issues</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5644;0.7129" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/><rect x="222" y="246" width="156" height="52" rx="9" fill="#059669"/><text x="300" y="276.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">✓ exit 0 · pass</text></g></g>
<g><rect x="428" y="242" width="164" height="60" rx="12" fill="#059669" fill-opacity=".18" stroke="#059669" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8515" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/></rect><rect x="432" y="246" width="156" height="52" rx="9" class="dg-box" stroke="#059669" stroke-width="2.2"/><text x="510" y="268.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">E-mail</text><text x="510" y="284" text-anchor="middle" font-size="11" class="dg-muted">a new issue affects you</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2871;0.4257" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/><circle cx="378" cy="140" r="9.5" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M378,135.5 V140.8 M378,143.6 V143.8" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8515" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/><circle cx="588" cy="140" r="9.5" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M588,135.5 V140.8 M588,143.6 V143.8" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0083;0.1192" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/><animateMotion path="M90,60 L300,60" keyPoints="0;0;1;1" keyTimes="0;0.0083;0.1192;1" calcMode="linear" dur="34.34s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.146;0.201" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/><animateMotion path="M300,60 L510,60" keyPoints="0;0;1;1" keyTimes="0;0.146;0.201;1" calcMode="linear" dur="34.34s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2129;0.2752" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/><animateMotion path="M510,60 L300,60 L300,166" keyPoints="0;0;1;1" keyTimes="0;0.2129;0.2752;1" calcMode="linear" dur="34.34s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4341;0.545" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/><animateMotion path="M300,166 L300,272" keyPoints="0;0;1;1" keyTimes="0;0.4341;0.545;1" calcMode="linear" dur="34.34s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5718;0.6312" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/><animateMotion path="M90,166 L300,166" keyPoints="0;0;1;1" keyTimes="0;0.5718;0.6312;1" calcMode="linear" dur="34.34s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6386;0.698" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/><animateMotion path="M300,166 L300,272" keyPoints="0;0;1;1" keyTimes="0;0.6386;0.698;1" calcMode="linear" dur="34.34s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7212;0.8321" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/><animateMotion path="M378,76 L405,76 L405,166 L432,166 L510,166" keyPoints="0;0;1;1" keyTimes="0;0.7212;0.8321;1" calcMode="linear" dur="34.34s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8589;0.9139" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/><animateMotion path="M510,60 L510,166" keyPoints="0;0;1;1" keyTimes="0;0.8589;0.9139;1" calcMode="linear" dur="34.34s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.9257;0.9851" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/><animateMotion path="M510,166 L510,272" keyPoints="0;0;1;1" keyTimes="0;0.9257;0.9851;1" calcMode="linear" dur="34.34s" repeatCount="indefinite"/><g><rect x="-9" y="-6" width="18" height="12" rx="2" fill="#db2777" stroke="#fff" stroke-width="1.6"/><path d="M-8,-5 L0,1 L8,-5" fill="none" stroke="#fff" stroke-width="1.4"/></g></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(21.2,316.5) scale(.8)"><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g><text x="33.4" y="320">dependencies</text><g transform="translate(123,316.5) scale(.8)"><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g><text x="134.4" y="320">dependency tree</text><g transform="translate(240.8,316.5) scale(.8)"><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g><text x="252.2" y="320">result</text><g transform="translate(308.2,316.5) scale(.8)"><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g><text x="319.6" y="320">policy</text><g transform="translate(375.6,316.5) scale(.8)"><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g><text x="387" y="320">exit code</text><g transform="translate(461.4,316.5) scale(.8)"><g><rect x="-9" y="-6" width="18" height="12" rx="2" fill="#db2777" stroke="#fff" stroke-width="1.6"/><path d="M-8,-5 L0,1 L8,-5" fill="none" stroke="#fff" stroke-width="1.4"/></g></g><text x="474.4" y="320">e-mail</text></g>
<rect x="12" y="332" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="332" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="34.34s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1386" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/><circle cx="36" cy="360" r="14" fill="#6366f1"/><text x="36" y="365" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="355" font-size="14" font-weight="800" fill="#6366f1">Install, then run snyk test</text><text x="578" y="355" text-anchor="end" font-size="10.5" class="dg-muted">snyk test · 1/7</text><text x="60" y="376" font-size="12.5" class="dg-text">Snyk asks pip what&#x27;s installed: requests brings urllib3, and more.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1386;0.2871" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/><circle cx="36" cy="360" r="14" fill="#6366f1"/><text x="36" y="365" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="355" font-size="14" font-weight="800" fill="#6366f1">Snyk checks the tree against its DB</text><text x="578" y="355" text-anchor="end" font-size="10.5" class="dg-muted">snyk test · 2/7</text><text x="60" y="376" font-size="12.5" class="dg-text">All 64 packages and versions are matched to known issues and fixes.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2871;0.4257" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/><circle cx="36" cy="360" r="14" fill="#6366f1"/><text x="36" y="365" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="355" font-size="14" font-weight="800" fill="#6366f1">It reports the issue and the fix</text><text x="578" y="355" text-anchor="end" font-size="10.5" class="dg-muted">snyk test · 3/7</text><text x="60" y="376" font-size="12.5" class="dg-text">urllib3@2.7.0, High, introduced by requests. Upgrade to urllib3@2.8.0.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4257;0.5644" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/><circle cx="36" cy="360" r="14" fill="#6366f1"/><text x="36" y="365" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="355" font-size="14" font-weight="800" fill="#6366f1">Exit 1: the CI gate warns or fails</text><text x="578" y="355" text-anchor="end" font-size="10.5" class="dg-muted">snyk test · 4/7</text><text x="60" y="376" font-size="12.5" class="dg-text">Report mode: exit 4, orange (Jenkins: UNSTABLE). Enforce mode: red.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5644;0.7129" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/><circle cx="36" cy="360" r="14" fill="#6366f1"/><text x="36" y="365" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="355" font-size="14" font-weight="800" fill="#6366f1">Fix it, or accept it in .snyk</text><text x="578" y="355" text-anchor="end" font-size="10.5" class="dg-muted">snyk test · 5/7</text><text x="60" y="376" font-size="12.5" class="dg-text">Raise the pin, or snyk ignore with a reason and --expiry. Then exit 0.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7129;0.8515" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/><circle cx="36" cy="360" r="14" fill="#db2777"/><text x="36" y="365" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="355" font-size="14" font-weight="800" fill="#db2777">snyk monitor saves a snapshot</text><text x="578" y="355" text-anchor="end" font-size="10.5" class="dg-muted">snyk monitor · 6/7</text><text x="60" y="376" font-size="12.5" class="dg-text">On the default branch it uploads the tree to the web app: orders-service.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8515" calcMode="discrete" dur="34.34s" repeatCount="indefinite"/><circle cx="36" cy="360" r="14" fill="#db2777"/><text x="36" y="365" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="355" font-size="14" font-weight="800" fill="#db2777">Later, a new vulnerability is published</text><text x="578" y="355" text-anchor="end" font-size="10.5" class="dg-muted">snyk monitor · 7/7</text><text x="60" y="376" font-size="12.5" class="dg-text">Snyk matches it to your snapshot and e-mails you. No new build needed.</text></g>
</svg>
```

```steps
#6366f1 | snyk test | Install, then run snyk test | Snyk asks pip what's installed: requests brings urllib3, and more.
#6366f1 | snyk test | Snyk checks the tree against its DB | All 64 packages and versions are matched to known issues and fixes.
#6366f1 | snyk test | It reports the issue and the fix | urllib3@2.7.0, High, introduced by requests. Upgrade to urllib3@2.8.0.
#6366f1 | snyk test | Exit 1: the CI gate warns or fails | Report mode: exit 4, orange (Jenkins: UNSTABLE). Enforce mode: red.
#6366f1 | snyk test | Fix it, or accept it in .snyk | Raise the pin, or snyk ignore with a reason and --expiry. Then exit 0.
#db2777 | snyk monitor | snyk monitor saves a snapshot | On the default branch it uploads the tree to the web app: orders-service.
#db2777 | snyk monitor | Later, a new vulnerability is published | Snyk matches it to your snapshot and e-mails you. No new build needed.
```

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
