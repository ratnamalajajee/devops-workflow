# Kubernetes

Kubernetes (K8s) runs containers across many machines. It keeps the right number of copies running, replaces failed ones, rolls out new versions with zero downtime, and routes traffic to them. You describe the **desired state** in YAML, and Kubernetes continuously works to make reality match.

> **Note:** Learn on a free local cluster with **kind** first. Every command here works the same on EKS later.

> **Tip:** No Docker or Kubernetes on your laptop? Use the **cloud lab machine** in the [Practice lab](#/lab). It has Docker, kind, kubectl, Helm, Terraform, the AWS CLI and the Argo CD CLI ready to go.

## Start here: Kubernetes in simple words

> **In simple words:** Docker runs a container on **one** computer. Kubernetes runs **many** containers across **many** computers, and keeps them healthy: it restarts crashed ones, adds more when traffic grows, and sends visitors to the healthy ones.

### Watch how it works

```svg Watch it work: kubectl apply turning into running pods, a user reaching them through the Ingress and the Service, and a deleted pod being replaced. The animation loops.
<svg viewBox="0 0 600 458" role="img" data-anim="kubernetes" aria-label="Animated Kubernetes flow on a local kind cluster called lab. Deploy: you run kubectl apply -f deployment.yaml. The API server checks the Deployment and saves it in etcd, the store for the cluster&#x27;s desired state. The controllers see it: the Deployment makes a ReplicaSet, and the ReplicaSet creates 3 pods, which are Pending because they have no node yet. The scheduler picks a worker node with enough free CPU and memory for each pod. The kubelet on that node sees its new pods and tells the container runtime, containerd, to pull the image hashicorp/http-echo:1.0 from the registry and start it. The kubelet checks each pod&#x27;s readiness probe, and Ready pods can get traffic. A user visits: a request for web.localtest.me reaches the Ingress, the nginx Ingress controller matches the host and sends it to Service web on port 80. The Service is one stable name in front of the 3 pods; it picks a Ready pod on port 8080, and the reply goes back the same way. Self-healing: a pod is deleted, or its node fails, and the Service stops sending it traffic. The ReplicaSet sees 2 pods instead of 3 and creates a new one, which is scheduled, started and becomes Ready.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<rect x="134" y="8" width="306" height="136" rx="12" fill="none" stroke="#3b82f6" stroke-width="1.5" stroke-dasharray="5 4"/>
<rect x="134" y="156" width="454" height="146" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.3" stroke-dasharray="3 4"/>
<polyline points="67,118 215,118" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="215,118 361,118" fill="none" stroke-linejoin="round" stroke="#0d9488" stroke-width="1.8" stroke-dasharray="6 3" stroke-opacity=".7"/>
<polyline points="215,76 215,96" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="361,54 288,57 288,118 215,118" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="1.6" stroke-opacity=".8"/>
<polyline points="245,118 245,203" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="215,203 361,203" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="361,203 521,203 521,62" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="215,203 215,274" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="1.6" stroke-opacity=".8"/>
<polyline points="215,238 507,238 507,274" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="1.6" stroke-opacity=".8"/>
<polyline points="361,203 361,274" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="1.6" stroke-opacity=".8"/>
<polyline points="67,340 215,340 434,340" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="434,340 434,308" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="215,294 215,308 507,308 507,294" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="361,308 361,294" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<rect x="140" y="14" width="84.7" height="16" rx="5" class="dg-box"/><text x="144" y="24" font-size="11" class="dg-muted">control plane</text>
<rect x="140" y="162" width="78.8" height="16" rx="5" class="dg-box"/><text x="144" y="172" font-size="11" class="dg-muted">worker nodes</text>
<g><rect x="8" y="91" width="118" height="54" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.112" calcMode="discrete" dur="25s" repeatCount="indefinite"/></rect><rect x="12" y="95" width="110" height="46" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="67" y="114.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">You</text><text x="67" y="130" text-anchor="middle" font-size="11" class="dg-muted">kubectl apply</text></g>
<g><rect x="146" y="28" width="138" height="52" rx="12" fill="#7c3aed" fill-opacity=".18" stroke="#7c3aed" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.112;0.224;0.88" calcMode="discrete" dur="25s" repeatCount="indefinite"/></rect><rect x="150" y="32" width="130" height="44" rx="9" class="dg-box" stroke="#7c3aed" stroke-width="2.2"/><text x="215" y="50.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Controllers</text><text x="215" y="66" text-anchor="middle" font-size="11" class="dg-muted">keep 3 replicas</text></g>
<g><rect x="146" y="92" width="138" height="52" rx="12" fill="#2563eb" fill-opacity=".18" stroke="#2563eb" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.112" calcMode="discrete" dur="25s" repeatCount="indefinite"/></rect><rect x="150" y="96" width="130" height="44" rx="9" class="dg-box" stroke="#2563eb" stroke-width="2.2"/><text x="215" y="114.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">API server</text><text x="215" y="130" text-anchor="middle" font-size="11" class="dg-muted">the front door</text></g>
<g><rect x="292" y="28" width="138" height="52" rx="12" fill="#c026d3" fill-opacity=".18" stroke="#c026d3" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.224;0.328" calcMode="discrete" dur="25s" repeatCount="indefinite"/></rect><rect x="296" y="32" width="130" height="44" rx="9" class="dg-box" stroke="#c026d3" stroke-width="2.2"/><text x="361" y="50.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Scheduler</text><text x="361" y="66" text-anchor="middle" font-size="11" class="dg-muted">picks a node</text></g>
<g><rect x="292" y="92" width="138" height="52" rx="12" fill="#0d9488" fill-opacity=".18" stroke="#0d9488" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.112" calcMode="discrete" dur="25s" repeatCount="indefinite"/></rect><rect x="296" y="96" width="130" height="44" rx="9" class="dg-box" stroke="#0d9488" stroke-width="2.2"/><text x="361" y="114.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">etcd</text><text x="361" y="130" text-anchor="middle" font-size="11" class="dg-muted">desired state</text></g>
<g><rect x="450" y="28" width="142" height="68" rx="12" fill="#f97316" fill-opacity=".18" stroke="#f97316" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.328;0.448" calcMode="discrete" dur="25s" repeatCount="indefinite"/></rect><rect x="454" y="32" width="134" height="60" rx="9" class="dg-box" stroke="#f97316" stroke-width="2.2"/><text x="521" y="51" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Image registry</text><text x="521" y="66.5" text-anchor="middle" font-size="11" class="dg-muted">Docker Hub</text><text x="521" y="81.5" text-anchor="middle" font-size="11" class="dg-muted">http-echo:1.0</text></g>
<g><rect x="146" y="180" width="138" height="46" rx="12" fill="#0ea5e9" fill-opacity=".18" stroke="#0ea5e9" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.328;0.552" calcMode="discrete" dur="25s" repeatCount="indefinite"/></rect><rect x="150" y="184" width="130" height="38" rx="9" class="dg-box" stroke="#0ea5e9" stroke-width="2.2"/><text x="215" y="199.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">kubelet</text><text x="215" y="215" text-anchor="middle" font-size="11" class="dg-muted">node agent</text></g>
<g><rect x="292" y="180" width="138" height="46" rx="12" fill="#0891b2" fill-opacity=".18" stroke="#0891b2" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.328;0.448" calcMode="discrete" dur="25s" repeatCount="indefinite"/></rect><rect x="296" y="184" width="130" height="38" rx="9" class="dg-box" stroke="#0891b2" stroke-width="2.2"/><text x="361" y="199.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">containerd</text><text x="361" y="215" text-anchor="middle" font-size="11" class="dg-muted">runs containers</text></g>
<rect x="150" y="254" width="130" height="40" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.112" calcMode="discrete" dur="25s" repeatCount="indefinite"/><rect x="146" y="250" width="138" height="48" rx="12" fill="#10b981" fill-opacity=".18" stroke="#10b981" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.112;0.224;0.448;0.552" calcMode="discrete" dur="25s" repeatCount="indefinite"/></rect><rect x="150" y="254" width="130" height="40" rx="9" class="dg-box" stroke="#10b981" stroke-width="2.2"/><text x="215" y="270.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Pod web</text><text x="215" y="286" text-anchor="middle" font-size="11" class="dg-muted">container :8080</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.112;0.328" calcMode="discrete" dur="25s" repeatCount="indefinite"/><rect x="150" y="254" width="130" height="40" rx="9" fill="#64748b"/><text x="215" y="278.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">Pending</text></g></g>
<rect x="296" y="254" width="130" height="40" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.112" calcMode="discrete" dur="25s" repeatCount="indefinite"/><rect x="292" y="250" width="138" height="48" rx="12" fill="#10b981" fill-opacity=".18" stroke="#10b981" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0;1;0" keyTimes="0;0.112;0.224;0.448;0.552;0.656;0.776" calcMode="discrete" dur="25s" repeatCount="indefinite"/></rect><rect x="296" y="254" width="130" height="40" rx="9" class="dg-box" stroke="#10b981" stroke-width="2.2"/><text x="361" y="270.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Pod web</text><text x="361" y="286" text-anchor="middle" font-size="11" class="dg-muted">container :8080</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.112;0.328" calcMode="discrete" dur="25s" repeatCount="indefinite"/><rect x="296" y="254" width="130" height="40" rx="9" fill="#64748b"/><text x="361" y="278.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">Pending</text></g></g>
<rect x="442" y="254" width="130" height="40" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.112" calcMode="discrete" dur="25s" repeatCount="indefinite"/><rect x="438" y="250" width="138" height="48" rx="12" fill="#10b981" fill-opacity=".18" stroke="#10b981" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0;1" keyTimes="0;0.112;0.224;0.448;0.552;0.776" calcMode="discrete" dur="25s" repeatCount="indefinite"/></rect><rect x="442" y="254" width="130" height="40" rx="9" class="dg-box" stroke="#10b981" stroke-width="2.2"/><text x="507" y="270.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Pod web</text><text x="507" y="286" text-anchor="middle" font-size="11" class="dg-muted">container :8080</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.112;0.328" calcMode="discrete" dur="25s" repeatCount="indefinite"/><rect x="442" y="254" width="130" height="40" rx="9" fill="#64748b"/><text x="507" y="278.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">Pending</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.776;0.88" calcMode="discrete" dur="25s" repeatCount="indefinite"/><rect x="442" y="254" width="130" height="40" rx="9" fill="#e11d48"/><text x="507" y="278.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">✕ deleted</text></g></g>
<g><rect x="8" y="314" width="118" height="52" rx="12" fill="#6366f1" fill-opacity=".18" stroke="#6366f1" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.552;0.656" calcMode="discrete" dur="25s" repeatCount="indefinite"/></rect><rect x="12" y="318" width="110" height="44" rx="9" class="dg-box" stroke="#6366f1" stroke-width="2.2"/><text x="67" y="336.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Browser</text><text x="67" y="352" text-anchor="middle" font-size="11" class="dg-muted">web.localtest.me</text></g>
<g><rect x="146" y="314" width="138" height="52" rx="12" fill="#d97706" fill-opacity=".18" stroke="#d97706" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.552;0.656" calcMode="discrete" dur="25s" repeatCount="indefinite"/></rect><rect x="150" y="318" width="130" height="44" rx="9" class="dg-box" stroke="#d97706" stroke-width="2.2"/><text x="215" y="336.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Ingress</text><text x="215" y="352" text-anchor="middle" font-size="11" class="dg-muted">nginx, by host</text></g>
<g><rect x="292" y="314" width="284" height="52" rx="12" fill="#059669" fill-opacity=".18" stroke="#059669" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.552;0.776" calcMode="discrete" dur="25s" repeatCount="indefinite"/></rect><rect x="296" y="318" width="276" height="44" rx="9" class="dg-box" stroke="#059669" stroke-width="2.2"/><text x="434" y="336.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Service web</text><text x="434" y="352" text-anchor="middle" font-size="11" class="dg-muted">one stable name · port 80 → 8080</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.448" calcMode="discrete" dur="25s" repeatCount="indefinite"/><circle cx="280" cy="254" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M275.5,254 L279,257.5 L284.5,250.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.448" calcMode="discrete" dur="25s" repeatCount="indefinite"/><circle cx="426" cy="254" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M421.5,254 L425,257.5 L430.5,250.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.448;0.776;0.88" calcMode="discrete" dur="25s" repeatCount="indefinite"/><circle cx="572" cy="254" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M567.5,254 L571,257.5 L576.5,250.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.776;0.88" calcMode="discrete" dur="25s" repeatCount="indefinite"/><circle cx="507" cy="308" r="9.5" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M503,304 L511,312 M511,304 L503,312" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0056;0.0504" calcMode="discrete" dur="25s" repeatCount="indefinite"/><animateMotion path="M67,118 L215,118" keyPoints="0;0;1;1" keyTimes="0;0.0056;0.0504;1" calcMode="linear" dur="25s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.056;0.1008" calcMode="discrete" dur="25s" repeatCount="indefinite"/><animateMotion path="M215,118 L361,118" keyPoints="0;0;1;1" keyTimes="0;0.056;0.1008;1" calcMode="linear" dur="25s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1176;0.1568" calcMode="discrete" dur="25s" repeatCount="indefinite"/><animateMotion path="M215,118 L215,54" keyPoints="0;0;1;1" keyTimes="0;0.1176;0.1568;1" calcMode="linear" dur="25s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.168;0.2128" calcMode="discrete" dur="25s" repeatCount="indefinite"/><animateMotion path="M215,54 L215,118" keyPoints="0;0;1;1" keyTimes="0;0.168;0.2128;1" calcMode="linear" dur="25s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2302;0.3134" calcMode="discrete" dur="25s" repeatCount="indefinite"/><animateMotion path="M361,54 L288,57 L288,118 L215,118" keyPoints="0;0;1;1" keyTimes="0;0.2302;0.3134;1" calcMode="linear" dur="25s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3328;0.364" calcMode="discrete" dur="25s" repeatCount="indefinite"/><animateMotion path="M245,118 L245,203 L361,203" keyPoints="0;0;1;1" keyTimes="0;0.3328;0.364;1" calcMode="linear" dur="25s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3676;0.4024" calcMode="discrete" dur="25s" repeatCount="indefinite"/><animateMotion path="M521,62 L521,203 L361,203" keyPoints="0;0;1;1" keyTimes="0;0.3676;0.4024;1" calcMode="linear" dur="25s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4072;0.4408" calcMode="discrete" dur="25s" repeatCount="indefinite"/><animateMotion path="M361,203 L215,238 L215,274" keyPoints="0;0;1;1" keyTimes="0;0.4072;0.4408;1" calcMode="linear" dur="25s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4072;0.4408" calcMode="discrete" dur="25s" repeatCount="indefinite"/><animateMotion path="M361,203 L361,274" keyPoints="0;0;1;1" keyTimes="0;0.4072;0.4408;1" calcMode="linear" dur="25s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4072;0.4408" calcMode="discrete" dur="25s" repeatCount="indefinite"/><animateMotion path="M361,203 L361,238 L507,238 L507,274" keyPoints="0;0;1;1" keyTimes="0;0.4072;0.4408;1" calcMode="linear" dur="25s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4542;0.5374" calcMode="discrete" dur="25s" repeatCount="indefinite"/><animateMotion path="M215,203 L215,274" keyPoints="0;0;1;1" keyTimes="0;0.4542;0.5374;1" calcMode="linear" dur="25s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4542;0.5374" calcMode="discrete" dur="25s" repeatCount="indefinite"/><animateMotion path="M215,203 L215,238 L361,238 L361,274" keyPoints="0;0;1;1" keyTimes="0;0.4542;0.5374;1" calcMode="linear" dur="25s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4542;0.5374" calcMode="discrete" dur="25s" repeatCount="indefinite"/><animateMotion path="M215,203 L507,238 L507,274" keyPoints="0;0;1;1" keyTimes="0;0.4542;0.5374;1" calcMode="linear" dur="25s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5582;0.6414" calcMode="discrete" dur="25s" repeatCount="indefinite"/><animateMotion path="M67,340 L215,340 L434,340" keyPoints="0;0;1;1" keyTimes="0;0.5582;0.6414;1" calcMode="linear" dur="25s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6608;0.704" calcMode="discrete" dur="25s" repeatCount="indefinite"/><animateMotion path="M434,340 L434,308 L361,308 L361,274" keyPoints="0;0;1;1" keyTimes="0;0.6608;0.704;1" calcMode="linear" dur="25s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7136;0.77" calcMode="discrete" dur="25s" repeatCount="indefinite"/><animateMotion path="M361,274 L361,308 L434,308 L434,340 L215,340 L67,340" keyPoints="0;0;1;1" keyTimes="0;0.7136;0.77;1" calcMode="linear" dur="25s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7822;0.8654" calcMode="discrete" dur="25s" repeatCount="indefinite"/><animateMotion path="M67,118 L215,118" keyPoints="0;0;1;1" keyTimes="0;0.7822;0.8654;1" calcMode="linear" dur="25s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8848;0.9064" calcMode="discrete" dur="25s" repeatCount="indefinite"/><animateMotion path="M215,118 L215,54" keyPoints="0;0;1;1" keyTimes="0;0.8848;0.9064;1" calcMode="linear" dur="25s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.91;0.9316" calcMode="discrete" dur="25s" repeatCount="indefinite"/><animateMotion path="M215,54 L215,118" keyPoints="0;0;1;1" keyTimes="0;0.91;0.9316;1" calcMode="linear" dur="25s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.9352;0.9592" calcMode="discrete" dur="25s" repeatCount="indefinite"/><animateMotion path="M245,118 L245,203 L361,203" keyPoints="0;0;1;1" keyTimes="0;0.9352;0.9592;1" calcMode="linear" dur="25s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.9628;0.9904" calcMode="discrete" dur="25s" repeatCount="indefinite"/><animateMotion path="M361,203 L361,238 L507,238 L507,274" keyPoints="0;0;1;1" keyTimes="0;0.9628;0.9904;1" calcMode="linear" dur="25s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(20.4,382.5) scale(.8)"><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g><text x="31.8" y="386">instruction</text><g transform="translate(115.8,382.5) scale(.8)"><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g><text x="127.2" y="386">saved state</text><g transform="translate(212,382.5) scale(.8)"><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g><text x="224.2" y="386">image</text><g transform="translate(274.6,382.5) scale(.8)"><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g><text x="286" y="386">check</text><g transform="translate(336.4,382.5) scale(.8)"><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g><text x="347.8" y="386">request</text><g transform="translate(409.4,382.5) scale(.8)"><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g><text x="420.8" y="386">reply</text></g>
<rect x="12" y="398" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="398" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="25s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.112" calcMode="discrete" dur="25s" repeatCount="indefinite"/><circle cx="36" cy="426" r="14" fill="#2563eb"/><text x="36" y="431" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="421" font-size="14" font-weight="800" fill="#2563eb">You apply the Deployment</text><text x="578" y="421" text-anchor="end" font-size="10.5" class="dg-muted">Deploy · 1/9</text><text x="60" y="442" font-size="12.5" class="dg-text">kubectl apply -f deployment.yaml. The API server saves it in etcd.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.112;0.224" calcMode="discrete" dur="25s" repeatCount="indefinite"/><circle cx="36" cy="426" r="14" fill="#2563eb"/><text x="36" y="431" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="421" font-size="14" font-weight="800" fill="#2563eb">Controllers create 3 pods</text><text x="578" y="421" text-anchor="end" font-size="10.5" class="dg-muted">Deploy · 2/9</text><text x="60" y="442" font-size="12.5" class="dg-text">The Deployment makes a ReplicaSet, which creates 3 pods. No node yet.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.224;0.328" calcMode="discrete" dur="25s" repeatCount="indefinite"/><circle cx="36" cy="426" r="14" fill="#2563eb"/><text x="36" y="431" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="421" font-size="14" font-weight="800" fill="#2563eb">The scheduler picks a node</text><text x="578" y="421" text-anchor="end" font-size="10.5" class="dg-muted">Deploy · 3/9</text><text x="60" y="442" font-size="12.5" class="dg-text">For each pod, it finds a worker node with enough free CPU and memory.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.328;0.448" calcMode="discrete" dur="25s" repeatCount="indefinite"/><circle cx="36" cy="426" r="14" fill="#2563eb"/><text x="36" y="431" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="421" font-size="14" font-weight="800" fill="#2563eb">The kubelet tells containerd to start it</text><text x="578" y="421" text-anchor="end" font-size="10.5" class="dg-muted">Deploy · 4/9</text><text x="60" y="442" font-size="12.5" class="dg-text">containerd pulls hashicorp/http-echo:1.0 and starts the container.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.448;0.552" calcMode="discrete" dur="25s" repeatCount="indefinite"/><circle cx="36" cy="426" r="14" fill="#2563eb"/><text x="36" y="431" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="421" font-size="14" font-weight="800" fill="#2563eb">The readiness probe passes</text><text x="578" y="421" text-anchor="end" font-size="10.5" class="dg-muted">Deploy · 5/9</text><text x="60" y="442" font-size="12.5" class="dg-text">The kubelet checks each pod. Only Ready pods get traffic: 3 of 3 Ready.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.552;0.656" calcMode="discrete" dur="25s" repeatCount="indefinite"/><circle cx="36" cy="426" r="14" fill="#0d9488"/><text x="36" y="431" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="421" font-size="14" font-weight="800" fill="#0d9488">A user opens web.localtest.me</text><text x="578" y="421" text-anchor="end" font-size="10.5" class="dg-muted">A user visits · 6/9</text><text x="60" y="442" font-size="12.5" class="dg-text">The Ingress matches the host name and sends it to Service web on port 80.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.656;0.776" calcMode="discrete" dur="25s" repeatCount="indefinite"/><circle cx="36" cy="426" r="14" fill="#0d9488"/><text x="36" y="431" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="421" font-size="14" font-weight="800" fill="#0d9488">The Service picks a Ready pod</text><text x="578" y="421" text-anchor="end" font-size="10.5" class="dg-muted">A user visits · 7/9</text><text x="60" y="442" font-size="12.5" class="dg-text">One stable name in front of 3 pods. The reply goes back the same way.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.776;0.88" calcMode="discrete" dur="25s" repeatCount="indefinite"/><circle cx="36" cy="426" r="14" fill="#e11d48"/><text x="36" y="431" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="421" font-size="14" font-weight="800" fill="#e11d48">A pod is deleted</text><text x="578" y="421" text-anchor="end" font-size="10.5" class="dg-muted">Self-healing · 8/9</text><text x="60" y="442" font-size="12.5" class="dg-text">kubectl delete pod, or its node fails. The Service stops sending it traffic.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.88" calcMode="discrete" dur="25s" repeatCount="indefinite"/><circle cx="36" cy="426" r="14" fill="#e11d48"/><text x="36" y="431" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">9</text><text x="60" y="421" font-size="14" font-weight="800" fill="#e11d48">The ReplicaSet makes a new one</text><text x="578" y="421" text-anchor="end" font-size="10.5" class="dg-muted">Self-healing · 9/9</text><text x="60" y="442" font-size="12.5" class="dg-text">It sees 2 pods, not 3, and creates a new one. It is scheduled and started.</text></g>
</svg>
```

### The problem Kubernetes solves

With only Docker, if your app crashes at 3 a.m., someone has to wake up and restart it. If traffic doubles, someone has to start more copies by hand. If a server dies, every app on it is gone.

Kubernetes does all of that automatically. You tell it **what you want** ("always keep 3 copies of my app running"), and it constantly makes sure that's true.

### A real-life comparison

Think of a **restaurant manager**. You don't tell the manager *how* to run the kitchen; you say "always have 3 cooks on shift". If a cook goes home sick, the manager calls in another one. If it gets busy, the manager can add cooks. Kubernetes is that manager, and the cooks are your containers.

This idea is called **desired state**: you describe what you want, and Kubernetes works non-stop to keep reality matching it.

### How the pieces fit

```text
 You ──kubectl──▶ Control plane (the "manager", decides what runs where)
                         │
       ┌─────────────────┼─────────────────┐
     Node 1            Node 2            Node 3      ◀ worker computers
   [pod][pod]        [pod][pod]         [pod]        ◀ pods = your running containers
       └────────── Service (one stable address) ──────────┘ ◀ visitors come in here
```

### Key words

| Word | Simple meaning |
|---|---|
| **Cluster** | The whole group of computers Kubernetes manages |
| **Node** | One computer (real or virtual) in the cluster |
| **Pod** | The smallest unit: one running copy of your app (one or more containers) |
| **Deployment** | The instruction "keep N copies of this pod running, and update them safely" |
| **Service** | A fixed address that sends traffic to whichever pods are healthy |
| **Namespace** | A folder to separate teams or projects inside one cluster |
| **ConfigMap / Secret** | Settings and passwords given to your app from outside the image |
| **Ingress** | The front door for web traffic: routes `website.com/...` to the right Service |
| **kubectl** | The command you type to talk to the cluster |
| **Manifest (YAML)** | A text file describing what you want, which you send with `kubectl apply` |

### Reading YAML

Kubernetes files are written in **YAML**. Indentation (spaces, never tabs) shows what belongs to what:

```yaml
kind: Deployment        # WHAT type of thing this is
metadata:
  name: web             # its name
spec:                   # what you WANT
  replicas: 3           # "keep 3 copies running"
```

### Check yourself

1. What does Kubernetes do when one of your pods crashes?
2. Why do you need a Service if you already have pods?
3. What does "desired state" mean?

> **Tip:** Answers: 1) It starts a new one automatically. 2) Pods come and go and change address; a Service gives one stable address that always reaches healthy pods. 3) You describe what you want, and Kubernetes keeps making reality match it.

