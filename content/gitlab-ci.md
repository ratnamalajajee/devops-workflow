# GitLab CI/CD

GitLab is an all-in-one DevOps platform: Git hosting, CI/CD pipelines, a container registry, environments and security scanning, in one product. Pipelines are defined in a single `.gitlab-ci.yml` file at the root of the repository. This guide uses free **gitlab.com**, builds a full pipeline for the sample app, then shows how to run your own runner.

> **Note:** You need a free account at [gitlab.com](https://gitlab.com) and the **sample app** from [CI/CD Basics](#/tool/cicd-basics).

## Start here: GitLab CI/CD in simple words

> **In simple words:** You add one file, `.gitlab-ci.yml`, to your project. Every time you push, GitLab reads it and runs the jobs it lists, stage by stage, on machines called **runners**, and shows the result as a pipeline diagram.

### Watch how it works

```svg Watch it work: a push making GitLab build a pipeline from .gitlab-ci.yml, runners taking the jobs stage by stage, the result on the merge request, then main pushing the image to the Container Registry and deploying to staging and, after a click, production. The animation loops.
<svg viewBox="0 0 600 436" role="img" data-anim="gitlab-ci" data-dur="37.06" data-starts="0 4.76 9.52 13.94 18.7 23.46 27.88 32.3" aria-label="Animated GitLab CI/CD pipeline for hello-app. Merge request: you push to a branch with a merge request. GitLab reads .gitlab-ci.yml and creates a pipeline with three stages: test, build and deploy. On a merge request, the rules skip the build and deploy jobs, so only the test stage runs. Runners, either GitLab&#x27;s shared runners or your own gitlab-runner, pick up the jobs. unit-tests and lint are in the same stage, so they run in parallel; lint is allowed to fail. The pipeline result and the JUnit test report show on the merge request. After the merge: the pipeline on main runs every stage. The tests pass, so the build stage starts, and a runner builds the image with Docker-in-Docker and pushes hello-app:1a2b3c4 to the project&#x27;s Container Registry. deploy-staging runs by itself and GitLab records the deployment in the staging environment. deploy-production is a manual job: it waits until someone clicks its play button, and protected environments limit who may click. Once clicked, production gets the same image as staging, and re-deploying an older deployment is a one-click rollback.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<rect x="132" y="64" width="460" height="192" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="5 4"/>
<rect x="142" y="92" width="124" height="152" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.3" stroke-dasharray="3 4"/>
<rect x="278" y="92" width="124" height="152" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.3" stroke-dasharray="3 4"/>
<rect x="414" y="92" width="168" height="152" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.3" stroke-dasharray="3 4"/>
<polyline points="68,145 204,145" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="204,145 272,145 272,177 340,177" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="1.6" stroke-opacity=".8"/>
<polyline points="204,209 272,209 272,177" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="1.6" stroke-opacity=".8"/>
<polyline points="340,177 408,177 408,145 498,145" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="1.6" stroke-opacity=".8"/>
<polyline points="408,177 408,209 498,209" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="1.6" stroke-opacity=".8"/>
<polyline points="340,177 340,30" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="204,244 204,290" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="340,244 340,290" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="498,244 498,290" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<rect x="138" y="70" width="185" height="16" rx="5" class="dg-box"/><text x="142" y="80" font-size="11" class="dg-muted">Pipeline · from .gitlab-ci.yml</text>
<rect x="148" y="98" width="31.6" height="16" rx="5" class="dg-box"/><text x="152" y="108" font-size="11" class="dg-muted">test</text>
<rect x="284" y="98" width="37.5" height="16" rx="5" class="dg-box"/><text x="288" y="108" font-size="11" class="dg-muted">build</text>
<rect x="420" y="98" width="43.4" height="16" rx="5" class="dg-box"/><text x="424" y="108" font-size="11" class="dg-muted">deploy</text>
<g><rect x="8" y="116" width="120" height="58" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1;0" keyTimes="0;0.1284;0.2569;0.5046" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/></rect><rect x="12" y="120" width="112" height="50" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="68" y="141.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Merge request</text><text x="68" y="157" text-anchor="middle" font-size="11" class="dg-muted">your branch</text></g>
<rect x="262" y="8" width="156" height="44" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.3761" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/><rect x="258" y="4" width="164" height="52" rx="12" fill="#7c3aed" fill-opacity=".18" stroke="#7c3aed" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5046;0.633" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/></rect><rect x="262" y="8" width="156" height="44" rx="9" class="dg-box" stroke="#7c3aed" stroke-width="2.2"/><text x="340" y="26.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Container Registry</text><text x="340" y="42" text-anchor="middle" font-size="11" class="dg-muted">hello-app:1a2b3c4</text></g>
<g><rect x="148" y="118" width="112" height="54" rx="12" fill="#0d9488" fill-opacity=".18" stroke="#0d9488" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1;0" keyTimes="0;0.2569;0.3761;0.5046" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/></rect><rect x="152" y="122" width="104" height="46" rx="9" class="dg-box" stroke="#0d9488" stroke-width="2.2"/><text x="204" y="141.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">unit-tests</text><text x="204" y="157" text-anchor="middle" font-size="11" class="dg-muted">pytest + JUnit</text></g>
<g><rect x="148" y="182" width="112" height="54" rx="12" fill="#0d9488" fill-opacity=".18" stroke="#0d9488" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1;0" keyTimes="0;0.2569;0.3761;0.5046" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/></rect><rect x="152" y="186" width="104" height="46" rx="9" class="dg-box" stroke="#0d9488" stroke-width="2.2"/><text x="204" y="205.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">lint</text><text x="204" y="221" text-anchor="middle" font-size="11" class="dg-muted">allow_failure</text></g>
<rect x="288" y="154" width="104" height="46" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.3761" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/><rect x="284" y="150" width="112" height="54" rx="12" fill="#f97316" fill-opacity=".18" stroke="#f97316" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3761;0.633" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/></rect><rect x="288" y="154" width="104" height="46" rx="9" class="dg-box" stroke="#f97316" stroke-width="2.2"/><text x="340" y="173.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">docker-image</text><text x="340" y="189" text-anchor="middle" font-size="11" class="dg-muted">build + push</text></g>
<rect x="424" y="122" width="148" height="46" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.3761" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/><rect x="420" y="118" width="156" height="54" rx="12" fill="#10b981" fill-opacity=".18" stroke="#10b981" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.633;0.7523" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/></rect><rect x="424" y="122" width="148" height="46" rx="9" class="dg-box" stroke="#10b981" stroke-width="2.2"/><text x="498" y="141.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">deploy-staging</text><text x="498" y="157" text-anchor="middle" font-size="11" class="dg-muted">staging.example.com</text></g>
<rect x="424" y="186" width="148" height="46" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.3761" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/><rect x="420" y="182" width="156" height="54" rx="12" fill="#2563eb" fill-opacity=".18" stroke="#2563eb" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.7523" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/></rect><rect x="424" y="186" width="148" height="46" rx="9" class="dg-box" stroke="#2563eb" stroke-width="2.2"/><text x="498" y="205.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">deploy-production</text><text x="498" y="221" text-anchor="middle" font-size="11" class="dg-muted">manual ▶</text></g>
<g><rect x="138" y="286" width="448" height="58" rx="12" fill="#c026d3" fill-opacity=".18" stroke="#c026d3" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.1284;0.2569;0.5046;0.633" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/></rect><rect x="142" y="290" width="440" height="50" rx="9" class="dg-box" stroke="#c026d3" stroke-width="2.2"/><text x="362" y="311.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Runners</text><text x="362" y="327" text-anchor="middle" font-size="11" class="dg-muted">GitLab&#x27;s shared runners, or your own gitlab-runner</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.2569" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/><circle cx="256" cy="122" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M251.5,122 L255,125.5 L260.5,118.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.5046" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/><circle cx="418" cy="8" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M413.5,8 L417,11.5 L422.5,4.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.633" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/><circle cx="572" cy="122" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M567.5,122 L571,125.5 L576.5,118.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7523;0.8716" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/><circle cx="572" cy="186" r="9.5" fill="#d97706" stroke="#fff" stroke-width="2"/><rect x="567.5" y="185" width="9" height="6.5" rx="1.2" fill="#fff"/><path d="M569.2,185 V183 A2.8,2.8 0 0 1 574.8,183 V185" fill="none" stroke="#fff" stroke-width="1.6"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8716" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/><circle cx="572" cy="186" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M567.5,186 L571,189.5 L576.5,182.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0077;0.1105" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/><animateMotion path="M68,145 L204,145" keyPoints="0;0;1;1" keyTimes="0;0.0077;0.1105;1" calcMode="linear" dur="37.06s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1349;0.1991" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/><animateMotion path="M204,244 L204,290" keyPoints="0;0;1;1" keyTimes="0;0.1349;0.1991;1" calcMode="linear" dur="37.06s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.167;0.2312" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/><animateMotion path="M204,244 L204,290" keyPoints="0;0;1;1" keyTimes="0;0.167;0.2312;1" calcMode="linear" dur="37.06s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.264;0.3594" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/><animateMotion path="M204,145 L68,145" keyPoints="0;0;1;1" keyTimes="0;0.264;0.3594;1" calcMode="linear" dur="37.06s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3839;0.4866" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/><animateMotion path="M68,145 L204,145 L272,145 L272,177 L340,177" keyPoints="0;0;1;1" keyTimes="0;0.3839;0.4866;1" calcMode="linear" dur="37.06s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.511;0.556" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/><animateMotion path="M340,244 L340,290" keyPoints="0;0;1;1" keyTimes="0;0.511;0.556;1" calcMode="linear" dur="37.06s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5662;0.6228" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/><animateMotion path="M340,177 L340,30" keyPoints="0;0;1;1" keyTimes="0;0.5662;0.6228;1" calcMode="linear" dur="37.06s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6402;0.7356" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/><animateMotion path="M340,177 L408,177 L408,145 L498,145" keyPoints="0;0;1;1" keyTimes="0;0.6402;0.7356;1" calcMode="linear" dur="37.06s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8793;0.982" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/><animateMotion path="M340,177 L408,177 L408,209 L498,209" keyPoints="0;0;1;1" keyTimes="0;0.8793;0.982;1" calcMode="linear" dur="37.06s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(20.4,360.5) scale(.8)"><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g><text x="31.8" y="364">job to a runner</text><g transform="translate(138.2,360.5) scale(.8)"><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g><text x="149.6" y="364">pipeline run</text><g transform="translate(239.2,360.5) scale(.8)"><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g><text x="250.6" y="364">result</text><g transform="translate(307.4,360.5) scale(.8)"><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g><text x="319.6" y="364">image</text></g>
<rect x="12" y="376" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="376" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="37.06s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1284" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/><circle cx="36" cy="404" r="14" fill="#6366f1"/><text x="36" y="409" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="399" font-size="14" font-weight="800" fill="#6366f1">Push: GitLab reads .gitlab-ci.yml</text><text x="578" y="399" text-anchor="end" font-size="10.5" class="dg-muted">Merge request · 1/8</text><text x="60" y="420" font-size="12.5" class="dg-text">It creates a pipeline. On a merge request, rules skip build and deploy.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1284;0.2569" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/><circle cx="36" cy="404" r="14" fill="#6366f1"/><text x="36" y="409" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="399" font-size="14" font-weight="800" fill="#6366f1">Runners pick up the test jobs</text><text x="578" y="399" text-anchor="end" font-size="10.5" class="dg-muted">Merge request · 2/8</text><text x="60" y="420" font-size="12.5" class="dg-text">unit-tests and lint are in the same stage, so they run in parallel.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2569;0.3761" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/><circle cx="36" cy="404" r="14" fill="#6366f1"/><text x="36" y="409" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="399" font-size="14" font-weight="800" fill="#6366f1">The result shows on the merge request</text><text x="578" y="399" text-anchor="end" font-size="10.5" class="dg-muted">Merge request · 3/8</text><text x="60" y="420" font-size="12.5" class="dg-text">Pipeline passed, and the Tests tab lists each test from the JUnit report.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3761;0.5046" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/><circle cx="36" cy="404" r="14" fill="#f97316"/><text x="36" y="409" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="399" font-size="14" font-weight="800" fill="#f97316">Merged: main runs every stage</text><text x="578" y="399" text-anchor="end" font-size="10.5" class="dg-muted">After the merge · 4/8</text><text x="60" y="420" font-size="12.5" class="dg-text">The tests pass again, so the build stage starts: the docker-image job.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5046;0.633" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/><circle cx="36" cy="404" r="14" fill="#f97316"/><text x="36" y="409" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="399" font-size="14" font-weight="800" fill="#f97316">The image goes to the Container Registry</text><text x="578" y="399" text-anchor="end" font-size="10.5" class="dg-muted">After the merge · 5/8</text><text x="60" y="420" font-size="12.5" class="dg-text">A runner builds it with Docker-in-Docker and pushes hello-app:1a2b3c4.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.633;0.7523" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/><circle cx="36" cy="404" r="14" fill="#f97316"/><text x="36" y="409" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="399" font-size="14" font-weight="800" fill="#f97316">deploy-staging runs by itself</text><text x="578" y="399" text-anchor="end" font-size="10.5" class="dg-muted">After the merge · 6/8</text><text x="60" y="420" font-size="12.5" class="dg-text">GitLab records the deploy under Operate → Environments: staging.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7523;0.8716" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/><circle cx="36" cy="404" r="14" fill="#f97316"/><text x="36" y="409" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="399" font-size="14" font-weight="800" fill="#f97316">Production waits for a click</text><text x="578" y="399" text-anchor="end" font-size="10.5" class="dg-muted">After the merge · 7/8</text><text x="60" y="420" font-size="12.5" class="dg-text">when: manual shows a ▶ button. Protected environments limit who clicks.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8716" calcMode="discrete" dur="37.06s" repeatCount="indefinite"/><circle cx="36" cy="404" r="14" fill="#f97316"/><text x="36" y="409" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="399" font-size="14" font-weight="800" fill="#f97316">Someone clicks ▶: production</text><text x="578" y="399" text-anchor="end" font-size="10.5" class="dg-muted">After the merge · 8/8</text><text x="60" y="420" font-size="12.5" class="dg-text">Same image as staging. Re-deploy an older one for a one-click rollback.</text></g>
</svg>
```

```steps
#6366f1 | Merge request | Push: GitLab reads .gitlab-ci.yml | It creates a pipeline. On a merge request, rules skip build and deploy.
#6366f1 | Merge request | Runners pick up the test jobs | unit-tests and lint are in the same stage, so they run in parallel.
#6366f1 | Merge request | The result shows on the merge request | Pipeline passed, and the Tests tab lists each test from the JUnit report.
#f97316 | After the merge | Merged: main runs every stage | The tests pass again, so the build stage starts: the docker-image job.
#f97316 | After the merge | The image goes to the Container Registry | A runner builds it with Docker-in-Docker and pushes hello-app:1a2b3c4.
#f97316 | After the merge | deploy-staging runs by itself | GitLab records the deploy under Operate → Environments: staging.
#f97316 | After the merge | Production waits for a click | when: manual shows a ▶ button. Protected environments limit who clicks.
#f97316 | After the merge | Someone clicks ▶: production | Same image as staging. Re-deploy an older one for a one-click rollback.
```

### How the pieces fit

```text
 git push
    │
    ▼
 .gitlab-ci.yml ──▶ Pipeline
                      ├── stage: test     ── job: unit-tests ──┐
                      │                   ── job: lint ────────┤ jobs in the same stage run in parallel
                      ├── stage: build    ── job: docker-image │ next stage starts when the previous one passes
                      └── stage: deploy   ── job: deploy-prod  (manual ▶ button)
                                     │
                              runs on Runners (GitLab's shared runners, or your own)
```

### Key words

| Word | Simple meaning |
|---|---|
| **`.gitlab-ci.yml`** | The pipeline recipe file, at the root of the repo |
| **Pipeline** | One full run of all jobs for a commit |
| **Stage** | A group of jobs; stages run in order (`build` → `test` → `deploy`) |
| **Job** | One task with a `script` of shell commands |
| **Runner** | The machine (or container) that runs jobs |
| **Executor** | How a runner runs jobs: in Docker containers, in a shell, on Kubernetes… |
| **Artifact** | Files a job saves for later jobs or for download |
| **Cache** | Files reused between pipelines to save time, like downloaded packages |
| **CI/CD variable** | A setting or secret given to jobs; can be **masked** and **protected** |
| **Environment** | A deploy target (`staging`, `production`) with a history of deployments |

### Check yourself

1. Where does the pipeline definition live?
2. Do jobs in the same stage run one at a time or together?
3. What's the difference between an artifact and a cache?

> **Tip:** Answers: 1) In `.gitlab-ci.yml` at the root of the repository. 2) Together, in parallel. 3) An artifact is a job's *output*, passed to later jobs or downloaded; a cache is a *speed-up*, reusing files like downloaded packages between runs.

