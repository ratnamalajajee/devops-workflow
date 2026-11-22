# Capstone: End-to-End Delivery on AWS

This project ties every guide together into the workflow you'd find on a real platform team. When you finish, a `git push` to your app repo will build a container, publish it to ECR, and have Argo CD roll it out to an EKS cluster that Terraform created, with no manual `kubectl` in the delivery path.

> **Cost:** This project runs an EKS cluster, EC2 nodes and a load balancer. Expect a few dollars per day. Do it in a focused session or two, and **run the final cleanup step**.

## Start here: the big picture in simple words

> **In simple words:** This project connects everything you learned into one automatic "assembly line". A developer changes the code, and a few minutes later the new version is live on a real cloud server, with no manual steps.

### Watch how it works

```svg Watch it work: Terraform building the platform, GitHub Actions publishing an image with OIDC, Argo CD rolling it out to EKS, users reaching it and monitoring watching. The animation loops.
<svg viewBox="0 0 600 458" role="img" data-anim="capstone" data-dur="42.16" data-starts="0 5.1 9.52 14.28 18.7 23.12 27.88 32.64 37.74" aria-label="Animated end-to-end delivery. Build the platform: terraform apply in platform-infra creates the VPC 10.20.0.0/16, the EKS cluster capstone, the ECR repository and the IAM role that GitHub Actions may assume with OIDC. CI, build and publish: you push a change to main in the hello-app repository, which starts the build-and-release workflow in GitHub Actions. Actions uses OIDC to assume the role gha-hello-app-ecr-push and gets short-lived credentials, so no AWS keys are stored in GitHub. It builds the image and pushes hello-app tagged with the commit SHA to ECR. It then runs kustomize edit set image in hello/dev and commits the new tag to the gitops repository. CD, deliver and run: Argo CD in the cluster sees the change and auto-syncs it to the hello-dev namespace, with no kubectl by hand. The nodes pull the new image from ECR and Kubernetes replaces the pods one at a time. Users reach the new version through the load balancer created by the Service. Monitoring keeps watching: kubectl top shows pod and node usage, and CloudWatch holds the control plane logs.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<rect x="128" y="8" width="466" height="90" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="5 4"/>
<rect x="128" y="104" width="466" height="260" rx="12" fill="none" stroke="#ff9900" stroke-width="2" stroke-dasharray="7 4"/>
<rect x="136" y="212" width="450" height="90" rx="12" fill="none" stroke="#3b82f6" stroke-width="1.5" stroke-dasharray="5 4"/>
<polyline points="64,59 205,59" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="205,59 365,59" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="365,59 524,59" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="294,59 285,59 285,162 280,162" fill="none" stroke-linejoin="round" stroke="#eab308" stroke-width="1.8" stroke-dasharray="3 3" stroke-opacity=".75"/>
<polyline points="365,59 365,162" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="64,162 210,162" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="64,188 64,200 410,200 410,188" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="300,200 300,240" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="524,84 524,240" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="524,265 365,265" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="365,162 365,265" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="64,265 205,265 365,265" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="365,265 365,333" fill="none" stroke-linejoin="round" stroke="#0d9488" stroke-width="1.8" stroke-dasharray="6 3" stroke-opacity=".7"/>
<rect x="134" y="14" width="43.4" height="16" rx="5" class="dg-box"/><text x="138" y="24" font-size="11" class="dg-muted">GitHub</text>
<rect x="134" y="111" width="91.6" height="18" rx="5" class="dg-box"/><text x="138" y="123" font-size="13" font-weight="800" fill="#ff9900">AWS account</text>
<rect x="142" y="218" width="102.4" height="16" rx="5" class="dg-box"/><text x="146" y="228" font-size="11" class="dg-muted">VPC 10.20.0.0/16</text>
<g><rect x="8" y="30" width="112" height="58" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.121;0.2258" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/></rect><rect x="12" y="34" width="104" height="50" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="64" y="55.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">You</text><text x="64" y="71" text-anchor="middle" font-size="11" class="dg-muted">git push</text></g>
<g><rect x="136" y="30" width="138" height="58" rx="12" fill="#475569" fill-opacity=".18" stroke="#475569" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.121;0.2258" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/></rect><rect x="140" y="34" width="130" height="50" rx="9" class="dg-box" stroke="#475569" stroke-width="2.2"/><text x="205" y="55.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">hello-app repo</text><text x="205" y="71" text-anchor="middle" font-size="11" class="dg-muted">code + Dockerfile</text></g>
<g><rect x="290" y="30" width="150" height="58" rx="12" fill="#2563eb" fill-opacity=".18" stroke="#2563eb" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.121;0.5484" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/></rect><rect x="294" y="34" width="142" height="50" rx="9" class="dg-box" stroke="#2563eb" stroke-width="2.2"/><text x="365" y="55.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">GitHub Actions</text><text x="365" y="71" text-anchor="middle" font-size="11" class="dg-muted">build-and-release</text></g>
<g><rect x="456" y="30" width="136" height="58" rx="12" fill="#ea580c" fill-opacity=".18" stroke="#ea580c" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4435;0.6613" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/></rect><rect x="460" y="34" width="128" height="50" rx="9" class="dg-box" stroke="#ea580c" stroke-width="2.2"/><text x="524" y="55.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">gitops repo</text><text x="524" y="71" text-anchor="middle" font-size="11" class="dg-muted">hello/dev image tag</text></g>
<g><rect x="8" y="132" width="112" height="60" rx="12" fill="#7c3aed" fill-opacity=".18" stroke="#7c3aed" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.121" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/></rect><rect x="12" y="136" width="104" height="52" rx="9" class="dg-box" stroke="#7c3aed" stroke-width="2.2"/><text x="64" y="158.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Terraform</text><text x="64" y="174" text-anchor="middle" font-size="11" class="dg-muted">platform-infra</text></g>
<g><rect x="136" y="132" width="148" height="60" rx="12" fill="#dc2626" fill-opacity=".18" stroke="#dc2626" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1;0" keyTimes="0;0.121;0.2258;0.3387" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/></rect><rect x="140" y="136" width="140" height="52" rx="9" class="dg-box" stroke="#dc2626" stroke-width="2.2"/><text x="210" y="158.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">IAM role (OIDC)</text><text x="210" y="174" text-anchor="middle" font-size="11" class="dg-muted">gha-hello-app-ecr-push</text></g>
<g><rect x="286" y="132" width="158" height="60" rx="12" fill="#f97316" fill-opacity=".18" stroke="#f97316" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1;0;1;0" keyTimes="0;0.121;0.3387;0.4435;0.6613;0.7742" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/></rect><rect x="290" y="136" width="150" height="52" rx="9" class="dg-box" stroke="#f97316" stroke-width="2.2"/><text x="365" y="158.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Amazon ECR</text><text x="365" y="174" text-anchor="middle" font-size="11" class="dg-muted">hello-app:&lt;sha&gt;</text></g>
<g><rect x="8" y="236" width="112" height="58" rx="12" fill="#6366f1" fill-opacity=".18" stroke="#6366f1" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7742;0.8952" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/></rect><rect x="12" y="240" width="104" height="50" rx="9" class="dg-box" stroke="#6366f1" stroke-width="2.2"/><text x="64" y="261.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Users</text><text x="64" y="277" text-anchor="middle" font-size="11" class="dg-muted">curl the LB</text></g>
<rect x="146" y="240" width="118" height="50" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.121" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><rect x="142" y="236" width="126" height="58" rx="12" fill="#c026d3" fill-opacity=".18" stroke="#c026d3" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7742;0.8952" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/></rect><rect x="146" y="240" width="118" height="50" rx="9" class="dg-box" stroke="#c026d3" stroke-width="2.2"/><text x="205" y="261.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Load balancer</text><text x="205" y="277" text-anchor="middle" font-size="11" class="dg-muted">Service type LB</text></g>
<g><rect x="273" y="236" width="184" height="58" rx="12" fill="#0ea5e9" fill-opacity=".18" stroke="#0ea5e9" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1" keyTimes="0;0.121;0.5484" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/></rect><rect x="277" y="240" width="176" height="50" rx="9" class="dg-box" stroke="#0ea5e9" stroke-width="2.2"/><text x="365" y="261.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">EKS cluster capstone</text><text x="365" y="277" text-anchor="middle" font-size="11" class="dg-muted">hello pods · hello-dev</text></g>
<rect x="468" y="240" width="112" height="50" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.121" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><rect x="464" y="236" width="120" height="58" rx="12" fill="#ea580c" fill-opacity=".18" stroke="#ea580c" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5484;0.6613" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/></rect><rect x="468" y="240" width="112" height="50" rx="9" class="dg-box" stroke="#ea580c" stroke-width="2.2"/><text x="524" y="261.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Argo CD</text><text x="524" y="277" text-anchor="middle" font-size="11" class="dg-muted">auto-sync</text></g>
<rect x="277" y="312" width="176" height="42" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.121" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><rect x="273" y="308" width="184" height="50" rx="12" fill="#059669" fill-opacity=".18" stroke="#059669" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8952" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/></rect><rect x="277" y="312" width="176" height="42" rx="9" class="dg-box" stroke="#059669" stroke-width="2.2"/><text x="365" y="329.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Monitoring</text><text x="365" y="345" text-anchor="middle" font-size="11" class="dg-muted">kubectl top · CloudWatch</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6613;0.8952" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><circle cx="453" cy="240" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M448.5,240 L452,243.5 L457.5,236.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0073;0.104" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><animateMotion path="M64,162 L210,162" keyPoints="0;0;1;1" keyTimes="0;0.0073;0.104;1" calcMode="linear" dur="42.16s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0073;0.104" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><animateMotion path="M64,162 L64,200 L410,200 L410,175" keyPoints="0;0;1;1" keyTimes="0;0.0073;0.104;1" calcMode="linear" dur="42.16s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0073;0.104" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><animateMotion path="M64,162 L64,200 L300,200 L300,265" keyPoints="0;0;1;1" keyTimes="0;0.0073;0.104;1" calcMode="linear" dur="42.16s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1262;0.1681" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><animateMotion path="M64,59 L205,59" keyPoints="0;0;1;1" keyTimes="0;0.1262;0.1681;1" calcMode="linear" dur="42.16s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1734;0.2153" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><animateMotion path="M205,59 L365,59" keyPoints="0;0;1;1" keyTimes="0;0.1734;0.2153;1" calcMode="linear" dur="42.16s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2315;0.2766" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><animateMotion path="M365,59 L285,59 L285,162 L210,162" keyPoints="0;0;1;1" keyTimes="0;0.2315;0.2766;1" calcMode="linear" dur="42.16s" repeatCount="indefinite"/><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2845;0.3297" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><animateMotion path="M210,162 L285,162 L285,59 L365,59" keyPoints="0;0;1;1" keyTimes="0;0.2845;0.3297;1" calcMode="linear" dur="42.16s" repeatCount="indefinite"/><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.345;0.4289" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><animateMotion path="M365,59 L365,162" keyPoints="0;0;1;1" keyTimes="0;0.345;0.4289;1" calcMode="linear" dur="42.16s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4498;0.5337" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><animateMotion path="M365,59 L524,59" keyPoints="0;0;1;1" keyTimes="0;0.4498;0.5337;1" calcMode="linear" dur="42.16s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.554;0.5992" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><animateMotion path="M524,59 L524,265" keyPoints="0;0;1;1" keyTimes="0;0.554;0.5992;1" calcMode="linear" dur="42.16s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6071;0.65" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><animateMotion path="M524,265 L365,265" keyPoints="0;0;1;1" keyTimes="0;0.6071;0.65;1" calcMode="linear" dur="42.16s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6681;0.7584" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><animateMotion path="M365,162 L365,265" keyPoints="0;0;1;1" keyTimes="0;0.6681;0.7584;1" calcMode="linear" dur="42.16s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7802;0.8286" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><animateMotion path="M64,265 L205,265 L365,265" keyPoints="0;0;1;1" keyTimes="0;0.7802;0.8286;1" calcMode="linear" dur="42.16s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8371;0.8855" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><animateMotion path="M365,265 L205,265 L64,265" keyPoints="0;0;1;1" keyTimes="0;0.8371;0.8855;1" calcMode="linear" dur="42.16s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.9015;0.9853" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><animateMotion path="M365,265 L365,333" keyPoints="0;0;1;1" keyTimes="0;0.9015;0.9853;1" calcMode="linear" dur="42.16s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(20.4,382.5) scale(.8)"><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g><text x="31.8" y="386">build / apply</text><g transform="translate(127.8,382.5) scale(.8)"><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g><text x="140" y="386">code and image</text><g transform="translate(241.6,382.5) scale(.8)"><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g><text x="254.6" y="386">OIDC credentials</text><g transform="translate(366.6,382.5) scale(.8)"><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g><text x="378" y="386">request</text><g transform="translate(439.6,382.5) scale(.8)"><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g><text x="451" y="386">reply</text><g transform="translate(501.4,382.5) scale(.8)"><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g><text x="512.8" y="386">metrics</text></g>
<rect x="12" y="398" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="398" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="42.16s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.121" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><circle cx="36" cy="426" r="14" fill="#7c3aed"/><text x="36" y="431" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="421" font-size="14" font-weight="800" fill="#7c3aed">Terraform builds the platform</text><text x="578" y="421" text-anchor="end" font-size="10.5" class="dg-muted">Build the platform · 1/9</text><text x="60" y="442" font-size="12.5" class="dg-text">terraform apply: the VPC, the EKS cluster capstone, ECR and the OIDC role.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.121;0.2258" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><circle cx="36" cy="426" r="14" fill="#2563eb"/><text x="36" y="431" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="421" font-size="14" font-weight="800" fill="#2563eb">You push to hello-app</text><text x="578" y="421" text-anchor="end" font-size="10.5" class="dg-muted">CI: build and publish · 2/9</text><text x="60" y="442" font-size="12.5" class="dg-text">A push to main starts the build-and-release workflow in GitHub Actions.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2258;0.3387" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><circle cx="36" cy="426" r="14" fill="#2563eb"/><text x="36" y="431" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="421" font-size="14" font-weight="800" fill="#2563eb">OIDC: no AWS keys stored</text><text x="578" y="421" text-anchor="end" font-size="10.5" class="dg-muted">CI: build and publish · 3/9</text><text x="60" y="442" font-size="12.5" class="dg-text">Actions assumes gha-hello-app-ecr-push and gets short-lived credentials.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3387;0.4435" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><circle cx="36" cy="426" r="14" fill="#2563eb"/><text x="36" y="431" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="421" font-size="14" font-weight="800" fill="#2563eb">Build and push the image</text><text x="578" y="421" text-anchor="end" font-size="10.5" class="dg-muted">CI: build and publish · 4/9</text><text x="60" y="442" font-size="12.5" class="dg-text">docker build, then push hello-app:&lt;sha&gt; to ECR, tagged with the commit.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4435;0.5484" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><circle cx="36" cy="426" r="14" fill="#2563eb"/><text x="36" y="431" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="421" font-size="14" font-weight="800" fill="#2563eb">CI bumps the tag in gitops</text><text x="578" y="421" text-anchor="end" font-size="10.5" class="dg-muted">CI: build and publish · 5/9</text><text x="60" y="442" font-size="12.5" class="dg-text">kustomize edit set image in hello/dev, then commit and push to gitops.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5484;0.6613" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><circle cx="36" cy="426" r="14" fill="#059669"/><text x="36" y="431" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="421" font-size="14" font-weight="800" fill="#059669">Argo CD sees it and syncs</text><text x="578" y="421" text-anchor="end" font-size="10.5" class="dg-muted">CD: deliver and run · 6/9</text><text x="60" y="442" font-size="12.5" class="dg-text">Auto-sync applies the new tag to hello-dev. No kubectl by hand.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6613;0.7742" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><circle cx="36" cy="426" r="14" fill="#059669"/><text x="36" y="431" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="421" font-size="14" font-weight="800" fill="#059669">A rolling update pulls the image</text><text x="578" y="421" text-anchor="end" font-size="10.5" class="dg-muted">CD: deliver and run · 7/9</text><text x="60" y="442" font-size="12.5" class="dg-text">Nodes pull hello-app:&lt;sha&gt; from ECR and replace pods one at a time.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7742;0.8952" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><circle cx="36" cy="426" r="14" fill="#059669"/><text x="36" y="431" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="421" font-size="14" font-weight="800" fill="#059669">Users get the new version</text><text x="578" y="421" text-anchor="end" font-size="10.5" class="dg-muted">CD: deliver and run · 8/9</text><text x="60" y="442" font-size="12.5" class="dg-text">curl http://&lt;lb-hostname&gt;/ goes through the load balancer and returns it.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8952" calcMode="discrete" dur="42.16s" repeatCount="indefinite"/><circle cx="36" cy="426" r="14" fill="#059669"/><text x="36" y="431" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">9</text><text x="60" y="421" font-size="14" font-weight="800" fill="#059669">Monitoring keeps watching</text><text x="578" y="421" text-anchor="end" font-size="10.5" class="dg-muted">CD: deliver and run · 9/9</text><text x="60" y="442" font-size="12.5" class="dg-text">kubectl top shows pod and node use; CloudWatch has the control plane logs.</text></g>
</svg>
```

