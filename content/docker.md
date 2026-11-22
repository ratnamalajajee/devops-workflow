# Docker

Docker packages an application and everything it needs (runtime, libraries, config) into an **image** that runs the same way on your laptop, in CI, and in production. Kubernetes, ECS, and most CI systems run containers, so this is the foundation for everything that follows.

> **Tip:** No Docker or Kubernetes on your laptop? Use the **cloud lab machine** in the [Practice lab](#/lab). It has Docker, kind, kubectl, Helm, Terraform, the AWS CLI and the Argo CD CLI ready to go.

## Start here: Docker in simple words

> **In simple words:** Docker packs an app together with everything it needs into a sealed box called a **container**. The box runs exactly the same on your laptop, a colleague's laptop and a cloud server.

### Watch how it works

```svg Watch it work: a Dockerfile built into image layers, the build cache at work, a container answering on port 8000, and the image pushed to a registry and pulled by another server. The animation loops.
<svg viewBox="0 0 600 398" role="img" data-anim="docker" data-dur="33.66" data-starts="0 4.42 9.52 14.62 19.04 23.8 28.56" aria-label="Animated Docker flow. Build: the Dockerfile is the recipe: FROM python:3.12-slim, COPY the requirements and the code, RUN pip install, and CMD to start gunicorn. docker build -t hello-docker:1.0.0 . runs the steps in order, and each COPY or RUN step adds a read-only layer on top of the base image. When you change app.py and build again, the earlier layers come from the cache and only COPY app.py and the steps after it run again. Run: docker run -d --name hello -p 8000:8000 hello-docker:1.0.0 starts a container from the image, adding a thin writable layer on top. The browser opens localhost:8000 on your laptop, and Docker forwards it to port 8000 inside the container, where gunicorn answers. Share: you tag the image with the registry name and docker push it to Docker Hub or Amazon ECR; layers the registry already has are skipped. Another server runs docker pull, gets the same layers, and runs exactly the same app.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<rect x="8" y="8" width="402" height="294" rx="12" fill="none" stroke="#64748b" stroke-width="2" stroke-dasharray="7 4"/>
<rect x="184" y="30" width="216" height="184" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="5 4"/>
<rect x="420" y="170" width="172" height="132" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="5 4"/>
<polyline points="90,120 172,120" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="172,70 172,190" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="172,70 200,70" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="172,100 200,100" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="172,130 200,130" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="172,160 200,160" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="172,190 200,190" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="294,202 294,232" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="90,260 292,260" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="388,100 510,100" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="540,128 540,232" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<rect x="14" y="15" width="91.6" height="18" rx="5" class="dg-box"/><text x="18" y="27" font-size="13" font-weight="800" class="dg-muted">Your laptop</text>
<rect x="190" y="36" width="149.6" height="16" rx="5" class="dg-box"/><text x="194" y="46" font-size="11" class="dg-muted">image hello-docker:1.0.0</text>
<rect x="426" y="176" width="90.6" height="16" rx="5" class="dg-box"/><text x="430" y="186" font-size="11" class="dg-muted">Another server</text>
<g><rect x="18" y="86" width="144" height="68" rx="12" fill="#f97316" fill-opacity=".18" stroke="#f97316" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1313" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/></rect><rect x="22" y="90" width="136" height="60" rx="9" class="dg-box" stroke="#f97316" stroke-width="2.2"/><text x="90" y="109" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Dockerfile</text><text x="90" y="124.5" text-anchor="middle" font-size="11" class="dg-muted">+ app.py</text><text x="90" y="139.5" text-anchor="middle" font-size="11" class="dg-muted">+ requirements.txt</text></g>
<g><rect x="196" y="54" width="196" height="32" rx="12" fill="#0ea5e9" fill-opacity=".18" stroke="#0ea5e9" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1313;0.4343" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/></rect><rect x="200" y="58" width="188" height="24" rx="9" class="dg-box" stroke="#0ea5e9" stroke-width="2.2"/><text x="294" y="74" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">RUN useradd appuser</text></g>
<g><rect x="196" y="84" width="196" height="32" rx="12" fill="#0ea5e9" fill-opacity=".18" stroke="#0ea5e9" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1313;0.4343" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/></rect><rect x="200" y="88" width="188" height="24" rx="9" class="dg-box" stroke="#0ea5e9" stroke-width="2.2"/><text x="294" y="104" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">COPY app.py</text></g>
<g><rect x="196" y="114" width="196" height="32" rx="12" fill="#0ea5e9" fill-opacity=".18" stroke="#0ea5e9" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1313;0.2828" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/></rect><rect x="200" y="118" width="188" height="24" rx="9" class="dg-box" stroke="#0ea5e9" stroke-width="2.2"/><text x="294" y="134" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">RUN pip install</text></g>
<g><rect x="196" y="144" width="196" height="32" rx="12" fill="#0ea5e9" fill-opacity=".18" stroke="#0ea5e9" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1313;0.2828" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/></rect><rect x="200" y="148" width="188" height="24" rx="9" class="dg-box" stroke="#0ea5e9" stroke-width="2.2"/><text x="294" y="164" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">COPY requirements.txt</text></g>
<g><rect x="196" y="174" width="196" height="32" rx="12" fill="#0ea5e9" fill-opacity=".18" stroke="#0ea5e9" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1313;0.2828" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/></rect><rect x="200" y="178" width="188" height="24" rx="9" class="dg-box" stroke="#0ea5e9" stroke-width="2.2"/><text x="294" y="194" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">FROM python:3.12-slim</text></g>
<g><rect x="180" y="228" width="224" height="64" rx="12" fill="#6366f1" fill-opacity=".18" stroke="#6366f1" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4343;0.7071" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/></rect><rect x="184" y="232" width="216" height="56" rx="9" class="dg-box" stroke="#6366f1" stroke-width="2.2"/><text x="292" y="256.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Container: hello</text><text x="292" y="272" text-anchor="middle" font-size="11" class="dg-muted">-p 8000:8000 → gunicorn</text></g>
<g><rect x="18" y="228" width="144" height="64" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5657;0.7071" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/></rect><rect x="22" y="232" width="136" height="56" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="90" y="256.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Browser</text><text x="90" y="272" text-anchor="middle" font-size="11" class="dg-muted">localhost:8000</text></g>
<g><rect x="428" y="68" width="164" height="64" rx="12" fill="#0891b2" fill-opacity=".18" stroke="#0891b2" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.7071" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/></rect><rect x="432" y="72" width="156" height="56" rx="9" class="dg-box" stroke="#0891b2" stroke-width="2.2"/><text x="510" y="96.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Registry</text><text x="510" y="112" text-anchor="middle" font-size="11" class="dg-muted">Docker Hub or ECR</text></g>
<g><rect x="432" y="228" width="156" height="64" rx="12" fill="#059669" fill-opacity=".18" stroke="#059669" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8485" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/></rect><rect x="436" y="232" width="148" height="56" rx="9" class="dg-box" stroke="#059669" stroke-width="2.2"/><text x="510" y="256.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Container</text><text x="510" y="272" text-anchor="middle" font-size="11" class="dg-muted">same image</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2828;0.4343" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/><circle cx="388" cy="178" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M383.5,178 L387,181.5 L392.5,174.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2828;0.4343" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/><circle cx="388" cy="148" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M383.5,148 L387,151.5 L392.5,144.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2828;0.4343" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/><circle cx="388" cy="118" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M383.5,118 L387,121.5 L392.5,114.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8485" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/><circle cx="588" cy="232" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M583.5,232 L587,235.5 L592.5,228.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1374;0.1707" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/><animateMotion path="M90,120 L172,120 L172,190 L294,190" keyPoints="0;0;1;1" keyTimes="0;0.1374;0.1707;1" calcMode="linear" dur="33.66s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1616;0.1949" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/><animateMotion path="M90,120 L172,120 L172,160 L294,160" keyPoints="0;0;1;1" keyTimes="0;0.1616;0.1949;1" calcMode="linear" dur="33.66s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1859;0.2192" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/><animateMotion path="M90,120 L172,120 L172,130 L294,130" keyPoints="0;0;1;1" keyTimes="0;0.1859;0.2192;1" calcMode="linear" dur="33.66s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2101;0.2434" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/><animateMotion path="M90,120 L172,120 L172,100 L294,100" keyPoints="0;0;1;1" keyTimes="0;0.2101;0.2434;1" calcMode="linear" dur="33.66s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2343;0.2677" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/><animateMotion path="M90,120 L172,120 L172,70 L294,70" keyPoints="0;0;1;1" keyTimes="0;0.2343;0.2677;1" calcMode="linear" dur="33.66s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.298;0.3586" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/><animateMotion path="M90,120 L172,120 L172,100 L294,100" keyPoints="0;0;1;1" keyTimes="0;0.298;0.3586;1" calcMode="linear" dur="33.66s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.351;0.4162" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/><animateMotion path="M90,120 L172,120 L172,70 L294,70" keyPoints="0;0;1;1" keyTimes="0;0.351;0.4162;1" calcMode="linear" dur="33.66s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4422;0.5473" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/><animateMotion path="M294,160 L294,260" keyPoints="0;0;1;1" keyTimes="0;0.4422;0.5473;1" calcMode="linear" dur="33.66s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5727;0.6293" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/><animateMotion path="M90,260 L292,260" keyPoints="0;0;1;1" keyTimes="0;0.5727;0.6293;1" calcMode="linear" dur="33.66s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6392;0.6958" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/><animateMotion path="M292,260 L90,260" keyPoints="0;0;1;1" keyTimes="0;0.6392;0.6958;1" calcMode="linear" dur="33.66s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7156;0.8287" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/><animateMotion path="M294,100 L510,100" keyPoints="0;0;1;1" keyTimes="0;0.7156;0.8287;1" calcMode="linear" dur="33.66s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8576;0.9788" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/><animateMotion path="M540,128 L540,232" keyPoints="0;0;1;1" keyTimes="0;0.8576;0.9788;1" calcMode="linear" dur="33.66s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(21.2,322.5) scale(.8)"><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g><text x="33.4" y="326">layers / image</text><g transform="translate(134.2,322.5) scale(.8)"><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g><text x="145.6" y="326">request</text><g transform="translate(207.2,322.5) scale(.8)"><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g><text x="218.6" y="326">reply</text></g>
<rect x="12" y="338" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="338" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="33.66s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1313" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/><circle cx="36" cy="366" r="14" fill="#f97316"/><text x="36" y="371" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="361" font-size="14" font-weight="800" fill="#f97316">The Dockerfile is the recipe</text><text x="578" y="361" text-anchor="end" font-size="10.5" class="dg-muted">Build · 1/7</text><text x="60" y="382" font-size="12.5" class="dg-text">FROM python:3.12-slim, COPY the code, RUN pip install, CMD gunicorn.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1313;0.2828" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/><circle cx="36" cy="366" r="14" fill="#f97316"/><text x="36" y="371" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="361" font-size="14" font-weight="800" fill="#f97316">docker build -t hello-docker:1.0.0 .</text><text x="578" y="361" text-anchor="end" font-size="10.5" class="dg-muted">Build · 2/7</text><text x="60" y="382" font-size="12.5" class="dg-text">Each COPY or RUN step adds a read-only layer on top of the last one.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2828;0.4343" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/><circle cx="36" cy="366" r="14" fill="#f97316"/><text x="36" y="371" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="361" font-size="14" font-weight="800" fill="#f97316">Change app.py and build again</text><text x="578" y="361" text-anchor="end" font-size="10.5" class="dg-muted">Build · 3/7</text><text x="60" y="382" font-size="12.5" class="dg-text">Earlier layers come from the cache; only COPY app.py and later steps rerun.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4343;0.5657" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/><circle cx="36" cy="366" r="14" fill="#6366f1"/><text x="36" y="371" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="361" font-size="14" font-weight="800" fill="#6366f1">docker run creates a container</text><text x="578" y="361" text-anchor="end" font-size="10.5" class="dg-muted">Run · 4/7</text><text x="60" y="382" font-size="12.5" class="dg-text">docker run -d --name hello -p 8000:8000 hello-docker:1.0.0 starts it.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5657;0.7071" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/><circle cx="36" cy="366" r="14" fill="#6366f1"/><text x="36" y="371" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="361" font-size="14" font-weight="800" fill="#6366f1">-p 8000:8000 lets the browser in</text><text x="578" y="361" text-anchor="end" font-size="10.5" class="dg-muted">Run · 5/7</text><text x="60" y="382" font-size="12.5" class="dg-text">localhost:8000 on your laptop is forwarded to port 8000 in the container.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7071;0.8485" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/><circle cx="36" cy="366" r="14" fill="#0891b2"/><text x="36" y="371" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="361" font-size="14" font-weight="800" fill="#0891b2">docker push to a registry</text><text x="578" y="361" text-anchor="end" font-size="10.5" class="dg-muted">Share · 6/7</text><text x="60" y="382" font-size="12.5" class="dg-text">Tag it with the registry name, then push. Layers already there are skipped.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8485" calcMode="discrete" dur="33.66s" repeatCount="indefinite"/><circle cx="36" cy="366" r="14" fill="#0891b2"/><text x="36" y="371" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="361" font-size="14" font-weight="800" fill="#0891b2">Another server pulls and runs it</text><text x="578" y="361" text-anchor="end" font-size="10.5" class="dg-muted">Share · 7/7</text><text x="60" y="382" font-size="12.5" class="dg-text">docker pull gets the same layers, so the app runs exactly the same.</text></g>
</svg>
```

```steps
#f97316 | Build | The Dockerfile is the recipe | FROM python:3.12-slim, COPY the code, RUN pip install, CMD gunicorn.
#f97316 | Build | docker build -t hello-docker:1.0.0 . | Each COPY or RUN step adds a read-only layer on top of the last one.
#f97316 | Build | Change app.py and build again | Earlier layers come from the cache; only COPY app.py and later steps rerun.
#6366f1 | Run | docker run creates a container | docker run -d --name hello -p 8000:8000 hello-docker:1.0.0 starts it.
#6366f1 | Run | -p 8000:8000 lets the browser in | localhost:8000 on your laptop is forwarded to port 8000 in the container.
#0891b2 | Share | docker push to a registry | Tag it with the registry name, then push. Layers already there are skipped.
#0891b2 | Share | Another server pulls and runs it | docker pull gets the same layers, so the app runs exactly the same.
```

### The problem Docker solves

Without Docker: "It works on my machine!" The app runs for the developer, then breaks on the server because it has a different version of Python, a missing library, or a different setting.

With Docker, you ship the **whole box** (the app plus its exact Python, libraries and settings), so there's nothing left to go wrong between machines.

### A real-life comparison

Think of **shipping containers** on cargo ships. Before them, every item (barrels, boxes, sacks) had to be loaded differently. A standard container can carry anything, and every ship, crane and truck knows how to handle it. Docker does the same for software: every server knows how to run a container, whatever is inside.

### How the pieces fit

```text
 Dockerfile ──build──▶ Image ──run──▶ Container (the app, running)
 (the recipe)          (the packed box)
                         │
                       push ▼  pull
                      Registry (an online store of images, e.g. Docker Hub, Amazon ECR)
```

| Word | Simple meaning | Everyday comparison |
|---|---|---|
| **Dockerfile** | A text file with step-by-step instructions to build the box | A recipe |
| **Image** | The finished, packed box, ready to run but not running | A frozen ready-meal |
| **Container** | A running copy of an image | The meal, heated and being eaten |
| **Registry** | A place to store and share images | A supermarket shelf |
| **Tag** | A version label on an image, like `1.0` | The "best before" label |
| **Volume** | Storage that survives when a container is deleted | A lunchbox you keep after the meal |
| **Port mapping** | Connecting a door on your computer to a door in the container | Forwarding phone calls to an extension |

One image can start many containers, just as one recipe can make many identical meals.

### Containers vs virtual machines

A **virtual machine** is a whole pretend computer with its own full operating system: heavy and slow to start. A **container** shares the host's operating system core and only packs the app's own files: light, and it starts in about a second.

### Check yourself

1. What's the difference between an image and a container?
2. Where do you store images so others can use them?
3. Why does "it works on my machine" stop being a problem?

> **Tip:** Answers: 1) An image is the packed box; a container is that box running. 2) In a registry, such as Docker Hub or Amazon ECR. 3) Because everything the app needs travels inside the image.

