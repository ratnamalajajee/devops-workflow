# GitHub Actions

GitHub Actions is the CI/CD system built into GitHub. There's no server to install: you add a YAML file to `.github/workflows/`, push it, and GitHub runs it on a fresh virtual machine. This guide goes from a "hello world" workflow to testing the sample app, publishing its Docker image, deploying to AWS without stored keys, and handing over to Argo CD.

> **Note:** You need a GitHub account and the **sample app** from [CI/CD Basics](#/tool/cicd-basics) pushed to a repo named `hello-app`.

## Start here: GitHub Actions in simple words

> **In simple words:** GitHub Actions is a robot that lives inside your GitHub repository. You give it a recipe file that says "**when** this happens, **do** these steps", and GitHub runs the steps on a brand-new computer each time.

### Watch how it works

```svg Watch it work: a push starting ci.yml, a matrix of fresh runners testing three Python versions, the checks on the pull request, then main publishing the image, logging in to AWS with OIDC and handing the new tag to Argo CD. The animation loops.
<svg viewBox="0 0 600 406" role="img" data-anim="github-actions" aria-label="Animated GitHub Actions flow. Test every push: a push or a pull request to hello-app is the event. The workflow file ci.yml in .github/workflows says on push and pull_request, so it starts. Its test job has a matrix, so GitHub starts three fresh GitHub-hosted Ubuntu runners in parallel, for Python 3.11, 3.12 and 3.13. On each one the steps run: the checkout and setup-python actions, then pip install and pytest. Three green checks appear on the commit or pull request; a required check that fails would block the merge. Ship from main: the jobs that need test run only on main, each on a fresh runner. The image job logs in with the automatic GITHUB_TOKEN and pushes ghcr.io/&lt;you&gt;/hello-app:sha-1a2b3c4 to GitHub Container Registry. The push-ecr job has id-token write permission, so it trades a GitHub OIDC token for short-lived credentials of the IAM role gha-hello-app, whose trust policy checks the repository and branch. It pushes the image to Amazon ECR, and no AWS access key is stored in GitHub. Hand over to Argo CD: the bump-gitops job uses the GITOPS_TOKEN secret to commit the new image tag to the gitops repository, and Argo CD sees the commit and syncs the cluster. The CI workflow never touches the cluster.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<rect x="162" y="8" width="176" height="306" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="5 4"/>
<rect x="362" y="8" width="230" height="150" rx="12" fill="none" stroke="#ff9900" stroke-width="2" stroke-dasharray="7 4"/>
<polyline points="74,62 74,155" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="74,62 176,62" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="150,62 150,174 176,174" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="150,118 176,118" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="74,155 150,155" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="250,174 250,268" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="74,277 176,277" fill="none" stroke-linejoin="round" stroke="#eab308" stroke-width="1.8" stroke-dasharray="3 3" stroke-opacity=".75"/>
<polyline points="250,268 416,268" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="350,268 350,63 376,63" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="1.6" stroke-opacity=".8"/>
<polyline points="350,123 376,123" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="1.6" stroke-opacity=".8"/>
<polyline points="350,199 362,199" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="1.6" stroke-opacity=".8"/>
<polyline points="416,268 538,268" fill="none" stroke-linejoin="round" stroke="#0d9488" stroke-width="1.8" stroke-dasharray="6 3" stroke-opacity=".7"/>
<rect x="168" y="14" width="131.9" height="16" rx="5" class="dg-box"/><text x="172" y="24" font-size="11" class="dg-muted">GitHub-hosted runners</text>
<rect x="368" y="15" width="30.8" height="18" rx="5" class="dg-box"/><text x="372" y="27" font-size="13" font-weight="800" fill="#ff9900">AWS</text>
<g><rect x="8" y="33" width="132" height="58" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1;0" keyTimes="0;0.1057;0.3252;0.439" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/></rect><rect x="12" y="37" width="124" height="50" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="74" y="58.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">hello-app</text><text x="74" y="74" text-anchor="middle" font-size="11" class="dg-muted">push or PR</text></g>
<g><rect x="8" y="126" width="132" height="58" rx="12" fill="#6366f1" fill-opacity=".18" stroke="#6366f1" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.2195" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/></rect><rect x="12" y="130" width="124" height="50" rx="9" class="dg-box" stroke="#6366f1" stroke-width="2.2"/><text x="74" y="151.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">ci.yml</text><text x="74" y="167" text-anchor="middle" font-size="11" class="dg-muted">.github/workflows/</text></g>
<g><rect x="8" y="248" width="132" height="58" rx="12" fill="#ca8a04" fill-opacity=".18" stroke="#ca8a04" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7805;0.8943" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/></rect><rect x="12" y="252" width="124" height="50" rx="9" class="dg-box" stroke="#ca8a04" stroke-width="2.2"/><text x="74" y="273.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Secrets</text><text x="74" y="289" text-anchor="middle" font-size="11" class="dg-muted">repo + environment</text></g>
<g><rect x="172" y="36" width="156" height="52" rx="12" fill="#0d9488" fill-opacity=".18" stroke="#0d9488" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1057;0.3252" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/></rect><rect x="176" y="40" width="148" height="44" rx="9" class="dg-box" stroke="#0d9488" stroke-width="2.2"/><text x="250" y="58.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">test · Python 3.11</text><text x="250" y="74" text-anchor="middle" font-size="11" class="dg-muted">fresh Ubuntu VM</text></g>
<g><rect x="172" y="92" width="156" height="52" rx="12" fill="#0d9488" fill-opacity=".18" stroke="#0d9488" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1057;0.3252" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/></rect><rect x="176" y="96" width="148" height="44" rx="9" class="dg-box" stroke="#0d9488" stroke-width="2.2"/><text x="250" y="114.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">test · Python 3.12</text><text x="250" y="130" text-anchor="middle" font-size="11" class="dg-muted">fresh Ubuntu VM</text></g>
<g><rect x="172" y="148" width="156" height="52" rx="12" fill="#0d9488" fill-opacity=".18" stroke="#0d9488" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1057;0.3252" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/></rect><rect x="176" y="152" width="148" height="44" rx="9" class="dg-box" stroke="#0d9488" stroke-width="2.2"/><text x="250" y="170.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">test · Python 3.13</text><text x="250" y="186" text-anchor="middle" font-size="11" class="dg-muted">fresh Ubuntu VM</text></g>
<g><rect x="172" y="232" width="156" height="72" rx="12" fill="#f97316" fill-opacity=".18" stroke="#f97316" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.439;0.8943" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/></rect><rect x="176" y="236" width="148" height="64" rx="9" class="dg-box" stroke="#f97316" stroke-width="2.2"/><text x="250" y="257" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Jobs on main</text><text x="250" y="272.5" text-anchor="middle" font-size="11" class="dg-muted">needs: test</text><text x="250" y="287.5" text-anchor="middle" font-size="11" class="dg-muted">image · push-ecr · bump</text></g>
<g><rect x="372" y="36" width="210" height="54" rx="12" fill="#dd344c" fill-opacity=".18" stroke="#dd344c" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5528;0.6748" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/></rect><rect x="376" y="40" width="202" height="46" rx="9" class="dg-box" stroke="#dd344c" stroke-width="2.2"/><text x="477" y="59.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">IAM role gha-hello-app</text><text x="477" y="75" text-anchor="middle" font-size="11" class="dg-muted">short-lived keys via OIDC</text></g>
<g><rect x="372" y="96" width="210" height="54" rx="12" fill="#ff9900" fill-opacity=".18" stroke="#ff9900" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6748;0.7805" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/></rect><rect x="376" y="100" width="202" height="46" rx="9" class="dg-box" stroke="#ff9900" stroke-width="2.2"/><text x="477" y="119.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Amazon ECR</text><text x="477" y="135" text-anchor="middle" font-size="11" class="dg-muted">hello-app:1a2b3c4</text></g>
<g><rect x="358" y="172" width="230" height="54" rx="12" fill="#7c3aed" fill-opacity=".18" stroke="#7c3aed" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.439;0.5528" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/></rect><rect x="362" y="176" width="222" height="46" rx="9" class="dg-box" stroke="#7c3aed" stroke-width="2.2"/><text x="473" y="195.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">GitHub Container Registry</text><text x="473" y="211" text-anchor="middle" font-size="11" class="dg-muted">hello-app:sha-1a2b3c4</text></g>
<g><rect x="358" y="239" width="116" height="58" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.7805" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/></rect><rect x="362" y="243" width="108" height="50" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="416" y="264.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">gitops repo</text><text x="416" y="280" text-anchor="middle" font-size="11" class="dg-muted">new tag</text></g>
<g><rect x="480" y="239" width="116" height="58" rx="12" fill="#ef7b4d" fill-opacity=".18" stroke="#ef7b4d" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8943" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/></rect><rect x="484" y="243" width="108" height="50" rx="9" class="dg-box" stroke="#ef7b4d" stroke-width="2.2"/><text x="538" y="264.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Argo CD</text><text x="538" y="280" text-anchor="middle" font-size="11" class="dg-muted">syncs cluster</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2195;0.439" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><circle cx="324" cy="40" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M319.5,40 L323,43.5 L328.5,36.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2195;0.439" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><circle cx="324" cy="96" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M319.5,96 L323,99.5 L328.5,92.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2195;0.439" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><circle cx="324" cy="152" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M319.5,152 L323,155.5 L328.5,148.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.439;0.5528" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><circle cx="584" cy="176" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M579.5,176 L583,179.5 L588.5,172.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5528;0.6748" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><circle cx="578" cy="40" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M573.5,40 L577,43.5 L582.5,36.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6748;0.7805" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><circle cx="578" cy="100" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M573.5,100 L577,103.5 L582.5,96.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0063;0.0909" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M74,62 L74,155" keyPoints="0;0;1;1" keyTimes="0;0.0063;0.0909;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1125;0.2036" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M74,155 L150,155 L150,62 L176,62" keyPoints="0;0;1;1" keyTimes="0;0.1125;0.2036;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1125;0.2036" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M74,155 L150,155 L150,118 L176,118" keyPoints="0;0;1;1" keyTimes="0;0.1125;0.2036;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1125;0.2036" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M74,155 L150,155 L150,174 L176,174" keyPoints="0;0;1;1" keyTimes="0;0.1125;0.2036;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.332;0.4231" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M250,62 L150,62 L74,62" keyPoints="0;0;1;1" keyTimes="0;0.332;0.4231;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.332;0.4231" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M250,118 L150,118 L150,62 L74,62" keyPoints="0;0;1;1" keyTimes="0;0.332;0.4231;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.332;0.4231" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M250,174 L150,174 L150,62 L74,62" keyPoints="0;0;1;1" keyTimes="0;0.332;0.4231;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4436;0.4732" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M250,174 L250,268" keyPoints="0;0;1;1" keyTimes="0;0.4436;0.4732;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.48;0.5437" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M250,268 L350,268 L350,199 L473,199" keyPoints="0;0;1;1" keyTimes="0;0.48;0.5437;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5589;0.6077" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M250,268 L350,268 L350,63 L477,63" keyPoints="0;0;1;1" keyTimes="0;0.5589;0.6077;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6163;0.665" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M477,63 L350,63 L350,268 L250,268" keyPoints="0;0;1;1" keyTimes="0;0.6163;0.665;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6811;0.7657" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M250,268 L350,268 L350,123 L477,123" keyPoints="0;0;1;1" keyTimes="0;0.6811;0.7657;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7862;0.826" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M74,277 L176,277" keyPoints="0;0;1;1" keyTimes="0;0.7862;0.826;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8351;0.8829" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M250,268 L416,268" keyPoints="0;0;1;1" keyTimes="0;0.8351;0.8829;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.9007;0.9852" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M416,268 L538,268" keyPoints="0;0;1;1" keyTimes="0;0.9007;0.9852;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(20.4,330.5) scale(.8)"><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g><text x="31.8" y="334">event / token</text><g transform="translate(127,330.5) scale(.8)"><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g><text x="138.4" y="334">job</text><g transform="translate(177.6,330.5) scale(.8)"><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g><text x="189" y="334">check result</text><g transform="translate(279.4,330.5) scale(.8)"><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g><text x="291.6" y="334">image / commit</text><g transform="translate(393.2,330.5) scale(.8)"><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g><text x="406.2" y="334">secret / keys</text><g transform="translate(501.4,330.5) scale(.8)"><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g><text x="512.8" y="334">sync</text></g>
<rect x="12" y="346" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="346" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="24.6s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1057" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><circle cx="36" cy="374" r="14" fill="#6366f1"/><text x="36" y="379" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="369" font-size="14" font-weight="800" fill="#6366f1">A push or pull request is the event</text><text x="578" y="369" text-anchor="end" font-size="10.5" class="dg-muted">Test every push · 1/9</text><text x="60" y="390" font-size="12.5" class="dg-text">ci.yml in .github/workflows/ says on: push and pull_request, so it starts.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1057;0.2195" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><circle cx="36" cy="374" r="14" fill="#6366f1"/><text x="36" y="379" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="369" font-size="14" font-weight="800" fill="#6366f1">The matrix starts three runners</text><text x="578" y="369" text-anchor="end" font-size="10.5" class="dg-muted">Test every push · 2/9</text><text x="60" y="390" font-size="12.5" class="dg-text">Each job gets a fresh Ubuntu VM: Python 3.11, 3.12 and 3.13, in parallel.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2195;0.3252" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><circle cx="36" cy="374" r="14" fill="#6366f1"/><text x="36" y="379" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="369" font-size="14" font-weight="800" fill="#6366f1">Steps run on each runner</text><text x="578" y="369" text-anchor="end" font-size="10.5" class="dg-muted">Test every push · 3/9</text><text x="60" y="390" font-size="12.5" class="dg-text">uses: checkout and setup-python, then run: pip install and pytest.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3252;0.439" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><circle cx="36" cy="374" r="14" fill="#6366f1"/><text x="36" y="379" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="369" font-size="14" font-weight="800" fill="#6366f1">The checks show on the pull request</text><text x="578" y="369" text-anchor="end" font-size="10.5" class="dg-muted">Test every push · 4/9</text><text x="60" y="390" font-size="12.5" class="dg-text">Three green checks. A required check that fails would block the merge.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.439;0.5528" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><circle cx="36" cy="374" r="14" fill="#f97316"/><text x="36" y="379" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="369" font-size="14" font-weight="800" fill="#f97316">On main, the image job pushes to GHCR</text><text x="578" y="369" text-anchor="end" font-size="10.5" class="dg-muted">Ship from main · 5/9</text><text x="60" y="390" font-size="12.5" class="dg-text">needs: test waits for all three. The automatic GITHUB_TOKEN logs it in.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5528;0.6748" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><circle cx="36" cy="374" r="14" fill="#f97316"/><text x="36" y="379" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="369" font-size="14" font-weight="800" fill="#f97316">OIDC: short-lived AWS keys</text><text x="578" y="369" text-anchor="end" font-size="10.5" class="dg-muted">Ship from main · 6/9</text><text x="60" y="390" font-size="12.5" class="dg-text">id-token: write lets push-ecr swap a GitHub token for the gha-hello-app role.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6748;0.7805" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><circle cx="36" cy="374" r="14" fill="#f97316"/><text x="36" y="379" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="369" font-size="14" font-weight="800" fill="#f97316">Push to ECR with no stored keys</text><text x="578" y="369" text-anchor="end" font-size="10.5" class="dg-muted">Ship from main · 7/9</text><text x="60" y="390" font-size="12.5" class="dg-text">The keys expire on their own. No AWS access key is saved in GitHub.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7805;0.8943" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><circle cx="36" cy="374" r="14" fill="#0d9488"/><text x="36" y="379" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="369" font-size="14" font-weight="800" fill="#0d9488">bump-gitops commits the new tag</text><text x="578" y="369" text-anchor="end" font-size="10.5" class="dg-muted">Hand over to Argo CD · 8/9</text><text x="60" y="390" font-size="12.5" class="dg-text">With the GITOPS_TOKEN secret it writes sha-1a2b3c4 into the gitops repo.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8943" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><circle cx="36" cy="374" r="14" fill="#0d9488"/><text x="36" y="379" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">9</text><text x="60" y="369" font-size="14" font-weight="800" fill="#0d9488">Argo CD deploys it</text><text x="578" y="369" text-anchor="end" font-size="10.5" class="dg-muted">Hand over to Argo CD · 9/9</text><text x="60" y="390" font-size="12.5" class="dg-text">Argo CD sees the commit and syncs the cluster. CI never touches it.</text></g>
</svg>
```

### How the pieces fit

```text
 Event (push, pull request, schedule, button)
   │ triggers
   ▼
 Workflow  (.github/workflows/ci.yml)
   ├── Job "test"   ── runs on ──▶ Runner (fresh Ubuntu VM from GitHub)
   │     ├── step: checkout code         (an action: actions/checkout)
   │     ├── step: set up Python         (an action: actions/setup-python)
   │     └── step: run: pytest           (a shell command)
   └── Job "build"  (needs: test) ──▶ another fresh runner
```

### Key words

| Word | Simple meaning |
|---|---|
| **Workflow** | One automated process, defined in a YAML file under `.github/workflows/` |
| **Event / trigger** | What starts it: `push`, `pull_request`, `schedule`, `workflow_dispatch` (a button) |
| **Job** | A group of steps that run on one runner. Jobs run **in parallel** unless linked with `needs` |
| **Step** | One command (`run:`) or one ready-made action (`uses:`) |
| **Action** | A reusable building block, like `actions/checkout`, from the GitHub Marketplace |
| **Runner** | The machine that runs a job: GitHub-hosted (fresh each time) or your own |
| **Secret** | An encrypted value such as a token, shown as `***` in logs |
| **Artifact** | A file a workflow saves for later download, such as a test report |

### Check yourself

1. Where do workflow files live?
2. Do two jobs in a workflow run one after another, or at the same time?
3. What's the difference between `run:` and `uses:`?

> **Tip:** Answers: 1) In `.github/workflows/` in the repository. 2) At the same time, unless one says `needs:` the other. 3) `run:` runs shell commands; `uses:` runs a ready-made action.

