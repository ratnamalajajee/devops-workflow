# Gitleaks: Secret Scanning

Gitleaks finds passwords, API keys and tokens that were committed to Git by mistake. This guide sets it up step by step: first on your laptop, then as a job in **GitLab CI** and as a stage in **Jenkins**. The commands, config files and pinned version are the ones that run in a real Python microservices project, where the scan checks every branch.

> **Note:** One guide per security tool: [Gitleaks](#/tool/gitleaks) · [SonarQube](#/tool/sonarqube) · [Trivy](#/tool/trivy) · [Snyk](#/tool/snyk) · [DAST with ZAP](#/tool/dast-zap). To see all of them in one pipeline, read [Jenkins DevSecOps Pipeline](#/tool/jenkins-devsecops).

## Start here: Gitleaks in simple words

> **In simple words:** Gitleaks is a **metal detector for secrets**. It reads your code (and, if you ask, every old commit) looking for anything shaped like a password, key or token, and tells you the file and the line.

### Watch how it works

```svg Watch it work: the pre-commit hook stopping a key, the CI job catching it in report or enforce mode, and the fix: rotate first, then remove it. The animation loops.
<svg viewBox="0 0 600 406" role="img" data-anim="gitleaks" aria-label="Animated Gitleaks flow. Before the commit: you put a line with an AWS access key, aws_access_key_id = AKIA and 16 more characters, in leak-test.txt and run git commit. The pre-commit hook runs gitleaks git --pre-commit --staged, finds the rule aws-access-token, exits 1 and blocks the commit. In the pipeline: a hook can be skipped with git commit --no-verify, so the key is pushed anyway. The CI job runs gitleaks dir . on the branch&#x27;s files, finds the key, and writes gitleaks.json and a JUnit report for the Tests tab. In report mode the GitLab job exits 3, which is allowed to fail, so it turns orange and the pipeline carries on; Jenkins marks the build UNSTABLE. In enforce mode, with GITLEAKS_ENFORCE=true, the job exits 1 and turns red, the pipeline stops, and Jenkins marks the build FAILED. Fix it: first rotate the key in AWS IAM, because every clone still has the old one, and keep the new key in a secret store such as AWS Secrets Manager or a CI variable. Then remove the key from the code and push again: the hook and the CI scan both pass. A false positive, such as a fake value in a test, is accepted by adding its fingerprint to .gitleaksignore with a comment saying why.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<polyline points="87,60 300,60 510,60" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="87,34 87,16 510,16 510,34" fill="none" stroke-linejoin="round" stroke="#e11d48" stroke-width="1.6" stroke-dasharray="3 4" stroke-opacity=".6"/>
<polyline points="510,60 510,172" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="510,172 300,172" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="510,172 510,284" fill="none" stroke-linejoin="round" stroke="#64748b" stroke-width="1.8" stroke-dasharray="4 3" stroke-opacity=".7"/>
<polyline points="87,60 87,172 87,284" fill="none" stroke-linejoin="round" stroke="#eab308" stroke-width="1.8" stroke-dasharray="3 3" stroke-opacity=".75"/>
<polyline points="378,284 405,284 405,190 432,190" fill="none" stroke-linejoin="round" stroke="#0ea5e9" stroke-width="1.8" stroke-dasharray="2 3" stroke-opacity=".75"/>
<g><rect x="8" y="30" width="158" height="60" rx="29" fill="#6366f1" fill-opacity=".18" stroke="#6366f1" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1048" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/></rect><rect x="12" y="34" width="150" height="52" rx="26" class="dg-box" stroke="#6366f1" stroke-width="2.2"/><text x="87" y="56.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">You</text><text x="87" y="72" text-anchor="middle" font-size="11" class="dg-muted">git commit</text></g>
<g><rect x="218" y="30" width="164" height="60" rx="12" fill="#7c3aed" fill-opacity=".18" stroke="#7c3aed" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.1048;0.2177;0.7823;0.8952" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/></rect><rect x="222" y="34" width="156" height="52" rx="9" class="dg-box" stroke="#7c3aed" stroke-width="2.2"/><text x="300" y="56.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Pre-commit hook</text><text x="300" y="72" text-anchor="middle" font-size="11" class="dg-muted">gitleaks --staged</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1048;0.2177" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><rect x="222" y="34" width="156" height="52" rx="9" fill="#e11d48"/><text x="300" y="64.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">✕ commit blocked</text></g></g>
<g><rect x="428" y="30" width="164" height="60" rx="12" fill="#f97316" fill-opacity=".18" stroke="#f97316" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2177;0.3306" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/></rect><rect x="432" y="34" width="156" height="52" rx="9" class="dg-box" stroke="#f97316" stroke-width="2.2"/><text x="510" y="56.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Git server</text><text x="510" y="72" text-anchor="middle" font-size="11" class="dg-muted">your branch</text></g>
<g><rect x="8" y="142" width="158" height="60" rx="12" fill="#d97706" fill-opacity=".18" stroke="#d97706" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6694;0.7823" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/></rect><rect x="12" y="146" width="150" height="52" rx="9" class="dg-box" stroke="#d97706" stroke-width="2.2"/><text x="87" y="168.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">AWS IAM</text><text x="87" y="184" text-anchor="middle" font-size="11" class="dg-muted">issued the key</text></g>
<rect x="222" y="146" width="156" height="52" rx="9" class="dg-box"/><g opacity="1"><animate attributeName="opacity" values="1;0.28;1" keyTimes="0;0.5565;0.6694" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><rect x="218" y="142" width="164" height="60" rx="12" fill="#10b981" fill-opacity=".18" stroke="#10b981" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4435;0.5565" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/></rect><rect x="222" y="146" width="156" height="52" rx="9" class="dg-box" stroke="#10b981" stroke-width="2.2"/><text x="300" y="168.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Next stages</text><text x="300" y="184" text-anchor="middle" font-size="11" class="dg-muted">build · test · deploy</text></g>
<g><rect x="428" y="142" width="164" height="60" rx="12" fill="#0891b2" fill-opacity=".18" stroke="#0891b2" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.3306;0.6694;0.7823;0.8952" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/></rect><rect x="432" y="146" width="156" height="52" rx="9" class="dg-box" stroke="#0891b2" stroke-width="2.2"/><text x="510" y="168.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">CI scan job</text><text x="510" y="184" text-anchor="middle" font-size="11" class="dg-muted">gitleaks dir .</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4435;0.5565" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><rect x="432" y="146" width="156" height="52" rx="9" fill="#d97706"/><text x="510" y="176.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">⚠ exit 3 · orange</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5565;0.6694" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><rect x="432" y="146" width="156" height="52" rx="9" fill="#e11d48"/><text x="510" y="176.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">✕ exit 1 · red</text></g></g>
<g><rect x="8" y="254" width="158" height="60" rx="12" fill="#16a34a" fill-opacity=".18" stroke="#16a34a" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6694;0.7823" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/></rect><rect x="12" y="258" width="150" height="52" rx="9" class="dg-box" stroke="#16a34a" stroke-width="2.2"/><text x="87" y="280.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Secret store</text><text x="87" y="296" text-anchor="middle" font-size="11" class="dg-muted">Secrets Manager, CI var</text></g>
<g><rect x="218" y="254" width="164" height="60" rx="12" fill="#0ea5e9" fill-opacity=".18" stroke="#0ea5e9" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8952" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/></rect><rect x="222" y="258" width="156" height="52" rx="9" class="dg-box" stroke="#0ea5e9" stroke-width="2.2"/><text x="300" y="280.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">.gitleaksignore</text><text x="300" y="296" text-anchor="middle" font-size="11" class="dg-muted">fingerprint + reason</text></g>
<g><rect x="428" y="254" width="164" height="60" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3306;0.4435" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/></rect><rect x="432" y="258" width="156" height="52" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="510" y="280.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Reports</text><text x="510" y="296" text-anchor="middle" font-size="11" class="dg-muted">gitleaks.json, JUnit</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1048;0.2177" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="405" cy="60" r="9.5" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M401,56 L409,64 M409,56 L401,64" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5565;0.6694" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="405" cy="172" r="9.5" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M401,168 L409,176 M409,168 L401,176" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7823;0.8952" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="378" cy="34" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M373.5,34 L377,37.5 L382.5,30.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7823;0.8952" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="588" cy="146" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M583.5,146 L587,149.5 L592.5,142.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0063;0.0902" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M87,60 L300,60" keyPoints="0;0;1;1" keyTimes="0;0.0063;0.0902;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1444;0.2065" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M300,60 L87,60" keyPoints="0;0;1;1" keyTimes="0;0.1444;0.2065;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><g><circle r="7" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M0,-3.5 V1 M0,3.2 V3.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2245;0.3148" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M87,34 L87,16 L510,16 L510,34" keyPoints="0;0;1;1" keyTimes="0;0.2245;0.3148;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3352;0.3781" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M510,60 L510,172" keyPoints="0;0;1;1" keyTimes="0;0.3352;0.3781;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3871;0.4323" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M510,172 L510,284" keyPoints="0;0;1;1" keyTimes="0;0.3871;0.4323;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><g><rect x="-8" y="-6" width="16" height="12" rx="2" fill="#64748b" stroke="#fff" stroke-width="1.6"/><path d="M-5,-2 H5 M-5,2 H3" stroke="#fff" stroke-width="1.4"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4774;0.5406" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M510,172 L300,172" keyPoints="0;0;1;1" keyTimes="0;0.4774;0.5406;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.579;0.6242" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M432,172 L417,172" keyPoints="0;0;1;1" keyTimes="0;0.579;0.6242;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><g><circle r="7" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M0,-3.5 V1 M0,3.2 V3.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.675;0.7202" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M87,60 L87,172" keyPoints="0;0;1;1" keyTimes="0;0.675;0.7202;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7258;0.771" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M87,172 L87,284" keyPoints="0;0;1;1" keyTimes="0;0.7258;0.771;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7879;0.8782" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M87,60 L300,60 L510,60 L510,172" keyPoints="0;0;1;1" keyTimes="0;0.7879;0.8782;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.9015;0.9853" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M378,284 L405,284 L405,190 L432,190 L510,172" keyPoints="0;0;1;1" keyTimes="0;0.9015;0.9853;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(21.2,330.5) scale(.8)"><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g><text x="33.4" y="334">commit / push</text><g transform="translate(128.6,330.5) scale(.8)"><g><circle r="7" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M0,-3.5 V1 M0,3.2 V3.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/></g></g><text x="140" y="334">blocked</text><g transform="translate(201.6,330.5) scale(.8)"><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g><text x="213" y="334">pipeline</text><g transform="translate(281,330.5) scale(.8)"><g><rect x="-8" y="-6" width="16" height="12" rx="2" fill="#64748b" stroke="#fff" stroke-width="1.6"/><path d="M-5,-2 H5 M-5,2 H3" stroke="#fff" stroke-width="1.4"/></g></g><text x="293.2" y="334">report</text><g transform="translate(349.2,330.5) scale(.8)"><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g><text x="360.6" y="334">next stage</text><g transform="translate(439.8,330.5) scale(.8)"><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g><text x="452.8" y="334">key</text><g transform="translate(492,330.5) scale(.8)"><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g><text x="503.4" y="334">exception</text></g>
<rect x="12" y="346" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="346" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="24.8s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1048" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="36" cy="374" r="14" fill="#7c3aed"/><text x="36" y="379" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="369" font-size="14" font-weight="800" fill="#7c3aed">You commit a key by mistake</text><text x="578" y="369" text-anchor="end" font-size="10.5" class="dg-muted">Before the commit · 1/9</text><text x="60" y="390" font-size="12.5" class="dg-text">leak-test.txt has aws_access_key_id = AKIA…, and you run git commit.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1048;0.2177" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="36" cy="374" r="14" fill="#7c3aed"/><text x="36" y="379" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="369" font-size="14" font-weight="800" fill="#7c3aed">The pre-commit hook blocks it</text><text x="578" y="369" text-anchor="end" font-size="10.5" class="dg-muted">Before the commit · 2/9</text><text x="60" y="390" font-size="12.5" class="dg-text">gitleaks git --pre-commit --staged finds aws-access-token and exits 1.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2177;0.3306" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="36" cy="374" r="14" fill="#f97316"/><text x="36" y="379" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="369" font-size="14" font-weight="800" fill="#f97316">Skipped with --no-verify and pushed</text><text x="578" y="369" text-anchor="end" font-size="10.5" class="dg-muted">In the pipeline · 3/9</text><text x="60" y="390" font-size="12.5" class="dg-text">Anyone can skip a hook. The CI scan is the control that counts.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3306;0.4435" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="36" cy="374" r="14" fill="#f97316"/><text x="36" y="379" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="369" font-size="14" font-weight="800" fill="#f97316">The CI job scans the branch&#x27;s files</text><text x="578" y="369" text-anchor="end" font-size="10.5" class="dg-muted">In the pipeline · 4/9</text><text x="60" y="390" font-size="12.5" class="dg-text">gitleaks dir . finds the key and writes gitleaks.json and a JUnit report.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4435;0.5565" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="36" cy="374" r="14" fill="#f97316"/><text x="36" y="379" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="369" font-size="14" font-weight="800" fill="#f97316">Report mode: orange, the pipeline goes on</text><text x="578" y="369" text-anchor="end" font-size="10.5" class="dg-muted">In the pipeline · 5/9</text><text x="60" y="390" font-size="12.5" class="dg-text">The job exits 3, which is allowed to fail. Jenkins marks it UNSTABLE.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5565;0.6694" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="36" cy="374" r="14" fill="#f97316"/><text x="36" y="379" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="369" font-size="14" font-weight="800" fill="#f97316">Enforce mode: red, the pipeline stops</text><text x="578" y="369" text-anchor="end" font-size="10.5" class="dg-muted">In the pipeline · 6/9</text><text x="60" y="390" font-size="12.5" class="dg-text">With GITLEAKS_ENFORCE=true the job exits 1. Jenkins marks it FAILED.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6694;0.7823" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="36" cy="374" r="14" fill="#059669"/><text x="36" y="379" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="369" font-size="14" font-weight="800" fill="#059669">First, rotate the key</text><text x="578" y="369" text-anchor="end" font-size="10.5" class="dg-muted">Fix it · 7/9</text><text x="60" y="390" font-size="12.5" class="dg-text">Revoke it in AWS IAM and make a new one: every clone still has the old key.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7823;0.8952" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="36" cy="374" r="14" fill="#059669"/><text x="36" y="379" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="369" font-size="14" font-weight="800" fill="#059669">Then remove it from the code</text><text x="578" y="369" text-anchor="end" font-size="10.5" class="dg-muted">Fix it · 8/9</text><text x="60" y="390" font-size="12.5" class="dg-text">The app reads the new key from the secret store. Both scans pass again.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8952" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="36" cy="374" r="14" fill="#059669"/><text x="36" y="379" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">9</text><text x="60" y="369" font-size="14" font-weight="800" fill="#059669">A false positive? Write it down</text><text x="578" y="369" text-anchor="end" font-size="10.5" class="dg-muted">Fix it · 9/9</text><text x="60" y="390" font-size="12.5" class="dg-text">Add its fingerprint to .gitleaksignore, with a comment saying why.</text></g>
</svg>
```

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