## Core concepts

> **In simple words:** The handful of words you'll hear all the time: image, container, Dockerfile, registry, tag and volume.

| Term | Meaning |
|---|---|
| **Image** | A read-only template: filesystem layers plus metadata. Built from a `Dockerfile`. |
| **Container** | A running instance of an image, an isolated process on the host. |
| **Dockerfile** | Recipe of instructions to build an image. |
| **Registry** | Stores images: Docker Hub, AWS ECR, GitHub Container Registry. |
| **Tag** | Version label, for example `nginx:1.27` or `myapp:v1.2.0`. |
| **Volume** | Persistent storage that outlives a container. |

### Containers vs virtual machines

A VM virtualizes **hardware** and boots a full OS kernel, which takes minutes and gigabytes. A container shares the host **kernel** and isolates only the process (using Linux namespaces and cgroups), so it starts in milliseconds and is usually tens of megabytes.

> **Why:** "It works on my machine" goes away. The image *is* the machine.

## Install and verify

> **In simple words:** Make sure Docker is installed and its background engine is running, then run a tiny test container.

If you completed **Workstation Setup**, Docker is already installed. Verify it:

```bash
docker version        # client AND server sections should both appear
docker info | head -20
docker run hello-world
```

If the server section is missing, the daemon is not running. Start Docker Desktop, or run `sudo systemctl start docker` on Linux.