## Your first workflow

> **In simple words:** Create one small file, push it, and watch GitHub run it in the **Actions** tab.

In `hello-app`, create `.github/workflows/hello.yml`:

```yaml
name: hello

on:
  push:
  workflow_dispatch:        # adds a "Run workflow" button in the Actions tab

jobs:
  greet:
    runs-on: ubuntu-latest
    steps:
      - name: Say hello
        run: |
          echo "Hello from GitHub Actions!"
          echo "Repo: $GITHUB_REPOSITORY  Branch: $GITHUB_REF_NAME  Commit: $GITHUB_SHA"
          echo "Triggered by: ${{ github.actor }} via ${{ github.event_name }}"
      - name: What machine am I on?
        run: |
          uname -a
          nproc && free -h
          docker --version && python3 --version
```

```bash
mkdir -p .github/workflows
# (create hello.yml as above)
git add .github && git commit -m "Add hello workflow" && git push
```

Open your repo on GitHub → **Actions** → **hello** → the latest run → **greet** to read each step's log.

Two kinds of variables appear above:
- `$GITHUB_SHA`: an **environment variable**, read by the shell.
- `${{ github.actor }}`: an **expression**, filled in by GitHub before the step runs. Expressions can read `github`, `env`, `secrets`, `vars`, `inputs`, `matrix`, `needs` and more.