## Architecture

> **In simple words:** Kubernetes has a "brain" (the control plane) that makes decisions, and "workers" (nodes) that actually run your apps.

```text
                ┌─────────────────── Control plane ───────────────────┐
 kubectl ─────▶ │ kube-apiserver ◀─▶ etcd (cluster state)             │
                │ scheduler (places pods)  controller-manager (loops) │
                └───────────────────────┬─────────────────────────────┘
                                        │
        ┌───────────── Worker node ─────┴──────┐   ┌──── Worker node ────┐
        │ kubelet  kube-proxy  container runtime│   │        ...          │
        │  [pod] [pod] [pod]                    │   │  [pod] [pod]        │
        └───────────────────────────────────────┘   └─────────────────────┘
```

| Component | Job |
|---|---|
| **API server** | The front door. Everything (kubectl, controllers, kubelets) talks to it. |
| **etcd** | Key-value store holding all cluster state |
| **Scheduler** | Picks a node for each new pod |
| **Controller manager** | Control loops: "desired 3 replicas, have 2, create 1" |
| **kubelet** | Agent on each node that starts and monitors pods |
| **kube-proxy** | Programs node networking for Services |

On EKS, AWS runs the control plane for you. You manage only the worker nodes and workloads.

## Create a local cluster with kind

