# Argo CD and GitOps

Argo CD is a **GitOps** continuous-delivery tool for Kubernetes. Instead of a pipeline running `kubectl apply`, you commit manifests to Git, and Argo CD, running *inside* the cluster, keeps the cluster in sync with what Git says. Git becomes the single source of truth, every change is a reviewed commit, and rollback is `git revert`.

> **Note:** You need a running cluster (the kind cluster from the Kubernetes guide is perfect) and a GitHub or GitLab account.

> **Tip:** No Docker or Kubernetes on your laptop? Use the **cloud lab machine** in the [Practice lab](#/lab). It has Docker, kind, kubectl, Helm, Terraform, the AWS CLI and the Argo CD CLI ready to go.

## Start here: Argo CD and GitOps in simple words

> **In simple words:** With GitOps, the files in a **Git repository** describe exactly what should be running. **Argo CD** watches that repository and keeps your Kubernetes cluster matching it automatically. To change the app, you change Git, never the cluster directly.

### Watch how it works

```svg Watch it work: Git holding the desired state, Argo CD rendering, comparing and syncing it, undoing a change made by hand, and deploying a new commit. The animation loops.
<svg viewBox="0 0 600 386" role="img" data-anim="argocd" aria-label="Animated GitOps flow with Argo CD. First sync: you commit the Kubernetes YAML or Helm chart and push it, so the Git repository holds the desired state. Argo CD runs inside the cluster, in the argocd namespace. Its repo server fetches the folder and renders the manifests, from plain YAML, Helm or Kustomize. The application controller compares them with what is live in the cluster; nothing is running yet, so the Application shows OutOfSync. A sync applies the manifests, which creates the Deployment, its pods and the Service. Live now matches Git and the pods are ready, so the Application is Synced and Healthy. Drift and self-heal: someone runs kubectl scale with --replicas=1 and goes around Git, so the Application is OutOfSync. With selfHeal true, Argo CD sets replicas back to 2 within seconds. A new commit: you change replicas from 2 to 4 and push. Argo CD sees it when it next polls Git, about every 3 minutes, or at once through a webhook. Automated sync applies it, 4 pods run, and the Application is Synced and Healthy again.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<rect x="146" y="8" width="446" height="284" rx="12" fill="none" stroke="#3b82f6" stroke-width="1.5" stroke-dasharray="5 4"/>
<rect x="158" y="44" width="428" height="110" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="5 4"/>
<rect x="158" y="170" width="428" height="110" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="5 4"/>
<polyline points="72,35 72,106" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="72,106 234,106 374,106" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="374,106 514,106" fill="none" stroke-linejoin="round" stroke="#0ea5e9" stroke-width="1.8" stroke-dasharray="2 3" stroke-opacity=".75"/>
<polyline points="374,106 374,162 234,162 234,232" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="234,232 374,232" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="1.6" stroke-opacity=".8"/>
<polyline points="514,232 374,232" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="1.6" stroke-opacity=".8"/>
<polyline points="72,232 234,232" fill="none" stroke-linejoin="round" stroke="#e11d48" stroke-width="1.6" stroke-dasharray="3 4" stroke-opacity=".6"/>
<rect x="152" y="14" width="114.2" height="16" rx="5" class="dg-box"/><text x="156" y="24" font-size="11" class="dg-muted">Kubernetes cluster</text>
<rect x="477.6" y="50" width="102.4" height="16" rx="5" class="dg-box"/><text x="576" y="60" text-anchor="end" font-size="11" class="dg-muted">argocd namespace</text>
<rect x="495.3" y="176" width="84.7" height="16" rx="5" class="dg-box"/><text x="576" y="186" text-anchor="end" font-size="11" class="dg-muted">app namespace</text>
<g><rect x="8" y="8" width="128" height="54" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1;0" keyTimes="0;0.1048;0.7661;0.879" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/></rect><rect x="12" y="12" width="120" height="46" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="72" y="31.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">You</text><text x="72" y="47" text-anchor="middle" font-size="11" class="dg-muted">commit + push</text></g>
<g><rect x="8" y="70" width="128" height="72" rx="12" fill="#ea580c" fill-opacity=".18" stroke="#ea580c" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1;0" keyTimes="0;0.2097;0.7661;0.879" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/></rect><rect x="12" y="74" width="120" height="64" rx="9" class="dg-box" stroke="#ea580c" stroke-width="2.2"/><text x="72" y="95" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Git repo</text><text x="72" y="110.5" text-anchor="middle" font-size="11" class="dg-muted">desired state</text><text x="72" y="125.5" text-anchor="middle" font-size="11" class="dg-muted">YAML or chart</text></g>
<g><rect x="8" y="200" width="128" height="64" rx="12" fill="#e11d48" fill-opacity=".18" stroke="#e11d48" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5403;0.6532" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/></rect><rect x="12" y="204" width="120" height="56" rx="9" class="dg-box" stroke="#e11d48" stroke-width="2.2"/><text x="72" y="228.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Someone</text><text x="72" y="244" text-anchor="middle" font-size="11" class="dg-muted">kubectl by hand</text></g>
<g><rect x="166" y="70" width="136" height="72" rx="12" fill="#0d9488" fill-opacity=".18" stroke="#0d9488" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.1048;0.2097;0.7661;0.879" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/></rect><rect x="170" y="74" width="128" height="64" rx="9" class="dg-box" stroke="#0d9488" stroke-width="2.2"/><text x="234" y="95" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Repo server</text><text x="234" y="110.5" text-anchor="middle" font-size="11" class="dg-muted">renders YAML,</text><text x="234" y="125.5" text-anchor="middle" font-size="11" class="dg-muted">Helm, Kustomize</text></g>
<g><rect x="306" y="70" width="136" height="72" rx="12" fill="#7c3aed" fill-opacity=".18" stroke="#7c3aed" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0;1" keyTimes="0;0.2097;0.4355;0.6532;0.7661;0.879" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/></rect><rect x="310" y="74" width="128" height="64" rx="9" class="dg-box" stroke="#7c3aed" stroke-width="2.2"/><text x="374" y="95" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Controller</text><text x="374" y="110.5" text-anchor="middle" font-size="11" class="dg-muted">compares Git</text><text x="374" y="125.5" text-anchor="middle" font-size="11" class="dg-muted">with the cluster</text></g>
<g><rect x="446" y="70" width="136" height="72" rx="12" fill="#2563eb" fill-opacity=".18" stroke="#2563eb" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.2097;0.3226;0.4355" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/></rect><rect x="450" y="74" width="128" height="64" rx="9" class="dg-box" stroke="#2563eb" stroke-width="2.2"/><text x="514" y="95" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Application</text><text x="514" y="110.5" text-anchor="middle" font-size="11" class="dg-muted">sync status</text><text x="514" y="125.5" text-anchor="middle" font-size="11" class="dg-muted">health status</text><g opacity="0"><animate attributeName="opacity" values="0;1;0;1;0;1;0" keyTimes="0;0.2097;0.3226;0.5403;0.6532;0.7661;0.879" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><rect x="450" y="74" width="128" height="64" rx="9" fill="#d97706"/><text x="514" y="110.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">OutOfSync</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3226;0.4355" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><rect x="450" y="74" width="128" height="64" rx="9" fill="#2563eb"/><text x="514" y="110.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">Syncing…</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0;1;0;1" keyTimes="0;0.4355;0.5403;0.6532;0.7661;0.879" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><rect x="450" y="74" width="128" height="64" rx="9" fill="#059669"/><text x="514" y="110.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">Synced · Healthy</text></g></g>
<rect x="170" y="200" width="128" height="64" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.3226" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><rect x="166" y="196" width="136" height="72" rx="12" fill="#0ea5e9" fill-opacity=".18" stroke="#0ea5e9" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0;1" keyTimes="0;0.3226;0.4355;0.5403;0.7661;0.879" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/></rect><rect x="170" y="200" width="128" height="64" rx="9" class="dg-box" stroke="#0ea5e9" stroke-width="2.2"/><text x="234" y="228.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Deployment</text><text x="234" y="244" text-anchor="middle" font-size="11" class="dg-muted">replicas: 2</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5403;0.6532" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><rect x="170" y="200" width="128" height="64" rx="9" fill="#d97706"/><text x="234" y="236.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">replicas: 1</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.879" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><rect x="170" y="200" width="128" height="64" rx="9" fill="#059669"/><text x="234" y="236.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">replicas: 4</text></g></g>
<rect x="310" y="200" width="128" height="64" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.3226" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><rect x="306" y="196" width="136" height="72" rx="12" fill="#10b981" fill-opacity=".18" stroke="#10b981" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.3226;0.5403;0.879" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/></rect><rect x="310" y="200" width="128" height="64" rx="9" class="dg-box" stroke="#10b981" stroke-width="2.2"/><text x="374" y="228.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Pods</text><text x="374" y="244" text-anchor="middle" font-size="11" class="dg-muted">2 running</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5403;0.6532" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><rect x="310" y="200" width="128" height="64" rx="9" fill="#d97706"/><text x="374" y="236.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">1 running</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.879" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><rect x="310" y="200" width="128" height="64" rx="9" fill="#059669"/><text x="374" y="236.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">4 running</text></g></g>
<rect x="450" y="200" width="128" height="64" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.3226" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><rect x="446" y="196" width="136" height="72" rx="12" fill="#059669" fill-opacity=".18" stroke="#059669" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3226;0.4355" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/></rect><rect x="450" y="200" width="128" height="64" rx="9" class="dg-box" stroke="#059669" stroke-width="2.2"/><text x="514" y="228.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Service</text><text x="514" y="244" text-anchor="middle" font-size="11" class="dg-muted">port 80</text></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0063;0.0902" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M72,35 L72,106" keyPoints="0;0;1;1" keyTimes="0;0.0063;0.0902;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1111;0.195" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M72,106 L234,106" keyPoints="0;0;1;1" keyTimes="0;0.1111;0.195;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2153;0.2548" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M234,106 L374,106" keyPoints="0;0;1;1" keyTimes="0;0.2153;0.2548;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2605;0.3113" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M374,106 L374,162 L234,162 L234,232" keyPoints="0;0;1;1" keyTimes="0;0.2605;0.3113;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3282;0.379" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M374,106 L374,162 L234,162 L234,232" keyPoints="0;0;1;1" keyTimes="0;0.3282;0.379;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3847;0.4242" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M234,232 L374,232" keyPoints="0;0;1;1" keyTimes="0;0.3847;0.4242;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4407;0.4827" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M374,106 L374,162 L234,162 L234,232" keyPoints="0;0;1;1" keyTimes="0;0.4407;0.4827;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4879;0.5246" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M374,106 L514,106" keyPoints="0;0;1;1" keyTimes="0;0.4879;0.5246;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5471;0.6374" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M72,232 L234,232" keyPoints="0;0;1;1" keyTimes="0;0.5471;0.6374;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><g><circle r="7" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M0,-3.5 V1 M0,3.2 V3.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6589;0.7006" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M234,232 L234,162 L374,162 L374,106" keyPoints="0;0;1;1" keyTimes="0;0.6589;0.7006;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7097;0.7548" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M374,106 L374,162 L234,162 L234,232" keyPoints="0;0;1;1" keyTimes="0;0.7097;0.7548;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7718;0.8113" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M72,35 L72,106" keyPoints="0;0;1;1" keyTimes="0;0.7718;0.8113;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8203;0.8655" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M72,106 L234,106" keyPoints="0;0;1;1" keyTimes="0;0.8203;0.8655;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8839;0.9153" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M234,106 L374,106" keyPoints="0;0;1;1" keyTimes="0;0.8839;0.9153;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.9202;0.9589" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M374,106 L374,162 L234,162 L234,232" keyPoints="0;0;1;1" keyTimes="0;0.9202;0.9589;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.9637;0.9903" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><animateMotion path="M234,232 L374,232" keyPoints="0;0;1;1" keyTimes="0;0.9637;0.9903;1" calcMode="linear" dur="24.8s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(21.2,310.5) scale(.8)"><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g><text x="33.4" y="314">manifests</text><g transform="translate(106.2,310.5) scale(.8)"><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g><text x="117.6" y="314">compare and status</text><g transform="translate(240.8,310.5) scale(.8)"><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g><text x="252.2" y="314">apply</text><g transform="translate(302.6,310.5) scale(.8)"><g><circle r="7" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M0,-3.5 V1 M0,3.2 V3.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/></g></g><text x="314" y="314">change by hand</text></g>
<rect x="12" y="326" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="326" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="24.8s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1048" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#ea580c"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="349" font-size="14" font-weight="800" fill="#ea580c">Git holds the desired state</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">First sync · 1/9</text><text x="60" y="370" font-size="12.5" class="dg-text">You commit the YAML or chart and push. Git now says what should run.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1048;0.2097" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#ea580c"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="349" font-size="14" font-weight="800" fill="#ea580c">The repo server renders it</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">First sync · 2/9</text><text x="60" y="370" font-size="12.5" class="dg-text">It fetches the folder and renders plain YAML, Helm or Kustomize.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2097;0.3226" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#ea580c"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="349" font-size="14" font-weight="800" fill="#ea580c">The controller compares Git with the cluster</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">First sync · 3/9</text><text x="60" y="370" font-size="12.5" class="dg-text">Nothing is running yet, so the Application shows OutOfSync.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3226;0.4355" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#ea580c"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="349" font-size="14" font-weight="800" fill="#ea580c">Sync applies the manifests</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">First sync · 4/9</text><text x="60" y="370" font-size="12.5" class="dg-text">argocd app sync, or auto-sync, creates the Deployment and the Service.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4355;0.5403" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#ea580c"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="349" font-size="14" font-weight="800" fill="#ea580c">Synced and Healthy</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">First sync · 5/9</text><text x="60" y="370" font-size="12.5" class="dg-text">Live matches Git, and the pods are running and ready.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5403;0.6532" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#e11d48"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="349" font-size="14" font-weight="800" fill="#e11d48">Someone changes the cluster by hand</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">Drift and self-heal · 6/9</text><text x="60" y="370" font-size="12.5" class="dg-text">kubectl scale --replicas=1 goes around Git. The cluster has drifted.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6532;0.7661" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#e11d48"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="349" font-size="14" font-weight="800" fill="#e11d48">Self-heal puts it back</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">Drift and self-heal · 7/9</text><text x="60" y="370" font-size="12.5" class="dg-text">With selfHeal: true, Argo CD sets replicas back to 2 within seconds.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7661;0.879" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#059669"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="349" font-size="14" font-weight="800" fill="#059669">A new commit in Git</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">A new commit · 8/9</text><text x="60" y="370" font-size="12.5" class="dg-text">You change replicas: 2 → 4. Argo CD polls Git every ~3 min, or a webhook.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.879" calcMode="discrete" dur="24.8s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#059669"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">9</text><text x="60" y="349" font-size="14" font-weight="800" fill="#059669">Auto-sync deploys it</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">A new commit · 9/9</text><text x="60" y="370" font-size="12.5" class="dg-text">4 pods, Synced and Healthy. The Git history is the deploy history.</text></g>
</svg>
```

### The problem it solves

Without GitOps, people deploy by running `kubectl` commands from their laptops. Soon nobody knows exactly what is running, who changed it, or how to go back to yesterday's version.

With GitOps:
- **Every change is a Git commit**, so you know who changed what, when, and why.
- **Going back is easy:** undo the commit, and the cluster follows.
- **Manual changes are undone:** if someone edits the cluster by hand, Argo CD puts it back to match Git.

### A real-life comparison

Think of an **architect's blueprint** and a **site supervisor**. The blueprint (Git) says exactly how the building should look. The supervisor (Argo CD) walks around all day comparing the building with the blueprint. If a wall is in the wrong place, the supervisor fixes it. If you want a change, you update the blueprint first, and the supervisor makes it happen.

### How it works

```text
 You edit YAML ─commit/push─▶ Git repository  (what SHOULD run)
                                     ▲
                                     │ Argo CD checks every few minutes
                                     │
                              Argo CD (inside the cluster)
                                     │ applies changes, fixes differences
                                     ▼
                              Kubernetes cluster  (what IS running)
```

### Key words

| Word | Simple meaning |
|---|---|
| **GitOps** | Running your system by changing files in Git |
| **Repository (repo)** | A project folder stored in Git, for example on GitHub |
| **Commit / push** | Save a change in Git / upload it to GitHub |
| **Application** | Argo CD's link between "this folder in Git" and "this place in the cluster" |
| **Sync** | Make the cluster match Git |
| **Synced / OutOfSync** | The cluster matches Git / doesn't match yet |
| **Healthy / Degraded** | The app is working / something is broken |
| **Drift** | A difference caused by someone changing the cluster by hand |
| **Self-heal** | Argo CD automatically undoing drift |

### Check yourself

1. In GitOps, how do you deploy a new version of an app?
2. What happens if someone changes the cluster by hand, with self-heal on?
3. How do you roll back a bad deploy?

> **Tip:** Answers: 1) Change the files in Git (for example the image tag) and push; Argo CD deploys it. 2) Argo CD puts it back to match Git. 3) Revert the Git commit; Argo CD follows.