## Your first containers

> **In simple words:** Start ready-made apps (a web server, a database) with one command each, look at their logs, step inside them, and remove them.

```bash
docker run -d --name web -p 8080:80 nginx:1.27
# -d detached, --name a friendly name, -p hostPort:containerPort
curl localhost:8080

docker ps                    # running containers
docker ps -a                 # including stopped
docker logs -f web           # follow logs
docker exec -it web bash     # shell inside the running container
docker stop web && docker start web
docker rm -f web             # stop + remove
```

Try an interactive throwaway container:

```bash
docker run -it --rm ubuntu:24.04 bash   # --rm deletes it on exit
cat /etc/os-release
exit
```

Pass configuration with environment variables:

```bash
docker run -d --name db -e POSTGRES_PASSWORD=secret -p 5432:5432 postgres:16
docker logs db | tail -5
```

## Working with images

> **In simple words:** Download, list, inspect and delete images: the packed boxes your containers are started from.

```bash
docker pull python:3.12-slim
docker images                       # list local images
docker image inspect python:3.12-slim | jq '.[0].Config.Env'
docker history python:3.12-slim     # see the layers
docker tag python:3.12-slim mypython:dev
docker rmi mypython:dev
docker system df                    # disk used by Docker
docker system prune                 # remove stopped containers, dangling images
```