> **In simple words:** kind builds a small practice Kubernetes cluster inside Docker on your own computer: free, and safe to break.

kind runs Kubernetes nodes as Docker containers. Create a multi-node cluster with ports mapped for Ingress later:

```bash
mkdir -p ~/code/k8s-lab && cd ~/code/k8s-lab
cat > kind-config.yaml <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
      - containerPort: 443
        hostPort: 443
  - role: worker
  - role: worker
EOF

kind create cluster --name lab --config kind-config.yaml
kubectl cluster-info --context kind-lab
kubectl get nodes -o wide
```

Delete it any time with `kind delete cluster --name lab`.

> **Tip:** Alternatives: **minikube** (`minikube start`), **k3d**, or Docker Desktop's built-in Kubernetes. Any of them works for this guide.

## kubectl essentials

> **In simple words:** kubectl is your remote control for the cluster. You use it to list, inspect, create and delete everything.

```bash
kubectl get nodes                       # list nodes
kubectl get pods -A                     # pods in all namespaces
kubectl get all -n kube-system
kubectl describe node <name>            # detailed info + events
kubectl explain deployment.spec         # built-in API docs
kubectl api-resources                   # every resource type
kubectl config get-contexts             # clusters you can talk to
kubectl config use-context kind-lab     # switch cluster
```