## CI for the sample app

> **In simple words:** Every push and every pull request automatically installs the app and runs its tests on three Python versions. A red ❌ means "don't merge this yet".

Create `.github/workflows/ci.yml`:

```yaml
name: ci

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read            # least privilege: this workflow only reads code

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        python: ["3.11", "3.12", "3.13"]
    steps:
      - uses: actions/checkout@v7

      - uses: actions/setup-python@v7
        with:
          python-version: ${{ matrix.python }}
          cache: pip                    # reuse downloaded packages between runs

      - name: Install
        run: pip install -r requirements-dev.txt

      - name: Test
        run: |
          mkdir -p reports
          pytest -v --junitxml=reports/junit-${{ matrix.python }}.xml

      - name: Upload test report
        if: always()                    # upload even when tests fail
        uses: actions/upload-artifact@v7
        with:
          name: test-report-${{ matrix.python }}
          path: reports/
```

Push it, then open a pull request that breaks a test (for example, change the expected message in `test_app.py`). The PR page shows the failing check. Fix it and push again, and the check turns green.

> **Tip:** Make the check **required**: **Settings → Branches → Add branch ruleset** (or *branch protection rule*) for `main` → **Require status checks to pass** → pick the `test` jobs. Now nobody can merge a red PR.

What's new:

| Feature | What it does |
|---|---|
| `strategy.matrix` | Runs the job once per value: 3 Python versions in parallel |
| `cache: pip` | Speeds up runs by reusing downloaded packages |
| `if: always()` | Run this step even if an earlier step failed |
| `upload-artifact` | Saves files; download them from the run's **Summary** page |
| `permissions` | Limits what the automatic `GITHUB_TOKEN` can do |

## Triggers, conditions and job order

> **In simple words:** Control **when** a workflow runs (which branches, files or times) and **in what order** jobs run.

```yaml
on:
  push:
    branches: [main, "release/**"]
    paths: ["**.py", "requirements*.txt", "Dockerfile"]   # skip runs for README-only changes
  pull_request:
    branches: [main]
  schedule:
    - cron: "0 3 * * 1"          # every Monday 03:00 UTC
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [staging, production]
        default: staging

concurrency:                       # a new push cancels the older, still-running run
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo "testing"

  build:
    needs: test                   # wait for test to pass
    runs-on: ubuntu-latest
    steps:
      - run: echo "building"

  deploy:
    needs: build
    if: github.ref == 'refs/heads/main' && github.event_name != 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - run: echo "deploying to ${{ inputs.environment || 'staging' }}"
```

## Secrets, variables and environments

> **In simple words:** Keep passwords in GitHub's locked safe (**secrets**), plain settings in **variables**, and use **environments** to add rules such as "a person must approve before production".