Every instruction in a Dockerfile creates a **layer**. Layers are cached and shared between images, which is why the instruction order in a Dockerfile matters for build speed.

## Write a Dockerfile

> **In simple words:** Write your own recipe that packs a small web app into an image, then build it and run it.

Create a tiny Python web app:

```bash
mkdir -p ~/code/hello-docker && cd ~/code/hello-docker
```

`app.py`:

```python
from flask import Flask
import os, socket

app = Flask(__name__)

@app.get("/")
def index():
    return {"message": "Hello from Docker!", "host": socket.gethostname(),
            "version": os.getenv("APP_VERSION", "dev")}

@app.get("/health")
def health():
    return {"status": "ok"}
```

`requirements.txt`:

```text
flask==3.0.3
gunicorn==23.0.0
```

`Dockerfile`:

```dockerfile
# 1. Base image: small, pinned version
FROM python:3.12-slim

# 2. Working directory inside the image
WORKDIR /app

# 3. Copy dependency list first so this layer is cached
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 4. Copy the source code (changes often, so it goes last)
COPY app.py .

# 5. Don't run as root
RUN useradd --create-home appuser
USER appuser

ENV APP_VERSION=1.0.0
EXPOSE 8000

# 6. Start command
CMD ["gunicorn", "-b", "0.0.0.0:8000", "app:app"]
```

