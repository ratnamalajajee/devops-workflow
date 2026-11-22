# DAST: Testing the Running App with OWASP ZAP

DAST (Dynamic Application Security Testing) tests your application **while it runs**, from the outside, the way an attacker would: it sends requests and studies the responses. It doesn't need the source code. This guide lists the common DAST tools, then shows how to install **OWASP ZAP** and use it on your laptop, in **GitLab CI** and in **Jenkins**.

> **Note:** The pipeline steps on this page follow ZAP's documentation and **haven't been run in our pipelines yet**. Practise on the vulnerable demo app below, then try a test environment, in report mode first.

> **Note:** One guide per security tool: [Gitleaks](#/tool/gitleaks) · [SonarQube](#/tool/sonarqube) · [Trivy](#/tool/trivy) · [Snyk](#/tool/snyk) · [DAST with ZAP](#/tool/dast-zap).

## Start here: DAST in simple words

> **In simple words:** SAST reads the **blueprint** of the house. DAST walks around the **finished house** and tries every door and window. It finds what only shows up at run time: missing security headers, cookies without `Secure`, error pages that leak details, and injection holes.

### Watch how it works

```svg Watch it work: ZAP crawling a running app, the passive scan watching the answers, the full scan's attacks, and the rules file turning alerts into a report and a CI gate. The animation loops.
<svg viewBox="0 0 600 396" role="img" data-anim="dast-zap" data-dur="39.1" data-starts="0 5.1 9.86 14.62 19.72 24.82 29.58 34.34" aria-label="Animated ZAP flow, practised on the OWASP Juice Shop demo app. Baseline scan: zap-baseline.py starts at the target http://juice-shop:3000, and the spider follows every link for the number of minutes given with -m, to find the pages. The passive scan only looks at the normal answers, for example a missing Content-Security-Policy header or a cookie without the Secure flag. Each finding becomes an alert with a rule ID, such as 10038, CSP header not set, ranked by risk: High, Medium, Low or Informational. Full scan: zap-full-scan.py also runs the active scan, which sends attack payloads such as SQL injection and cross-site scripting. A weak answer can become a High alert such as 40018, SQL Injection. Attacks can change data, so the full scan runs against a test environment only, never production. Rules and result: the rules file zap-rules.tsv sets each rule ID to IGNORE, INFO, WARN or FAIL, and here 40018 is FAIL. ZAP writes zap-report.html, with each alert&#x27;s risk, URLs, description and fix. A FAIL rule makes ZAP exit 1: in report mode the GitLab job turns orange and Jenkins marks the build UNSTABLE, and in enforce mode the job fails.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<rect x="180" y="8" width="182" height="296" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="5 4"/>
<polyline points="77,166 274,166" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="164,62 164,270" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="164,62 274,62" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="164,270 274,270" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="274,166 510,166" fill="none" stroke-linejoin="round" stroke="#0d9488" stroke-width="1.8" stroke-dasharray="6 3" stroke-opacity=".7"/>
<polyline points="274,270 392,270 392,166" fill="none" stroke-linejoin="round" stroke="#0d9488" stroke-width="1.8" stroke-dasharray="6 3" stroke-opacity=".7"/>
<polyline points="510,62 510,166" fill="none" stroke-linejoin="round" stroke="#0ea5e9" stroke-width="1.8" stroke-dasharray="2 3" stroke-opacity=".75"/>
<polyline points="510,166 510,270" fill="none" stroke-linejoin="round" stroke="#64748b" stroke-width="1.8" stroke-dasharray="4 3" stroke-opacity=".7"/>
<rect x="186" y="14" width="84.7" height="16" rx="5" class="dg-box"/><text x="190" y="24" font-size="11" class="dg-muted">ZAP in Docker</text>
<g><rect x="8" y="136" width="138" height="60" rx="12" fill="#6366f1" fill-opacity=".18" stroke="#6366f1" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1;0" keyTimes="0;0.1304;0.3739;0.5043" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/></rect><rect x="12" y="140" width="130" height="52" rx="9" class="dg-box" stroke="#6366f1" stroke-width="2.2"/><text x="77" y="162.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Juice Shop</text><text x="77" y="178" text-anchor="middle" font-size="11" class="dg-muted">juice-shop:3000</text></g>
<g><rect x="192" y="32" width="164" height="60" rx="12" fill="#0ea5e9" fill-opacity=".18" stroke="#0ea5e9" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1304" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/></rect><rect x="196" y="36" width="156" height="52" rx="9" class="dg-box" stroke="#0ea5e9" stroke-width="2.2"/><text x="274" y="58.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Spider</text><text x="274" y="74" text-anchor="middle" font-size="11" class="dg-muted">follows links for -m min</text></g>
<g><rect x="192" y="136" width="164" height="60" rx="12" fill="#0d9488" fill-opacity=".18" stroke="#0d9488" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1304;0.2522" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/></rect><rect x="196" y="140" width="156" height="52" rx="9" class="dg-box" stroke="#0d9488" stroke-width="2.2"/><text x="274" y="162.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Passive scan</text><text x="274" y="178" text-anchor="middle" font-size="11" class="dg-muted">only looks at answers</text></g>
<rect x="196" y="244" width="156" height="52" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.3739" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/><rect x="192" y="240" width="164" height="60" rx="12" fill="#e11d48" fill-opacity=".18" stroke="#e11d48" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3739;0.5043" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/></rect><rect x="196" y="244" width="156" height="52" rx="9" class="dg-box" stroke="#e11d48" stroke-width="2.2"/><text x="274" y="266.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Active scan</text><text x="274" y="282" text-anchor="middle" font-size="11" class="dg-muted">attacks · full scan only</text></g>
<g><rect x="428" y="32" width="164" height="60" rx="12" fill="#ca8a04" fill-opacity=".18" stroke="#ca8a04" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6348;0.7565" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/></rect><rect x="432" y="36" width="156" height="52" rx="9" class="dg-box" stroke="#ca8a04" stroke-width="2.2"/><text x="510" y="58.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">zap-rules.tsv</text><text x="510" y="74" text-anchor="middle" font-size="11" class="dg-muted">IGNORE, INFO, WARN, FAIL</text></g>
<g><rect x="428" y="136" width="164" height="60" rx="12" fill="#d97706" fill-opacity=".18" stroke="#d97706" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.2522;0.3739;0.5043;0.7565" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/></rect><rect x="432" y="140" width="156" height="52" rx="9" class="dg-box" stroke="#d97706" stroke-width="2.2"/><text x="510" y="162.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Alerts</text><text x="510" y="178" text-anchor="middle" font-size="11" class="dg-muted">High, Medium, Low, Info</text></g>
<g><rect x="428" y="240" width="164" height="60" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.7565" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/></rect><rect x="432" y="244" width="156" height="52" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="510" y="266.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Report + CI gate</text><text x="510" y="282" text-anchor="middle" font-size="11" class="dg-muted">zap-report.html</text><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8783" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/><rect x="432" y="244" width="156" height="52" rx="9" fill="#e11d48"/><text x="510" y="274.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">✕ exit 1 · FAIL</text></g></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5043;0.6348" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/><circle cx="588" cy="140" r="9.5" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M588,135.5 V140.8 M588,143.6 V143.8" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0052;0.0574" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/><animateMotion path="M274,62 L164,62 L164,166 L77,166" keyPoints="0;0;1;1" keyTimes="0;0.0052;0.0574;1" calcMode="linear" dur="39.1s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0652;0.1174" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/><animateMotion path="M77,166 L164,166 L164,62 L274,62" keyPoints="0;0;1;1" keyTimes="0;0.0652;0.1174;1" calcMode="linear" dur="39.1s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1377;0.2351" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/><animateMotion path="M77,166 L274,166" keyPoints="0;0;1;1" keyTimes="0;0.1377;0.2351;1" calcMode="linear" dur="39.1s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2595;0.3569" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/><animateMotion path="M274,166 L510,166" keyPoints="0;0;1;1" keyTimes="0;0.2595;0.3569;1" calcMode="linear" dur="39.1s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3791;0.4313" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/><animateMotion path="M274,270 L164,270 L164,166 L77,166" keyPoints="0;0;1;1" keyTimes="0;0.3791;0.4313;1" calcMode="linear" dur="39.1s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4365;0.4887" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/><animateMotion path="M274,270 L164,270 L164,166 L77,166" keyPoints="0;0;1;1" keyTimes="0;0.4365;0.4887;1" calcMode="linear" dur="39.1s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5096;0.5617" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/><animateMotion path="M77,166 L164,166 L164,270 L274,270" keyPoints="0;0;1;1" keyTimes="0;0.5096;0.5617;1" calcMode="linear" dur="39.1s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5696;0.6217" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/><animateMotion path="M274,270 L392,270 L392,166 L510,166" keyPoints="0;0;1;1" keyTimes="0;0.5696;0.6217;1" calcMode="linear" dur="39.1s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6421;0.7395" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/><animateMotion path="M510,62 L510,166" keyPoints="0;0;1;1" keyTimes="0;0.6421;0.7395;1" calcMode="linear" dur="39.1s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7638;0.8612" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/><animateMotion path="M510,166 L510,270" keyPoints="0;0;1;1" keyTimes="0;0.7638;0.8612;1" calcMode="linear" dur="39.1s" repeatCount="indefinite"/><g><rect x="-8" y="-6" width="16" height="12" rx="2" fill="#64748b" stroke="#fff" stroke-width="1.6"/><path d="M-5,-2 H5 M-5,2 H3" stroke="#fff" stroke-width="1.4"/></g></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(20.4,320.5) scale(.8)"><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g><text x="31.8" y="324">request</text><g transform="translate(93.4,320.5) scale(.8)"><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g><text x="104.8" y="324">answer</text><g transform="translate(160.8,320.5) scale(.8)"><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g><text x="172.2" y="324">attack</text><g transform="translate(228.2,320.5) scale(.8)"><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g><text x="239.6" y="324">alert</text><g transform="translate(290,320.5) scale(.8)"><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g><text x="301.4" y="324">rule</text><g transform="translate(347,320.5) scale(.8)"><g><rect x="-8" y="-6" width="16" height="12" rx="2" fill="#64748b" stroke="#fff" stroke-width="1.6"/><path d="M-5,-2 H5 M-5,2 H3" stroke="#fff" stroke-width="1.4"/></g></g><text x="359.2" y="324">report</text></g>
<rect x="12" y="336" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="336" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="39.1s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1304" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/><circle cx="36" cy="364" r="14" fill="#0ea5e9"/><text x="36" y="369" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="359" font-size="14" font-weight="800" fill="#0ea5e9">The spider maps the site</text><text x="578" y="359" text-anchor="end" font-size="10.5" class="dg-muted">Baseline scan · 1/8</text><text x="60" y="380" font-size="12.5" class="dg-text">zap-baseline.py -t http://juice-shop:3000 -m 2 follows every link.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1304;0.2522" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/><circle cx="36" cy="364" r="14" fill="#0ea5e9"/><text x="36" y="369" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="359" font-size="14" font-weight="800" fill="#0ea5e9">The passive scan only looks</text><text x="578" y="359" text-anchor="end" font-size="10.5" class="dg-muted">Baseline scan · 2/8</text><text x="60" y="380" font-size="12.5" class="dg-text">It reads normal answers: a missing CSP header, a cookie without Secure.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2522;0.3739" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/><circle cx="36" cy="364" r="14" fill="#0ea5e9"/><text x="36" y="369" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="359" font-size="14" font-weight="800" fill="#0ea5e9">Each finding becomes an alert</text><text x="578" y="359" text-anchor="end" font-size="10.5" class="dg-muted">Baseline scan · 3/8</text><text x="60" y="380" font-size="12.5" class="dg-text">Ranked by risk, with a rule ID: 10038 is &quot;CSP header not set&quot;.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3739;0.5043" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/><circle cx="36" cy="364" r="14" fill="#e11d48"/><text x="36" y="369" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="359" font-size="14" font-weight="800" fill="#e11d48">Full scan: real attacks</text><text x="578" y="359" text-anchor="end" font-size="10.5" class="dg-muted">Full scan, test only · 4/8</text><text x="60" y="380" font-size="12.5" class="dg-text">zap-full-scan.py also sends SQL injection and XSS payloads.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5043;0.6348" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/><circle cx="36" cy="364" r="14" fill="#e11d48"/><text x="36" y="369" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="359" font-size="14" font-weight="800" fill="#e11d48">A weak answer can become a High alert</text><text x="578" y="359" text-anchor="end" font-size="10.5" class="dg-muted">Full scan, test only · 5/8</text><text x="60" y="380" font-size="12.5" class="dg-text">Such as 40018 SQL Injection. Attacks change data: never scan production.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6348;0.7565" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/><circle cx="36" cy="364" r="14" fill="#d97706"/><text x="36" y="369" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="359" font-size="14" font-weight="800" fill="#d97706">The rules file decides each alert</text><text x="578" y="359" text-anchor="end" font-size="10.5" class="dg-muted">Rules and result · 6/8</text><text x="60" y="380" font-size="12.5" class="dg-text">zap-rules.tsv sets each rule ID to IGNORE, INFO, WARN or FAIL. 40018: FAIL.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7565;0.8783" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/><circle cx="36" cy="364" r="14" fill="#d97706"/><text x="36" y="369" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="359" font-size="14" font-weight="800" fill="#d97706">A report for people</text><text x="578" y="359" text-anchor="end" font-size="10.5" class="dg-muted">Rules and result · 7/8</text><text x="60" y="380" font-size="12.5" class="dg-text">zap-report.html lists each alert: its risk, the URLs, and how to fix it.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8783" calcMode="discrete" dur="39.1s" repeatCount="indefinite"/><circle cx="36" cy="364" r="14" fill="#d97706"/><text x="36" y="369" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="359" font-size="14" font-weight="800" fill="#d97706">A FAIL rule sets the CI gate</text><text x="578" y="359" text-anchor="end" font-size="10.5" class="dg-muted">Rules and result · 8/8</text><text x="60" y="380" font-size="12.5" class="dg-text">ZAP exits 1. Report mode: orange or UNSTABLE. Enforce mode: the job fails.</text></g>
</svg>
```

```steps
#0ea5e9 | Baseline scan | The spider maps the site | zap-baseline.py -t http://juice-shop:3000 -m 2 follows every link.
#0ea5e9 | Baseline scan | The passive scan only looks | It reads normal answers: a missing CSP header, a cookie without Secure.
#0ea5e9 | Baseline scan | Each finding becomes an alert | Ranked by risk, with a rule ID: 10038 is "CSP header not set".
#e11d48 | Full scan, test only | Full scan: real attacks | zap-full-scan.py also sends SQL injection and XSS payloads.
#e11d48 | Full scan, test only | A weak answer can become a High alert | Such as 40018 SQL Injection. Attacks change data: never scan production.
#d97706 | Rules and result | The rules file decides each alert | zap-rules.tsv sets each rule ID to IGNORE, INFO, WARN or FAIL. 40018: FAIL.
#d97706 | Rules and result | A report for people | zap-report.html lists each alert: its risk, the URLs, and how to fix it.
#d97706 | Rules and result | A FAIL rule sets the CI gate | ZAP exits 1. Report mode: orange or UNSTABLE. Enforce mode: the job fails.
```

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
