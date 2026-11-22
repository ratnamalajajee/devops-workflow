# Jenkins

Jenkins is the original open-source automation server and still the most widely used CI/CD tool in large companies. You install it yourself, describe pipelines in a `Jenkinsfile`, and extend it with plugins. This guide starts from nothing: install Jenkins, unlock it, then build up from a one-line job to a full pipeline that tests, builds and ships the sample app.

> **Note:** You need Docker (see Workstation Setup) and the **sample app** from [CI/CD Basics](#/tool/cicd-basics) pushed to a GitHub repo. No Docker on your laptop? Use the cloud lab machine in the [Practice lab](#/lab). Codespaces forwards port 8080 for you.

## Start here: Jenkins in simple words

> **In simple words:** Jenkins is a **robot butler** that sits on a server and waits for instructions. When code changes, or when you press a button, it follows a written list of steps: get the code, test it, build it, ship it. Then it reports back whether everything worked.

### Watch how it works

```svg Watch it work: a webhook starting a build on the controller, the queue handing it to an agent, the Jenkinsfile stages running with a stored credential, the results coming back, and a multibranch scan building a new branch. The animation loops.
<svg viewBox="0 0 600 404" role="img" data-anim="jenkins" aria-label="Animated Jenkins flow. A push to main: GitHub calls the Jenkins webhook URL, and the multibranch job hello-app-mb starts build number 42 for the main branch. The controller only schedules: the build waits in the build queue until an executor on the agent docker-agent-1 is free, and is then handed to that agent. The agent clones hello-app from GitHub into its workspace and runs the Jenkinsfile stages: Test inside a python:3.12-slim container, Build image, and a Smoke test on /health. For the Push stage, withCredentials hands the stored dockerhub token to the step, the console log shows it as four stars, and the image is pushed to Docker Hub. The test results and archived files go back to the controller and are kept on the build 42 page, where you see the result. A new branch: the multibranch job scans the repository, finds the branch feature/new-message with a Jenkinsfile, and adds a job for it. That build goes through the same queue to a free executor, with its own workspace and history. Because the Push stage says when branch main, it is skipped on the branch, so only main publishes images.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<rect x="124" y="20" width="284" height="286" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="5 4"/>
<rect x="424" y="20" width="168" height="218" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="5 4"/>
<polyline points="60,52 60,10 508,10 508,52" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="60,77 198,77" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="60,102 60,141 198,141" fill="none" stroke-linejoin="round" stroke="#0ea5e9" stroke-width="1.8" stroke-dasharray="2 3" stroke-opacity=".75"/>
<polyline points="198,77 438,77" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="198,141 270,141 270,77" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="336,205 438,205" fill="none" stroke-linejoin="round" stroke="#eab308" stroke-width="1.8" stroke-dasharray="3 3" stroke-opacity=".75"/>
<polyline points="452,224 452,269 198,269" fill="none" stroke-linejoin="round" stroke="#0d9488" stroke-width="1.8" stroke-dasharray="6 3" stroke-opacity=".7"/>
<polyline points="198,269 60,269" fill="none" stroke-linejoin="round" stroke="#db2777" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="538,224 538,258" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<rect x="130" y="26" width="214.5" height="16" rx="5" class="dg-box"/><text x="134" y="36" font-size="11" class="dg-muted">Jenkins controller · brain + web UI</text>
<rect x="430" y="26" width="120.1" height="16" rx="5" class="dg-box"/><text x="434" y="36" font-size="11" class="dg-muted">Agent · 2 executors</text>
<g><rect x="8" y="48" width="104" height="58" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1;0;1;0" keyTimes="0;0.1048;0.2177;0.3226;0.6613;0.7742" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/></rect><rect x="12" y="52" width="96" height="50" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="60" y="73.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">GitHub</text><text x="60" y="89" text-anchor="middle" font-size="11" class="dg-muted">hello-app</text></g>
<g><rect x="8" y="240" width="104" height="58" rx="12" fill="#db2777" fill-opacity=".18" stroke="#db2777" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5484;0.6613" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/></rect><rect x="12" y="244" width="96" height="50" rx="9" class="dg-box" stroke="#db2777" stroke-width="2.2"/><text x="60" y="265.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">You</text><text x="60" y="281" text-anchor="middle" font-size="11" class="dg-muted">see the result</text></g>
<g><rect x="130" y="48" width="136" height="58" rx="12" fill="#6366f1" fill-opacity=".18" stroke="#6366f1" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.2177" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/></rect><rect x="134" y="52" width="128" height="50" rx="9" class="dg-box" stroke="#6366f1" stroke-width="2.2"/><text x="198" y="73.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">hello-app-mb</text><text x="198" y="89" text-anchor="middle" font-size="11" class="dg-muted">branch main · #42</text></g>
<rect x="134" y="116" width="128" height="50" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.6613" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><rect x="130" y="112" width="136" height="58" rx="12" fill="#0d9488" fill-opacity=".18" stroke="#0d9488" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6613;0.8871" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/></rect><rect x="134" y="116" width="128" height="50" rx="9" class="dg-box" stroke="#0d9488" stroke-width="2.2"/><text x="198" y="137.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">hello-app-mb</text><text x="198" y="153" text-anchor="middle" font-size="11" class="dg-muted">feature/new-message</text></g>
<g><rect x="274" y="48" width="124" height="58" rx="12" fill="#0ea5e9" fill-opacity=".18" stroke="#0ea5e9" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.1048;0.2177;0.7742;0.8871" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/></rect><rect x="278" y="52" width="116" height="50" rx="9" class="dg-box" stroke="#0ea5e9" stroke-width="2.2"/><text x="336" y="73.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Build queue</text><text x="336" y="89" text-anchor="middle" font-size="11" class="dg-muted">waits for a slot</text></g>
<g><rect x="274" y="176" width="124" height="58" rx="12" fill="#ca8a04" fill-opacity=".18" stroke="#ca8a04" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4355;0.5484" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/></rect><rect x="278" y="180" width="116" height="50" rx="9" class="dg-box" stroke="#ca8a04" stroke-width="2.2"/><text x="336" y="201.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Credentials</text><text x="336" y="217" text-anchor="middle" font-size="11" class="dg-muted">dockerhub ****</text></g>
<g><rect x="130" y="240" width="136" height="58" rx="12" fill="#059669" fill-opacity=".18" stroke="#059669" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5484;0.6613" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/></rect><rect x="134" y="244" width="128" height="50" rx="9" class="dg-box" stroke="#059669" stroke-width="2.2"/><text x="198" y="265.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Build #42 page</text><text x="198" y="281" text-anchor="middle" font-size="11" class="dg-muted">tests + artifacts</text></g>
<g><rect x="434" y="48" width="148" height="180" rx="12" fill="#f59e0b" fill-opacity=".18" stroke="#f59e0b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.1048;0.6613;0.7742" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/></rect><rect x="438" y="52" width="140" height="172" rx="9" class="dg-box" stroke="#f59e0b" stroke-width="2.2"/><text x="508" y="97" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">docker-agent-1</text><text x="508" y="112.5" text-anchor="middle" font-size="11" class="dg-muted">labels: linux docker</text><text x="508" y="127.5" text-anchor="middle" font-size="11" class="dg-muted">Checkout</text><text x="508" y="142.5" text-anchor="middle" font-size="11" class="dg-muted">Test</text><text x="508" y="157.5" text-anchor="middle" font-size="11" class="dg-muted">Build image</text><text x="508" y="172.5" text-anchor="middle" font-size="11" class="dg-muted">Smoke test</text><text x="508" y="187.5" text-anchor="middle" font-size="11" class="dg-muted">Push</text></g>
<g><rect x="480" y="254" width="116" height="58" rx="12" fill="#2563eb" fill-opacity=".18" stroke="#2563eb" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4355;0.5484" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/></rect><rect x="484" y="258" width="108" height="50" rx="9" class="dg-box" stroke="#2563eb" stroke-width="2.2"/><text x="538" y="279.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Docker Hub</text><text x="538" y="295" text-anchor="middle" font-size="11" class="dg-muted">you/hello-app:42</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3226;0.4355" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="578" cy="52" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M573.5,52 L577,55.5 L582.5,48.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4355;0.5484" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="592" cy="258" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M587.5,258 L591,261.5 L596.5,254.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5484;0.6613" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="262" cy="244" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M257.5,244 L261,247.5 L266.5,240.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8871" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="538" cy="241" r="9.5" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M534,237 L542,245 M542,237 L534,245" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0063;0.0902" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M60,77 L198,77" keyPoints="0;0;1;1" keyTimes="0;0.0063;0.0902;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1116;0.2065" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M198,77 L438,77" keyPoints="0;0;1;1" keyTimes="0;0.1116;0.2065;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.224;0.3079" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M60,52 L60,10 L508,10 L508,52" keyPoints="0;0;1;1" keyTimes="0;0.224;0.3079;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4411;0.4829" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M336,205 L438,205" keyPoints="0;0;1;1" keyTimes="0;0.4411;0.4829;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4919;0.5371" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M538,224 L538,258" keyPoints="0;0;1;1" keyTimes="0;0.4919;0.5371;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.554;0.6161" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M452,224 L452,269 L198,269" keyPoints="0;0;1;1" keyTimes="0;0.554;0.6161;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6206;0.6545" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M198,269 L60,269" keyPoints="0;0;1;1" keyTimes="0;0.6206;0.6545;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><g><rect x="-9" y="-6" width="18" height="12" rx="2" fill="#db2777" stroke="#fff" stroke-width="1.6"/><path d="M-8,-5 L0,1 L8,-5" fill="none" stroke="#fff" stroke-width="1.4"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6681;0.7584" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M60,102 L60,141 L198,141" keyPoints="0;0;1;1" keyTimes="0;0.6681;0.7584;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.781;0.8713" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M198,141 L270,141 L270,77 L438,77" keyPoints="0;0;1;1" keyTimes="0;0.781;0.8713;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(20.4,328.5) scale(.8)"><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g><text x="31.8" y="332">webhook</text><g transform="translate(93.4,328.5) scale(.8)"><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g><text x="104.8" y="332">build</text><g transform="translate(156,328.5) scale(.8)"><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g><text x="168.2" y="332">code / image</text><g transform="translate(258.6,328.5) scale(.8)"><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g><text x="271.6" y="332">credential</text><g transform="translate(350,328.5) scale(.8)"><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g><text x="361.4" y="332">results</text><g transform="translate(423,328.5) scale(.8)"><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g><text x="434.4" y="332">branch scan</text></g>
<rect x="12" y="344" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="344" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="24.8s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1048" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="36" cy="372" r="14" fill="#6366f1"/><text x="36" y="377" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="367" font-size="14" font-weight="800" fill="#6366f1">A push fires the webhook</text><text x="578" y="367" text-anchor="end" font-size="10.5" class="dg-muted">A push to main · 1/9</text><text x="60" y="388" font-size="12.5" class="dg-text">GitHub calls https://&lt;jenkins&gt;/github-webhook/. Build #42 starts.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1048;0.2177" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="36" cy="372" r="14" fill="#6366f1"/><text x="36" y="377" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="367" font-size="14" font-weight="800" fill="#6366f1">Queued, then sent to an agent</text><text x="578" y="367" text-anchor="end" font-size="10.5" class="dg-muted">A push to main · 2/9</text><text x="60" y="388" font-size="12.5" class="dg-text">#42 waits in the queue until an executor on docker-agent-1 is free.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2177;0.3226" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="36" cy="372" r="14" fill="#6366f1"/><text x="36" y="377" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="367" font-size="14" font-weight="800" fill="#6366f1">The agent checks out the code</text><text x="578" y="367" text-anchor="end" font-size="10.5" class="dg-muted">A push to main · 3/9</text><text x="60" y="388" font-size="12.5" class="dg-text">It clones hello-app into its workspace. Builds run here, not on the controller.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3226;0.4355" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="36" cy="372" r="14" fill="#6366f1"/><text x="36" y="377" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="367" font-size="14" font-weight="800" fill="#6366f1">The Jenkinsfile stages run</text><text x="578" y="367" text-anchor="end" font-size="10.5" class="dg-muted">A push to main · 4/9</text><text x="60" y="388" font-size="12.5" class="dg-text">Test inside python:3.12-slim, then Build image and a Smoke test on /health.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4355;0.5484" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="36" cy="372" r="14" fill="#6366f1"/><text x="36" y="377" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="367" font-size="14" font-weight="800" fill="#6366f1">Push with a stored credential</text><text x="578" y="367" text-anchor="end" font-size="10.5" class="dg-muted">A push to main · 5/9</text><text x="60" y="388" font-size="12.5" class="dg-text">withCredentials hands the step the dockerhub token. The log shows ****.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5484;0.6613" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="36" cy="372" r="14" fill="#6366f1"/><text x="36" y="377" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="367" font-size="14" font-weight="800" fill="#6366f1">Results come back to you</text><text x="578" y="367" text-anchor="end" font-size="10.5" class="dg-muted">A push to main · 6/9</text><text x="60" y="388" font-size="12.5" class="dg-text">Test results and archived files are kept on build #42&#x27;s page. It&#x27;s green.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6613;0.7742" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="36" cy="372" r="14" fill="#0d9488"/><text x="36" y="377" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="367" font-size="14" font-weight="800" fill="#0d9488">A scan finds a new branch</text><text x="578" y="367" text-anchor="end" font-size="10.5" class="dg-muted">A new branch · 7/9</text><text x="60" y="388" font-size="12.5" class="dg-text">feature/new-message has a Jenkinsfile, so the multibranch job adds it.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7742;0.8871" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="36" cy="372" r="14" fill="#0d9488"/><text x="36" y="377" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="367" font-size="14" font-weight="800" fill="#0d9488">The branch builds on its own</text><text x="578" y="367" text-anchor="end" font-size="10.5" class="dg-muted">A new branch · 8/9</text><text x="60" y="388" font-size="12.5" class="dg-text">The second executor runs it, with its own workspace and build history.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8871" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="36" cy="372" r="14" fill="#0d9488"/><text x="36" y="377" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">9</text><text x="60" y="367" font-size="14" font-weight="800" fill="#0d9488">Only main pushes images</text><text x="578" y="367" text-anchor="end" font-size="10.5" class="dg-muted">A new branch · 9/9</text><text x="60" y="388" font-size="12.5" class="dg-text">when { branch &#x27;main&#x27; } skips the Push stage on every other branch.</text></g>
</svg>
```

### How Jenkins is organised

```text
                ┌────────────── Jenkins controller (the "brain" + web UI) ──────────────┐
 Git push ────▶ │  Jobs / Pipelines   Credentials   Plugins   Build history & logs      │
 or "Build now" └──────────────┬──────────────────────────────────────────────────────────┘
                               │ hands work to
              ┌────────────────┼────────────────┐
           Agent 1          Agent 2          (built-in node)     ◀ machines that run the steps
          [executor]       [executor]         [executor]         ◀ one executor = one build at a time
```

### Key words

| Word | Simple meaning |
|---|---|
| **Controller** | The main Jenkins server: web UI, settings and scheduling |
| **Agent (node)** | A machine that runs builds for the controller |
| **Executor** | A "slot" on an agent; 2 executors means 2 builds at once |
| **Job / Item / Project** | Something Jenkins can run, such as a pipeline |
| **Freestyle job** | An old-style job configured by clicking. Fine for tiny tasks |
| **Pipeline** | A job defined as code in a `Jenkinsfile`, the modern way |
| **Multibranch pipeline** | Finds every branch with a `Jenkinsfile` and builds each one |
| **Build** | One run of a job, numbered #1, #2, #3… |
| **Workspace** | The folder where a build checks out code and works |
| **Plugin** | An add-on that teaches Jenkins new skills (Git, Docker, Slack…) |
| **Credentials** | Passwords and tokens stored safely inside Jenkins |

### Check yourself

1. What's the difference between the controller and an agent?
2. Why is a Pipeline better than a Freestyle job?
3. What is a workspace?

> **Tip:** Answers: 1) The controller is the brain and UI; agents are the machines that run builds. 2) It's written as code in the repo, so it can be reviewed, versioned and reused. 3) The folder where a build checks out the code and works on it.

