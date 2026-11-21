# EKS Cluster Setup: Runbook

A step-by-step runbook for creating an Amazon EKS cluster in an **existing VPC** with `eksctl`, then installing the add-ons most platforms need: the **AWS Load Balancer Controller**, **EBS** block storage, **EFS** shared storage, and the **Istio** service mesh. Set your values once in the first step, then copy each block in order.

> **Note:** You need admin-level AWS access (or rights to create EKS, EC2, IAM, EFS and CloudFormation resources) and an existing VPC with private subnets. The [AWS](#/tool/aws), [IAM](#/tool/aws-iam) and [Kubernetes](#/tool/kubernetes) guides explain the concepts used here.

> **Cost:** The EKS control plane is **$0.10/hour** on a version in standard support, but **$0.60/hour** once the version reaches extended support. Nodes cost extra: a `c5.4xlarge` is about $0.68/hour on-demand in us-east-1, so two of them run around $1,000/month. Load balancers, EBS, EFS and NAT traffic come on top. See [EKS pricing](https://aws.amazon.com/eks/pricing/).

> **Warning:** Never paste real account IDs, VPC or subnet IDs, IP ranges or passwords into shared runbooks, tickets or chat. Keep environment values in your team's private configuration and use the variables below.

## Start here: the flow in simple words

> **In simple words:** `eksctl` reads one YAML file and builds the cluster and its worker nodes inside your VPC. Then you install a few add-ons, each with its own IAM role: one creates AWS load balancers, two give pods disks, and one adds a service mesh.

### Watch how it works

```svg Watch it work: shipping an image to two pods, the Load Balancer Controller turning an Ingress into a load balancer, a user visiting, and a Deployment replacing a crashed pod. The animation loops.
<svg viewBox="0 0 600 476" role="img" data-anim="eks" aria-label="Animated EKS flow. Ship: the image is built and pushed to ECR, kubectl apply sends the Deployment, Service and Ingress to the EKS control plane, the scheduler places two pods on worker nodes, the pods pull the image from ECR, the Load Balancer Controller reads the Ingress and creates the load balancer, and the pod IPs join the target group. Visit: the browser asks Route 53, connects over HTTPS to the load balancer, the target group sends the request to pod 1, and the reply goes back. Self-healing: pod 2 crashes and leaves the target group, and the Deployment starts a new pod.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<rect x="136" y="12" width="452" height="318" rx="14" class="dg-region"/>
<text x="148" y="31" font-size="13" font-weight="800" fill="#f97316">VPC</text>
<rect x="148" y="40" width="428" height="72" rx="10" fill="none" stroke="#10b981" stroke-width="1.5" stroke-dasharray="5 4"/>
<text x="568" y="57" text-anchor="end" font-size="11" class="dg-muted">public subnets</text>
<rect x="148" y="124" width="428" height="194" rx="10" fill="none" stroke="#3b82f6" stroke-width="1.5" stroke-dasharray="5 4"/>
<text x="568" y="141" text-anchor="end" font-size="11" class="dg-muted">private subnets</text>
<polyline points="66,98 66,130" fill="none" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="120,76 184,76" fill="none" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="304,76 324,76" fill="none" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="376,98 376,150" fill="none" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="301,150 451,150" fill="none" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="301,150 301,180" fill="none" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="451,150 451,180" fill="none" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="120,369 236,369" fill="none" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".6"/>
<polyline points="301,346 301,250" fill="none" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".6"/>
<polyline points="346,346 346,336 420,336 420,250" fill="none" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".6"/>
<polyline points="461,346 461,250" fill="none" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".7"/>
<polyline points="461,296 272,296 272,250" fill="none" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".7"/>
<polyline points="272,296 189,296 189,250" fill="none" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".7"/>
<polyline points="66,392 66,404 461,404 461,392" fill="none" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".7"/>
<polyline points="189,180 189,98" fill="none" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".7"/>
<g><rect x="8" y="50" width="116" height="52" rx="12" fill="#6366f1" fill-opacity=".18" stroke="#6366f1" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.5181;0.5964;0.747;0.8253" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/></rect><rect x="12" y="54" width="108" height="44" rx="9" class="dg-box" stroke="#6366f1" stroke-width="2.2"/><text x="66" y="72" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">User</text><text x="66" y="89" text-anchor="middle" font-size="11" class="dg-muted">browser</text></g>
<g><rect x="8" y="126" width="116" height="52" rx="12" fill="#7c3aed" fill-opacity=".18" stroke="#7c3aed" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5181;0.5964" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/></rect><rect x="12" y="130" width="108" height="44" rx="9" class="dg-box" stroke="#7c3aed" stroke-width="2.2"/><text x="66" y="148" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Route 53</text><text x="66" y="165" text-anchor="middle" font-size="11" class="dg-muted">DNS</text></g>
<g><rect x="8" y="342" width="116" height="54" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.0843" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/></rect><rect x="12" y="346" width="108" height="46" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="66" y="365" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Laptop / CI</text><text x="66" y="382" text-anchor="middle" font-size="11" class="dg-muted">your code</text></g>
<g><rect x="232" y="342" width="138" height="54" rx="12" fill="#2563eb" fill-opacity=".18" stroke="#2563eb" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.0843" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/></rect><rect x="236" y="346" width="130" height="46" rx="9" class="dg-box" stroke="#2563eb" stroke-width="2.2"/><text x="301" y="365" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Amazon ECR</text><text x="301" y="382" text-anchor="middle" font-size="11" class="dg-muted">hello-app:1.1.0</text></g>
<g><rect x="382" y="342" width="158" height="54" rx="12" fill="#ff9900" fill-opacity=".18" stroke="#ff9900" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.0843;0.1687;0.9096" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/></rect><rect x="386" y="346" width="150" height="46" rx="9" class="dg-box" stroke="#ff9900" stroke-width="2.2"/><text x="461" y="365" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">EKS control plane</text><text x="461" y="382" text-anchor="middle" font-size="11" class="dg-muted">AWS runs it</text></g>
<g opacity="0.3"><animate attributeName="opacity" values="0.3;1" keyTimes="0;0.3373" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><rect x="180" y="50" width="128" height="52" rx="12" fill="#c026d3" fill-opacity=".18" stroke="#c026d3" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.3373;0.4337;0.5964;0.6747" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/></rect><rect x="184" y="54" width="120" height="44" rx="9" class="dg-box" stroke="#c026d3" stroke-width="2.2"/><text x="244" y="72" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Load balancer</text><text x="244" y="89" text-anchor="middle" font-size="11" class="dg-muted">HTTPS · ACM</text></g>
<g opacity="0.3"><animate attributeName="opacity" values="0.3;1" keyTimes="0;0.3373" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><rect x="320" y="50" width="112" height="52" rx="12" fill="#0ea5e9" fill-opacity=".18" stroke="#0ea5e9" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0;1;0" keyTimes="0;0.4337;0.5181;0.5964;0.6747;0.8253;0.9096" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/></rect><rect x="324" y="54" width="104" height="44" rx="9" class="dg-box" stroke="#0ea5e9" stroke-width="2.2"/><text x="376" y="72" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Target group</text><text x="376" y="89" text-anchor="middle" font-size="11" class="dg-muted">pod IPs</text></g>
<g><rect x="232" y="176" width="138" height="78" rx="12" fill="#3b82f6" fill-opacity=".18" stroke="#3b82f6" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.1687;0.3373;0.6747;0.747" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/></rect><rect x="236" y="180" width="130" height="70" rx="9" class="dg-box" stroke="#3b82f6" stroke-width="2.2"/><text x="301" y="211" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Pod 1</text><text x="301" y="229" text-anchor="middle" font-size="11" class="dg-muted">worker node A</text></g>
<g><rect x="382" y="176" width="138" height="78" rx="12" fill="#3b82f6" fill-opacity=".18" stroke="#3b82f6" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.1687;0.3373;0.8253" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/></rect><rect x="386" y="180" width="130" height="70" rx="9" class="dg-box" stroke="#3b82f6" stroke-width="2.2"/><text x="451" y="211" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Pod 2</text><text x="451" y="229" text-anchor="middle" font-size="11" class="dg-muted">worker node B</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8253;0.9096" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><rect x="386" y="180" width="130" height="70" rx="9" fill="#e11d48"/><text x="451" y="220" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">✕ crashed</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.9096" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><rect x="386" y="180" width="130" height="70" rx="9" fill="#059669"/><text x="451" y="220" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">+ new pod</text></g></g>
<g><rect x="146" y="176" width="86" height="78" rx="12" fill="#8b5cf6" fill-opacity=".18" stroke="#8b5cf6" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3373;0.4337" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/></rect><rect x="150" y="180" width="78" height="70" rx="9" class="dg-box" stroke="#8b5cf6" stroke-width="2.2"/><text x="189" y="211" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">LB</text><text x="189" y="229" text-anchor="middle" font-size="11" class="dg-muted">controller</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8253;0.9096" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><circle cx="451" cy="165" r="9" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M447,161 L455,169 M455,161 L447,169" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/></g>
<g font-size="10.5" class="dg-muted"><circle cx="18" cy="16" r="5" fill="#6366f1"/><text x="27" y="20">request</text><circle cx="70" cy="16" r="5" fill="#10b981"/><text x="79" y="20">reply</text><rect x="13" y="28" width="10" height="9" rx="2" fill="#f97316"/><text x="27" y="37">code</text><circle cx="70" cy="33" r="4.5" fill="#a855f7"/><text x="79" y="37">command</text></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0051;0.0725" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><animateMotion path="M66,369 L301,369" keyPoints="0;0;1;1" keyTimes="0;0.0051;0.0725;1" calcMode="linear" dur="33.2s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0894;0.1569" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><animateMotion path="M66,369 L66,404 L461,404 L461,369" keyPoints="0;0;1;1" keyTimes="0;0.0894;0.1569;1" calcMode="linear" dur="33.2s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1737;0.2412" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><animateMotion path="M461,369 L461,296 L272,296 L272,215" keyPoints="0;0;1;1" keyTimes="0;0.1737;0.2412;1" calcMode="linear" dur="33.2s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1737;0.2412" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><animateMotion path="M461,369 L461,215" keyPoints="0;0;1;1" keyTimes="0;0.1737;0.2412;1" calcMode="linear" dur="33.2s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2581;0.3255" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><animateMotion path="M301,369 L301,215" keyPoints="0;0;1;1" keyTimes="0;0.2581;0.3255;1" calcMode="linear" dur="33.2s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2581;0.3255" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><animateMotion path="M346,369 L346,336 L420,336 L420,215" keyPoints="0;0;1;1" keyTimes="0;0.2581;0.3255;1" calcMode="linear" dur="33.2s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3412;0.3817" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><animateMotion path="M461,369 L461,296 L189,296 L189,215" keyPoints="0;0;1;1" keyTimes="0;0.3412;0.3817;1" calcMode="linear" dur="33.2s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3875;0.4241" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><animateMotion path="M189,215 L189,76" keyPoints="0;0;1;1" keyTimes="0;0.3875;0.4241;1" calcMode="linear" dur="33.2s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4388;0.5063" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><animateMotion path="M301,215 L301,150 L376,150 L376,76" keyPoints="0;0;1;1" keyTimes="0;0.4388;0.5063;1" calcMode="linear" dur="33.2s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4388;0.5063" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><animateMotion path="M451,215 L451,150 L376,150 L376,76" keyPoints="0;0;1;1" keyTimes="0;0.4388;0.5063;1" calcMode="linear" dur="33.2s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5228;0.5854" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><animateMotion path="M66,76 L66,152 L66,76" keyPoints="0;0;1;1" keyTimes="0;0.5228;0.5854;1" calcMode="linear" dur="33.2s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6011;0.6637" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><animateMotion path="M66,76 L244,76 L376,76" keyPoints="0;0;1;1" keyTimes="0;0.6011;0.6637;1" calcMode="linear" dur="33.2s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.679;0.7369" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><animateMotion path="M376,76 L376,150 L301,150 L301,215" keyPoints="0;0;1;1" keyTimes="0;0.679;0.7369;1" calcMode="linear" dur="33.2s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7517;0.8143" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><animateMotion path="M301,215 L301,150 L376,150 L376,76 L244,76 L66,76" keyPoints="0;0;1;1" keyTimes="0;0.7517;0.8143;1" calcMode="linear" dur="33.2s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.9151;0.9873" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><animateMotion path="M461,369 L461,215" keyPoints="0;0;1;1" keyTimes="0;0.9151;0.9873;1" calcMode="linear" dur="33.2s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<rect x="12" y="414" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/>
<rect x="12" y="414" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="33.2s" repeatCount="indefinite"/></rect>
<g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.0843" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><circle cx="36" cy="442" r="14" fill="#f97316"/><text x="36" y="447" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="437" font-size="14" font-weight="800" fill="#f97316">Build and push the image</text><text x="578" y="437" text-anchor="end" font-size="10.5" class="dg-muted">Ship a new version · 1/12</text><text x="60" y="458" font-size="12.5" class="dg-text">docker build and docker push put hello-app:1.1.0 in ECR.</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0843;0.1687" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><circle cx="36" cy="442" r="14" fill="#f97316"/><text x="36" y="447" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="437" font-size="14" font-weight="800" fill="#f97316">kubectl apply</text><text x="578" y="437" text-anchor="end" font-size="10.5" class="dg-muted">Ship a new version · 2/12</text><text x="60" y="458" font-size="12.5" class="dg-text">You send the Deployment, Service and Ingress YAML to the EKS control plane.</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1687;0.253" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><circle cx="36" cy="442" r="14" fill="#f97316"/><text x="36" y="447" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="437" font-size="14" font-weight="800" fill="#f97316">The scheduler places the pods</text><text x="578" y="437" text-anchor="end" font-size="10.5" class="dg-muted">Ship a new version · 3/12</text><text x="60" y="458" font-size="12.5" class="dg-text">The control plane picks a worker node for each of the 2 pods.</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.253;0.3373" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><circle cx="36" cy="442" r="14" fill="#f97316"/><text x="36" y="447" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="437" font-size="14" font-weight="800" fill="#f97316">Pods pull the image</text><text x="578" y="437" text-anchor="end" font-size="10.5" class="dg-muted">Ship a new version · 4/12</text><text x="60" y="458" font-size="12.5" class="dg-text">Each worker node downloads the image from ECR and starts the container.</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3373;0.4337" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><circle cx="36" cy="442" r="14" fill="#f97316"/><text x="36" y="447" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="437" font-size="14" font-weight="800" fill="#f97316">The Ingress becomes a load balancer</text><text x="578" y="437" text-anchor="end" font-size="10.5" class="dg-muted">Ship a new version · 5/12</text><text x="60" y="458" font-size="12.5" class="dg-text">The LB Controller reads the Ingress and creates an ALB with your certificate.</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4337;0.5181" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><circle cx="36" cy="442" r="14" fill="#f97316"/><text x="36" y="447" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="437" font-size="14" font-weight="800" fill="#f97316">Pods join the target group</text><text x="578" y="437" text-anchor="end" font-size="10.5" class="dg-muted">Ship a new version · 6/12</text><text x="60" y="458" font-size="12.5" class="dg-text">The controller adds each pod&#x27;s IP once its readiness probe passes.</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5181;0.5964" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><circle cx="36" cy="442" r="14" fill="#6366f1"/><text x="36" y="447" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="437" font-size="14" font-weight="800" fill="#6366f1">A user opens eks.example.com</text><text x="578" y="437" text-anchor="end" font-size="10.5" class="dg-muted">A user visits · 7/12</text><text x="60" y="458" font-size="12.5" class="dg-text">The browser asks Route 53, which answers with the load balancer&#x27;s address.</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5964;0.6747" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><circle cx="36" cy="442" r="14" fill="#6366f1"/><text x="36" y="447" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="437" font-size="14" font-weight="800" fill="#6366f1">HTTPS to the load balancer</text><text x="578" y="437" text-anchor="end" font-size="10.5" class="dg-muted">A user visits · 8/12</text><text x="60" y="458" font-size="12.5" class="dg-text">The ACM certificate gives the padlock; the target group picks a ready pod.</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6747;0.747" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><circle cx="36" cy="442" r="14" fill="#6366f1"/><text x="36" y="447" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">9</text><text x="60" y="437" font-size="14" font-weight="800" fill="#6366f1">Pod 1 answers</text><text x="578" y="437" text-anchor="end" font-size="10.5" class="dg-muted">A user visits · 9/12</text><text x="60" y="458" font-size="12.5" class="dg-text">Your container replies on port 8000, straight from worker node A.</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.747;0.8253" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><circle cx="36" cy="442" r="14" fill="#6366f1"/><text x="36" y="447" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">10</text><text x="60" y="437" font-size="14" font-weight="800" fill="#6366f1">The reply goes back the same way</text><text x="578" y="437" text-anchor="end" font-size="10.5" class="dg-muted">A user visits · 10/12</text><text x="60" y="458" font-size="12.5" class="dg-text">Load balancer → browser. The next visitor may be sent to pod 2.</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8253;0.9096" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><circle cx="36" cy="442" r="14" fill="#e11d48"/><text x="36" y="447" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">11</text><text x="60" y="437" font-size="14" font-weight="800" fill="#e11d48">If pod 2 crashes…</text><text x="578" y="437" text-anchor="end" font-size="10.5" class="dg-muted">Self-healing · 11/12</text><text x="60" y="458" font-size="12.5" class="dg-text">Its readiness probe fails, so it is taken out of the target group.</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.9096" calcMode="discrete" dur="33.2s" repeatCount="indefinite"/><circle cx="36" cy="442" r="14" fill="#e11d48"/><text x="36" y="447" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">12</text><text x="60" y="437" font-size="14" font-weight="800" fill="#e11d48">…the Deployment replaces it</text><text x="578" y="437" text-anchor="end" font-size="10.5" class="dg-muted">Self-healing · 12/12</text><text x="60" y="458" font-size="12.5" class="dg-text">replicas: 2 → Kubernetes starts a new pod, and it joins the target group.</text></g>
</svg>
```

```text
 1. Install tools (aws, kubectl, eksctl, helm) and set variables
 2. Check the VPC: private subnets in 2+ AZs, outbound internet or VPC endpoints, subnet tags
 3. Write eks.yaml (cluster + managed node group)
 4. eksctl create cluster  →  ~20 minutes  →  kubectl get nodes
 5. AWS Load Balancer Controller   (Ingress → ALB, Service → NLB)
 6. EBS CSI driver + gp3 StorageClass   (one disk per pod)
 7. EFS file system + EFS CSI driver   (shared ReadWriteMany storage)
 8. Istio (base + istiod, optional ingress gateway)
 9. Verify everything
```

### Prerequisites

| Requirement | Check with |
|---|---|
| AWS CLI v2, logged in to the right account | `aws sts get-caller-identity` |
| An existing VPC with **private subnets in at least 2 AZs** | `aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID` |
| Outbound access from those subnets (NAT gateway, or VPC endpoints for ECR, S3, EC2, STS) | Ask the network team if unsure |
| Enough free IPs in each subnet (every pod gets a VPC IP) | `AvailableIpAddressCount` in the command above |

### Set your values once

```bash
export AWS_REGION=us-east-1
export AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
export CLUSTER_NAME=my-cluster                     # CHANGE
export K8S_VERSION=1.36                            # a version in EKS standard support (see below)
export VPC_ID=vpc-0123456789abcdef0                # CHANGE: existing VPC
export PRIVATE_SUBNETS="subnet-0aaaaaaaaaaaaaaaa subnet-0bbbbbbbbbbbbbbbb subnet-0cccccccccccccccc"   # CHANGE: one per AZ
export LBC_VERSION=v3.6.2                          # AWS Load Balancer Controller release
export ISTIO_VERSION=1.31.3                        # Istio release (check its supported Kubernetes versions)
```

**Pick a supported Kubernetes version.** EKS gives each version 14 months of standard support, then 12 months of more expensive extended support. For example, 1.33 left standard support on July 29, 2026. Always start new clusters on a recent version. AWS docs: [Kubernetes version lifecycle on EKS](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html)

## Install the tools

> **In simple words:** Four command-line tools do all the work: `aws` talks to AWS, `kubectl` to the cluster, `eksctl` builds the cluster, and `helm` installs add-ons. Install them once on your laptop or jump host.

`aws`, `kubectl` and `helm` are covered in [Workstation Setup](#/tool/setup). Install `eksctl`:

```bash
ARCH=amd64        # arm64 on ARM machines
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_${ARCH}.tar.gz"
tar -xzf eksctl_Linux_${ARCH}.tar.gz -C /tmp && rm eksctl_Linux_${ARCH}.tar.gz
sudo install -m 0755 /tmp/eksctl /usr/local/bin/eksctl

aws --version && kubectl version --client && eksctl version && helm version --short
```

## Check the VPC and tag the subnets

> **In simple words:** EKS builds the cluster *inside* your network, so the network must be ready first: private subnets in at least two Availability Zones, a way for nodes to reach AWS services, and tags that tell load balancers which subnets to use.

```bash
aws ec2 describe-subnets --subnet-ids $PRIVATE_SUBNETS --region $AWS_REGION \
  --query 'Subnets[].[SubnetId,AvailabilityZone,CidrBlock,AvailableIpAddressCount,MapPublicIpOnLaunch]' --output table
```

Check that each subnet is in a **different AZ**, has plenty of free IPs, and has `MapPublicIpOnLaunch = False`.

Tag the subnets so the Load Balancer Controller can find them:

```bash
# internal load balancers go into private subnets
aws ec2 create-tags --region $AWS_REGION --resources $PRIVATE_SUBNETS \
  --tags Key=kubernetes.io/role/internal-elb,Value=1

# only if you also want internet-facing load balancers, tag your PUBLIC subnets:
# aws ec2 create-tags --region $AWS_REGION --resources subnet-public-a subnet-public-b \
#   --tags Key=kubernetes.io/role/elb,Value=1
```

AWS docs: [EKS networking requirements](https://docs.aws.amazon.com/eks/latest/userguide/network-reqs.html) · [Load balancer subnet discovery](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/subnet_discovery/)

## Write the cluster config (eks.yaml)

> **In simple words:** One file describes the whole cluster: its name and version, which VPC and subnets to use, how the API endpoint is reachable, and the worker nodes. Keep this file in Git so the cluster can be rebuilt the same way.

Create `eks.yaml` and change the values marked `# CHANGE`:

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: my-cluster                  # CHANGE: same as $CLUSTER_NAME
  region: us-east-1                 # CHANGE
  version: "1.36"                   # CHANGE: a version in standard support
  tags:
    team: platform
    environment: dev

iam:
  withOIDC: true                    # enables IAM roles for service accounts (used by every add-on below)

vpc:
  id: vpc-0123456789abcdef0         # CHANGE: existing VPC (its CIDR is read automatically)
  subnets:
    private:
      us-east-1a: { id: subnet-0aaaaaaaaaaaaaaaa }   # CHANGE: one private subnet per AZ
      us-east-1b: { id: subnet-0bbbbbbbbbbbbbbbb }
      us-east-1c: { id: subnet-0cccccccccccccccc }
  clusterEndpoints:
    privateAccess: true             # nodes and VPN users reach the API privately
    publicAccess: true              # set false for a private-only API (needs VPN or a bastion)

addons:                             # core EKS add-ons, managed by AWS
  - name: vpc-cni
  - name: coredns
  - name: kube-proxy

managedNodeGroups:
  - name: ng-general
    instanceType: c5.4xlarge        # CHANGE: size for your workloads
    minSize: 2
    desiredCapacity: 2
    maxSize: 4
    volumeSize: 100
    volumeType: gp3
    privateNetworking: true         # nodes get private IPs only
    labels:
      role: general

cloudWatch:
  clusterLogging:
    enableTypes: ["api", "audit", "authenticator"]   # control-plane logs to CloudWatch
```

| Setting | Why |
|---|---|
| `iam.withOIDC: true` | Creates the OIDC provider at cluster creation, so there's no separate `associate-iam-oidc-provider` step |
| No `vpc.cidr` | Not needed for an existing VPC: eksctl reads it from the VPC |
| `minSize` / `maxSize` | Lets an autoscaler (Cluster Autoscaler or Karpenter) grow and shrink the group later |
| `privateNetworking: true` | Nodes have no public IPs |
| `clusterLogging` | API and audit logs help with security reviews and troubleshooting |

## Create the cluster and connect

> **In simple words:** `eksctl` turns the file into CloudFormation stacks: first the control plane, then the nodes. It takes about 15–25 minutes. When it finishes, your `kubectl` is already pointed at the new cluster.

```bash
eksctl create cluster -f eks.yaml --dry-run | less    # optional: review the full expanded config
eksctl create cluster -f eks.yaml

aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
kubectl config current-context
kubectl get nodes -o wide                  # 2 nodes, STATUS Ready, private IPs only
kubectl get pods -n kube-system            # aws-node, coredns, kube-proxy running
```

Progress can be followed in **CloudFormation** (stacks named `eksctl-<cluster>-cluster` and `eksctl-<cluster>-nodegroup-…`).

AWS docs: [What is eksctl?](https://docs.aws.amazon.com/eks/latest/eksctl/what-is-eksctl.html)

## Install the AWS Load Balancer Controller

> **In simple words:** This controller watches Kubernetes and creates real AWS load balancers: an **ALB** for every Ingress, and an **NLB** for every Service of type `LoadBalancer`. It needs an IAM role, and the role's policy must match the controller version you install.

```bash
# 1. IAM policy from the SAME release as the controller
curl -fsSL -o lbc-iam-policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/${LBC_VERSION}/docs/install/iam_policy.json
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy-$CLUSTER_NAME \
  --policy-document file://lbc-iam-policy.json

# 2. IAM role + Kubernetes service account (IRSA)
eksctl create iamserviceaccount \
  --cluster $CLUSTER_NAME --region $AWS_REGION \
  --namespace kube-system --name aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole-$CLUSTER_NAME \
  --attach-policy-arn arn:aws:iam::${AWS_ACCOUNT}:policy/AWSLoadBalancerControllerIAMPolicy-$CLUSTER_NAME \
  --approve

# 3. Install the controller with Helm (chart version = controller version)
helm repo add eks https://aws.github.io/eks-charts && helm repo update eks
helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system \
  --version ${LBC_VERSION#v} \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$AWS_REGION \
  --set vpcId=$VPC_ID

kubectl -n kube-system rollout status deploy/aws-load-balancer-controller
kubectl -n kube-system get deploy aws-load-balancer-controller      # READY 2/2
```

- Every multi-line command needs a `\` at the end of each line except the last. A missing `\` silently drops the flags after it (for example `--approve`).
- `region` and `vpcId` are set explicitly, so the controller doesn't depend on reading them from the instance metadata service.
- The chart's default image is pulled from Amazon ECR Public. In clusters with **no internet access**, mirror the image to your own ECR and set `image.repository`.
- From v2.5 on, the controller handles **all** new Services of type `LoadBalancer` (as NLBs, **internal by default**). Use the annotation `service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing` only when you really need a public one.

AWS docs: [AWS Load Balancer Controller](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html) · [Installation guide](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/installation/)

## Install the EBS CSI driver (block storage)

> **In simple words:** Pods like databases need their own disk that survives restarts. The EBS CSI driver creates an EBS volume for each PersistentVolumeClaim and attaches it to whichever node the pod runs on.

```bash
# 1. IAM role for the driver (AWS managed policy)
eksctl create iamserviceaccount \
  --cluster $CLUSTER_NAME --region $AWS_REGION \
  --namespace kube-system --name ebs-csi-controller-sa \
  --role-name AmazonEKS_EBS_CSI_DriverRole-$CLUSTER_NAME --role-only \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve

# 2. Install the EKS add-on with that role
eksctl create addon --cluster $CLUSTER_NAME --region $AWS_REGION \
  --name aws-ebs-csi-driver \
  --service-account-role-arn arn:aws:iam::${AWS_ACCOUNT}:role/AmazonEKS_EBS_CSI_DriverRole-$CLUSTER_NAME \
  --force

kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver
```

Make an encrypted **gp3** class the default:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
parameters:
  type: gp3
  encrypted: "true"
EOF
kubectl annotate storageclass gp2 storageclass.kubernetes.io/is-default-class=false --overwrite 2>/dev/null || true
kubectl get storageclass                    # gp3 marked (default)
```

AWS docs: [Amazon EBS CSI driver](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html)

## Set up EFS (shared storage)

> **In simple words:** EFS is a network file system that **many pods on many nodes can read and write at the same time** (`ReadWriteMany`), which suits shared uploads, content and caches. You create the file system, let the nodes reach it on the NFS port, and install the EFS CSI driver.

### 1. IAM role and the EFS CSI add-on

```bash
EFS_ROLE=AmazonEKS_EFS_CSI_DriverRole-$CLUSTER_NAME
eksctl create iamserviceaccount \
  --cluster $CLUSTER_NAME --region $AWS_REGION \
  --namespace kube-system --name efs-csi-controller-sa \
  --role-name $EFS_ROLE --role-only \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy \
  --approve

# let both driver service accounts (controller and node) use the role
TRUST_POLICY=$(aws iam get-role --role-name $EFS_ROLE --query 'Role.AssumeRolePolicyDocument' --output json | \
  sed -e 's/efs-csi-controller-sa/efs-csi-*/' -e 's/StringEquals/StringLike/')
aws iam update-assume-role-policy --role-name $EFS_ROLE --policy-document "$TRUST_POLICY"

eksctl create addon --cluster $CLUSTER_NAME --region $AWS_REGION \
  --name aws-efs-csi-driver \
  --service-account-role-arn arn:aws:iam::${AWS_ACCOUNT}:role/$EFS_ROLE \
  --force
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-efs-csi-driver
```

### 2. Security group: allow NFS (port 2049) from the cluster only

```bash
CLUSTER_SG=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION \
  --query cluster.resourcesVpcConfig.clusterSecurityGroupId --output text)

EFS_SG=$(aws ec2 create-security-group --region $AWS_REGION --vpc-id $VPC_ID \
  --group-name efs-nfs-$CLUSTER_NAME --description "NFS from EKS nodes to EFS" \
  --query GroupId --output text)

aws ec2 authorize-security-group-ingress --region $AWS_REGION --group-id $EFS_SG \
  --protocol tcp --port 2049 --source-group $CLUSTER_SG

# only if other networks must mount this EFS (e.g. a VPN range), add them explicitly:
# aws ec2 authorize-security-group-ingress --region $AWS_REGION --group-id $EFS_SG --protocol tcp --port 2049 --cidr <OTHER_CIDR>
```

Allowing the **cluster security group** (which managed nodes use) is tighter than opening NFS to the whole VPC CIDR.

### 3. Create the file system and one mount target per AZ

```bash
EFS_ID=$(aws efs create-file-system --region $AWS_REGION --encrypted \
  --performance-mode generalPurpose --throughput-mode elastic \
  --tags Key=Name,Value=efs-$CLUSTER_NAME --query FileSystemId --output text)

until [ "$(aws efs describe-file-systems --region $AWS_REGION --file-system-id $EFS_ID \
  --query 'FileSystems[0].LifeCycleState' --output text)" = "available" ]; do sleep 5; done

for SUBNET in $PRIVATE_SUBNETS; do
  aws efs create-mount-target --region $AWS_REGION --file-system-id $EFS_ID \
    --subnet-id $SUBNET --security-groups $EFS_SG
done
aws efs describe-mount-targets --region $AWS_REGION --file-system-id $EFS_ID \
  --query 'MountTargets[].[SubnetId,AvailabilityZoneName,LifeCycleState]' --output table
echo "EFS_ID=$EFS_ID"
```

### 4. StorageClass for dynamic EFS volumes

```bash
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap          # each PVC gets its own EFS access point (directory)
  fileSystemId: ${EFS_ID}
  directoryPerms: "700"
  basePath: "/dynamic"
EOF
```

Workloads then request `storageClassName: efs-sc` with `accessModes: [ReadWriteMany]`.

AWS docs: [Amazon EFS CSI driver](https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html)

## Install Istio

> **In simple words:** Istio adds a **service mesh**: a small proxy next to each pod that handles encryption between services (mTLS), traffic routing, retries and detailed metrics, without changing application code. `istio-base` installs its CRDs, and `istiod` is the control plane.

```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts && helm repo update istio
kubectl create namespace istio-system

helm install istio-base istio/base -n istio-system --version $ISTIO_VERSION \
  --set defaultRevision=default --wait

helm install istiod istio/istiod -n istio-system --version $ISTIO_VERSION \
  --set-json 'pilot.env={"PILOT_SCOPE_GATEWAY_TO_NAMESPACE":"true"}' --wait

kubectl get pods -n istio-system          # istiod Running
helm ls -n istio-system
```

| Setting | Meaning |
|---|---|
| Pinned `--version` on both charts | `istio-base` and `istiod` must be the **same** version. Check Istio's supported Kubernetes versions before upgrading either |
| `PILOT_SCOPE_GATEWAY_TO_NAMESPACE=true` | A `Gateway` resource only configures gateway pods **in its own namespace**, so one team's Gateway can't take over another team's ingress gateway |

Turn on sidecar injection for an application namespace. Existing pods only get the proxy after a restart:

```bash
kubectl label namespace my-app istio-injection=enabled --overwrite
kubectl rollout restart deployment -n my-app
kubectl get pods -n my-app            # READY 2/2 = app container + istio-proxy
```

Optional: an **internal** ingress gateway, exposed through an NLB by the Load Balancer Controller:

```bash
helm install istio-ingress istio/gateway -n istio-ingress --create-namespace --version $ISTIO_VERSION \
  --set service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"=internal \
  --set service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-nlb-target-type"=ip
kubectl get svc -n istio-ingress      # EXTERNAL-IP shows the internal NLB hostname
```

Because of `PILOT_SCOPE_GATEWAY_TO_NAMESPACE`, `Gateway` resources for this gateway must be created in the `istio-ingress` namespace.

Docs: [Install Istio with Helm](https://istio.io/latest/docs/setup/install/helm/) · [Istio supported releases](https://istio.io/latest/docs/releases/supported-releases/)

## Verify the whole cluster

> **In simple words:** A quick health check of every piece before handing the cluster to application teams.

```bash
kubectl get nodes -o wide                                            # all Ready
kubectl get pods -A | grep -v -E 'Running|Completed'                 # should print only the header
eksctl get addons --cluster $CLUSTER_NAME --region $AWS_REGION       # all ACTIVE
eksctl get iamserviceaccount --cluster $CLUSTER_NAME --region $AWS_REGION
kubectl -n kube-system get deploy aws-load-balancer-controller
kubectl get storageclass                                             # gp3 (default), efs-sc
kubectl get pods -n istio-system
```

Storage smoke test: one EBS volume and one shared EFS volume, mounted by a test pod:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: test-ebs }
spec: { accessModes: [ReadWriteOnce], storageClassName: gp3, resources: { requests: { storage: 1Gi } } }
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: test-efs }
spec: { accessModes: [ReadWriteMany], storageClassName: efs-sc, resources: { requests: { storage: 1Gi } } }
---
apiVersion: v1
kind: Pod
metadata: { name: storage-test }
spec:
  containers:
    - name: test
      image: busybox:1.36
      command: ["sh", "-c", "date | tee /ebs/ok /efs/ok && sleep 3600"]
      volumeMounts: [{ name: ebs, mountPath: /ebs }, { name: efs, mountPath: /efs }]
  volumes:
    - { name: ebs, persistentVolumeClaim: { claimName: test-ebs } }
    - { name: efs, persistentVolumeClaim: { claimName: test-efs } }
EOF
kubectl wait --for=condition=Ready pod/storage-test --timeout=180s
kubectl get pvc test-ebs test-efs              # both Bound
kubectl exec storage-test -- cat /ebs/ok /efs/ok
kubectl delete pod storage-test && kubectl delete pvc test-ebs test-efs
```

Next step: install Argo CD with the [Argo CD on EKS runbook](#/tool/argocd-eks).

## Troubleshooting

> **In simple words:** Cluster problems are usually network (nodes can't reach AWS), IAM (an add-on's role is missing or too old), or tags and security groups (load balancers or EFS can't find or reach things).

| Problem | Fix |
|---|---|
| `eksctl create cluster` fails or hangs | Open the failing **CloudFormation** stack's **Events** tab, or run `eksctl utils describe-stacks --cluster $CLUSTER_NAME --region $AWS_REGION` |
| Nodes never join / stay `NotReady` | Private subnets have no route out (NAT) and no VPC endpoints for ECR, S3, EC2 and STS, or the subnet is out of IPs |
| A version is "in extended support" | Upgrade the control plane, then the node group: `eksctl upgrade cluster`, then `eksctl upgrade nodegroup` |
| `--approve` ran as a separate command | A missing `\` at the end of the previous line. Re-run the whole command as one block |
| Policy ARN with an empty account ID (`arn:aws:iam:::policy/…`) | `AWS_ACCOUNT` wasn't set. Run the variables block again |
| Load Balancer Controller logs `AccessDenied` | The IAM policy is older than the controller. Download `iam_policy.json` for `$LBC_VERSION` and create a new policy version |
| Ingress or Service gets no load balancer | Subnets aren't tagged (`kubernetes.io/role/internal-elb` / `elb`). Check `kubectl logs -n kube-system deploy/aws-load-balancer-controller` |
| EBS PVC stays `Pending` | Normal with `WaitForFirstConsumer` until a pod uses it. Otherwise check the add-on's role: `kubectl describe pvc <name>` |
| EFS mount times out | Port 2049 not allowed from the nodes' security group, or no mount target in the node's AZ |
| `create-security-group` returns two values | Always add `--query GroupId` so only the ID is captured |
| Pods show `1/1` instead of `2/2` after enabling Istio | Namespace not labelled, or pods not restarted after labelling |
| `iamserviceaccount … already exists` | Add `--override-existing-serviceaccounts`, or delete it with `eksctl delete iamserviceaccount` first |

## Clean up

> **In simple words:** Delete in reverse order. Remove anything that created AWS resources from *inside* Kubernetes (load balancers, volumes) **before** the cluster, otherwise those resources are left behind and keep costing money.

```bash
# 1. Load balancers and volumes created by Kubernetes
kubectl get ingress -A; kubectl get svc -A | grep LoadBalancer      # delete these first
helm uninstall istio-ingress -n istio-ingress 2>/dev/null
helm uninstall istiod istio-base -n istio-system
kubectl get pvc -A                                                    # delete PVCs you no longer need
helm uninstall aws-load-balancer-controller -n kube-system

# 2. EFS (mount targets, then file system, then security group)
for MT in $(aws efs describe-mount-targets --region $AWS_REGION --file-system-id $EFS_ID --query 'MountTargets[].MountTargetId' --output text); do
  aws efs delete-mount-target --region $AWS_REGION --mount-target-id $MT; done
sleep 60
aws efs delete-file-system --region $AWS_REGION --file-system-id $EFS_ID
aws ec2 delete-security-group --region $AWS_REGION --group-id $EFS_SG

# 3. The cluster (also removes the IAM roles eksctl created for service accounts)
eksctl delete cluster -f eks.yaml --wait

# 4. The customer-managed policy
aws iam delete-policy --policy-arn arn:aws:iam::${AWS_ACCOUNT}:policy/AWSLoadBalancerControllerIAMPolicy-$CLUSTER_NAME
```

## Quick reference

> **In simple words:** The whole runbook as one compact list, for when you've done it before.

```bash
# variables: see step 1
eksctl create cluster -f eks.yaml && aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
aws ec2 create-tags --region $AWS_REGION --resources $PRIVATE_SUBNETS --tags Key=kubernetes.io/role/internal-elb,Value=1

# Load Balancer Controller
curl -fsSL -o lbc-iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/${LBC_VERSION}/docs/install/iam_policy.json
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy-$CLUSTER_NAME --policy-document file://lbc-iam-policy.json
eksctl create iamserviceaccount --cluster $CLUSTER_NAME --region $AWS_REGION --namespace kube-system --name aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole-$CLUSTER_NAME --attach-policy-arn arn:aws:iam::${AWS_ACCOUNT}:policy/AWSLoadBalancerControllerIAMPolicy-$CLUSTER_NAME --approve
helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --version ${LBC_VERSION#v} \
  --set clusterName=$CLUSTER_NAME --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller --set region=$AWS_REGION --set vpcId=$VPC_ID

# EBS
eksctl create iamserviceaccount --cluster $CLUSTER_NAME --region $AWS_REGION --namespace kube-system --name ebs-csi-controller-sa \
  --role-name AmazonEKS_EBS_CSI_DriverRole-$CLUSTER_NAME --role-only --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy --approve
eksctl create addon --cluster $CLUSTER_NAME --region $AWS_REGION --name aws-ebs-csi-driver \
  --service-account-role-arn arn:aws:iam::${AWS_ACCOUNT}:role/AmazonEKS_EBS_CSI_DriverRole-$CLUSTER_NAME --force

# EFS: role + add-on, security group, file system + mount targets, StorageClass (see step 8)

# Istio
helm install istio-base istio/base -n istio-system --create-namespace --version $ISTIO_VERSION --set defaultRevision=default --wait
helm install istiod istio/istiod -n istio-system --version $ISTIO_VERSION --set-json 'pilot.env={"PILOT_SCOPE_GATEWAY_TO_NAMESPACE":"true"}' --wait
```
