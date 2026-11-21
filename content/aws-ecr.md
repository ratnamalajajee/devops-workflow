# Amazon ECR: Container Registry

Amazon ECR (Elastic Container Registry) is AWS's private Docker registry. It stores your container images next to where they run (ECS, EKS, Lambda and EC2) with IAM permissions, vulnerability scanning, automatic cleanup and replication built in. This guide covers repositories, pushing and pulling, tags vs digests, scanning, lifecycle policies, permissions, caching public images and CI usage.

> **Note:** You need Docker and the AWS CLI configured. The examples use the **sample app** from [CI/CD Basics](#/tool/cicd-basics); any image works.

> **Cost:** Storage is about **$0.10 per GB-month**. Pulls from the same Region by AWS services are free; data transfer to the internet or other Regions is charged. Lifecycle policies keep storage small. See [ECR pricing](https://aws.amazon.com/ecr/pricing/).

## Start here: ECR in simple words

> **In simple words:** ECR is a **private Docker Hub inside your AWS account**. You push images to it from your laptop or CI, and your servers, ECS and Kubernetes pull them. Access is controlled by IAM, so there are no extra registry passwords to manage.

### Watch how it works

```svg Watch it work: Docker logs in with a temporary token, pushes only the missing layers, ECR scans the image, ECS and EKS pull it, and a lifecycle policy cleans up. The animation loops.
<svg viewBox="0 0 600 464" role="img" data-anim="aws-ecr" aria-label="Animated Amazon ECR flow. Push and scan: on your laptop or in CI, aws ecr get-login-password turns your IAM identity into a temporary password that is valid for 12 hours, and Docker logs in with it. docker push then checks which layers the repository hello-app already has: the base OS layer is already there, so only the libraries layer and the app code layer are uploaded. The tag 1.0.0 now points to the image, and because the repository has immutable tags, a later push of different content as 1.0.0 is refused. Scan on push checks the new image for known vulnerabilities: basic scanning checks operating system packages, enhanced scanning with Amazon Inspector also checks language packages. The findings are listed by severity. Pull and run: an ECS task, using its task execution role, and an EKS node, using its node IAM role, pull the image. No registry passwords are needed. Clean up: the lifecycle policy expires untagged images 7 days after they were pushed, so an old untagged image is deleted automatically, while release tags are kept.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<rect x="136" y="8" width="322" height="362" rx="12" fill="none" stroke="#ff9900" stroke-width="2" stroke-dasharray="7 4"/>
<rect x="150" y="100" width="296" height="202" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="5 4"/>
<rect x="162" y="128" width="150" height="162" rx="12" fill="none" stroke="#3b82f6" stroke-width="1.5" stroke-dasharray="5 4"/>
<polyline points="66,218 66,63 216,63" fill="none" stroke-linejoin="round" stroke="#eab308" stroke-width="1.8" stroke-dasharray="3 3" stroke-opacity=".75"/>
<polyline points="66,218 243,218" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="174,218 174,174 243,174" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="174,218 174,262 243,262" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="312,174 377,174 377,63" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="1.6" stroke-opacity=".8"/>
<polyline points="243,218 533,218 533,156" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="533,218 533,280" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="220,337 379,337 379,263" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<rect x="142" y="15" width="175.2" height="18" rx="5" class="dg-box"/><text x="146" y="27" font-size="13" font-weight="800" fill="#ff9900">Amazon ECR · us-east-1</text>
<rect x="156" y="106" width="126" height="16" rx="5" class="dg-box"/><text x="160" y="116" font-size="11" class="dg-muted">repository hello-app</text>
<rect x="168" y="134" width="137.8" height="16" rx="5" class="dg-box"/><text x="172" y="144" font-size="11" class="dg-muted">image 1.0.0 · 3 layers</text>
<g><rect x="8" y="188" width="116" height="60" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.2661" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/></rect><rect x="12" y="192" width="108" height="52" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="66" y="214.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Laptop / CI</text><text x="66" y="230" text-anchor="middle" font-size="11" class="dg-muted">docker + AWS CLI</text></g>
<g><rect x="146" y="36" width="140" height="54" rx="12" fill="#ca8a04" fill-opacity=".18" stroke="#ca8a04" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1284" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/></rect><rect x="150" y="40" width="132" height="46" rx="9" class="dg-box" stroke="#ca8a04" stroke-width="2.2"/><text x="216" y="59.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Login token</text><text x="216" y="75" text-anchor="middle" font-size="11" class="dg-muted">valid 12 hours</text></g>
<g><rect x="306" y="36" width="142" height="54" rx="12" fill="#7c3aed" fill-opacity=".18" stroke="#7c3aed" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3853;0.6239" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/></rect><rect x="310" y="40" width="134" height="46" rx="9" class="dg-box" stroke="#7c3aed" stroke-width="2.2"/><text x="377" y="59.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Scan on push</text><text x="377" y="75" text-anchor="middle" font-size="11" class="dg-muted">basic: OS packages</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5046;0.6239" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/><rect x="310" y="40" width="134" height="46" rx="9" fill="#d97706"/><text x="377" y="67.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">1 HIGH · 4 MEDIUM</text></g></g>
<g><rect x="182" y="154" width="122" height="40" rx="12" fill="#f97316" fill-opacity=".18" stroke="#f97316" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.2661;0.3853;0.6239;0.7615" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/></rect><rect x="186" y="158" width="114" height="32" rx="9" class="dg-box" stroke="#f97316" stroke-width="2.2"/><text x="243" y="178" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">base OS</text></g>
<g><rect x="182" y="198" width="122" height="40" rx="12" fill="#f97316" fill-opacity=".18" stroke="#f97316" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.1284;0.3853;0.6239;0.7615" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/></rect><rect x="186" y="202" width="114" height="32" rx="9" class="dg-box" stroke="#f97316" stroke-width="2.2"/><text x="243" y="222" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">libraries</text></g>
<g><rect x="182" y="242" width="122" height="40" rx="12" fill="#f97316" fill-opacity=".18" stroke="#f97316" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.1284;0.3853;0.6239;0.7615" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/></rect><rect x="186" y="246" width="114" height="32" rx="9" class="dg-box" stroke="#f97316" stroke-width="2.2"/><text x="243" y="266" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">your code</text></g>
<g><rect x="320" y="236" width="118" height="54" rx="12" fill="#94a3b8" fill-opacity=".18" stroke="#94a3b8" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7615;0.8807" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/></rect><rect x="324" y="240" width="110" height="46" rx="9" class="dg-box" stroke="#94a3b8" stroke-width="2.2"/><text x="379" y="259.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">old image</text><text x="379" y="275" text-anchor="middle" font-size="11" class="dg-muted">untagged, 9 days</text><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8807" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/><rect x="324" y="240" width="110" height="46" rx="9" fill="#e11d48"/><text x="379" y="267.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">expired</text></g></g>
<g><rect x="146" y="310" width="148" height="54" rx="12" fill="#e11d48" fill-opacity=".18" stroke="#e11d48" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.7615" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/></rect><rect x="150" y="314" width="140" height="46" rx="9" class="dg-box" stroke="#e11d48" stroke-width="2.2"/><text x="220" y="333.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Lifecycle policy</text><text x="220" y="349" text-anchor="middle" font-size="11" class="dg-muted">untagged &gt; 7 days</text></g>
<g><rect x="472" y="126" width="122" height="60" rx="12" fill="#0891b2" fill-opacity=".18" stroke="#0891b2" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6239;0.7615" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/></rect><rect x="476" y="130" width="114" height="52" rx="9" class="dg-box" stroke="#0891b2" stroke-width="2.2"/><text x="533" y="152.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">ECS task</text><text x="533" y="168" text-anchor="middle" font-size="11" class="dg-muted">execution role</text></g>
<g><rect x="472" y="250" width="122" height="60" rx="12" fill="#2563eb" fill-opacity=".18" stroke="#2563eb" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6239;0.7615" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/></rect><rect x="476" y="254" width="114" height="52" rx="9" class="dg-box" stroke="#2563eb" stroke-width="2.2"/><text x="533" y="276.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">EKS node</text><text x="533" y="292" text-anchor="middle" font-size="11" class="dg-muted">node IAM role</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1284;0.2661" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/><circle cx="300" cy="158" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M295.5,158 L299,161.5 L304.5,154.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2661;0.3853" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/><circle cx="312" cy="128" r="9.5" fill="#d97706" stroke="#fff" stroke-width="2"/><rect x="307.5" y="127" width="9" height="6.5" rx="1.2" fill="#fff"/><path d="M309.2,127 V125 A2.8,2.8 0 0 1 314.8,125 V127" fill="none" stroke="#fff" stroke-width="1.6"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2661;0.3853" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/><circle cx="150" cy="218" r="9.5" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M146,214 L154,222 M154,214 L146,222" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5046;0.6239" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/><circle cx="444" cy="40" r="9.5" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M444,35.5 V40.8 M444,43.6 V43.8" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6239;0.7615" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/><circle cx="590" cy="130" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M585.5,130 L589,133.5 L594.5,126.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6239;0.7615" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/><circle cx="590" cy="254" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M585.5,254 L589,257.5 L594.5,250.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8807" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/><circle cx="434" cy="240" r="9.5" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M430,236 L438,244 M438,236 L430,244" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0064;0.0578" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/><animateMotion path="M66,218 L66,63 L216,63" keyPoints="0;0;1;1" keyTimes="0;0.0064;0.0578;1" calcMode="linear" dur="21.8s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0668;0.1182" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/><animateMotion path="M216,63 L66,63 L66,218" keyPoints="0;0;1;1" keyTimes="0;0.0668;0.1182;1" calcMode="linear" dur="21.8s" repeatCount="indefinite"/><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1339;0.178" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/><animateMotion path="M66,218 L174,218 L174,174 L243,174" keyPoints="0;0;1;1" keyTimes="0;0.1339;0.178;1" calcMode="linear" dur="21.8s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1835;0.255" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/><animateMotion path="M66,218 L243,218" keyPoints="0;0;1;1" keyTimes="0;0.1835;0.255;1" calcMode="linear" dur="21.8s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1835;0.255" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/><animateMotion path="M66,218 L174,218 L174,262 L243,262" keyPoints="0;0;1;1" keyTimes="0;0.1835;0.255;1" calcMode="linear" dur="21.8s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3018;0.3555" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/><animateMotion path="M66,218 L150,218" keyPoints="0;0;1;1" keyTimes="0;0.3018;0.3555;1" calcMode="linear" dur="21.8s" repeatCount="indefinite"/><g><circle r="7" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M0,-3.5 V1 M0,3.2 V3.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3925;0.4879" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/><animateMotion path="M312,174 L377,174 L377,63" keyPoints="0;0;1;1" keyTimes="0;0.3925;0.4879;1" calcMode="linear" dur="21.8s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6321;0.7422" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/><animateMotion path="M243,218 L533,218 L533,156" keyPoints="0;0;1;1" keyTimes="0;0.6321;0.7422;1" calcMode="linear" dur="21.8s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6321;0.7422" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/><animateMotion path="M243,218 L533,218 L533,280" keyPoints="0;0;1;1" keyTimes="0;0.6321;0.7422;1" calcMode="linear" dur="21.8s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7686;0.864" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/><animateMotion path="M220,337 L379,337 L379,263" keyPoints="0;0;1;1" keyTimes="0;0.7686;0.864;1" calcMode="linear" dur="21.8s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(20.4,388.5) scale(.8)"><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g><text x="31.8" y="392">command</text><g transform="translate(94.2,388.5) scale(.8)"><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g><text x="107.2" y="392">token</text><g transform="translate(158.4,388.5) scale(.8)"><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g><text x="170.6" y="392">image layer</text><g transform="translate(254.6,388.5) scale(.8)"><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g><text x="266" y="392">check / scan</text><g transform="translate(355.6,388.5) scale(.8)"><g><circle r="7" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M0,-3.5 V1 M0,3.2 V3.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/></g></g><text x="367" y="392">refused</text></g>
<rect x="12" y="404" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="404" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="21.8s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1284" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/><circle cx="36" cy="432" r="14" fill="#f97316"/><text x="36" y="437" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="427" font-size="14" font-weight="800" fill="#f97316">Docker logs in with a temporary token</text><text x="578" y="427" text-anchor="end" font-size="10.5" class="dg-muted">Push and scan · 1/8</text><text x="60" y="448" font-size="12.5" class="dg-text">aws ecr get-login-password turns your IAM identity into a 12-hour password.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1284;0.2661" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/><circle cx="36" cy="432" r="14" fill="#f97316"/><text x="36" y="437" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="427" font-size="14" font-weight="800" fill="#f97316">docker push sends only the missing layers</text><text x="578" y="427" text-anchor="end" font-size="10.5" class="dg-muted">Push and scan · 2/8</text><text x="60" y="448" font-size="12.5" class="dg-text">ECR already has the base OS layer from an earlier push, so only 2 layers upload.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2661;0.3853" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/><circle cx="36" cy="432" r="14" fill="#f97316"/><text x="36" y="437" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="427" font-size="14" font-weight="800" fill="#f97316">Tag 1.0.0 is locked to this image</text><text x="578" y="427" text-anchor="end" font-size="10.5" class="dg-muted">Push and scan · 3/8</text><text x="60" y="448" font-size="12.5" class="dg-text">Immutable tags: pushing other content as 1.0.0 later is refused.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3853;0.5046" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/><circle cx="36" cy="432" r="14" fill="#f97316"/><text x="36" y="437" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="427" font-size="14" font-weight="800" fill="#f97316">Scan on push checks the new image</text><text x="578" y="427" text-anchor="end" font-size="10.5" class="dg-muted">Push and scan · 4/8</text><text x="60" y="448" font-size="12.5" class="dg-text">Basic scanning checks OS packages. Enhanced (Inspector) adds pip, npm and more.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5046;0.6239" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/><circle cx="36" cy="432" r="14" fill="#f97316"/><text x="36" y="437" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="427" font-size="14" font-weight="800" fill="#f97316">Findings are listed by severity</text><text x="578" y="427" text-anchor="end" font-size="10.5" class="dg-muted">Push and scan · 5/8</text><text x="60" y="448" font-size="12.5" class="dg-text">Fix them by rebuilding on a newer, slimmer base image and updating packages.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6239;0.7615" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/><circle cx="36" cy="432" r="14" fill="#0891b2"/><text x="36" y="437" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="427" font-size="14" font-weight="800" fill="#0891b2">ECS and EKS pull the image</text><text x="578" y="427" text-anchor="end" font-size="10.5" class="dg-muted">Pull and run · 6/8</text><text x="60" y="448" font-size="12.5" class="dg-text">The ECS task execution role or the EKS node role lets it pull. No passwords.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7615;0.8807" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/><circle cx="36" cy="432" r="14" fill="#e11d48"/><text x="36" y="437" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="427" font-size="14" font-weight="800" fill="#e11d48">The lifecycle policy checks old images</text><text x="578" y="427" text-anchor="end" font-size="10.5" class="dg-muted">Clean up · 7/8</text><text x="60" y="448" font-size="12.5" class="dg-text">Rule: expire untagged images 7 days after push. This one is 9 days old.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8807" calcMode="discrete" dur="21.8s" repeatCount="indefinite"/><circle cx="36" cy="432" r="14" fill="#e11d48"/><text x="36" y="437" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="427" font-size="14" font-weight="800" fill="#e11d48">The old image is deleted automatically</text><text x="578" y="427" text-anchor="end" font-size="10.5" class="dg-muted">Clean up · 8/8</text><text x="60" y="448" font-size="12.5" class="dg-text">Release tags like 1.0.0 don&#x27;t match the rule, so they stay. Storage stays small.</text></g>
</svg>
```

### How it fits

```text
 laptop / CI ──docker push──▶  ECR repository  ──pull──▶  ECS tasks / EKS pods / EC2 / Lambda
                               111122223333.dkr.ecr.us-east-1.amazonaws.com/hello-app:1.0.0
                               ├─ scan for vulnerabilities on push
                               ├─ lifecycle policy deletes old images
                               └─ replicate to another Region (optional)
```

### Key words

| Word | Simple meaning |
|---|---|
| **Registry** | Your account's ECR endpoint in one Region: `<account>.dkr.ecr.<region>.amazonaws.com` |
| **Repository** | One image name, such as `hello-app`, holding many versions |
| **Tag** | A human label on an image version, such as `1.0.0` or `sha-1a2b3c4` |
| **Digest** | The image's unique fingerprint, `sha256:…`. It never changes |
| **Image manifest** | The description of an image's layers; multi-arch images have a list of them |
| **Lifecycle policy** | Rules that delete old or untagged images automatically |
| **Pull-through cache** | ECR fetches and caches images from public registries for you |

### Check yourself

1. What's the difference between a tag and a digest?
2. How do you log Docker in to ECR without a password?
3. Why use a lifecycle policy?

> **Tip:** Answers: 1) A tag is a movable label; a digest is the fixed fingerprint of exact content. 2) `aws ecr get-login-password` creates a 12-hour token from your IAM credentials. 3) To delete old images automatically and keep storage costs down.