| Type | Where to set it | Use in YAML | Shown in logs? |
|---|---|---|---|
| **Secret** | Repo → **Settings → Secrets and variables → Actions → Secrets** | `${{ secrets.NAME }}` | No, masked as `***` |
| **Variable** | Same page → **Variables** | `${{ vars.NAME }}` | Yes |
| **Environment** | Repo → **Settings → Environments** | `environment: production` on a job | n/a |

Create an environment named `production`, tick **Required reviewers** and add yourself. Then:

```yaml
jobs:
  deploy-prod:
    runs-on: ubuntu-latest
    environment: production        # pauses until a reviewer approves
    steps:
      - run: ./deploy.sh            # the script reads $MY_KEY; never echo secrets
        env:
          MY_KEY: ${{ secrets.PROD_API_KEY }}    # environment-level secret
```

The run pauses with **Review deployments**. Approve it, and the job continues.

> **Warning:** Secrets are **not** passed to workflows triggered by pull requests from **forks**, for safety. Never use `pull_request_target` together with checking out the PR's code unless you fully understand the risk: it lets untrusted code run with your secrets.

## Build and push the Docker image (GHCR)

> **In simple words:** After the tests pass, build the app's Docker image and publish it to **GitHub Container Registry** (`ghcr.io`), which is free and needs no extra account.