Imperative vs declarative:

```bash
kubectl create deployment web --image=nginx:1.27      # imperative: quick experiments
kubectl apply -f deployment.yaml                      # declarative: the real way, kept in Git
kubectl create deployment web --image=nginx --dry-run=client -o yaml > web.yaml   # generate YAML
```

> **Tip:** With the `k` alias from setup, `k get po`, `k get svc`, and `k get deploy` save a lot of typing. Also try `kubectx` / `kubens` and **k9s** (a terminal UI).

## Pods

> **In simple words:** A pod is one running copy of your app. You rarely create pods by hand, but every app ends up running inside them.

A **Pod** is the smallest deployable unit: one or more containers that share network (same IP) and storage. You rarely create pods directly, but you need to understand them.

`pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hello
  labels:
    app: hello
spec:
  containers:
    - name: hello
      image: nginx:1.27
      ports:
        - containerPort: 80
```

```bash
kubectl apply -f pod.yaml
kubectl get pods -o wide
kubectl logs hello
kubectl exec -it hello -- sh
kubectl port-forward pod/hello 8080:80     # then curl localhost:8080
kubectl delete -f pod.yaml
```

Every manifest has the same shape: `apiVersion`, `kind`, `metadata` (name, labels), `spec` (desired state). Kubernetes adds `status` (actual state).