```steps
#7c3aed | Build the platform | Terraform builds the platform | terraform apply: the VPC, the EKS cluster capstone, ECR and the OIDC role.
#2563eb | CI: build and publish | You push to hello-app | A push to main starts the build-and-release workflow in GitHub Actions.
#2563eb | CI: build and publish | OIDC: no AWS keys stored | Actions assumes gha-hello-app-ecr-push and gets short-lived credentials.
#2563eb | CI: build and publish | Build and push the image | docker build, then push hello-app:<sha> to ECR, tagged with the commit.
#2563eb | CI: build and publish | CI bumps the tag in gitops | kustomize edit set image in hello/dev, then commit and push to gitops.
#059669 | CD: deliver and run | Argo CD sees it and syncs | Auto-sync applies the new tag to hello-dev. No kubectl by hand.
#059669 | CD: deliver and run | A rolling update pulls the image | Nodes pull hello-app:<sha> from ECR and replace pods one at a time.
#059669 | CD: deliver and run | Users get the new version | curl http://<lb-hostname>/ goes through the load balancer and returns it.
#059669 | CD: deliver and run | Monitoring keeps watching | kubectl top shows pod and node use; CloudWatch has the control plane logs.
```

### The journey of one code change

1. **A developer edits the app** on their laptop and pushes the change to GitHub. *(Git)*
2. **GitHub Actions** notices the push, builds a fresh Docker image and uploads it to AWS ECR. *(Docker, AWS)*
3. **CI writes the new image version** into the GitOps repository. *(Git)*
4. **Argo CD** sees the change in Git and tells Kubernetes to use the new image. *(Argo CD)*
5. **Kubernetes** swaps the old copies for new ones, one at a time, so users never see downtime. *(Kubernetes)*
6. **All of it runs** on AWS servers and networks that **Terraform** built from code. *(Terraform, AWS)*