Add a second job to `ci.yml`:

```yaml
  image:
    needs: test
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write              # allow pushing to ghcr.io
    steps:
      - uses: actions/checkout@v7

      - uses: docker/setup-buildx-action@v4

      - uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}     # automatic, no setup needed

      - id: meta
        uses: docker/metadata-action@v6
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=sha,format=short
            type=raw,value=latest,enable={{is_default_branch}}

      - uses: docker/build-push-action@v7
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          build-args: APP_VERSION=${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

After a push to `main`, the image appears under your repo's **Packages**, tagged like `sha-1a2b3c4`. Pull it anywhere:

```bash
docker pull ghcr.io/<you>/hello-app:sha-1a2b3c4
```

> **Tip:** New packages are **private**. To let a cluster pull without credentials, open the package → **Package settings → Change visibility → Public**.

## Deploy to AWS without keys (OIDC)

> **In simple words:** Instead of saving AWS access keys in GitHub, let GitHub prove its identity to AWS and receive **short-lived** credentials for each run. Nothing to leak, and nothing to rotate.

One-time setup in AWS (console: **IAM → Identity providers → Add provider**):
1. **OpenID Connect**, provider URL `https://token.actions.githubusercontent.com`, audience `sts.amazonaws.com`.
2. **IAM → Roles → Create role → Web identity**, pick that provider, audience `sts.amazonaws.com`, **GitHub organization** `<you>`, **repository** `hello-app`, **branch** `main`.
3. Attach permissions, for example `AmazonEC2ContainerRegistryPowerUser`, and name the role `gha-hello-app`.