## Deployments, rollouts and rollbacks

> **In simple words:** A Deployment keeps the right number of pods running, replaces crashed ones, and updates your app to a new version without downtime. It can roll back if the new version is bad.

A **Deployment** manages a **ReplicaSet**, which keeps N identical pods running. This is how you run stateless apps.

`deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  labels:
    app: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: web
          image: hashicorp/http-echo:1.0
          args: ["-text=hello v1", "-listen=:8080"]
          ports:
            - containerPort: 8080
```

```bash
kubectl apply -f deployment.yaml
kubectl get deploy,rs,pods -l app=web

# Self-healing: delete a pod and watch a replacement appear
kubectl delete pod -l app=web --wait=false && kubectl get pods -l app=web -w

# Scale
kubectl scale deployment web --replicas=5

# Rolling update: change args to "hello v2" in the file, then:
kubectl apply -f deployment.yaml
kubectl rollout status deployment/web
kubectl rollout history deployment/web

# Roll back
kubectl rollout undo deployment/web
```

> **Note:** Other workload types: **StatefulSet** (stable identity and storage, for databases), **DaemonSet** (one pod per node, for log or monitoring agents), **Job / CronJob** (run to completion, or on a schedule).

## Services: stable networking

> **In simple words:** Pods keep changing address. A Service gives your app one permanent name and address, and spreads traffic across the healthy pods.