**Think of it like this:** a car factory. Terraform builds the factory, Docker makes the standard boxes, GitHub Actions is the conveyor belt, Argo CD is the shift supervisor following the plan, and Kubernetes is the floor team doing the work.

### Before you start

- Finish the earlier guides, or at least their labs. This project assumes them.
- Work through the phases **in order**, and check each **Checkpoint** before moving on.
- This uses real AWS resources that cost money. Do it in one or two sittings and **always run the Cleanup step**.

## Target architecture

> **In simple words:** A map of what you're building and which tool is responsible for each part.

```text
 app repo ──push──▶ GitHub Actions ──build+push──▶ Amazon ECR
     │                    │
     │                    └──commit new image tag──▶ gitops repo
     │                                                   │
     │                         Argo CD (in EKS) ◀──pull──┘
     │                                │ sync
     ▼                                ▼
 Terraform ──creates──▶ VPC + EKS cluster + ECR + IAM (OIDC role for CI)
```

| Layer | Tool | Guide |
|---|---|---|
| Infrastructure | Terraform: VPC, EKS, ECR, IAM | Terraform, AWS |
| Packaging | Dockerfile, multi-stage, non-root | Docker |
| CI | GitHub Actions with AWS OIDC (no stored keys) | Terraform (CI step) |
| Runtime | Kubernetes Deployment, Service, Ingress, HPA | Kubernetes |
| CD | Argo CD app-of-apps, auto-sync | Argo CD |
| Ops skills | Logs, debugging, cleanup | Linux, all |