The role's trust policy will contain a condition like this. It's what stops other repos using your role:

```json
"Condition": {
  "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
  "StringLike":   { "token.actions.githubusercontent.com:sub": "repo:<you>/hello-app:ref:refs/heads/main" }
}
```

Then in a workflow:

```yaml
  push-ecr:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions:
      id-token: write              # REQUIRED for OIDC
      contents: read
    steps:
      - uses: actions/checkout@v7
      - uses: aws-actions/configure-aws-credentials@v6
        with:
          role-to-assume: arn:aws:iam::<ACCOUNT_ID>:role/gha-hello-app
          aws-region: us-east-1
      - id: ecr
        uses: aws-actions/amazon-ecr-login@v2
      - run: |
          IMAGE=${{ steps.ecr.outputs.registry }}/hello-app:${GITHUB_SHA::7}
          docker build -t $IMAGE .
          docker push $IMAGE
      - run: aws sts get-caller-identity     # proves which role the run is using
```

The Terraform version of this setup is in the Capstone project.

## Hand over to Argo CD (GitOps)

> **In simple words:** The CI workflow doesn't touch the cluster. It just writes the new image tag into your GitOps repo, and Argo CD notices and deploys it.

Add a final job that updates a Kustomize file in a separate `gitops` repo. Create a **fine-grained personal access token** with **Contents: Read and write** on the `gitops` repo only, and save it as the secret `GITOPS_TOKEN`.

```yaml
  bump-gitops:
    needs: image
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
        with:
          repository: <you>/gitops
          token: ${{ secrets.GITOPS_TOKEN }}
      - name: Set new image tag
        run: |
          cd apps/hello/overlays/dev
          kustomize edit set image hello-app=ghcr.io/${{ github.repository }}:sha-${GITHUB_SHA::7}
          git config user.name  "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git commit -am "hello-app: deploy sha-${GITHUB_SHA::7}" && git push
```

The `gitops` repo layout and the Argo CD side are in the Argo CD guide's **Sample application flow** step. (`kustomize` is preinstalled on GitHub's Ubuntu runners.)

## Reuse: composite actions and reusable workflows

> **In simple words:** Don't copy the same steps into every repo. Package them once and call them from anywhere.

**Reusable workflow**: a whole workflow other workflows can call. In `.github/workflows/python-ci.yml`:

```yaml
on:
  workflow_call:
    inputs:
      python-version:
        type: string
        default: "3.12"

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-python@v7
        with:
          python-version: ${{ inputs.python-version }}
          cache: pip
      - run: pip install -r requirements-dev.txt && pytest -v
```

Call it from any repo:

```yaml
jobs:
  ci:
    uses: <you>/hello-app/.github/workflows/python-ci.yml@main
    with:
      python-version: "3.13"
```

A **composite action** (`action.yml` with `runs: using: composite`) packages a few *steps* instead of whole jobs. Use it for small shared snippets, such as "log in and set up our tools".

## Runners