## Set up the project on GitLab

> **In simple words:** Create an empty project on gitlab.com and push the sample app into it.

1. On gitlab.com: **New project → Create blank project**, named `hello-app`, with **Initialize repository with a README** *unticked*.
2. Add your SSH key: **avatar → Edit profile → SSH Keys** (the same `~/.ssh/id_ed25519.pub` from Workstation Setup).
3. Push the sample app:

```bash
cd ~/code/hello-app
git remote add gitlab git@gitlab.com:<your-username>/hello-app.git
git push -u gitlab main
```

> **Note:** New gitlab.com accounts may have to **verify identity** (phone or card) before using GitLab's shared runners. That's an anti-abuse check, and you won't be charged. If you can't, use your own runner (see **Runners** below).

> **Tip:** Want GitLab on your own server? The `gitlab/gitlab-ce` Docker image runs a complete self-managed GitLab, but it needs **4+ GB of RAM**. For learning, gitlab.com is much easier.

## Your first pipeline

> **In simple words:** Create `.gitlab-ci.yml`, push it, and open **Build → Pipelines** to watch it run.

```yaml
stages:
  - hello
  - info

say-hello:
  stage: hello
  image: alpine:3.20
  script:
    - echo "Hello from GitLab CI!"
    - echo "Project $CI_PROJECT_PATH, branch $CI_COMMIT_BRANCH, commit $CI_COMMIT_SHORT_SHA"

machine-info:
  stage: info
  image: alpine:3.20
  script:
    - uname -a
    - cat /etc/os-release
    - echo "Pipeline $CI_PIPELINE_ID triggered by $GITLAB_USER_LOGIN via $CI_PIPELINE_SOURCE"
```