## Repositories

> **In simple words:** Three Git repositories with separate jobs: one for infrastructure, one for the app's code, and one describing what runs in the cluster.

Create three repos (or three folders in one monorepo):

```text
platform-infra/      # Terraform
  ├── bootstrap/     # state bucket
  └── envs/dev/      # vpc, eks, ecr, iam
hello-app/           # application source + Dockerfile + CI workflow
gitops/              # what runs in the cluster
  ├── apps/          # Argo CD Applications (app-of-apps)
  └── hello/         # Helm chart or Kustomize for hello-app
      ├── base/
      └── dev/
```

## Phase 1: Infrastructure with Terraform

> **In simple words:** Use Terraform to build the network, the Kubernetes cluster and the image store in AWS, all from code.

In `platform-infra/envs/dev`, use the community modules:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name               = "capstone"
  cidr               = "10.20.0.0/16"
  azs                = ["us-east-1a", "us-east-1b"]
  private_subnets    = ["10.20.1.0/24", "10.20.2.0/24"]
  public_subnets     = ["10.20.101.0/24", "10.20.102.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true          # cheaper for non-prod

  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name                   = "capstone"
  kubernetes_version     = "1.33"
  endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.medium"]
      min_size       = 2
      max_size       = 3
      desired_size   = 2
    }
  }
}

