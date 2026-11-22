# Trivy: Container Image and Dependency Scanning

Trivy finds **known vulnerabilities (CVEs)** in your container images: the operating system packages and the Python libraries installed inside. It can also scan dependency files, Dockerfiles, Kubernetes YAML and Terraform. This guide sets it up step by step: on your laptop, then in **GitLab CI** and **Jenkins**, with the rule that matters most: **scan the image before you push it**. The settings are the ones that work in a real Python microservices project.

> **Note:** One guide per security tool: [Gitleaks](#/tool/gitleaks) · [SonarQube](#/tool/sonarqube) · [Trivy](#/tool/trivy) · [Snyk](#/tool/snyk) · [DAST with ZAP](#/tool/dast-zap). The [Jenkins DevSecOps Pipeline](#/tool/jenkins-devsecops) shows Trivy in a full build-scan-push pipeline.

## Start here: Trivy in simple words

> **In simple words:** Trivy is a **food inspector for container images**. It reads the list of ingredients (every package and its version) and checks it against a recall list (the vulnerability database). If an ingredient was recalled and a safe version exists, it tells you which one to use instead.

### Watch how it works

```svg Watch it work: Trivy checking a freshly built image against the vulnerability DB and .trivyignore before the push, and a nightly scan finding a new CVE. The animation loops.
<svg viewBox="0 0 600 392" role="img" data-anim="trivy" data-dur="38.76" data-starts="0 4.42 9.18 13.94 18.7 23.46 28.56 33.66" aria-label="Animated Trivy flow. Build-time gate: docker build makes the orders-service image from the Dockerfile and requirements.txt, and keeps it local, so nothing is pushed yet. trivy image lists every package inside: OS packages such as openssl and Python libraries such as urllib3, with their versions. It checks them against the vulnerability database, which is downloaded on the first run and kept in a cache between runs. CVEs accepted in .trivyignore, such as CVE-2026-12345 with exp:2027-01-31, are not counted until their expiry date. A fixable HIGH vulnerability is left, so Trivy exits 1 and the image is not pushed: it never reaches the registry, so no cluster can pull it. You raise the pin to the fixed version, or rebuild with docker build --pull, and scan again. The image is clean, so docker push sends it to the registry, Amazon ECR or the GitLab Container Registry. Every night: a scheduled job scans the newest image in the registry again, with today&#x27;s database, because new CVEs are published every day. It finds a new CVE in an image that was already pushed, exits 3 for an orange warning, and sends a report and a team chat message, so you can fix and rebuild.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<polyline points="90,56 90,164 287,164 481,164" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="287,56 287,164" fill="none" stroke-linejoin="round" stroke="#0d9488" stroke-width="1.8" stroke-dasharray="6 3" stroke-opacity=".7"/>
<polyline points="287,272 287,164" fill="none" stroke-linejoin="round" stroke="#0ea5e9" stroke-width="1.8" stroke-dasharray="2 3" stroke-opacity=".75"/>
<polyline points="287,56 481,56" fill="none" stroke-linejoin="round" stroke="#0d9488" stroke-width="1.8" stroke-dasharray="6 3" stroke-opacity=".7"/>
<polyline points="481,56 481,164" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="556,56 578,56 578,272 556,272" fill="none" stroke-linejoin="round" stroke="#e11d48" stroke-width="1.6" stroke-dasharray="3 4" stroke-opacity=".6"/>
<g><rect x="8" y="26" width="164" height="60" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.114" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/></rect><rect x="12" y="30" width="156" height="52" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="90" y="52.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Your code</text><text x="90" y="68" text-anchor="middle" font-size="11" class="dg-muted">Dockerfile, requirements</text></g>
<g><rect x="8" y="134" width="164" height="60" rx="12" fill="#f97316" fill-opacity=".18" stroke="#f97316" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.114" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/></rect><rect x="12" y="138" width="156" height="52" rx="9" class="dg-box" stroke="#f97316" stroke-width="2.2"/><text x="90" y="160.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">docker build</text><text x="90" y="176" text-anchor="middle" font-size="11" class="dg-muted">orders-service image</text></g>
<g><rect x="208" y="26" width="158" height="60" rx="12" fill="#0d9488" fill-opacity=".18" stroke="#0d9488" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.2368;0.3596;0.7368;0.8684" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/></rect><rect x="212" y="30" width="150" height="52" rx="9" class="dg-box" stroke="#0d9488" stroke-width="2.2"/><text x="287" y="52.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Vulnerability DB</text><text x="287" y="68" text-anchor="middle" font-size="11" class="dg-muted">downloaded, then cached</text></g>
<g><rect x="208" y="134" width="158" height="60" rx="12" fill="#0ea5e9" fill-opacity=".18" stroke="#0ea5e9" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.114;0.3596;0.4825;0.6053" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/></rect><rect x="212" y="138" width="150" height="52" rx="9" class="dg-box" stroke="#0ea5e9" stroke-width="2.2"/><text x="287" y="160.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">trivy image</text><text x="287" y="176" text-anchor="middle" font-size="11" class="dg-muted">HIGH,CRITICAL, fixable</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4825;0.6053" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/><rect x="212" y="138" width="150" height="52" rx="9" fill="#e11d48"/><text x="287" y="168.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">✕ exit 1 · no push</text></g></g>
<g><rect x="208" y="242" width="158" height="60" rx="12" fill="#ca8a04" fill-opacity=".18" stroke="#ca8a04" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3596;0.4825" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/></rect><rect x="212" y="246" width="150" height="52" rx="9" class="dg-box" stroke="#ca8a04" stroke-width="2.2"/><text x="287" y="268.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">.trivyignore</text><text x="287" y="284" text-anchor="middle" font-size="11" class="dg-muted">CVE, reason, exp: date</text></g>
<g><rect x="402" y="26" width="158" height="60" rx="12" fill="#7c3aed" fill-opacity=".18" stroke="#7c3aed" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7368;0.8684" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/></rect><rect x="406" y="30" width="150" height="52" rx="9" class="dg-box" stroke="#7c3aed" stroke-width="2.2"/><text x="481" y="52.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Nightly scan</text><text x="481" y="68" text-anchor="middle" font-size="11" class="dg-muted">newest tag, every night</text><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8684" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/><rect x="406" y="30" width="150" height="52" rx="9" fill="#d97706"/><text x="481" y="60.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">⚠ new HIGH CVE</text></g></g>
<rect x="406" y="138" width="150" height="52" rx="9" class="dg-box"/><g opacity="1"><animate attributeName="opacity" values="1;0.28;1" keyTimes="0;0.4825;0.6053" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/><rect x="402" y="134" width="158" height="60" rx="12" fill="#10b981" fill-opacity=".18" stroke="#10b981" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6053;0.7368" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/></rect><rect x="406" y="138" width="150" height="52" rx="9" class="dg-box" stroke="#10b981" stroke-width="2.2"/><text x="481" y="160.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Registry</text><text x="481" y="176" text-anchor="middle" font-size="11" class="dg-muted">ECR or GitLab registry</text></g>
<g><rect x="402" y="242" width="158" height="60" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8684" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/></rect><rect x="406" y="246" width="150" height="52" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="481" y="268.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Report + chat</text><text x="481" y="284" text-anchor="middle" font-size="11" class="dg-muted">exit 3: orange warning</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4825;0.6053" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/><circle cx="384" cy="164" r="9.5" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M380,160 L388,168 M388,160 L380,168" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6053;0.7368" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/><circle cx="362" cy="138" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M357.5,138 L361,141.5 L366.5,134.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0068;0.0981" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/><animateMotion path="M90,56 L90,164" keyPoints="0;0;1;1" keyTimes="0;0.0068;0.0981;1" calcMode="linear" dur="38.76s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1214;0.2196" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/><animateMotion path="M90,164 L287,164" keyPoints="0;0;1;1" keyTimes="0;0.1214;0.2196;1" calcMode="linear" dur="38.76s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2442;0.3425" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/><animateMotion path="M287,56 L287,164" keyPoints="0;0;1;1" keyTimes="0;0.2442;0.3425;1" calcMode="linear" dur="38.76s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.367;0.4653" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/><animateMotion path="M287,272 L287,164" keyPoints="0;0;1;1" keyTimes="0;0.367;0.4653;1" calcMode="linear" dur="38.76s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6118;0.7237" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/><animateMotion path="M90,56 L90,164 L287,164 L481,164" keyPoints="0;0;1;1" keyTimes="0;0.6118;0.7237;1" calcMode="linear" dur="38.76s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7434;0.7961" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/><animateMotion path="M481,164 L481,56" keyPoints="0;0;1;1" keyTimes="0;0.7434;0.7961;1" calcMode="linear" dur="38.76s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8026;0.8553" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/><animateMotion path="M287,56 L481,56" keyPoints="0;0;1;1" keyTimes="0;0.8026;0.8553;1" calcMode="linear" dur="38.76s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8816;0.9816" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/><animateMotion path="M556,56 L578,56 L578,272 L556,272" keyPoints="0;0;1;1" keyTimes="0;0.8816;0.9816;1" calcMode="linear" dur="38.76s" repeatCount="indefinite"/><g><circle r="7" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M0,-3.5 V1 M0,3.2 V3.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/></g></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(21.2,316.5) scale(.8)"><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g><text x="33.4" y="320">image</text><g transform="translate(83.8,316.5) scale(.8)"><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g><text x="95.2" y="320">vulnerability DB</text><g transform="translate(207.2,316.5) scale(.8)"><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g><text x="218.6" y="320">accepted CVE</text><g transform="translate(308.2,316.5) scale(.8)"><g><circle r="7" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M0,-3.5 V1 M0,3.2 V3.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/></g></g><text x="319.6" y="320">finding</text></g>
<rect x="12" y="332" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="332" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="38.76s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.114" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/><circle cx="36" cy="360" r="14" fill="#0ea5e9"/><text x="36" y="365" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="355" font-size="14" font-weight="800" fill="#0ea5e9">docker build makes the image</text><text x="578" y="355" text-anchor="end" font-size="10.5" class="dg-muted">Build-time gate · 1/8</text><text x="60" y="376" font-size="12.5" class="dg-text">From the Dockerfile and requirements.txt. It stays local: nothing is pushed.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.114;0.2368" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/><circle cx="36" cy="360" r="14" fill="#0ea5e9"/><text x="36" y="365" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="355" font-size="14" font-weight="800" fill="#0ea5e9">Trivy lists every package inside</text><text x="578" y="355" text-anchor="end" font-size="10.5" class="dg-muted">Build-time gate · 2/8</text><text x="60" y="376" font-size="12.5" class="dg-text">OS packages such as openssl, Python libraries such as urllib3, and versions.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2368;0.3596" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/><circle cx="36" cy="360" r="14" fill="#0ea5e9"/><text x="36" y="365" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="355" font-size="14" font-weight="800" fill="#0ea5e9">It checks them against the CVE DB</text><text x="578" y="355" text-anchor="end" font-size="10.5" class="dg-muted">Build-time gate · 3/8</text><text x="60" y="376" font-size="12.5" class="dg-text">The DB is downloaded on the first run and kept in a cache between runs.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3596;0.4825" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/><circle cx="36" cy="360" r="14" fill="#0ea5e9"/><text x="36" y="365" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="355" font-size="14" font-weight="800" fill="#0ea5e9">Accepted CVEs are skipped until expiry</text><text x="578" y="355" text-anchor="end" font-size="10.5" class="dg-muted">Build-time gate · 4/8</text><text x="60" y="376" font-size="12.5" class="dg-text">CVE-2026-12345 exp:2027-01-31 in .trivyignore: not counted until then.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4825;0.6053" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/><circle cx="36" cy="360" r="14" fill="#0ea5e9"/><text x="36" y="365" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="355" font-size="14" font-weight="800" fill="#0ea5e9">A fixable HIGH CVE is left: no push</text><text x="578" y="355" text-anchor="end" font-size="10.5" class="dg-muted">Build-time gate · 5/8</text><text x="60" y="376" font-size="12.5" class="dg-text">Exit code 1. The image never reaches the registry, so nothing can pull it.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6053;0.7368" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/><circle cx="36" cy="360" r="14" fill="#0ea5e9"/><text x="36" y="365" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="355" font-size="14" font-weight="800" fill="#0ea5e9">Upgrade, rebuild, and it&#x27;s pushed</text><text x="578" y="355" text-anchor="end" font-size="10.5" class="dg-muted">Build-time gate · 6/8</text><text x="60" y="376" font-size="12.5" class="dg-text">Raise the pin to the Fixed Version, or build --pull. Clean: docker push.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7368;0.8684" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/><circle cx="36" cy="360" r="14" fill="#7c3aed"/><text x="36" y="365" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="355" font-size="14" font-weight="800" fill="#7c3aed">Every night, scan the registry again</text><text x="578" y="355" text-anchor="end" font-size="10.5" class="dg-muted">Every night · 7/8</text><text x="60" y="376" font-size="12.5" class="dg-text">New CVEs appear every day, so the newest image is checked with today&#x27;s DB.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8684" calcMode="discrete" dur="38.76s" repeatCount="indefinite"/><circle cx="36" cy="360" r="14" fill="#7c3aed"/><text x="36" y="365" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="355" font-size="14" font-weight="800" fill="#7c3aed">A new CVE in an image already pushed</text><text x="578" y="355" text-anchor="end" font-size="10.5" class="dg-muted">Every night · 8/8</text><text x="60" y="376" font-size="12.5" class="dg-text">Exit 3: an orange warning, a report and a chat message. Fix and rebuild.</text></g>
</svg>
```

```steps
#0ea5e9 | Build-time gate | docker build makes the image | From the Dockerfile and requirements.txt. It stays local: nothing is pushed.
#0ea5e9 | Build-time gate | Trivy lists every package inside | OS packages such as openssl, Python libraries such as urllib3, and versions.
#0ea5e9 | Build-time gate | It checks them against the CVE DB | The DB is downloaded on the first run and kept in a cache between runs.
#0ea5e9 | Build-time gate | Accepted CVEs are skipped until expiry | CVE-2026-12345 exp:2027-01-31 in .trivyignore: not counted until then.
#0ea5e9 | Build-time gate | A fixable HIGH CVE is left: no push | Exit code 1. The image never reaches the registry, so nothing can pull it.
#0ea5e9 | Build-time gate | Upgrade, rebuild, and it's pushed | Raise the pin to the Fixed Version, or build --pull. Clean: docker push.
#7c3aed | Every night | Every night, scan the registry again | New CVEs appear every day, so the newest image is checked with today's DB.
#7c3aed | Every night | A new CVE in an image already pushed | Exit 3: an orange warning, a report and a chat message. Fix and rebuild.
```

An image has two kinds of ingredients: the OS packages from the base image (`openssl`, `glibc`, `zlib`…) and your app's libraries (`requests`, `urllib3`, `pillow`…). Trivy checks both.

### What Trivy can scan

| Command | Target | Finds |
|---|---|---|
| `trivy image` | A built container image | Vulnerable OS packages and libraries. Optionally secrets in the layers |
| `trivy fs` | A folder (your repository) | Vulnerable libraries in `requirements.txt`, `poetry.lock`, `package-lock.json`… |
| `trivy config` | Dockerfiles, Kubernetes YAML, Helm, Terraform | Misconfigurations: running as root, no resource limits, open security groups… |
| `trivy repo` | A remote Git repository | Same as `fs`, without cloning by hand |
| `trivy sbom` | An SBOM file | Vulnerabilities in a software bill of materials |

### Key words

| Word | Meaning |
|---|---|
| CVE | A public ID for one known vulnerability, such as `CVE-2026-12345` (GitHub uses `GHSA-…`) |
| Severity | `CRITICAL`, `HIGH`, `MEDIUM`, `LOW` or `UNKNOWN` |
| Installed / Fixed version | The version in your image, and the first version without the problem |
| Unfixed | No fixed version exists yet. `--ignore-unfixed` hides these, because you can't act on them |
| Vulnerability DB | Trivy's database of CVEs. It downloads it on first use and updates it every few hours |
| `.trivyignore` | Your list of accepted CVEs, each with a reason and an expiry date |
| SBOM | Software Bill Of Materials: the full ingredient list of an image |

### Check yourself

1. Your image passed the scan last month. Can it fail today without any change?
2. Why scan **before** the push, not after?
3. What does `--ignore-unfixed` hide?

> **Tip:** Answers: 1) Yes. New CVEs are published every day, so scan the images in your registry regularly, too. 2) A vulnerable image never reaches the registry, so no cluster can pull it. 3) Vulnerabilities that have no fixed version yet, which you can't fix by upgrading.