## GitOps concepts

> **In simple words:** GitOps means Git is the single source of truth: the cluster always copies what Git says, never the other way round.

```text
 Developer ──PR──▶ Git repo (desired state) ◀──watches/pulls── Argo CD (in cluster)
                                                                    │ applies + reports drift
                                                                    ▼
                                                             Kubernetes cluster
```

| Push-based CD (classic pipeline) | Pull-based GitOps (Argo CD) |
|---|---|
| CI holds cluster credentials | Credentials never leave the cluster |
| Manual `kubectl` changes go unnoticed | Drift is detected and can be auto-reverted |
| Hard to know what's deployed | Git history *is* the deployment history |
| Rollback means re-running an old pipeline | Rollback means `git revert` |

The four GitOps principles: **declarative**, **versioned and immutable** (in Git), **pulled automatically**, **continuously reconciled**.

Key Argo CD terms:

| Term | Meaning |
|---|---|
| **Application** | A CRD linking a Git *source* (repo + path + revision) to a *destination* (cluster + namespace) |
| **Sync** | Apply what's in Git to the cluster |
| **Sync status** | `Synced` or `OutOfSync`: does the cluster match Git? |
| **Health status** | `Healthy`, `Progressing` or `Degraded`: are the resources actually working? |
| **Project** | Groups apps and restricts which repos and destinations they may use |