resource "aws_ecr_repository" "hello" {
  name                 = "hello-app"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
}
```

> **Note:** Module input names change between major versions. Check the module's README on the Terraform Registry for the version you pin, and run `terraform validate` early. Use a Kubernetes version that EKS currently supports.

Then:

```bash
terraform init && terraform apply            # ~15-20 min
aws eks update-kubeconfig --name capstone --region us-east-1
kubectl get nodes
```

**Checkpoint:** two `Ready` nodes, and an empty ECR repo.

## Phase 2: CI with GitHub Actions and OIDC

> **In simple words:** Make GitHub build and upload a new image on every push. OIDC lets GitHub log into AWS safely without storing any passwords.

Let GitHub Actions assume an AWS role without any stored keys. Add this to Terraform:

```hcl
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "gha_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:<your-github-user>/hello-app:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "gha_ecr_push" {
  name               = "gha-hello-app-ecr-push"
  assume_role_policy = data.aws_iam_policy_document.gha_trust.json
}

resource "aws_iam_role_policy_attachment" "ecr_push" {
  role       = aws_iam_role.gha_ecr_push.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}
```

In `hello-app/.github/workflows/build.yaml`:

```yaml
name: build-and-release
on:
  push:
    branches: [main]
permissions:
  id-token: write
  contents: read