## Create a repository

> **In simple words:** One repository per application image. Turn on scan-on-push and immutable tags from day one.

```bash
export AWS_REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY=$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

aws ecr create-repository --repository-name hello-app \
  --image-tag-mutability IMMUTABLE \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256 \
  --tags Key=team,Value=platform

aws ecr describe-repositories --repository-names hello-app \
  --query 'repositories[0].[repositoryUri,imageTagMutability,imageScanningConfiguration.scanOnPush]' --output table
```

| Setting | Recommended | Why |
|---|---|---|
| **Tag immutability** | `IMMUTABLE` | Nobody can overwrite `1.0.0` with different content, so a tag always means the same image |
| **Scan on push** | On | Every new image is checked for known vulnerabilities |
| **Encryption** | `AES256`, or `KMS` with your own key | Images are encrypted at rest either way; KMS adds your own key policy and audit |

Repository names can contain slashes for organisation: `team-a/hello-app`, `team-b/worker`.

AWS docs: [What is Amazon ECR?](https://docs.aws.amazon.com/AmazonECR/latest/userguide/what-is-ecr.html)

## Log in, push and pull

> **In simple words:** Docker needs a login before it can push. ECR gives you a temporary 12-hour password generated from your IAM identity. Then you tag the image with the repository's full address and push.

```bash
# 1. Log Docker in (valid 12 hours)
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $REGISTRY

# 2. Build and tag with the full repository URI
cd ~/code/hello-app
docker build -t hello-app:1.0.0 .
docker tag hello-app:1.0.0 $REGISTRY/hello-app:1.0.0

# 3. Push
docker push $REGISTRY/hello-app:1.0.0

# 4. Pull (anywhere with ECR permissions)
docker pull $REGISTRY/hello-app:1.0.0

aws ecr list-images --repository-name hello-app
aws ecr describe-images --repository-name hello-app \
  --query 'imageDetails[].[imageTags[0],imageDigest,imageSizeInBytes,imagePushedAt]' --output table
```

> **Tip:** Building on an Apple Silicon Mac for x86 servers? Use `docker build --platform linux/amd64 …`, or build a multi-arch image with `docker buildx build --platform linux/amd64,linux/arm64 --push …`. Otherwise containers fail with `exec format error`.

> **Tip:** Tired of `docker login`? The **Amazon ECR Docker Credential Helper** (`amazon-ecr-credential-helper`) gets tokens automatically from your AWS credentials.

AWS docs: [Private registry authentication](https://docs.aws.amazon.com/AmazonECR/latest/userguide/registry_auth.html)

## Tags, digests and immutability

> **In simple words:** A tag is a sticky note that could move to a different image; a digest is the image's fingerprint and can't. With immutable tags, the sticky note can't move either, which makes deployments predictable.

```bash
# Try to overwrite an existing tag (fails with IMMUTABLE)
docker tag hello-app:1.0.0 $REGISTRY/hello-app:1.0.0 && docker push $REGISTRY/hello-app:1.0.0
# → tag invalid: The image tag '1.0.0' already exists … cannot be overwritten because the repository is immutable

# Pull by digest: guaranteed exact content
DIGEST=$(aws ecr describe-images --repository-name hello-app --image-ids imageTag=1.0.0 \
  --query 'imageDetails[0].imageDigest' --output text)
docker pull $REGISTRY/hello-app@$DIGEST
```

Good tagging scheme:

| Tag | Example | Purpose |
|---|---|---|
| Git SHA | `sha-1a2b3c4` | Traceable to the exact commit, set by CI |
| Semantic version | `1.4.2` | Human-friendly releases |
| Environment pointer | `prod`, `staging` | Only in **mutable** repos, or use a separate repo per environment |
| `latest` | `latest` | Convenient locally; **avoid in deployments** |

AWS docs: [Image tag mutability](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-tag-mutability.html)

## Vulnerability scanning

> **In simple words:** ECR checks your images against databases of known security holes in operating system and language packages, and lists what it finds by severity.

| Mode | How | Covers |
|---|---|---|
| **Basic** | On push, or on demand | Operating system packages |
| **Enhanced** (Amazon Inspector) | **Continuous**: rescans when new vulnerabilities are published | OS **and** language packages (pip, npm, Maven…). Inspector charges apply |

```bash
aws ecr start-image-scan --repository-name hello-app --image-id imageTag=1.0.0    # manual scan
aws ecr wait image-scan-complete --repository-name hello-app --image-id imageTag=1.0.0
aws ecr describe-image-scan-findings --repository-name hello-app --image-id imageTag=1.0.0 \
  --query 'imageScanFindings.findingSeverityCounts'
aws ecr describe-image-scan-findings --repository-name hello-app --image-id imageTag=1.0.0 \
  --query 'imageScanFindings.findings[?severity==`HIGH`].[name,uri]' --output table

# Turn on enhanced (continuous) scanning for the whole registry
aws ecr put-registry-scanning-configuration --scan-type ENHANCED \
  --rules '[{"scanFrequency":"CONTINUOUS_SCAN","repositoryFilters":[{"filter":"*","filterType":"WILDCARD"}]}]'
```

How to reduce findings: use slim or distroless base images, rebuild regularly to pick up patched base images, and pin and update dependencies.

AWS docs: [Image scanning](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-scanning.html)

## Lifecycle policies: automatic cleanup

> **In simple words:** Every CI build pushes a new image, and storage grows forever. A lifecycle policy deletes old images by rule, for example "keep the last 30 releases, delete untagged images after 7 days".

Save as `lifecycle.json`:

```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Delete untagged images after 7 days",
      "selection": { "tagStatus": "untagged", "countType": "sinceImagePushed", "countUnit": "days", "countNumber": 7 },
      "action": { "type": "expire" }
    },
    {
      "rulePriority": 2,
      "description": "Keep only the last 30 CI builds",
      "selection": { "tagStatus": "tagged", "tagPrefixList": ["sha-"], "countType": "imageCountMoreThan", "countNumber": 30 },
      "action": { "type": "expire" }
    }
  ]
}
```

```bash
# Preview what WOULD be deleted, before applying
aws ecr start-lifecycle-policy-preview --repository-name hello-app --lifecycle-policy-text file://lifecycle.json
aws ecr get-lifecycle-policy-preview --repository-name hello-app --query 'previewResults[].[imageTags[0],action.type]'

aws ecr put-lifecycle-policy --repository-name hello-app --lifecycle-policy-text file://lifecycle.json
```

Release tags like `1.4.2` aren't matched by the rules above, so they're kept.

AWS docs: [Lifecycle policies](https://docs.aws.amazon.com/AmazonECR/latest/userguide/LifecyclePolicies.html)

## Permissions: IAM and repository policies

> **In simple words:** IAM decides what your own users and roles may do. A **repository policy** is attached to the repo itself and is mainly used to let **other AWS accounts** pull.

AWS managed policies you'll attach most often:

| Policy | Allows | Give it to |
|---|---|---|
| `AmazonEC2ContainerRegistryReadOnly` | Pull (and describe) | EKS nodes, EC2 servers |
| `AmazonEC2ContainerRegistryPullOnly` | Pull only | Workloads that only pull |
| `AmazonEC2ContainerRegistryPowerUser` | Push and pull, no delete or repo admin | CI pipelines |
| `AmazonECSTaskExecutionRolePolicy` | Pull plus write logs | ECS task execution role |

Repository policy letting another account pull, `repo-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowProdAccountPull",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::444455556666:root" },
      "Action": ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"]
    }
  ]
}
```

```bash
aws ecr set-repository-policy --repository-name hello-app --policy-text file://repo-policy.json
aws ecr get-repository-policy --repository-name hello-app
```

The other account also needs an IAM policy allowing those actions plus `ecr:GetAuthorizationToken`.

AWS docs: [Repository policies](https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-policies.html)

## Pull-through cache and replication

> **In simple words:** **Pull-through cache** makes ECR fetch public images (from ECR Public, Docker Hub, Kubernetes registry…) once and keep a copy in your account. That's faster, avoids Docker Hub rate limits, and the copies get scanned. **Replication** copies your images to other Regions or accounts automatically.

```bash
# Cache images from ECR Public under the prefix "ecr-public"
aws ecr create-pull-through-cache-rule --ecr-repository-prefix ecr-public --upstream-registry-url public.ecr.aws

# Pull nginx through your cache (the repo is created automatically on first pull)
docker pull $REGISTRY/ecr-public/docker/library/nginx:latest
aws ecr describe-repositories --query "repositories[?starts_with(repositoryName,'ecr-public/')].repositoryName"
```

Docker Hub and GitHub Container Registry upstreams need credentials stored in **Secrets Manager** (name prefix `ecr-pullthroughcache/`).

Replicate every repository to another Region:

```bash
aws ecr put-replication-configuration --replication-configuration '{
  "rules": [{ "destinations": [{ "region": "us-west-2", "registryId": "'$ACCOUNT_ID'" }] }]
}'
```

AWS docs: [Pull-through cache](https://docs.aws.amazon.com/AmazonECR/latest/userguide/pull-through-cache.html) · [Replication](https://docs.aws.amazon.com/AmazonECR/latest/userguide/replication.html)

## Using ECR from CI, ECS and EKS

> **In simple words:** Each consumer just needs the right IAM permission. There are no registry passwords to distribute.

| Consumer | How it gets access |
|---|---|
| **GitHub Actions** | OIDC role with push rights, then `aws-actions/amazon-ecr-login`. See the [GitHub Actions guide](#/tool/github-actions) |
| **GitLab CI / Jenkins** | An IAM role (OIDC or instance role) with push rights, then `aws ecr get-login-password \| docker login …` |
| **ECS (Fargate/EC2)** | The **task execution role** pulls the image. See the [ECS guide](#/tool/aws-ecs) |
| **EKS nodes** | The node IAM role has `AmazonEC2ContainerRegistryReadOnly` (eksctl and EKS add it by default) |
| **EC2 server** | Instance role with pull rights, then `docker login` with `get-login-password` |

Kubernetes Deployments just use the full URI: `image: 111122223333.dkr.ecr.us-east-1.amazonaws.com/hello-app:1.0.0`.

## Troubleshooting

> **In simple words:** Most ECR errors are "not logged in", "no permission", "wrong Region or account in the URI" or "tag already exists".

| Error | Fix |
|---|---|
| `no basic auth credentials` | Run the `get-login-password \| docker login` command (tokens expire after 12 hours) |
| `denied: User … is not authorized to perform: ecr:InitiateLayerUpload` | The identity can't push. Attach PowerUser or a custom push policy |
| `name unknown: The repository … does not exist` | Create the repo first, or fix the Region or account ID in the URI |
| `tag invalid … cannot be overwritten` | The repo has immutable tags. Use a new tag |
| `manifest unknown` | That tag doesn't exist (`aws ecr list-images` to check) |
| `exec format error` when the container starts | Image built for the wrong CPU architecture. Rebuild with `--platform` |
| ECS: `CannotPullContainerError` | Task execution role missing, or the task has no route to ECR (no public IP and no NAT or VPC endpoints) |
| EKS: `ImagePullBackOff` with 403 | Node role lacks ECR read access, or a cross-account repo policy is missing |

## Clean up

> **In simple words:** Delete images and repositories you created. Storage keeps billing until they're gone.

```bash
aws ecr batch-delete-image --repository-name hello-app --image-ids imageTag=1.0.0
aws ecr delete-repository --repository-name hello-app --force          # --force deletes remaining images
aws ecr delete-pull-through-cache-rule --ecr-repository-prefix ecr-public
for r in $(aws ecr describe-repositories --query "repositories[?starts_with(repositoryName,'ecr-public/')].repositoryName" --output text); do
  aws ecr delete-repository --repository-name $r --force; done
aws ecr put-replication-configuration --replication-configuration '{"rules":[]}'
```

## Lab: a production-ready repository

> **In simple words:** Practice time: set up a repository the way a platform team would, and push to it from CI.

1. Create `hello-app` with **immutable tags** and **scan on push**.
2. Push `1.0.0` and `sha-<short-sha>` tags of the sample app; try to overwrite `1.0.0` and see it rejected.
3. Read the scan findings. Switch the base image to a newer slim version, push again, and compare the counts.
4. Add the lifecycle policy, preview it, then apply it.
5. Configure a pull-through cache for ECR Public and pull `nginx` through it.
6. From GitHub Actions (OIDC) or GitLab CI, push an image on every commit to `main`.
7. Run the image on ECS (next guide) or EKS straight from ECR.

### Cheat sheet

| Task | Command |
|---|---|
| Create repo | `aws ecr create-repository --repository-name app --image-tag-mutability IMMUTABLE --image-scanning-configuration scanOnPush=true` |
| Docker login | `aws ecr get-login-password \| docker login --username AWS --password-stdin ACCT.dkr.ecr.REGION.amazonaws.com` |
| Push | `docker tag app:1 URI:1 && docker push URI:1` |
| List images | `aws ecr describe-images --repository-name app` |
| Scan results | `aws ecr describe-image-scan-findings --repository-name app --image-id imageTag=1` |
| Lifecycle | `aws ecr put-lifecycle-policy --repository-name app --lifecycle-policy-text file://l.json` |