```bash
git add .gitlab-ci.yml && git commit -m "First pipeline" && git push gitlab main
```

In GitLab: **Build → Pipelines** → click the pipeline → click a job to see its log.

> **Tip:** Use **Build → Pipeline editor** to edit `.gitlab-ci.yml` in the browser. It **validates** the file as you type and shows a visual preview of the stages.

`CI_PROJECT_PATH`, `CI_COMMIT_SHORT_SHA` and friends are **predefined variables** GitLab gives every job. The full list is in the docs: [Predefined CI/CD variables](https://docs.gitlab.com/ci/variables/predefined_variables/).

## CI for the sample app

> **In simple words:** On every push, run the tests in a Python container, keep downloaded packages between runs, and show test results right inside merge requests.

Replace `.gitlab-ci.yml` with:

```yaml
stages:
  - test
  - build
  - deploy

default:
  image: python:3.12-slim

variables:
  PIP_CACHE_DIR: "$CI_PROJECT_DIR/.cache/pip"

unit-tests:
  stage: test
  cache:
    key:
      files: [requirements-dev.txt]     # new cache only when dependencies change
    paths: [.cache/pip]
  script:
    - pip install -r requirements-dev.txt
    - mkdir -p reports
    - pytest -v --junitxml=reports/junit.xml
  artifacts:
    when: always                         # keep the report even if tests fail
    reports:
      junit: reports/junit.xml           # shows results in pipelines and merge requests
    paths: [reports/]
    expire_in: 1 week

lint:
  stage: test
  script:
    - pip install ruff
    - ruff check .
  allow_failure: true                    # report problems but don't block the pipeline
```

Push it. `unit-tests` and `lint` run **in parallel** because they're in the same stage. Open the pipeline's **Tests** tab to see each test.

Now create a **merge request** that breaks a test. The MR shows the failed pipeline and which test failed. To block merging, go to **Settings → Merge requests → Pipelines must succeed**.

## Variables, secrets and rules

> **In simple words:** **Variables** feed settings and secrets to jobs. **Rules** decide *when* a job runs: on which branch, for merge requests, for tags, or only when someone clicks a button.

### CI/CD variables

Set them under **Settings → CI/CD → Variables → Add variable**:

| Option | Meaning |
|---|---|
| **Masked** | Hidden as `[MASKED]` in job logs |
| **Protected** | Only given to pipelines on **protected** branches and tags (like `main`), so feature branches can't read production secrets |
| **Type: File** | GitLab writes the value to a temporary file and the variable holds its **path**, which is handy for kubeconfigs and certificates |
| **Environment scope** | Only for jobs deploying to a matching environment, such as `production` |

### Rules

```yaml
workflow:                                     # when to create a pipeline at all
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    - if: $CI_COMMIT_TAG

deploy-staging:
  stage: deploy
  script: echo "deploy to staging"
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH       # only from main

deploy-production:
  stage: deploy
  script: echo "deploy to production"
  rules:
    - if: $CI_COMMIT_TAG                                # only for tags like v1.2.0
      when: manual                                      # someone must click ▶
```

`rules` are checked top to bottom, and the first match wins. If none match, the job is skipped.

## Build and push to the GitLab Container Registry

> **In simple words:** Every GitLab project includes a free private Docker registry. This job builds the app's image and pushes it there, using login details GitLab provides automatically.

Add to `.gitlab-ci.yml`:

```yaml
docker-image:
  stage: build
  image: docker:29
  services:
    - docker:29-dind                     # a Docker engine running next to the job
  variables:
    DOCKER_TLS_CERTDIR: "/certs"
    IMAGE: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA
  before_script:
    - echo "$CI_REGISTRY_PASSWORD" | docker login -u "$CI_REGISTRY_USER" --password-stdin "$CI_REGISTRY"
  script:
    - docker build --build-arg APP_VERSION=$CI_COMMIT_SHORT_SHA -t $IMAGE .
    - docker run -d --name smoke $IMAGE
    - docker run --rm --network container:smoke curlimages/curl:8.10.1 -sf --retry 10 --retry-connrefused --retry-delay 1 http://localhost:8000/health
    - docker push $IMAGE
    - |
      if [ "$CI_COMMIT_BRANCH" = "$CI_DEFAULT_BRANCH" ]; then
        docker tag $IMAGE $CI_REGISTRY_IMAGE:latest
        docker push $CI_REGISTRY_IMAGE:latest
      fi
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    - if: $CI_COMMIT_TAG
```

After it runs: **Deploy → Container Registry** lists `hello-app:<short-sha>` and `latest`.

| Predefined variable | Value |
|---|---|
| `CI_REGISTRY` | `registry.gitlab.com` |
| `CI_REGISTRY_IMAGE` | `registry.gitlab.com/<you>/hello-app` |
| `CI_REGISTRY_USER` / `CI_REGISTRY_PASSWORD` | A short-lived login valid only for this job |

> **Note:** **Docker-in-Docker** (`docker:dind`) needs a runner in **privileged** mode. GitLab's shared Linux runners support it; on your own runner, set `privileged = true` (see **Runners**). Without privileged mode, use a daemonless builder such as Buildah.

## Environments and deployments

> **In simple words:** Tell GitLab *where* a job deploys. GitLab then keeps a history of what went where, shows a link to the live app, and lets you re-deploy an older version with one click.

```yaml
deploy-staging:
  stage: deploy
  image: alpine:3.20
  script:
    - echo "Deploying $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA to staging"
  environment:
    name: staging
    url: https://staging.example.com
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

deploy-production:
  stage: deploy
  image: alpine:3.20
  script:
    - echo "Deploying $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA to production"
  environment:
    name: production
    url: https://www.example.com
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      when: manual
  resource_group: production             # never run two production deploys at once
```

Open **Operate → Environments**: each environment lists its deployments. **Re-deploy** on an older one is a one-click rollback. Protect production under **Settings → CI/CD → Protected environments** so only chosen people can click ▶.

## Faster and cleaner pipelines

> **In simple words:** Tricks to make pipelines quicker (start jobs early, split tests) and shorter to write (reuse config instead of copy-pasting).

### `needs`: start jobs as soon as their inputs are ready

```yaml
docker-image:
  stage: build
  needs: [unit-tests]          # don't wait for lint; start right after unit-tests
```

### `parallel: matrix`: one job definition, several runs

```yaml
unit-tests:
  stage: test
  image: python:${PY}-slim
  parallel:
    matrix:
      - PY: ["3.11", "3.12", "3.13"]
  script:
    - pip install -r requirements-dev.txt && pytest -q
```

### `extends`, anchors and `include`: don't repeat yourself

```yaml
.python-job:                    # a hidden "template" job (starts with a dot)
  image: python:3.12-slim
  before_script:
    - pip install -r requirements-dev.txt

unit-tests:
  extends: .python-job
  stage: test
  script: [pytest -q]

include:
  - template: Jobs/SAST.gitlab-ci.yml          # GitLab's built-in security scanning
  - project: my-group/ci-templates             # shared templates from another repo
    file: /python.yml
```

## Runners: GitLab's or your own

> **In simple words:** A runner is the worker that executes jobs. gitlab.com lends you shared runners; you can also install a runner on your own machine, which gives you no minute limits, private network access and your own tools.

| | GitLab-hosted (shared) | Your own (self-managed) |
|---|---|---|
| Setup | None | Install and register `gitlab-runner` |
| Limits | Monthly compute minutes on the free tier | Your hardware |
| Privileged Docker | Supported | You decide (`privileged = true`) |

Run your own runner in Docker:

1. In GitLab: **Settings → CI/CD → Runners → New project runner**. Tick **Run untagged jobs**, then **Create runner**. Copy the token, which starts with `glrt-`.
2. Start the runner and register it:

```bash
docker volume create gitlab-runner-config
docker run -d --name gitlab-runner --restart always \
  -v gitlab-runner-config:/etc/gitlab-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gitlab/gitlab-runner:alpine

docker exec -it gitlab-runner gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.com/" \
  --token "glrt-REPLACE_ME" \
  --executor "docker" \
  --docker-image "alpine:3.20" \
  --docker-privileged \
  --description "my-laptop-runner"
```

3. Back on the Runners page, your runner shows a green dot. To force jobs onto it, disable shared runners for the project, or add tags (`tags: [laptop]`) to the runner and the jobs.

```bash
docker exec gitlab-runner gitlab-runner list        # registered runners
docker logs -f gitlab-runner                        # what it's doing
```

Official docs: [Registering runners](https://docs.gitlab.com/runner/register/)

> **Warning:** `--docker-privileged` and the Docker socket give jobs full control of that machine. Only use such a runner for projects you trust.

## Hand over to Argo CD (GitOps)

> **In simple words:** As in the other CI tools, GitLab builds and pushes the image, then writes the new tag into a GitOps repo. Argo CD deploys it.

Create a **project access token** on your `gitops` project (**Settings → Access tokens**, role *Developer*, scope `write_repository`). Save it in `hello-app` as a **masked, protected** variable named `GITOPS_TOKEN`. Then:

```yaml
bump-gitops:
  stage: deploy
  image: alpine:3.20
  needs: [docker-image]
  before_script:
    - apk add --no-cache git kustomize
  script:
    - git clone "https://oauth2:${GITOPS_TOKEN}@gitlab.com/<you>/gitops.git"
    - cd gitops/apps/hello/overlays/dev
    - kustomize edit set image hello-app=$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA
    - git config user.name "gitlab-ci" && git config user.email "gitlab-ci@example.com"
    - git commit -am "hello-app: deploy $CI_COMMIT_SHORT_SHA" && git push
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

See the Argo CD guide's **Sample application flow** for the `gitops` repo layout. If the image registry is private, the cluster also needs a **deploy token** with `read_registry` as an image pull secret.

## Troubleshooting

> **In simple words:** Open the failed job, read the log from the first error, and check the **Pipeline editor** for YAML mistakes.

> **Tip:** More real-world failures (controller down, local-vs-CI builds, dev-vs-prod differences, ECR push errors) are covered in [CI/CD Troubleshooting](#/tool/cicd-troubleshooting).

| Problem | Fix |
|---|---|
| No pipeline runs at all | The file must be named exactly `.gitlab-ci.yml` at the repo root; check `workflow: rules` |
| Job stuck: *"pending… no runners"* | Shared runners disabled or account not verified, or job `tags` match no runner |
| `yaml invalid` | Use **Pipeline editor → Validate**. Indentation must be spaces |
| `Cannot connect to the Docker daemon` | Missing `services: [docker:29-dind]`, missing `DOCKER_TLS_CERTDIR`, or runner not privileged |
| Variable is empty on a branch | It's **protected**, and the branch isn't protected |
| `denied: access forbidden` pushing image | Log in with `$CI_REGISTRY_USER`/`$CI_REGISTRY_PASSWORD` to `$CI_REGISTRY`, and the image path must start with `$CI_REGISTRY_IMAGE` |
| Job skipped | Its `rules` didn't match, or a job it `needs` failed |

## Lab: complete GitLab pipeline

> **In simple words:** Practice time: build the whole pipeline for the sample app on GitLab.

1. Push `hello-app` to GitLab and add `unit-tests` (with JUnit report) and `lint` jobs.
2. Turn on **Pipelines must succeed** and prove it blocks a broken merge request.
3. Add `docker-image` to build, smoke-test and push to the GitLab Container Registry.
4. Add `deploy-staging` (automatic) and `deploy-production` (manual, tags only) with environments.
5. Run the Python tests on 3 versions with `parallel: matrix`.
6. Register your own runner with Docker and run a pipeline on it.
7. Bonus: add `bump-gitops` and complete the Argo CD **Sample application flow**.

### Cheat sheet

| Task | YAML |
|---|---|
| Order of stages | `stages: [test, build, deploy]` |
| Container for a job | `image: python:3.12-slim` |
| Only on main | `rules: [{ if: '$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH' }]` |
| Manual button | `when: manual` |
| Save files | `artifacts: { paths: [dist/] }` |
| Speed up installs | `cache: { paths: [.cache/pip] }` |
| Start early | `needs: [unit-tests]` |