Pods come and go, and their IPs change. A **Service** gives a stable name and IP and load-balances across the pods whose labels match its `selector`.

`service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  type: ClusterIP
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 8080
```

```bash
kubectl apply -f service.yaml
kubectl get svc web
kubectl get endpointslices -l kubernetes.io/service-name=web   # which pods back it

# Test from inside the cluster: DNS name is <svc>.<namespace>.svc.cluster.local
kubectl run tmp --rm -it --image=curlimages/curl --restart=Never -- curl -s http://web
```

| Type | Reachable from | Use |
|---|---|---|
| `ClusterIP` (default) | Inside the cluster only | Internal services |
| `NodePort` | `<any-node-ip>:30000-32767` | Testing, simple setups |
| `LoadBalancer` | Cloud load balancer (NLB/ALB on AWS) | Exposing directly on EKS |
| Headless (`clusterIP: None`) | Direct pod IPs via DNS | StatefulSets |

## ConfigMaps and Secrets

> **In simple words:** Keep settings and passwords **outside** the image, so the same image can run in test and production with different settings.

Keep configuration out of images.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-config
data:
  APP_MODE: "production"
  LOG_LEVEL: "info"
---
apiVersion: v1
kind: Secret
metadata:
  name: web-secret
type: Opaque
stringData:
  DB_PASSWORD: "change-me"