## Install Argo CD

> **In simple words:** Install Argo CD into your cluster. It runs as a few small apps inside Kubernetes itself.

> **Tip:** Installing on **EKS** with a **Bitbucket** repository? Follow the step-by-step [Argo CD on EKS runbook](#/tool/argocd-eks): CLI, install, login, internal load balancer, SSH repo access and a Helm Application.

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl -n argocd rollout status deploy/argocd-server
kubectl get pods -n argocd
```

You should see the `argocd-server`, `argocd-repo-server`, `argocd-application-controller`, `argocd-redis` and `argocd-dex-server` pods running.

> **Tip:** For production, install with the official Helm chart (`helm repo add argo https://argoproj.github.io/argo-helm`, then `helm install argocd argo/argo-cd -n argocd`) so Argo CD's own config lives in Git too.

## Installation methods compared

> **In simple words:** There are several ways to install Argo CD. They differ in how much is included (web UI or not), how resilient it is, and how you manage its settings. Pick one based on where you are: laptop, team cluster, or production.

| Method | What you get | Use it for |
|---|---|---|
| **Standard manifest** (`install.yaml`) | Everything (UI, API, SSO server) with one copy of each component | Learning, small clusters. This is what the previous step installed |
| **High availability** (`ha/install.yaml`) | Several copies of each component plus Redis HA | Production. Needs **3 or more nodes** |
| **Core only** (`core-install.yaml`) | Just the GitOps engine: **no web UI, no API server, no SSO** | Small or locked-down clusters managed by platform teams with `kubectl` |
| **Helm chart** (`argo/argo-cd`) | Same components, fully configurable through a values file | Teams that manage Argo CD's own settings in Git (recommended) |

### Pin a version

`stable` always means "the latest release", which changes under you. In real environments, install a **specific version** so upgrades are deliberate:

```bash
ARGOCD_VERSION=v3.5.6     # check https://github.com/argoproj/argo-cd/releases
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml
```

### High availability

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/ha/install.yaml
```

### Core only (no UI)

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/core-install.yaml

# Use the CLI directly against Kubernetes (no API server needed)
kubectl config set-context --current --namespace=argocd
argocd login --core
argocd app list
argocd admin dashboard -n argocd     # temporary local UI at http://localhost:8080
```

### Helm chart (recommended for teams)

Put the settings in a `values.yaml` file, commit it, and install:

```yaml
global:
  domain: argocd.example.com          # the URL people will use

configs:
  params:
    server.insecure: true             # TLS is handled by the Ingress in front

server:
  ingress:
    enabled: true
    ingressClassName: nginx

# For production HA, also scale controller, repoServer and server replicas and enable redis-ha
```

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm search repo argo/argo-cd --versions | head -5        # pick a chart version to pin
helm upgrade --install argocd argo/argo-cd \
  -n argocd --create-namespace -f values.yaml --version <CHART_VERSION>
```

### How to reach the UI

| Option | Command | When |
|---|---|---|
| Port-forward | `kubectl port-forward svc/argocd-server -n argocd 8080:443` | Laptops and quick access. Nothing exposed |
| LoadBalancer | `kubectl patch svc argocd-server -n argocd -p '{"spec":{"type":"LoadBalancer"}}'` | Cloud clusters (on EKS this creates an AWS load balancer, which costs money) |
| Ingress | Helm `server.ingress.enabled: true`, or your own Ingress | Teams: a proper URL with TLS and SSO |

### Upgrade and uninstall

```bash
# Upgrade: apply the newer version's manifest (read the release notes first)
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/<NEW_VERSION>/manifests/install.yaml

# Uninstall: delete your Applications first, then Argo CD itself
kubectl delete applications --all -n argocd
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml
kubectl delete namespace argocd
# (Helm installs: helm uninstall argocd -n argocd)
```

> **Tip:** Once Argo CD is installed, it can manage **itself**: create an Application that points at your Helm values in Git, and upgrades become a pull request. Tools like **Argo CD Autopilot** set this up for you.

Official docs: [Installation](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/)

## Access the UI and CLI

> **In simple words:** Open Argo CD's web dashboard and log in, and connect the `argocd` command, so you can watch and control deployments.

```bash
# 1. Port-forward the API/UI (leave running in a separate terminal)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 2. Get the initial admin password
argocd admin initial-password -n argocd

# 3. Log in with the CLI
argocd login localhost:8080 --username admin --insecure
argocd account update-password
```

Open **https://localhost:8080** (accept the self-signed certificate) and log in as `admin`.

> **Warning:** After changing the password, delete the bootstrap secret: `kubectl -n argocd delete secret argocd-initial-admin-secret`. In real environments, disable `admin` and use SSO.

## Prepare a GitOps repository

> **In simple words:** Create a Git repository holding the Kubernetes files for your app. This is the "blueprint" Argo CD will follow.

Create a new GitHub repository, for example `gitops-lab`, with this layout:

```text
gitops-lab/
├── apps/                     # Argo CD Application manifests
│   └── guestbook.yaml
├── guestbook/                # plain manifests for one app
│   ├── deployment.yaml
│   └── service.yaml
└── envs/                     # Kustomize overlays (later step)
```

```bash
git clone git@github.com:<you>/gitops-lab.git && cd gitops-lab
mkdir -p apps guestbook
```

`guestbook/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: guestbook
spec:
  replicas: 2
  selector:
    matchLabels:
      app: guestbook
  template:
    metadata:
      labels:
        app: guestbook
    spec:
      containers:
        - name: guestbook
          image: gcr.io/heptio-images/ks-guestbook-demo:0.2
          ports:
            - containerPort: 80
```

`guestbook/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: guestbook
spec:
  selector:
    app: guestbook
  ports:
    - port: 80
      targetPort: 80
```

```bash
git add . && git commit -m "Add guestbook manifests" && git push
```

> **Tip:** Many companies keep **application source code** and **deployment manifests** in separate repos. CI builds the image, then commits the new image tag to the GitOps repo, and Argo CD deploys it.

## Your first Application

> **In simple words:** Tell Argo CD "deploy the files in this Git folder into this namespace", then watch it create your app.

Define the Application declaratively, so it can live in Git as well. `apps/guestbook.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<you>/gitops-lab.git
    targetRevision: main
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: guestbook
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

```bash
kubectl apply -f apps/guestbook.yaml
argocd app get guestbook          # Status: OutOfSync (nothing deployed yet)
argocd app sync guestbook         # deploy
argocd app wait guestbook --health
kubectl get all -n guestbook
```

Watch the resource tree appear in the UI. Now make a **GitOps change**: edit `replicas: 2` → `replicas: 4`, commit and push, then:

```bash
argocd app diff guestbook
argocd app sync guestbook
```

The CLI equivalent of the YAML, useful for quick experiments:

```bash
argocd app create guestbook --repo https://github.com/<you>/gitops-lab.git --path guestbook \
  --dest-server https://kubernetes.default.svc --dest-namespace guestbook --sync-option CreateNamespace=true
```

## Automated sync, prune and self-heal

> **In simple words:** Switch on autopilot: Argo CD deploys new commits by itself, deletes things removed from Git, and undoes manual changes.

Manual sync is good for learning. Real GitOps is automatic. Update `syncPolicy`:

```yaml
  syncPolicy:
    automated:
      prune: true      # delete resources removed from Git
      selfHeal: true   # revert manual changes made in the cluster
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 10s
        factor: 2
        maxDuration: 3m
```

```bash
kubectl apply -f apps/guestbook.yaml
```

Test self-heal by going around Git:

```bash
kubectl scale deploy guestbook -n guestbook --replicas=1
kubectl get deploy guestbook -n guestbook -w
# Argo CD sets it back to the Git value within seconds
```

> **Why:** Self-heal enforces "Git is the only way to change production". Manual hotfixes get reverted, so they have to go through a pull request.

Argo CD polls Git every ~3 minutes by default. Configure a **webhook** from GitHub to `https://<argocd>/api/webhook` for instant syncs.

## Helm and Kustomize sources

> **In simple words:** Argo CD can also deploy ready-made Helm packages, and Kustomize lets you keep one base setup with small changes per environment (dev vs prod).

### Helm chart from a repository

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: redis
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.bitnami.com/bitnami
    chart: redis
    targetRevision: 20.*            # chart version
    helm:
      valuesObject:
        architecture: standalone
        auth:
          enabled: false
  destination:
    server: https://kubernetes.default.svc
    namespace: data
  syncPolicy:
    automated: { prune: true, selfHeal: true }
    syncOptions: [CreateNamespace=true]
```

### Kustomize overlays per environment

Kustomize patches a shared **base** for each environment, without templates:

```text
envs/
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
├── dev/
│   └── kustomization.yaml
└── prod/
    └── kustomization.yaml
```

`envs/base/kustomization.yaml`:

```yaml
resources:
  - deployment.yaml
  - service.yaml
```

`envs/prod/kustomization.yaml`:

```yaml
resources:
  - ../base
namespace: guestbook-prod
replicas:
  - name: guestbook
    count: 5
images:
  - name: gcr.io/heptio-images/ks-guestbook-demo
    newTag: "0.2"
```

```bash
kubectl kustomize envs/prod     # preview the rendered output
```

Point an Application's `path` at `envs/prod`. Argo CD detects Kustomize automatically.

## App of Apps and ApplicationSets

> **In simple words:** Ways to manage many apps at once: one "parent" app that creates all the others, or a template that creates an app per folder or cluster.

Managing dozens of Application objects by hand doesn't scale.

### App of Apps

One "root" Application points at the `apps/` folder, which contains other Application manifests. Bootstrap the cluster once, and everything else comes from Git:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<you>/gitops-lab.git
    targetRevision: main
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated: { prune: true, selfHeal: true }
```

### ApplicationSet

Generate Applications from a template, here one per environment folder:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: guestbook-envs
  namespace: argocd
spec:
  goTemplate: true
  generators:
    - git:
        repoURL: https://github.com/<you>/gitops-lab.git
        revision: main
        directories:
          - path: envs/*
          - path: envs/base
            exclude: true
  template:
    metadata:
      name: 'guestbook-{{.path.basename}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/<you>/gitops-lab.git
        targetRevision: main
        path: '{{.path.path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: 'guestbook-{{.path.basename}}'
      syncPolicy:
        automated: { prune: true, selfHeal: true }
        syncOptions: [CreateNamespace=true]
```

Add a new folder under `envs/`, and a new environment deploys automatically. Other generators: **list**, **cluster** (one app per registered cluster), **pull request** (preview environments).

## Private repos, projects and access

> **In simple words:** Connect private Git repositories and other clusters, and limit what each team is allowed to deploy, and where.

```bash
# Private Git repo over SSH
argocd repo add git@github.com:<org>/gitops-private.git --ssh-private-key-path ~/.ssh/argocd_deploy_key

# Register another cluster (e.g. EKS) - Argo CD installs a service account there
argocd cluster add <kube-context-name>
argocd cluster list
```

Restrict teams with an **AppProject**:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-a
  namespace: argocd
spec:
  description: Team A apps
  sourceRepos:
    - https://github.com/<org>/team-a-*
  destinations:
    - server: https://kubernetes.default.svc
      namespace: team-a-*
  clusterResourceWhitelist: []      # no cluster-scoped resources
```

Production checklist: SSO (OIDC with Okta, Entra ID or Google) via `argocd-cm`, RBAC in `argocd-rbac-cm`, admin disabled, TLS Ingress for the UI, and notifications (Slack/Teams) via **argocd-notifications**.

## Rollback and troubleshooting

> **In simple words:** How to go back to a previous version (undo the commit), and how to find out why an app won't sync or isn't healthy.

### Rolling back

The GitOps way is to revert the commit:

```bash
git revert <bad-commit-sha> && git push   # Argo CD syncs the previous state
```

For an emergency (auto-sync must be disabled first, or self-heal undoes it):

```bash
argocd app history guestbook
argocd app rollback guestbook <history-id>
```

### Troubleshooting

| Symptom | Check |
|---|---|
| `OutOfSync` forever | `argocd app diff <app>`. Often a field mutated by a controller. Use `ignoreDifferences`. |
| `ComparisonError` / repo errors | Wrong `repoURL` or `path`, or private repo not added. `argocd repo list` |
| `Degraded` health | It's the workload: `kubectl describe` / `logs` the failing pods |
| Sync stuck on a resource | A finalizer or hook is waiting. Check the app's events in the UI |
| Changes not picked up | Polling delay. `argocd app get <app> --refresh` or add a webhook |

```bash
argocd app list
argocd app get guestbook --show-operation
kubectl logs -n argocd deploy/argocd-repo-server
kubectl logs -n argocd statefulset/argocd-application-controller
```

## Sample application flow: from commit to running pod

> **In simple words:** This step connects everything. A developer changes the app, the **CI tool** (Jenkins, GitHub Actions or GitLab) tests it and builds a new image, CI writes the new image tag into the **GitOps repo**, and **Argo CD** deploys it to Kubernetes. Nobody runs `kubectl` by hand.

```text
 1. developer pushes code to hello-app
      │
      ▼
 2. CI (GitHub Actions / GitLab CI / Jenkins)
      test → build image → push to registry (ghcr.io / GitLab / Docker Hub)
      │
      ▼
 3. CI commits the new image tag to the gitops repo
      apps/hello/overlays/dev/kustomization.yaml   newTag: sha-1a2b3c4
      │
      ▼
 4. Argo CD notices the commit (polls ~3 min, or instantly with a webhook)
      │
      ▼
 5. Argo CD syncs → Kubernetes rolling update → new pods with the new image
      │
      ▼
 6. verify:  curl → {"version": "1a2b3c4…"}      rollback: git revert in gitops
```

You need: the kind cluster with Argo CD from earlier, the **sample app** from [CI/CD Basics](#/tool/cicd-basics), and a CI pipeline that pushes its image from one of the [GitHub Actions](#/tool/github-actions), [GitLab CI](#/tool/gitlab-ci) or [Jenkins](#/tool/jenkins) guides.

### 1. Create the GitOps repository

Create a new repo called `gitops` (on GitHub or GitLab) with this layout:

```text
gitops/
├── apps/
│   └── hello/
│       ├── base/
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   └── kustomization.yaml
│       └── overlays/
│           └── dev/
│               └── kustomization.yaml   ◀ CI changes the image tag here
└── argocd/
    └── hello-dev.yaml                   ◀ the Argo CD Application
```

`apps/hello/base/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello
  template:
    metadata:
      labels:
        app: hello
    spec:
      containers:
        - name: hello
          image: hello-app            # placeholder: the overlay sets the real image and tag
          ports:
            - containerPort: 8000
          readinessProbe:
            httpGet:
              path: /health
              port: 8000
          livenessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 10
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              memory: 128Mi
```

`apps/hello/base/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: hello
spec:
  selector:
    app: hello
  ports:
    - port: 80
      targetPort: 8000
```

`apps/hello/base/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
```

`apps/hello/overlays/dev/kustomization.yaml`. Set `newName` to **your** registry path, and `newTag` to a tag that already exists:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: hello-dev
resources:
  - ../../base
images:
  - name: hello-app
    newName: ghcr.io/<you>/hello-app          # GitLab: registry.gitlab.com/<you>/hello-app · Docker Hub: <user>/hello-app
    newTag: sha-1a2b3c4                       # CI updates this line
```

Check that it renders before committing:

```bash
kubectl kustomize apps/hello/overlays/dev | grep image:
```

### 2. Create the Argo CD Application

`argocd/hello-dev.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: hello-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<you>/gitops.git
    targetRevision: main
    path: apps/hello/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: hello-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

```bash
git add . && git commit -m "hello app: base, dev overlay, Argo CD application" && git push
kubectl apply -f argocd/hello-dev.yaml
argocd app wait hello-dev --health --timeout 180
kubectl get pods -n hello-dev
```

> **Note:** If the image is in a **private** registry, the cluster needs pull credentials. The easiest fix for learning is to make the GHCR package public (package → **Package settings → Change visibility**). Otherwise create a secret with `kubectl create secret docker-registry regcred -n hello-dev --docker-server=… --docker-username=… --docker-password=<token>`, and add `imagePullSecrets: [{name: regcred}]` to the pod spec.

### 3. Connect your CI tool

Add the "hand over to Argo CD" job from your CI guide. Each one updates `apps/hello/overlays/dev/kustomization.yaml` with `kustomize edit set image`:

| CI tool | Job to add | Tag it writes |
|---|---|---|
| GitHub Actions | `bump-gitops` in the [GitHub Actions guide](#/tool/github-actions) | `ghcr.io/<you>/hello-app:sha-<short>` |
| GitLab CI | `bump-gitops` in the [GitLab guide](#/tool/gitlab-ci) | `registry.gitlab.com/<you>/hello-app:<short-sha>` |
| Jenkins | Add a stage after **Push** that clones `gitops`, runs `kustomize edit set image …:$BUILD_NUMBER`, commits and pushes (store a Git token as a Jenkins credential) | `<user>/hello-app:<build-number>` |

### 4. Make a change and watch it flow

```bash
cd ~/code/hello-app
sed -i 's/Hello from CI\/CD!/Hello from GitOps!/' app.py test_app.py
git commit -am "New greeting" && git push
```

Now follow it through each stage:

| Where | What you should see |
|---|---|
| CI tool | Pipeline runs: tests ✓, image pushed ✓, gitops bumped ✓ |
| `gitops` repo history | A new commit: *"hello-app: deploy sha-…"* |
| Argo CD UI | `hello-dev` goes **OutOfSync → Syncing → Synced, Healthy** |
| Cluster | New pods replace old ones: `kubectl get pods -n hello-dev -w` |

Don't want to wait for the ~3 minute poll? Run `argocd app get hello-dev --refresh`.

Verify the new version is live:

```bash
kubectl port-forward -n hello-dev svc/hello 8081:80 &
curl -s localhost:8081/        # {"message": "Hello from GitOps!", "version": "<new sha>", ...}
kill %1
```

### 5. Roll back

The new version is broken? Undo the deploy commit in the **gitops** repo, not in the cluster:

```bash
cd ~/code/gitops
git pull
git log --oneline -3                 # find the "hello-app: deploy …" commit
git revert --no-edit HEAD && git push
argocd app get hello-dev --refresh   # Argo CD rolls the pods back to the previous image
```

The app code in `hello-app` is untouched. Fix it at your own pace, and the next CI run deploys the fix.

### 6. Promote to production

Add `apps/hello/overlays/prod/kustomization.yaml` (namespace `hello-prod`, `replicas` patched to 3) and an Application `hello-prod`. Promotion is then **a pull request that copies the tested tag** from `overlays/dev` to `overlays/prod`. The review is your approval gate, and Git records who promoted what and when.

> **Tip:** Instead of CI committing tags, **Argo CD Image Updater** can watch the registry and update tags for you. It's handy when you have many apps, but the explicit CI commit shown here is easier to understand and debug.

## Lab: full GitOps loop

> **In simple words:** Practice time: deploy your own app the GitOps way, from a Git push all the way to a running app.

1. Install Argo CD on your kind cluster and log in with the CLI.
2. In your GitOps repo, add your Helm chart from the Kubernetes lab, or plain manifests for your `hello-docker` image.
3. Create a **root app-of-apps** that deploys your app *and* Redis (Helm source).
4. Enable automated sync with prune and self-heal. Prove self-heal by deleting a Deployment by hand.
5. Add `envs/dev` and `envs/prod` Kustomize overlays and deploy both with an **ApplicationSet**.
6. Push a bad image tag, watch the app go `Degraded`, then fix it with `git revert`.
7. Bonus: write a GitHub Actions workflow that builds the image and commits the new tag to the GitOps repo.

### Cheat sheet

| Task | Command |
|---|---|
| Login | `argocd login localhost:8080 --insecure` |
| List apps | `argocd app list` |
| App details | `argocd app get <app>` |
| Diff vs Git | `argocd app diff <app>` |
| Sync now | `argocd app sync <app>` |
| Force refresh from Git | `argocd app get <app> --refresh` |
| History / rollback | `argocd app history <app>` / `argocd app rollback <app> <id>` |