## How the working setup is organised

> **In simple words:** Trivy runs twice. At build time it's a **gate**: nothing is pushed while a fixable HIGH or CRITICAL vulnerability exists. On a schedule it **re-checks** the images already in the registry, because new CVEs appear every day.

```text
 build time:
 docker build ──► unit tests ──► trivy image ──┬── clean ───────────────► docker push
                                               └── fixable HIGH/CRITICAL ─► stop: nothing pushed
                                                   (urgent release: TRIVY_ALLOW_PUSH=true)
 every night:
 newest image of every repository in the registry ──► trivy image ──► report (+ team chat message)
```

| Choice | Value | Why |
|---|---|---|
| Version | `0.76.2`, pinned (`aquasec/trivy:0.76.2`) | Same results everywhere. Upgrade on purpose |
| Severity | `HIGH,CRITICAL` | Block on what matters; MEDIUM and LOW go to the backlog |
| Unfixed | `--ignore-unfixed` | Only report what you can fix by upgrading |
| Scanners | `vuln` (add `secret` to search image layers for secrets) | Fast and focused |
| Accepted CVEs | `.trivyignore` in the repository root, with reason and `exp:` date | Exceptions are written down, reviewed and expire |
| Cache | The vulnerability DB is kept between runs | Each run downloads only small updates |
| Reports | JSON per image, a readable table in the log, JUnit for the test tab | People, scripts and CI each get what they need |