> **In simple words:** GitHub lends you a fresh computer for every job. You can also connect your own machine when you need special hardware, private network access, or more minutes.

| | GitHub-hosted | Self-hosted |
|---|---|---|
| Setup | None: `runs-on: ubuntu-latest` | Install the runner app on your machine |
| Clean? | Brand-new VM every job | Reused; you must clean up |
| Cost | Free minutes for public repos; a monthly quota for private ones | Your own hardware |
| Reaches private networks? | No | Yes |

Add a self-hosted runner: repo → **Settings → Actions → Runners → New self-hosted runner**, then copy the commands GitHub shows (download, `./config.sh --url … --token …`, `./run.sh`). Target it with `runs-on: self-hosted`.

> **Warning:** Never attach self-hosted runners to **public** repos. Anyone could open a pull request that runs code on your machine.

## Security best practices

> **In simple words:** A workflow can read your code and use your secrets, so treat workflow files like production code.

- Set `permissions:` at the top of every workflow, starting from `contents: read`, and add only what each job needs.
- Prefer **OIDC** over long-lived cloud keys.
- **Pin third-party actions** to a full commit SHA (`uses: owner/action@<40-char-sha>`), not a moving tag. Let **Dependabot** propose updates: add `.github/dependabot.yml` with `package-ecosystem: github-actions`.
- Use **environments with required reviewers** for production.
- Never `echo` secrets, and don't build commands from untrusted input such as PR titles: `run: echo "${{ github.event.pull_request.title }}"` can be abused. Pass the value through `env:` instead.

## Troubleshooting

> **In simple words:** Open the failed run, expand the red step, and read the first error. Most problems are YAML indentation, permissions or a wrong path.

> **Tip:** More real-world failures (controller down, local-vs-CI builds, dev-vs-prod differences, ECR push errors) are covered in [CI/CD Troubleshooting](#/tool/cicd-troubleshooting).

| Problem | Fix |
|---|---|
| Workflow doesn't appear | The file must be in `.github/workflows/` on the default branch, ending in `.yml` or `.yaml` |
| `Invalid workflow file` | YAML indentation: use spaces, not tabs. Validate with the editor's YAML extension |
| `Resource not accessible by integration` | The `GITHUB_TOKEN` lacks a permission. Add it under `permissions:` |
| `denied: permission_denied` pushing to ghcr.io | Add `packages: write`; the image name must match `ghcr.io/<owner>/<repo>` |
| OIDC: `Not authorized to perform sts:AssumeRoleWithWebIdentity` | Missing `id-token: write`, or the trust policy's `sub` doesn't match the repo or branch |
| Secret is empty | Wrong name, set in a different environment, or the run came from a fork |
| Job skipped | Its `if:` was false, or a job it `needs` failed |
| Want to debug interactively | Re-run with **Enable debug logging**, or test locally with [`act`](https://github.com/nektos/act) |

## Lab: complete GitHub Actions pipeline

> **In simple words:** Practice time: build the full pipeline for the sample app on your own.

1. Add `ci.yml` with a **matrix** test job on 3 Python versions and a test-report artifact.
2. Protect `main` so a PR can't merge unless tests pass, then prove it with a breaking PR.
3. Add an `image` job that pushes `ghcr.io/<you>/hello-app:sha-<short>` only from `main`.
4. Add a `workflow_dispatch` input `environment` and a `deploy` job that uses the matching GitHub **environment**, with a required reviewer for `production`.
5. Set up AWS **OIDC** and push the same image to ECR with no stored AWS keys.
6. Bonus: add the `bump-gitops` job and complete the Argo CD **Sample application flow**.

### Cheat sheet

| Task | YAML |
|---|---|
| Run on push to main | `on: { push: { branches: [main] } }` |
| Manual button | `on: workflow_dispatch` |
| Job order | `needs: test` |
| Condition | `if: github.ref == 'refs/heads/main'` |
| Use a secret | `${{ secrets.NAME }}` |
| Parallel versions | `strategy: { matrix: { python: ["3.12","3.13"] } }` |
| Allow OIDC | `permissions: { id-token: write }` |