env:
  AWS_REGION: us-east-1
  ECR_REPO: hello-app
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: aws-actions/configure-aws-credentials@v6
        with:
          role-to-assume: arn:aws:iam::<ACCOUNT_ID>:role/gha-hello-app-ecr-push
          aws-region: ${{ env.AWS_REGION }}
      - id: ecr
        uses: aws-actions/amazon-ecr-login@v2
      - name: Build and push
        run: |
          IMAGE=${{ steps.ecr.outputs.registry }}/${{ env.ECR_REPO }}:${GITHUB_SHA::7}
          docker build -t $IMAGE .
          docker push $IMAGE
      - name: Bump tag in gitops repo
        env:
          GH_TOKEN: ${{ secrets.GITOPS_TOKEN }}   # fine-grained PAT with contents:write on gitops repo
        run: |
          git clone https://x-access-token:${GH_TOKEN}@github.com/<you>/gitops.git
          cd gitops/hello/dev
          kustomize edit set image hello-app=${{ steps.ecr.outputs.registry }}/${{ env.ECR_REPO }}:${GITHUB_SHA::7}
          git config user.name "ci-bot" && git config user.email "ci-bot@users.noreply.github.com"
          git commit -am "hello-app: deploy ${GITHUB_SHA::7}" && git push
```

**Checkpoint:** pushing to `hello-app` puts a new image in ECR and creates a commit in `gitops`.

## Phase 3: Kubernetes manifests

> **In simple words:** Write the files that tell Kubernetes how to run your app: how many copies, health checks, and how visitors reach it.

In `gitops/hello/base`, write a Deployment (3 replicas, requests and limits, readiness and liveness probes, non-root `securityContext`), a ClusterIP Service, and an HPA. In `gitops/hello/dev/kustomization.yaml`:

```yaml
resources:
  - ../base