## Install Jenkins with Docker

> **In simple words:** Run Jenkins itself as a container. It's the quickest clean install, and deleting the container leaves your laptop untouched.

We'll build a small custom image: the official Jenkins LTS image plus the **Docker CLI** (so pipelines can build images) and a few plugins.

```bash
mkdir -p ~/code/jenkins && cd ~/code/jenkins
```

`Dockerfile`:

```dockerfile
FROM jenkins/jenkins:2.580.2-lts-jdk21

USER root
# Install the Docker CLI so pipelines can run "docker build"
RUN apt-get update && apt-get install -y ca-certificates curl && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
      > /etc/apt/sources.list.d/docker.list && \
    apt-get update && apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*
USER jenkins

# Pre-install the plugins used in this guide
RUN jenkins-plugin-cli --plugins \
    git workflow-aggregator docker-workflow pipeline-stage-view \
    credentials-binding github junit ws-cleanup
```

Build and run it:

```bash
docker build -t my-jenkins:lts .

docker run -d --name jenkins --restart=on-failure \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add "$(stat -c '%g' /var/run/docker.sock)" \
  my-jenkins:lts

docker logs -f jenkins      # wait for "Jenkins is fully up and running", then Ctrl+C
```

What each part does:

| Option | Why |
|---|---|
| `-p 8080:8080` | The web UI at http://localhost:8080 |
| `-p 50000:50000` | Port that remote agents use to connect |
| `-v jenkins_home:/var/jenkins_home` | **All Jenkins data** (jobs, plugins, settings) lives in this volume and survives container restarts |
| `-v /var/run/docker.sock:…` | Lets Jenkins use your machine's Docker to build images |
| `--group-add …` | Gives the `jenkins` user permission to use that Docker socket |