```

Use them in a container spec:

```yaml
          envFrom:
            - configMapRef:
                name: web-config
            - secretRef:
                name: web-secret
```

```bash
kubectl create secret generic db --from-literal=password=s3cr3t --dry-run=client -o yaml
kubectl get secret web-secret -o jsonpath='{.data.DB_PASSWORD}' | base64 -d
```

> **Warning:** Kubernetes Secrets are only **base64-encoded**, not encrypted, and anyone with read access to them can decode them. Never commit them to Git in plain text. In production use **External Secrets Operator** with AWS Secrets Manager, or **Sealed Secrets** / **SOPS**.

## Namespaces, resources and probes

> **In simple words:** Namespaces separate teams. Resource limits stop one app hogging the machine. Probes are health checks that tell Kubernetes when an app is ready, or stuck and needs a restart.

### Namespaces

```bash
kubectl create namespace team-a
kubectl apply -f deployment.yaml -n team-a
kubectl config set-context --current --namespace=team-a   # default ns for this context
```

### Requests and limits

**Requests** are what the scheduler reserves. **Limits** are the hard cap: a container that exceeds its memory limit is OOMKilled, and one that exceeds its CPU limit is throttled.

### Health probes

| Probe | Question | On failure |
|---|---|---|
| `readinessProbe` | Ready for traffic? | Removed from Service endpoints |
| `livenessProbe` | Still alive? | Container restarted |
| `startupProbe` | Finished starting? | Holds off the other probes |

A production-ready container block:

```yaml
      containers:
        - name: web
          image: myrepo/web:1.4.2
          ports:
            - containerPort: 8000
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              memory: 256Mi
          readinessProbe:
            httpGet:
              path: /health
              port: 8000
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 10
            periodSeconds: 10
          securityContext:
            runAsNonRoot: true
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
```

Autoscale on CPU with a HorizontalPodAutoscaler (needs metrics-server):

```bash
kubectl autoscale deployment web --cpu-percent=70 --min=2 --max=10
kubectl get hpa
```

## Storage: volumes and PVCs

> **In simple words:** Pods are temporary, so files written inside them vanish. A PersistentVolumeClaim asks for a real disk that survives restarts.

A **PersistentVolumeClaim** asks for storage. A **StorageClass** provisions it dynamically: on kind it's a local path, on EKS an EBS volume.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: writer
spec:
  containers:
    - name: writer
      image: busybox:1.36
      command: ["sh", "-c", "date >> /data/log.txt; sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: data
```