namespace: hello-dev
images:
  - name: hello-app
    newName: <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/hello-app
    newTag: "initial"
```

Expose it with one of these:

- a Service of `type: LoadBalancer` (simplest: creates an AWS load balancer), or
- install the **AWS Load Balancer Controller** and use an Ingress with `ingressClassName: alb`.

> **Tip:** EKS nodes can pull from ECR in the same account out of the box, because the node role includes ECR read-only access. No image pull secret needed.

## Phase 4: Argo CD delivery

> **In simple words:** Connect Argo CD to your GitOps repository, so every new image version is deployed automatically.

1. Install Argo CD on EKS (Argo CD guide, install step), ideally with Helm.
2. In `gitops/apps/` create `hello-dev.yaml` pointing at `hello/dev`, with automated sync, prune and self-heal.
3. Create and apply the **root** app-of-apps pointing at `gitops/apps`.

```bash
kubectl apply -f gitops/apps/root.yaml
argocd app list
kubectl get svc -n hello-dev        # grab the load balancer hostname
curl http://<elb-hostname>/
```

**The full loop:** change the response message in `hello-app`, push to `main`, and watch:

1. GitHub Actions builds and pushes `hello-app:<sha>`.
2. CI commits the new tag to `gitops`.
3. Argo CD detects the change and syncs.
4. Kubernetes performs a rolling update.
5. `curl` returns the new message.

## Phase 5: Operate it

> **In simple words:** Practise real-life situations: a bad release, a traffic spike and a manual change, and see how the system reacts.

Prove you can run what you built:

- **Break it:** push an image whose `/health` returns 500. What happens to the rollout? Use `kubectl describe`, `kubectl logs` and the Argo CD UI to explain it, then fix it with `git revert`.
- **Scale it:** generate load (`kubectl run load --rm -it --image=busybox:1.36 -- sh -c "while true; do wget -qO- http://hello.hello-dev; done"`) and watch the HPA scale out.
- **Drift:** `kubectl edit` the deployment's replicas and watch self-heal revert it.
- **Observe:** check node and pod metrics with `kubectl top`, and the control plane logs in CloudWatch.
- **Document:** write a `README.md` in each repo explaining how to run, deploy and roll back. Explaining it in writing is what makes the knowledge stick.

## Cleanup

> **In simple words:** Delete everything in the right order so nothing is left running and costing money.

Delete in this order. Kubernetes-created load balancers must go **before** Terraform destroys the VPC, otherwise the destroy hangs on dependencies.

```bash
# 1. Remove apps (deletes the AWS load balancers they created)
kubectl delete -f gitops/apps/root.yaml
kubectl delete ns hello-dev
kubectl get svc -A | grep LoadBalancer      # should be empty

# 2. Remove images, then destroy infrastructure
aws ecr batch-delete-image --repository-name hello-app \
  --image-ids "$(aws ecr list-images --repository-name hello-app --query 'imageIds[*]' --output json)"
cd platform-infra/envs/dev && terraform destroy

# 3. Double-check nothing is left
aws eks list-clusters
aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'
aws ec2 describe-nat-gateways --filter Name=state,Values=available --query 'NatGateways[].NatGatewayId'
```

### You're done

You have built and operated a production-shaped delivery platform. Good next topics:

- **Observability:** Prometheus, Grafana, Loki, OpenTelemetry
- **Security:** policy as code (Kyverno / OPA Gatekeeper), image signing (cosign), External Secrets
- **Progressive delivery:** Argo Rollouts for canary and blue-green releases
- **Scaling:** Karpenter for nodes, KEDA for event-driven pods
- **Certifications:** AWS Solutions Architect Associate, CKA / CKAD, Terraform Associate