> **Warning:** Mounting the Docker socket gives Jenkins full control of Docker on that machine. That's fine on a learning laptop, but not for a shared production server. The official docs show a more isolated "Docker-in-Docker" setup, and real teams usually run builds on separate **agents**.

Official docs: [Installing Jenkins with Docker](https://www.jenkins.io/doc/book/installing/docker/)

## Or: install Jenkins on an Ubuntu server

> **In simple words:** The "classic" install, straight onto a Linux server (for example the EC2 instance from the AWS lab), running as a normal system service.

Jenkins needs **Java 21**. Install Java first, then Jenkins from the official LTS repository:

```bash
sudo apt update
sudo apt install -y fontconfig openjdk-21-jre
java -version

sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update
sudo apt install -y jenkins

sudo systemctl enable --now jenkins
sudo systemctl status jenkins
```

Jenkins listens on port **8080**. On EC2, open port 8080 in the security group **to your IP only**.

> **Note:** The repository signing key changes from time to time (the current one is `jenkins.io-2026.key`). If `apt update` complains about a `NO_PUBKEY` error, re-download the key from the [official Linux install page](https://www.jenkins.io/doc/book/installing/linux/).

To let pipelines build Docker images on this server, install Docker and add the `jenkins` user to the `docker` group:

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

## Unlock Jenkins and first-time setup

> **In simple words:** The first time you open Jenkins, it asks for a one-time password to prove you're the owner, then helps you create your admin login.

1. Open **http://localhost:8080** (or `http://<server-ip>:8080`).
2. Get the one-time password:

```bash
# Docker install
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
# Ubuntu install
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

3. Paste it, then choose **Install suggested plugins** and wait a few minutes.
4. **Create First Admin User** with your own username and a strong password.
5. **Instance Configuration:** keep `http://localhost:8080/`, then **Save and Finish → Start using Jenkins**.

You're now on the **Dashboard**. Take a minute to find:

| Where | What it's for |
|---|---|
| **+ New Item** | Create jobs and pipelines |
| **Manage Jenkins → Plugins** | Install and update plugins |
| **Manage Jenkins → Credentials** | Store passwords and tokens |
| **Manage Jenkins → Nodes** | See the built-in node and add agents |
| **Build Queue / Build Executor Status** (left side) | What's waiting and what's running |

## Example 1: a Freestyle job

> **In simple words:** The simplest possible job: click a few boxes, and Jenkins runs a shell command when you press "Build Now".

1. **+ New Item** → name `hello-freestyle` → **Freestyle project** → **OK**.
2. Tick **This project is parameterized → Add Parameter → String Parameter**: name `NAME`, default `World`.
3. **Build Steps → Add build step → Execute shell**:

```bash
echo "Hello, $NAME!"
echo "Build number: $BUILD_NUMBER  Job: $JOB_NAME"
echo "Running on: $(hostname) as $(whoami)"
date
```

4. **Save → Build with Parameters → Build**.
5. Click the build **#1** → **Console Output** to see the log.

Jenkins gives every build useful **environment variables** like `BUILD_NUMBER`, `JOB_NAME`, `WORKSPACE` and `BUILD_URL`. The full list is at `http://localhost:8080/env-vars.html`.

> **Why:** Freestyle jobs are fine for tiny chores, but their settings live only in the Jenkins UI: not in Git, not reviewable, easy to lose. For anything real, use a **Pipeline**.

## Example 2: your first Pipeline

> **In simple words:** The same idea, but the steps are written as code. Each **stage** shows up as a coloured box, so you can see exactly where a build failed.

**+ New Item** → name `hello-pipeline` → **Pipeline** → **OK**. Scroll to **Pipeline → Definition: Pipeline script**, paste this, then **Save → Build Now**:

```groovy
pipeline {
    agent any                       // run on any available executor

    parameters {
        string(name: 'NAME', defaultValue: 'World', description: 'Who to greet')
        booleanParam(name: 'FAIL', defaultValue: false, description: 'Make the build fail on purpose')
    }

    environment {
        GREETING = "Hello, ${params.NAME}"
    }

    stages {
        stage('Greet') {
            steps {
                echo "${env.GREETING}"
                sh 'echo "Build #$BUILD_NUMBER in $WORKSPACE"'
            }
        }
        stage('Work') {
            steps {
                sh '''
                    mkdir -p out
                    date > out/built-at.txt
                    ls -l out
                '''
            }
        }
        stage('Maybe fail') {
            when { expression { params.FAIL } }
            steps {
                error 'Failing because FAIL=true'
            }
        }
    }

    post {
        success { echo 'Pipeline succeeded' }
        failure { echo 'Pipeline failed: check the stage in red' }
        always  { archiveArtifacts artifacts: 'out/*.txt', allowEmptyArchive: true }
    }
}
```

The first run picks up the parameters; from the second run, use **Build with Parameters**. Try once with `FAIL` ticked.

How the parts fit:

| Block | Meaning |
|---|---|
| `pipeline { }` | Everything lives inside this (**declarative** syntax) |
| `agent` | Where to run: `any`, a `label`, or a Docker image |
| `parameters` | Inputs you fill in when starting a build |
| `environment` | Variables for all stages |
| `stages` / `stage` / `steps` | The assembly line: named stations, each with commands |
| `when` | Only run this stage if a condition is true |
| `post` | Runs after the stages: `always`, `success`, `failure`, `unstable` |

> **Tip:** Click **Pipeline Syntax** (left menu of any pipeline job) for the **Snippet Generator**. Pick a step from a list, fill in a form, and it writes the Groovy for you.

## Example 3: pipeline from Git (Jenkinsfile) for the sample app

> **In simple words:** Put the pipeline file **inside the app's repository**, so the instructions for building the app travel with the app itself.

In your `hello-app` repo, add a file named `Jenkinsfile`:

```groovy
pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timeout(time: 20, unit: 'MINUTES')
    }

    environment {
        IMAGE = 'hello-app'
        TAG   = "${env.BUILD_NUMBER}"
    }

    stages {
        stage('Test') {
            // Run tests inside a throwaway Python container
            agent {
                docker {
                    image 'python:3.12-slim'
                    reuseNode true
                }
            }
            steps {
                sh '''
                    python -m venv .venv
                    . .venv/bin/activate
                    pip install --no-cache-dir -r requirements-dev.txt
                    mkdir -p reports
                    pytest -v --junitxml=reports/junit.xml
                '''
            }
            post {
                always { junit 'reports/junit.xml' }
            }
        }

        stage('Build image') {
            steps {
                sh 'docker build --build-arg APP_VERSION=$TAG -t $IMAGE:$TAG .'
            }
        }

        stage('Smoke test') {
            steps {
                sh '''
                    docker run -d --name smoke-$BUILD_NUMBER $IMAGE:$TAG
                    docker run --rm --network container:smoke-$BUILD_NUMBER curlimages/curl:8.10.1 \
                      -sf --retry 10 --retry-connrefused --retry-delay 1 http://localhost:8000/health
                '''
            }
            post {
                always { sh 'docker rm -f smoke-$BUILD_NUMBER || true' }
            }
        }
    }

    post {
        always { cleanWs() }
    }
}
```

Commit and push it, then create the job:

1. **+ New Item** → `hello-app` → **Pipeline** → **OK**.
2. **Pipeline → Definition: Pipeline script from SCM → SCM: Git**.
3. **Repository URL:** `https://github.com/<you>/hello-app.git`, **Branch:** `*/main`, **Script Path:** `Jenkinsfile`.
4. **Save → Build Now**.

Watch the **Stage View**. After the run, click **Test Result** on the build page to see each test.

What's new here:

- **`agent { docker { … } }`** runs the Test stage *inside* a `python:3.12-slim` container, so the Jenkins server needs no Python at all. That needs the **Docker Pipeline** plugin.
- **`junit`** reads the test report so Jenkins can show passed and failed tests and their trends.
- **Smoke test** starts the freshly built image and checks `/health` actually answers. If it doesn't, the build fails.
- **`cleanWs()`** empties the workspace afterwards.

## Example 4: credentials and pushing to a registry

> **In simple words:** Store your Docker Hub password inside Jenkins (never in the Jenkinsfile), then let the pipeline log in and upload the image.

1. On Docker Hub: **Account settings → Personal access tokens → Generate** (Read & Write).
2. In Jenkins: **Manage Jenkins → Credentials → System → Global credentials → Add Credentials**:
   - **Kind:** Username with password
   - **Username:** your Docker Hub username, **Password:** the token
   - **ID:** `dockerhub`
3. Add this stage to the `Jenkinsfile`, after **Smoke test**:

```groovy
        stage('Push') {
            when { branch 'main' }       // only publish from main (multibranch jobs)
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub',
                                                  usernameVariable: 'DH_USER',
                                                  passwordVariable: 'DH_TOKEN')]) {
                    sh '''
                        echo "$DH_TOKEN" | docker login -u "$DH_USER" --password-stdin
                        docker tag $IMAGE:$TAG $DH_USER/$IMAGE:$TAG
                        docker push $DH_USER/$IMAGE:$TAG
                        docker logout
                    '''
                }
            }
        }
```

Jenkins **masks** credential values in the console log: they show as `****`.

> **Note:** `when { branch 'main' }` only works in **Multibranch** pipelines (next step). In a plain Pipeline job, remove the `when` line.

> **Warning:** Use single quotes `'''` around `sh` blocks that use secrets, so the shell reads them from the environment. With double quotes `"""`, Groovy pastes the secret into the command text, and Jenkins warns about it.

## Example 5: multibranch pipelines and webhooks

> **In simple words:** Instead of one job per branch, a Multibranch Pipeline finds every branch (and pull request) that has a `Jenkinsfile` and builds each one automatically.

1. **+ New Item** → `hello-app-mb` → **Multibranch Pipeline** → **OK**.
2. **Branch Sources → Add source → GitHub**. For a public repo you can leave credentials empty; for a private one, add a GitHub **personal access token** as a credential.
3. **Repository HTTPS URL:** `https://github.com/<you>/hello-app.git`.
4. **Scan Multibranch Pipeline Triggers:** tick **Periodically if not otherwise run**, interval **1 minute** (useful when Jenkins can't receive webhooks).
5. **Save**. Jenkins scans the repo and creates a job per branch.

Create a branch, push it, and watch a new job appear:

```bash
git checkout -b feature/new-message
sed -i 's/Hello from CI\/CD!/Hello from a branch!/' app.py test_app.py
git commit -am "Change greeting" && git push -u origin feature/new-message
```

**Webhooks (instant builds):** when Jenkins has a public URL, add a webhook in GitHub (**repo → Settings → Webhooks → Add webhook**): Payload URL `https://<jenkins>/github-webhook/`, content type `application/json`, event **Just the push event**. A laptop Jenkins has no public URL, so use the 1-minute scan instead.

## Example 6: parallel stages and manual approval

> **In simple words:** Run independent checks at the same time to save minutes, and pause before production until a person clicks **Proceed**.

```groovy
pipeline {
    agent any
    stages {
        stage('Checks') {
            parallel {
                stage('Unit tests') { steps { sh 'echo running unit tests; sleep 5' } }
                stage('Lint')       { steps { sh 'echo running linter; sleep 3' } }
                stage('Security')   { steps { sh 'echo scanning dependencies; sleep 4' } }
            }
        }
        stage('Deploy to staging') {
            steps { echo 'Deploying to staging…' }
        }
        stage('Approve production') {
            steps {
                timeout(time: 30, unit: 'MINUTES') {
                    input message: 'Deploy to production?', ok: 'Deploy'
                }
            }
        }
        stage('Deploy to production') {
            steps { echo 'Deploying to production…' }
        }
    }
}
```

The three checks run side by side. When the build reaches **Approve production**, it waits; open the build and click **Deploy** (or **Abort**).

## Agents: running builds on other machines

> **In simple words:** The controller should organise work, not do it. Agents are extra machines that run the builds, so you can add capacity and keep the controller safe.

Add a Docker-based agent:

1. **Manage Jenkins → Nodes → New Node** → name `docker-agent-1` → **Permanent Agent** → **Create**.
2. **Remote root directory:** `/home/jenkins/agent`, **Labels:** `linux docker`, **Launch method:** *Launch agent by connecting it to the controller*. **Save**.
3. Open the new node. Jenkins shows a **secret** and a command. Start the agent as a container on the same Docker network:

```bash
docker network create jenkins-net 2>/dev/null; docker network connect jenkins-net jenkins
docker run -d --name docker-agent-1 --network jenkins-net jenkins/inbound-agent \
  -url http://jenkins:8080 -name docker-agent-1 -secret <SECRET_FROM_UI> -workDir /home/jenkins/agent
```

4. Target it from a pipeline with `agent { label 'linux' }`.

Set **Manage Jenkins → Nodes → Built-In Node → Number of executors** to `0`, so builds never run on the controller itself, which is a security best practice.

## Running Jenkins well

> **In simple words:** Jenkins is a server you own, so you're responsible for updating it, backing it up and locking it down.

| Task | How |
|---|---|
| **Security** | **Manage Jenkins → Security**: no anonymous access; use **Matrix-based security** or SSO; give people the least access they need |
| **Updates** | Update the LTS image or package monthly; **Manage Jenkins → Plugins → Updates**. Old plugins are the #1 security risk |
| **Backups** | Everything is in `JENKINS_HOME` (the `jenkins_home` volume). Back it up regularly, for example `docker run --rm -v jenkins_home:/data -v $PWD:/backup alpine tar czf /backup/jenkins-home.tgz -C /data .` |
| **Config as code** | The **Configuration as Code (JCasC)** plugin defines Jenkins settings in YAML, so a new server can be rebuilt automatically |
| **Reuse** | **Shared Libraries** hold common pipeline steps in one Git repo, used by many Jenkinsfiles |
| **Keep it lean** | Few plugins, builds on agents, old builds discarded (`buildDiscarder`) |

## Troubleshooting

> **In simple words:** When a build fails, open **Console Output** and read from the **first** red error, not the last line.

> **Tip:** More real-world failures (controller down, local-vs-CI builds, dev-vs-prod differences, ECR push errors) are covered in [CI/CD Troubleshooting](#/tool/cicd-troubleshooting).

| Problem | Fix |
|---|---|
| Can't find the initial admin password | `docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword` |
| `permission denied … /var/run/docker.sock` | The `--group-add` group didn't match. Check with `docker exec jenkins id`. For a lab only: `docker exec -u root jenkins chmod 666 /var/run/docker.sock` |
| `docker: not found` in a pipeline | Your Jenkins image has no Docker CLI. Use the custom Dockerfile above |
| `Invalid agent type "docker"` | Install the **Docker Pipeline** plugin (`docker-workflow`) |
| `pip install` permission errors inside the docker agent | Use a virtual env (`python -m venv .venv`) as in Example 3 |
| `No such DSL method …` | The plugin providing that step is missing; check the Snippet Generator |
| Build waits forever: *"Waiting for next available executor"* | No free executor, or no agent with the requested `label` is online |
| `Couldn't find any revision to build` | Wrong branch name (for example `*/master` vs `*/main`) |
| Jenkins slow or crashing | Give the container more memory, delete old builds, remove unused plugins |

Logs of Jenkins itself: `docker logs jenkins`, or `journalctl -u jenkins` on Ubuntu.

## Lab: a full Jenkins pipeline

> **In simple words:** Practice time: build a complete pipeline for the sample app, end to end, without looking back.

> **Tip:** Ready for security scanning? The [Jenkins DevSecOps Pipeline](#/tool/jenkins-devsecops) adds Gitleaks, SonarQube, Trivy and OWASP ZAP, and pushes to ECR only when every gate passes.

1. Install Jenkins with Docker and create your admin user.
2. Add a `Jenkinsfile` to `hello-app` with stages **Test → Build image → Smoke test → Push**.
3. Store your Docker Hub token as a credential and push `hello-app:<build-number>`.
4. Make it a **Multibranch Pipeline** and only push from `main`.
5. Add a **parallel** stage that runs `pytest` and a lint check (`pip install ruff && ruff check .`) at the same time.
6. Break a test on a branch, push, and confirm the branch build goes red while `main` stays green.
7. Back up the `jenkins_home` volume to a `.tgz` file.

### Cheat sheet

| Task | Where / command |
|---|---|
| Admin password | `docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword` |
| Jenkins logs | `docker logs -f jenkins` |
| Restart Jenkins | `http://localhost:8080/safeRestart` |
| Pipeline syntax help | Job → **Pipeline Syntax** |
| Use a secret | `withCredentials([usernamePassword(credentialsId: 'id', …)]) { … }` |
| Run in a container | `agent { docker { image 'python:3.12-slim' } }` |
| Manual approval | `input message: 'Deploy?'` |