```bash
kubectl apply -f pvc.yaml
kubectl get pvc,pv
kubectl get storageclass
kubectl delete pod writer && kubectl apply -f pvc.yaml
kubectl exec writer -- cat /data/log.txt     # two lines: data persisted
```

## Ingress: HTTP routing

> **In simple words:** Ingress is the front door for websites: it reads the web address and sends each visitor to the right app.

An **Ingress** routes HTTP(S) by host and path to Services through a single entry point. It needs an **Ingress controller**. Install ingress-nginx for kind:

```bash
kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml
kubectl wait -n ingress-nginx --for=condition=ready pod -l app.kubernetes.io/component=controller --timeout=180s
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
spec:
  ingressClassName: nginx
  rules:
    - host: web.localtest.me
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port:
                  number: 80
```

```bash
kubectl apply -f ingress.yaml
curl http://web.localtest.me      # *.localtest.me resolves to 127.0.0.1
```

> **Note:** The upstream ingress-nginx project is being retired, and the community is moving to the **Gateway API** (`Gateway` + `HTTPRoute`). Ingress concepts carry over directly. Check which one your company uses. On EKS, the **AWS Load Balancer Controller** turns Ingress into an ALB.

## Helm: the package manager

> **In simple words:** Helm installs complete apps (like a database) into Kubernetes with one command, the way an app store installs apps on a phone.

> **Tip:** Want to write your own chart and deploy it to dev, staging and prod with different settings? Follow [Helm: App per Environment](#/tool/helm-environments).

Helm packages a set of templated manifests as a **chart**, so you can install complex apps with one command and configure them with values.

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo redis

helm install cache bitnami/redis -n data --create-namespace --set architecture=standalone
helm list -A
helm get values cache -n data
helm upgrade cache bitnami/redis -n data -f my-values.yaml
helm rollback cache 1 -n data
helm uninstall cache -n data
```

Create your own chart:

```bash
helm create mychart
tree mychart            # Chart.yaml, values.yaml, templates/
helm template mychart   # render YAML locally, without installing
helm lint mychart
helm install demo ./mychart --set replicaCount=2
```

Inside templates, values are referenced like `{{ .Values.image.repository }}:{{ .Values.image.tag }}`.

## Debugging workflow

> **In simple words:** A step-by-step routine to find out why a pod isn't working: look at its status, its events, then its logs.

> **Tip:** For a deep dive into every common error (CrashLoopBackOff, Pending, ImagePullBackOff, timeouts, OOMKilled and more) with a break-and-fix lab, see [Kubernetes Troubleshooting](#/tool/k8s-troubleshooting).

When something is wrong, work from the outside in:

```bash
kubectl get pods                         # STATUS and RESTARTS columns
kubectl describe pod <pod>               # read the Events at the bottom
kubectl logs <pod>                       # app logs
kubectl logs <pod> --previous            # logs from the crashed container
kubectl logs deploy/web -c web -f        # follow a deployment's container
kubectl get events --sort-by=.lastTimestamp
kubectl exec -it <pod> -- sh
kubectl debug -it <pod> --image=busybox:1.36 --target=<container>   # for distroless images
kubectl top pods                         # needs metrics-server
```

| Status | Usual cause |
|---|---|
| `Pending` | No node has enough CPU or memory, or the PVC isn't bound. Check `describe` events. |
| `ImagePullBackOff` | Wrong image name or tag, or a private registry without credentials |
| `CrashLoopBackOff` | The app starts then exits. Check `logs --previous`. |
| `OOMKilled` | Memory limit too low, or a memory leak |
| Running but no traffic | Service `selector` doesn't match pod labels, or the readiness probe is failing. Check endpoints. |
| `CreateContainerConfigError` | A referenced ConfigMap or Secret is missing |

## Lab: deploy your own app

> **In simple words:** Practice time: run your own Docker image on Kubernetes with health checks, settings and a web address.

Use the image you built in the Docker lab.

1. Load it into kind: `kind load docker-image hello-docker:1.0.0 --name lab`.
2. Create a namespace `hello` and a Deployment with 3 replicas, resource requests and limits, and readiness and liveness probes on `/health`.
3. Put `APP_VERSION` in a ConfigMap and inject it as an env var.
4. Expose it with a ClusterIP Service and an Ingress at `hello.localtest.me`.
5. Build `1.1.0`, load it, roll it out, and watch with `kubectl rollout status`. Then roll back.
6. Break it on purpose: wrong image tag, wrong probe path, wrong Service selector. Diagnose each one using only `get`, `describe` and `logs`.
7. Package everything as a Helm chart with the image tag and replicas in `values.yaml`.

### Cheat sheet

| Task | Command |
|---|---|
| Apply a folder | `kubectl apply -f k8s/` |
| Watch pods | `kubectl get pods -w` |
| Why isn't it running? | `kubectl describe pod <p>` |
| Logs of crashed container | `kubectl logs <p> --previous` |
| Shell in | `kubectl exec -it <p> -- sh` |
| Port-forward | `kubectl port-forward svc/web 8080:80` |
| Restart deployment | `kubectl rollout restart deploy/web` |
| Roll back | `kubectl rollout undo deploy/web` |