## Install Trivy on your laptop

> **In simple words:** Pick one way. Docker needs no installation and works the same everywhere. The native binary is a little faster.

### Docker (any system)

```bash
docker pull aquasec/trivy:0.76.2
docker run --rm aquasec/trivy:0.76.2 --version
```

To type `trivy` as if it were installed, add a shortcut. It mounts the Docker socket (to read your local images), a named volume for the database cache, and the current folder.

Bash (`~/.bashrc`):

```bash
alias trivy='docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache/trivy -v "$PWD:/work" -w /work aquasec/trivy:0.76.2'
```

PowerShell (`notepad $PROFILE`):

```powershell
function trivy { docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache/trivy -v "${PWD}:/work" -w /work aquasec/trivy:0.76.2 @args }
```

### Windows (native)

Download `trivy_0.76.2_windows-64bit.zip` from the [Trivy releases page](https://github.com/aquasecurity/trivy/releases), unzip it, and put `trivy.exe` in a folder on your `PATH`. Community packages also exist (`scoop install trivy`, `choco install trivy`); check which version they install.

### macOS

```bash
brew install trivy
trivy --version
```

### Linux (pinned version, checksum verified)

```bash
VERSION=0.76.2
cd /tmp
curl -sSfLO "https://github.com/aquasecurity/trivy/releases/download/v${VERSION}/trivy_${VERSION}_Linux-64bit.tar.gz"
curl -sSfLO "https://github.com/aquasecurity/trivy/releases/download/v${VERSION}/trivy_${VERSION}_checksums.txt"
grep " trivy_${VERSION}_Linux-64bit.tar.gz$" "trivy_${VERSION}_checksums.txt" | sha256sum -c -
sudo tar -xzf "trivy_${VERSION}_Linux-64bit.tar.gz" -C /usr/local/bin trivy
trivy --version
```

Ubuntu and Debian can also use Trivy's apt repository (see the [Jenkins DevSecOps guide](#/tool/jenkins-devsecops/prepare-the-build-agent)).

> **Warning:** Scanners run with access to your images, code and CI secrets, which makes them a favourite supply-chain target. Pin an exact version, verify the checksum, and upgrade deliberately after reading the release notes.

## Run it locally and prove it works

> **In simple words:** Scan an image you built, then scan an old image on purpose to see the gate fail. That proves the scanner works before you trust it in CI.

### 1. Scan an image you built

```bash
docker build -t orders-service:local services/orders-service
trivy image --severity HIGH,CRITICAL --ignore-unfixed orders-service:local
```

How to read the table:

| Column | Meaning |
|---|---|
| Library | The package, for example `openssl` or `urllib3` |
| Vulnerability | The CVE ID (with a link to details) |
| Severity | CRITICAL, HIGH… |
| Installed Version | What's in your image |
| Fixed Version | Upgrade to at least this |
| Title | One-line description |

The header of each table names the **target**: the OS (`orders-service:local (debian 12.x)`) or a Python package path (`usr/local/lib/python3.11/site-packages/…`). That tells you whether to fix the base image or `requirements.txt`.

### 2. Prove the gate fails

An old base image always has fixable vulnerabilities:

```bash
trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 python:3.9.0-slim
echo "exit code: $?"           # 1 = the gate would stop the push
```

In PowerShell, print the result with `"exit code: $LASTEXITCODE"`.

### 3. Scan dependencies before you build (fs)

```bash
trivy fs --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed services/
```

> **Note:** For `requirements.txt`, Trivy only understands pinned versions (`urllib3==2.8.0`). A line like `pillow>=12.3.0` can't be matched to a version, so it's skipped. The image scan always sees the version that was actually installed.

### 4. Scan Dockerfiles, Kubernetes and Terraform files (config)

```bash
trivy config --severity HIGH,CRITICAL .
```

Typical findings: `Image user should not be 'root'` (add a `USER` line to the Dockerfile), missing resource limits in a Deployment, a security group open to `0.0.0.0/0`.

### 5. Save reports

```bash
mkdir -p security-reports/trivy
trivy image --ignore-unfixed --format json --output security-reports/trivy/orders-service.json orders-service:local
trivy convert --format table security-reports/trivy/orders-service.json         # readable table from the JSON
trivy image --format cyclonedx --output security-reports/trivy/orders-service.sbom.json orders-service:local
```

For a JUnit report (for CI test tabs), use the template that ships with Trivy:

| How Trivy is installed | Template option |
|---|---|
| Docker image `aquasec/trivy` | `--format template --template "@/contrib/junit.tpl"` |
| apt or rpm package | `--format template --template "@/usr/local/share/trivy/templates/junit.tpl"` |
| Anything else | Download `contrib/junit.tpl` from the Trivy repository at your version's tag |

## Accept a finding with .trivyignore

> **In simple words:** When a CVE can't be fixed now and isn't a real risk for you, write it down in `.trivyignore` with **why** and **until when**. The entry stops working on its expiry date, so the decision is looked at again.

`.trivyignore` in the repository root (Trivy reads it from the folder it runs in; elsewhere, pass `--ignorefile path/to/.trivyignore`):

```text
# Accepted container-image vulnerabilities. One CVE or GHSA ID per line.
# Say why it is accepted and when to look again.

# Not reachable: only the CLI uses this package; fix pending in the base image. Owner: platform team.
CVE-2026-12345 exp:2027-01-31
```

> **Tip:** Keep the reason, the owner and the date on every entry. A `.trivyignore` with bare IDs soon becomes a list nobody dares to touch.

## GitLab CI: step by step

> **In simple words:** Three jobs, each for one purpose: **build, scan, push** in one job (the gate), a **nightly scan** of the image in the registry, and a quick **dependency scan** in merge requests.

### 1. Commit `.trivyignore`

Even an empty one with the header comment, so everyone knows where exceptions go.

### 2. The gate: build, scan, push in one job

Trivy scans the image while it's still local. Only a clean image (or an urgent release with `TRIVY_ALLOW_PUSH=true`) is pushed to the GitLab Container Registry.

```yaml
stages: [security, build, test, deploy]

variables:
  TRIVY_VERSION: "0.76.2"
  TRIVY_SEVERITY: "HIGH,CRITICAL"          # Trivy reads TRIVY_* variables as options
  TRIVY_CACHE_DIR: "$CI_PROJECT_DIR/.trivycache"
  TRIVY_NO_PROGRESS: "true"

.install-trivy: &install-trivy
  - apk add --no-cache curl
  - cd /tmp
  - curl -sSfLO "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz"
  - curl -sSfLO "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_checksums.txt"
  - grep " trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz$" "trivy_${TRIVY_VERSION}_checksums.txt" | sha256sum -c -
  - tar -xzf "trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" -C /usr/local/bin trivy
  - curl -sSfL -o /tmp/junit.tpl "https://raw.githubusercontent.com/aquasecurity/trivy/v${TRIVY_VERSION}/contrib/junit.tpl"
  - cd "$CI_PROJECT_DIR"
  - trivy --version

build-scan-push:
  stage: build
  image: docker:29
  services:
    - docker:29-dind
  variables:
    DOCKER_TLS_CERTDIR: "/certs"
    IMAGE: "$CI_REGISTRY_IMAGE/orders-service:$CI_COMMIT_SHORT_SHA"
    TRIVY_ALLOW_PUSH: "false"              # "true" only for an urgent release
  cache:
    key: trivy-db
    paths: [.trivycache/]
  before_script:
    - *install-trivy
    - echo "$CI_REGISTRY_PASSWORD" | docker login -u "$CI_REGISTRY_USER" --password-stdin "$CI_REGISTRY"
  script:
    - docker build --pull -t "$IMAGE" services/orders-service
    - docker save "$IMAGE" -o image.tar    # Trivy reads the saved image: no Docker daemon access needed
    - mkdir -p security-reports/junit
    - |
      rc=0
      trivy image --input image.tar --ignore-unfixed --exit-code 1 \
        --format json --output security-reports/trivy-orders-service.json || rc=$?
      rm -f image.tar
      trivy convert --format table security-reports/trivy-orders-service.json
      trivy convert --format template --template "@/tmp/junit.tpl" \
        --output security-reports/junit/trivy-orders-service.xml security-reports/trivy-orders-service.json
      if [ "$rc" -ne 0 ]; then
        if [ "$TRIVY_ALLOW_PUSH" = "true" ]; then
          echo "WARNING: Trivy did not pass, but TRIVY_ALLOW_PUSH=true: pushing anyway."
        else
          echo "Trivy found fixable $TRIVY_SEVERITY vulnerabilities (or could not scan): nothing pushed."
          echo "Fix: upgrade the package or base image, or accept the CVE in .trivyignore (reason + exp: date)."
          exit 1
        fi
      fi
    - docker push "$IMAGE"
  artifacts:
    when: always
    expire_in: 30 days
    paths: [security-reports/]
    reports:
      junit: security-reports/junit/trivy-orders-service.xml
```

> **Note:** Docker-in-Docker needs a runner in **privileged** mode. GitLab.com's shared Linux runners have it; on your own runner set `privileged = true`. See [Build and push to the GitLab Container Registry](#/tool/gitlab-ci/build-and-push-to-the-gitlab-container-registry).

### 3. Nightly: re-scan the image in the registry

```yaml
trivy-registry-scan:
  stage: security
  image:
    name: aquasec/trivy:0.76.2
    entrypoint: [""]
  variables:
    TRIVY_USERNAME: "$CI_REGISTRY_USER"     # Trivy logs in to the registry with these
    TRIVY_PASSWORD: "$CI_REGISTRY_PASSWORD"
  cache:
    key: trivy-db
    paths: [.trivycache/]
  script:
    - mkdir -p security-reports/junit
    - |
      rc=0
      trivy image --ignore-unfixed --exit-code 1 --format json \
        --output security-reports/trivy.json "$CI_REGISTRY_IMAGE/orders-service:latest" || rc=$?
      trivy convert --format table security-reports/trivy.json
      trivy convert --format template --template "@/contrib/junit.tpl" \
        --output security-reports/junit/trivy.xml security-reports/trivy.json
      if [ "$rc" -ne 0 ]; then exit 3; fi   # findings: orange warning, not a red pipeline
  allow_failure:
    exit_codes: [3]
  artifacts:
    when: always
    paths: [security-reports/]
    reports:
      junit: security-reports/junit/trivy.xml
  rules:
    - if: $CI_PIPELINE_SOURCE == "schedule"
```

Then **Build → Pipeline schedules → New schedule**: every night, on the default branch. For images in **Amazon ECR**, give the job AWS credentials (for example with GitLab OIDC) instead of `TRIVY_USERNAME` and `TRIVY_PASSWORD`; Trivy logs in to ECR by itself.

### 4. Quick dependency scan in merge requests

```yaml
trivy-deps:
  stage: security
  image:
    name: aquasec/trivy:0.76.2
    entrypoint: [""]
  script:
    - trivy fs --scanners vuln --ignore-unfixed --exit-code 1 .
  allow_failure: true                       # a hint for the developer; the image gate decides
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
```

### 5. Test it

1. On a test branch, change the Dockerfile's `FROM` to an old image such as `python:3.9.0-slim` and push.
2. `build-scan-push` fails, the log shows the table, the MR's **Tests** tab lists the CVEs, and **nothing is in the registry** for that commit.
3. Run the pipeline again with the variable `TRIVY_ALLOW_PUSH=true` (**Run pipeline**) to see the override work. Then revert the Dockerfile.

## Jenkins: step by step

> **In simple words:** Build the image, scan it with the Trivy Docker image (nothing to install on the agent), publish the results under **Tests**, and push only if the scan passed.

### 1. Prepare the agent

- A Linux agent with Docker, the agent user in the `docker` group, and the label `docker-build`.
- Plugins: **Pipeline**, **Git**, **JUnit**.
- For pushing to Amazon ECR, see the [ECR guide](#/tool/aws-ecr) and the [Jenkins DevSecOps Pipeline](#/tool/jenkins-devsecops/credentials-and-aws-permissions).

### 2. The Jenkinsfile

```groovy
pipeline {
    agent { label 'docker-build' }                       // CHANGE: an agent with Docker

    parameters {
        booleanParam(name: 'TRIVY_ALLOW_PUSH', defaultValue: false,
                     description: 'Urgent release only: push even when Trivy finds vulnerabilities')
    }

    environment {
        TRIVY_IMAGE    = 'aquasec/trivy:0.76.2'
        TRIVY_SEVERITY = 'HIGH,CRITICAL'
        IMAGE          = "123456789012.dkr.ecr.us-east-1.amazonaws.com/orders-service:${env.BUILD_NUMBER}"   // CHANGE
    }

    stages {
        stage('Checkout') {
            steps { checkout scm }
        }

        stage('Docker build') {
            steps { sh 'docker build --pull -t "$IMAGE" services/orders-service' }
        }

        stage('Image scan: Trivy') {
            steps {
                sh 'mkdir -p security-reports/junit "$HOME/.cache/trivy"'
                script {
                    def rc = sh(returnStatus: true, script: '''
                        # Trivy in Docker, as the agent user: it reads local images through the Docker socket.
                        trivy() {
                          docker run --rm -u "$(id -u):$(id -g)" --group-add "$(stat -c %g /var/run/docker.sock)" \
                            -e TRIVY_CACHE_DIR=/cache -e TRIVY_SEVERITY \
                            -v /var/run/docker.sock:/var/run/docker.sock -v "$HOME/.cache/trivy:/cache" \
                            -v "$WORKSPACE:/work" -w /work "$TRIVY_IMAGE" "$@"
                        }
                        rc=0
                        trivy image --scanners vuln --ignore-unfixed --exit-code 1 \
                          --format json --output security-reports/trivy.json "$IMAGE" || rc=$?
                        trivy convert --format table security-reports/trivy.json || true
                        trivy convert --format template --template "@/contrib/junit.tpl" \
                          --output security-reports/junit/trivy.xml security-reports/trivy.json || true
                        exit $rc
                    ''')
                    if (rc != 0) {
                        if (params.TRIVY_ALLOW_PUSH) {
                            unstable 'Trivy did not pass, but TRIVY_ALLOW_PUSH is ticked: pushing anyway'
                        } else {
                            error 'Trivy found fixable HIGH/CRITICAL vulnerabilities (or could not scan): nothing pushed'
                        }
                    }
                }
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'security-reports/junit/trivy.xml'
                    archiveArtifacts artifacts: 'security-reports/**', allowEmptyArchive: true
                }
            }
        }

        stage('Push') {
            steps {
                // log in to the registry first (see the ECR guide), then:
                sh 'docker push "$IMAGE"'
            }
        }
    }
}
```

The stage reads `.trivyignore` from the workspace root by itself, because Trivy runs in `/work`.

### 3. Nightly registry scan

Create a second Pipeline job with **Build Triggers → Build periodically**, schedule `H 2 * * *`, that runs `trivy image` on the newest tag of each repository (no build, no push). Use the same `trivy()` function, and report findings with `unstable` instead of `error`.

### 4. Test it

Change the Dockerfile's `FROM` to `python:3.9.0-slim` on a test branch and build. The **Image scan** stage fails, **Tests** lists the CVEs, and the **Push** stage is skipped. Build again with `TRIVY_ALLOW_PUSH` ticked: the build is yellow and the image is pushed.

### Without Docker

Install the binary on the agent (see [Install Trivy](#/tool/trivy/install-trivy-on-your-laptop)) and call `trivy image ...` directly. Use the apt template path for JUnit (`@/usr/local/share/trivy/templates/junit.tpl`).

## Handling findings

> **In simple words:** Most findings are fixed by **upgrading**: a newer base image for OS packages, a newer pin in `requirements.txt` for Python packages. Only what can't be fixed now goes into `.trivyignore`, with a reason and a date.

| Where the finding is | How to fix it |
|---|---|
| OS package (target shows `debian`, `alpine`…) | Rebuild with `docker build --pull` to get the patched base image. Still there? Move to a newer base (for example a newer `python:3.11-slim` tag), or add `apt-get upgrade -y` in the Dockerfile |
| Python package (target shows `site-packages`) | Raise the pin in `requirements.txt` to at least the **Fixed Version**, rebuild, run the tests |
| A package pulled in by another package | Pin the fixed version yourself in `requirements.txt`, or upgrade the parent package |
| No fixed version yet | `--ignore-unfixed` hides it. Watch it; the nightly scan tells you when a fix ships |
| Not reachable in your app, fix not possible now | `.trivyignore` with a reason, an owner and an `exp:` date |

Find which file brought a package in:

```bash
jq -r '.Results[] | .Target as $t | (.Vulnerabilities // [])[] | "\($t)  \(.PkgName) \(.InstalledVersion) -> \(.FixedVersion)  \(.VulnerabilityID)"' \
  security-reports/trivy/orders-service.json
```

## Troubleshooting

> **In simple words:** Most problems are the database download, Trivy not finding the image, or Docker socket permissions.

| Problem | Fix |
|---|---|
| `failed to download vulnerability DB` or `TOOMANYREQUESTS` | Keep the cache between runs. Use another mirror: `--db-repository public.ecr.aws/aquasecurity/trivy-db:2` |
| `unable to find the specified image` | The image isn't local, or the Docker socket isn't mounted. Pull or build it first, or scan a saved file with `--input image.tar` |
| `permission denied … /var/run/docker.sock` | Add the user to the `docker` group, or pass `--group-add` with the socket's group, as in the Jenkinsfile |
| Every run is slow | The DB cache isn't kept. Check `TRIVY_CACHE_DIR` and the CI cache |
| `trivy fs` finds nothing in `requirements.txt` | Versions aren't pinned with `==`. Scan the built image instead |
| `.trivyignore` seems ignored | Trivy didn't run in the folder that holds the file. Pass `--ignorefile` |
| Jenkins can't delete workspace files after a scan | Files were written by `root` in the container. Run Trivy with `-u "$(id -u):$(id -g)"`, as in the Jenkinsfile |
| GitLab: `Cannot connect to the Docker daemon at tcp://docker:2376` | The `docker:29-dind` service, `DOCKER_TLS_CERTDIR` or privileged mode is missing |
| Different results on laptop and CI | Different Trivy versions or database age. Pin the version, and compare with `trivy --version` (it prints the DB date) |

## Cheat sheet

> **In simple words:** The commands you'll use most.

```bash
trivy --version                                   # Trivy version and DB date
trivy image IMAGE                                 # all severities
trivy image --severity HIGH,CRITICAL --ignore-unfixed IMAGE
trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 IMAGE   # gate: exit 1 on findings
trivy image --input image.tar                     # an image saved with docker save
trivy image --scanners vuln,secret IMAGE          # also look for secrets in the layers
trivy fs --scanners vuln .                        # dependency files in this folder
trivy config .                                    # Dockerfile / Kubernetes / Terraform misconfigurations
trivy image --format json --output r.json IMAGE   # JSON report
trivy convert --format table r.json               # table from a JSON report
trivy image --format cyclonedx --output sbom.json IMAGE   # SBOM
trivy image --download-db-only                    # warm the cache
trivy clean --all                                 # delete the cache
```

Docs: [Trivy documentation](https://trivy.dev/latest/docs/) · [Trivy on GitHub](https://github.com/aquasecurity/trivy)