`.dockerignore` keeps junk out of the build context:

```text
.git
__pycache__
*.pyc
.env
```

Build and run:

```bash
docker build -t hello-docker:1.0.0 .
docker run -d --name hello -p 8000:8000 hello-docker:1.0.0
curl localhost:8000
curl localhost:8000/health
```

### Key instructions

| Instruction | Purpose |
|---|---|
| `FROM` | Base image |
| `WORKDIR` | Set the working directory |
| `COPY` / `ADD` | Copy files in (prefer `COPY`) |
| `RUN` | Execute at **build** time |
| `ENV` | Environment variable |
| `EXPOSE` | Document the port (doesn't publish it) |
| `USER` | Run as non-root |
| `CMD` | Default command at **run** time (overridable) |
| `ENTRYPOINT` | Fixed executable. `CMD` becomes its arguments |

## Multi-stage builds

> **In simple words:** Build the app in one big "workshop" image, then copy only the finished result into a tiny final image. Smaller is faster and safer.

Compiled languages need build tools that should not ship to production. Multi-stage builds compile in one stage and copy only the result into a minimal final image. Example for Go:

```dockerfile
FROM golang:1.23 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /out/server .

FROM gcr.io/distroless/static-debian12
COPY --from=build /out/server /server
USER nonroot
ENTRYPOINT ["/server"]
```

The final image is a few MB, with no shell and no package manager, so there is much less to attack.

## Volumes and bind mounts

> **In simple words:** Containers forget everything when deleted. Volumes are separate storage that keeps data (like a database) safe across restarts.

Containers are disposable. Anything written inside one disappears when it is removed, unless you mount storage.

```bash
# Named volume, managed by Docker. Use it for databases.
docker volume create pgdata
docker run -d --name db -e POSTGRES_PASSWORD=secret -v pgdata:/var/lib/postgresql/data postgres:16
docker rm -f db
docker run -d --name db -e POSTGRES_PASSWORD=secret -v pgdata:/var/lib/postgresql/data postgres:16
# data survived

# Bind mount: a host folder, great for local development
docker run -d -p 8081:80 -v "$(pwd)/site:/usr/share/nginx/html:ro" nginx:1.27

docker volume ls
docker volume inspect pgdata
```

## Networking

> **In simple words:** Put containers on the same private network so they can find and talk to each other by name.

```bash
docker network create appnet
docker run -d --name db  --network appnet -e POSTGRES_PASSWORD=secret postgres:16
docker run -it --rm --network appnet postgres:16 psql -h db -U postgres
# containers on the same user-defined network resolve each other by NAME
docker network ls
docker network inspect appnet
```

| Driver | Use |
|---|---|
| `bridge` (default) | Containers on one host |
| `host` | Share the host network stack (Linux only) |
| `none` | No networking |

## Docker Compose

> **In simple words:** Describe several containers that work together (an app plus its database) in one file, and start them all with one command.

Compose describes a multi-container application in one YAML file. Add `compose.yaml` to `hello-docker`:

```yaml
services:
  web:
    build: .
    ports:
      - "8000:8000"
    environment:
      APP_VERSION: "1.1.0"
      DATABASE_URL: postgres://postgres:secret@db:5432/postgres
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: secret
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      retries: 5

volumes:
  pgdata:
```

```bash
docker compose up -d --build   # build and start everything
docker compose ps
docker compose logs -f web
docker compose exec db psql -U postgres
docker compose down            # stop and remove (add -v to delete volumes)
```

## Push to a registry

> **In simple words:** Upload your image to an online registry so servers and teammates can download and run it.

### Docker Hub

```bash
docker login
docker tag hello-docker:1.0.0 <your-dockerhub-user>/hello-docker:1.0.0
docker push <your-dockerhub-user>/hello-docker:1.0.0
```

### AWS ECR (used again in the AWS guide and the Capstone)

```bash
AWS_REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REPO=hello-docker

aws ecr create-repository --repository-name $REPO --region $AWS_REGION
aws ecr get-login-password --region $AWS_REGION \
  | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

docker tag hello-docker:1.0.0 $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO:1.0.0
docker push $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO:1.0.0
```

> **Tip:** Tag images with something traceable, such as a version (`1.4.2`) or Git SHA (`git rev-parse --short HEAD`). Avoid deploying `latest`: you can't tell what is running or roll back reliably.

## Best practices and security

> **In simple words:** Habits that keep images small, fast to build and hard to attack.

- **Pin base images** (`python:3.12-slim`, not `python`), and prefer `slim`, `alpine` or `distroless`.
- **Order layers** from least to most frequently changed. Dependencies go before source code.
- **Run as non-root** with `USER`.
- **Never bake secrets** into images. They stay in the layer history forever. Pass them at runtime.
- Use **`.dockerignore`**.
- **One process per container.** Let the orchestrator handle the rest.
- **Scan images:** `docker scout cves hello-docker:1.0.0` or `trivy image hello-docker:1.0.0`.
- Add a **HEALTHCHECK**, or rely on Kubernetes probes later.

## Troubleshooting

> **In simple words:** The common errors and what each one means, so you know where to look when a container won't start.

| Symptom | Check |
|---|---|
| Container exits immediately | `docker logs <name>`. The main process ended or crashed. |
| `port is already allocated` | Another container or process uses that host port: `docker ps`, `ss -tulpn` |
| Can't reach app on `-p` port | App must listen on `0.0.0.0`, not `127.0.0.1`, inside the container |
| `permission denied ... docker.sock` | Add yourself to the `docker` group, then re-login |
| Out of disk | `docker system df`, then `docker system prune -a` (careful) |
| Need to look inside | `docker exec -it <name> sh`, `docker inspect <name>` |

## Lab: containerize and compose

> **In simple words:** Practice time: pack your own app into an image, run it with a database, and publish it.

1. Write a Dockerfile for any small app (Node, Python, Go, or a static site on nginx).
2. Make it run as non-root and keep the image under 200 MB. Check with `docker images`.
3. Add a `compose.yaml` with your app plus Redis or Postgres. The app must reach the database by service name.
4. Persist the database in a named volume. Prove the data survives `docker compose down` and `up`.
5. Push your image to Docker Hub or ECR with a version tag.
6. Scan it with `docker scout` or `trivy` and fix one finding, for example by switching to a slimmer base.

### Cheat sheet

| Task | Command |
|---|---|
| Run detached with port | `docker run -d -p 8080:80 --name x img` |
| Shell into container | `docker exec -it x sh` |
| Logs | `docker logs -f x` |
| Build | `docker build -t name:tag .` |
| Compose up / down | `docker compose up -d` / `docker compose down` |
| Clean up | `docker system prune` |
