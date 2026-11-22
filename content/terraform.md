# Terraform

Terraform describes infrastructure in code (HCL), works out what needs to change, and makes it so. Instead of clicking through the console or writing long CLI scripts, you **declare** the end state ("a VPC with 4 subnets and an EKS cluster"). Terraform creates it, tracks it in **state**, and can rebuild or destroy it on demand.

> **Note:** You need the AWS CLI configured (`aws sts get-caller-identity` works) before starting. Terraform uses the same credentials.

> **Tip:** No Docker or Kubernetes on your laptop? Use the **cloud lab machine** in the [Practice lab](#/lab). It has Docker, kind, kubectl, Helm, Terraform, the AWS CLI and the Argo CD CLI ready to go.

## Start here: Terraform in simple words

> **In simple words:** Terraform lets you **write down** the cloud setup you want (servers, networks, databases) in a text file. Terraform then builds it for you, can show you every change before it happens, and can delete it all with one command.

### Watch how it works

```svg Watch it work: terraform init, plan and apply building an S3 bucket and saving the state in a locked S3 backend, then a change by hand showing up as drift, then terraform destroy. The animation loops.
<svg viewBox="0 0 600 412" role="img" data-anim="terraform" data-dur="38.42" data-starts="0 4.42 9.18 13.94 19.04 23.46 28.22 33.32" aria-label="Animated Terraform workflow. Build it: you write main.tf with an S3 bucket, its versioning set to Enabled, and an S3 backend for the state. terraform init downloads the hashicorp/aws provider from the Terraform Registry into the .terraform folder and sets up the backend. terraform plan locks the state, reads it, finds it empty, compares it with your code and shows Plan: 3 to add. terraform apply asks you to type yes, then the provider calls the AWS APIs and the bucket tf-first-1a2b3c4d appears with versioning enabled. The new state is saved in the S3 backend and the lock is released. Drift: someone suspends versioning by hand in the AWS console, but the code and the state still say Enabled. The next terraform plan reads the real bucket, finds the difference and shows an update in place from Suspended back to Enabled; apply would put it back. Destroy: terraform destroy, after you type yes, deletes everything this code created, and the state becomes empty.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<rect x="136" y="100" width="456" height="218" rx="12" fill="none" stroke="#ff9900" stroke-width="2" stroke-dasharray="7 4"/>
<polyline points="136,48 160,48" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="284,48 308,48" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="468,48 444,48" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="222,76 222,140" fill="none" stroke-linejoin="round" stroke="#0d9488" stroke-width="1.8" stroke-dasharray="6 3" stroke-opacity=".7"/>
<polyline points="376,76 376,228 418,228" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="376,158 418,158" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="124,288 498,288 498,252" fill="none" stroke-linejoin="round" stroke="#e11d48" stroke-width="1.6" stroke-dasharray="3 4" stroke-opacity=".6"/>
<rect x="464" y="107" width="122" height="18" rx="5" class="dg-box"/><text x="582" y="119" text-anchor="end" font-size="13" font-weight="800" fill="#ff9900">AWS · us-east-1</text>
<g><rect x="8" y="16" width="132" height="64" rx="12" fill="#7c3aed" fill-opacity=".18" stroke="#7c3aed" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1;0" keyTimes="0;0.115;0.2389;0.3628" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/></rect><rect x="12" y="20" width="124" height="56" rx="9" class="dg-box" stroke="#7c3aed" stroke-width="2.2"/><text x="74" y="44.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">main.tf</text><text x="74" y="60" text-anchor="middle" font-size="11" class="dg-muted">what you want</text></g>
<g><rect x="156" y="16" width="132" height="64" rx="12" fill="#7c3aed" fill-opacity=".18" stroke="#7c3aed" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1;0;1;0;1" keyTimes="0;0.115;0.2389;0.3628;0.4956;0.6106;0.7345" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/></rect><rect x="160" y="20" width="124" height="56" rx="9" class="dg-box" stroke="#7c3aed" stroke-width="2.2"/><text x="222" y="44.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">terraform</text><text x="222" y="60" text-anchor="middle" font-size="11" class="dg-muted">init · plan · apply</text></g>
<rect x="308" y="20" width="136" height="56" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.115" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><rect x="304" y="16" width="144" height="64" rx="12" fill="#f59e0b" fill-opacity=".18" stroke="#f59e0b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0;1;0" keyTimes="0;0.115;0.2389;0.3628;0.4956;0.7345;0.8673" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/></rect><rect x="308" y="20" width="136" height="56" rx="9" class="dg-box" stroke="#f59e0b" stroke-width="2.2"/><text x="376" y="44.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">AWS provider</text><text x="376" y="60" text-anchor="middle" font-size="11" class="dg-muted">in .terraform/</text></g>
<g><rect x="464" y="16" width="128" height="64" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.115;0.2389" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/></rect><rect x="468" y="20" width="120" height="56" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="528" y="44.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Registry</text><text x="528" y="60" text-anchor="middle" font-size="11" class="dg-muted">hashicorp/aws</text></g>
<g><rect x="143" y="136" width="158" height="68" rx="12" fill="#0d9488" fill-opacity=".18" stroke="#0d9488" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0;1" keyTimes="0;0.115;0.3628;0.4956;0.6106;0.7345" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/></rect><rect x="147" y="140" width="150" height="60" rx="9" class="dg-box" stroke="#0d9488" stroke-width="2.2"/><text x="222" y="159" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">State in S3</text><text x="222" y="174.5" text-anchor="middle" font-size="11" class="dg-muted">terraform.tfstate</text><text x="222" y="189.5" text-anchor="middle" font-size="11" class="dg-muted">locked while in use</text></g>
<rect x="418" y="132" width="160" height="52" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.3628" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><rect x="414" y="128" width="168" height="60" rx="12" fill="#16a34a" fill-opacity=".18" stroke="#16a34a" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.3628;0.4956;0.8673" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/></rect><rect x="418" y="132" width="160" height="52" rx="9" class="dg-box" stroke="#16a34a" stroke-width="2.2"/><text x="498" y="154.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">S3 bucket</text><text x="498" y="170" text-anchor="middle" font-size="11" class="dg-muted">tf-first-1a2b3c4d</text><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8673" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><rect x="418" y="132" width="160" height="52" rx="9" fill="#e11d48"/><text x="498" y="162.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">✕ deleted</text></g></g>
<rect x="418" y="204" width="160" height="48" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.3628" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><rect x="414" y="200" width="168" height="56" rx="12" fill="#16a34a" fill-opacity=".18" stroke="#16a34a" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.3628;0.4956;0.6106" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/></rect><rect x="418" y="204" width="160" height="48" rx="9" class="dg-box" stroke="#16a34a" stroke-width="2.2"/><text x="498" y="224.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Versioning</text><text x="498" y="240" text-anchor="middle" font-size="11" class="dg-muted">status: Enabled</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6106;0.8673" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><rect x="418" y="204" width="160" height="48" rx="9" fill="#d97706"/><text x="498" y="232.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">Suspended, by hand</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8673" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><rect x="418" y="204" width="160" height="48" rx="9" fill="#e11d48"/><text x="498" y="232.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">✕ deleted</text></g></g>
<g><rect x="8" y="258" width="120" height="60" rx="28" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6106;0.7345" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/></rect><rect x="12" y="262" width="112" height="52" rx="25" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="68" y="284.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Someone</text><text x="68" y="300" text-anchor="middle" font-size="11" class="dg-muted">in the console</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.2389;0.4956;0.7345" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><circle cx="297" cy="140" r="9.5" fill="#d97706" stroke="#fff" stroke-width="2"/><rect x="292.5" y="139" width="9" height="6.5" rx="1.2" fill="#fff"/><path d="M294.2,139 V137 A2.8,2.8 0 0 1 299.8,137 V139" fill="none" stroke="#fff" stroke-width="1.6"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7345;0.8673" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><circle cx="578" cy="204" r="9.5" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M578,199.5 V204.8 M578,207.6 V207.8" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0069;0.0989" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><animateMotion path="M74,48 L222,48" keyPoints="0;0;1;1" keyTimes="0;0.0069;0.0989;1" calcMode="linear" dur="38.42s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1212;0.177" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><animateMotion path="M528,48 L376,48" keyPoints="0;0;1;1" keyTimes="0;0.1212;0.177;1" calcMode="linear" dur="38.42s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.177;0.2265" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><animateMotion path="M222,48 L222,170" keyPoints="0;0;1;1" keyTimes="0;0.177;0.2265;1" calcMode="linear" dur="38.42s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2464;0.3455" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><animateMotion path="M222,170 L222,48" keyPoints="0;0;1;1" keyTimes="0;0.2464;0.3455;1" calcMode="linear" dur="38.42s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3695;0.4292" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><animateMotion path="M376,48 L376,158 L498,158" keyPoints="0;0;1;1" keyTimes="0;0.3695;0.4292;1" calcMode="linear" dur="38.42s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4159;0.4823" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><animateMotion path="M376,48 L376,228 L498,228" keyPoints="0;0;1;1" keyTimes="0;0.4159;0.4823;1" calcMode="linear" dur="38.42s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5025;0.5945" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><animateMotion path="M222,48 L222,170" keyPoints="0;0;1;1" keyTimes="0;0.5025;0.5945;1" calcMode="linear" dur="38.42s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6181;0.7172" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><animateMotion path="M68,288 L498,288 L498,228" keyPoints="0;0;1;1" keyTimes="0;0.6181;0.7172;1" calcMode="linear" dur="38.42s" repeatCount="indefinite"/><g><circle r="7" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M0,-3.5 V1 M0,3.2 V3.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7412;0.7942" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><animateMotion path="M376,48 L376,228 L498,228" keyPoints="0;0;1;1" keyTimes="0;0.7412;0.7942;1" calcMode="linear" dur="38.42s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8009;0.8566" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><animateMotion path="M498,228 L376,228 L376,48 L222,48" keyPoints="0;0;1;1" keyTimes="0;0.8009;0.8566;1" calcMode="linear" dur="38.42s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8739;0.9336" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><animateMotion path="M376,48 L376,158 L498,158" keyPoints="0;0;1;1" keyTimes="0;0.8739;0.9336;1" calcMode="linear" dur="38.42s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.9403;0.9894" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><animateMotion path="M222,48 L222,170" keyPoints="0;0;1;1" keyTimes="0;0.9403;0.9894;1" calcMode="linear" dur="38.42s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(21.2,336.5) scale(.8)"><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g><text x="33.4" y="340">code / provider</text><g transform="translate(139.8,336.5) scale(.8)"><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g><text x="151.2" y="340">state</text><g transform="translate(201.6,336.5) scale(.8)"><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g><text x="213" y="340">AWS API call</text><g transform="translate(302.6,336.5) scale(.8)"><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g><text x="314" y="340">read real AWS</text><g transform="translate(409.2,336.5) scale(.8)"><g><circle r="7" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M0,-3.5 V1 M0,3.2 V3.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/></g></g><text x="420.6" y="340">change by hand</text></g>
<rect x="12" y="352" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="352" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="38.42s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.115" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><circle cx="36" cy="380" r="14" fill="#7c3aed"/><text x="36" y="385" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="375" font-size="14" font-weight="800" fill="#7c3aed">You write what you want</text><text x="578" y="375" text-anchor="end" font-size="10.5" class="dg-muted">Build it · 1/8</text><text x="60" y="396" font-size="12.5" class="dg-text">main.tf: an S3 bucket with versioning Enabled, and an S3 backend for state.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.115;0.2389" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><circle cx="36" cy="380" r="14" fill="#7c3aed"/><text x="36" y="385" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="375" font-size="14" font-weight="800" fill="#7c3aed">terraform init</text><text x="578" y="375" text-anchor="end" font-size="10.5" class="dg-muted">Build it · 2/8</text><text x="60" y="396" font-size="12.5" class="dg-text">Downloads the hashicorp/aws provider into .terraform/ and sets up the backend.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2389;0.3628" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><circle cx="36" cy="380" r="14" fill="#7c3aed"/><text x="36" y="385" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="375" font-size="14" font-weight="800" fill="#7c3aed">terraform plan</text><text x="578" y="375" text-anchor="end" font-size="10.5" class="dg-muted">Build it · 3/8</text><text x="60" y="396" font-size="12.5" class="dg-text">It locks and reads the state (empty) and compares it with the code: 3 to add.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3628;0.4956" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><circle cx="36" cy="380" r="14" fill="#7c3aed"/><text x="36" y="385" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="375" font-size="14" font-weight="800" fill="#7c3aed">terraform apply</text><text x="578" y="375" text-anchor="end" font-size="10.5" class="dg-muted">Build it · 4/8</text><text x="60" y="396" font-size="12.5" class="dg-text">You type yes. The provider calls the AWS APIs and the bucket appears.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4956;0.6106" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><circle cx="36" cy="380" r="14" fill="#7c3aed"/><text x="36" y="385" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="375" font-size="14" font-weight="800" fill="#7c3aed">The state is saved in S3</text><text x="578" y="375" text-anchor="end" font-size="10.5" class="dg-muted">Build it · 5/8</text><text x="60" y="396" font-size="12.5" class="dg-text">It now lists the bucket. The lock is released for the next person.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6106;0.7345" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><circle cx="36" cy="380" r="14" fill="#d97706"/><text x="36" y="385" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="375" font-size="14" font-weight="800" fill="#d97706">Someone changes it by hand</text><text x="578" y="375" text-anchor="end" font-size="10.5" class="dg-muted">Drift · 6/8</text><text x="60" y="396" font-size="12.5" class="dg-text">Versioning is suspended in the console. Code and state still say Enabled.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7345;0.8673" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><circle cx="36" cy="380" r="14" fill="#d97706"/><text x="36" y="385" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="375" font-size="14" font-weight="800" fill="#d97706">The next plan shows the drift</text><text x="578" y="375" text-anchor="end" font-size="10.5" class="dg-muted">Drift · 7/8</text><text x="60" y="396" font-size="12.5" class="dg-text">plan reads the real bucket: ~ status &quot;Suspended&quot; -&gt; &quot;Enabled&quot;. 1 to change.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8673" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><circle cx="36" cy="380" r="14" fill="#e11d48"/><text x="36" y="385" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="375" font-size="14" font-weight="800" fill="#e11d48">terraform destroy</text><text x="578" y="375" text-anchor="end" font-size="10.5" class="dg-muted">Destroy · 8/8</text><text x="60" y="396" font-size="12.5" class="dg-text">After a yes, everything this code created is deleted. The state is empty.</text></g>
</svg>
```

```steps
#7c3aed | Build it | You write what you want | main.tf: an S3 bucket with versioning Enabled, and an S3 backend for state.
#7c3aed | Build it | terraform init | Downloads the hashicorp/aws provider into .terraform/ and sets up the backend.
#7c3aed | Build it | terraform plan | It locks and reads the state (empty) and compares it with the code: 3 to add.
#7c3aed | Build it | terraform apply | You type yes. The provider calls the AWS APIs and the bucket appears.
#7c3aed | Build it | The state is saved in S3 | It now lists the bucket. The lock is released for the next person.
#d97706 | Drift | Someone changes it by hand | Versioning is suspended in the console. Code and state still say Enabled.
#d97706 | Drift | The next plan shows the drift | plan reads the real bucket: ~ status "Suspended" -> "Enabled". 1 to change.
#e11d48 | Destroy | terraform destroy | After a yes, everything this code created is deleted. The state is empty.
```

### The problem Terraform solves

Building cloud infrastructure by clicking in the AWS console works once, but:

- Nobody remembers exactly which buttons were clicked.
- Building the same thing again for "test" and "production" gives slightly different results.
- Forgotten resources keep costing money.

With Terraform, the **file is the instructions**. Anyone can read it, review it, and rebuild exactly the same thing again.

### A real-life comparison

Clicking in the console is like **cooking without a recipe**: it might taste good, but you can't repeat it exactly. Terraform is **the written recipe**, and Terraform is also the chef who follows it perfectly every time.

It's **declarative**: you describe *what* you want ("2 servers and 1 network"), not *how* to build it step by step. It's like ordering in a restaurant: you say "pasta, please", not "boil water, add salt…".

### How it works

```text
  main.tf  ──terraform plan──▶  "Here's what I WILL do: +2 create, ~1 change"
 (your wish)                         │  you review it
                         terraform apply ▼
                         AWS builds the resources
                                     │
                         terraform.tfstate  ◀── Terraform's notebook of what it built
```

### Key words

| Word | Simple meaning |
|---|---|
| **HCL / `.tf` file** | The language and files where you write what you want |
| **Provider** | A plug-in that teaches Terraform to talk to a platform (AWS, Azure, GitHub…) |
| **Resource** | One thing to create, like a server or a bucket |
| **Variable** | A blank to fill in, so one file can be reused with different values |
| **Output** | A value printed at the end, like a server's IP address |
| **State** | Terraform's notebook listing what it created, so it knows what to change next time |
| **Plan** | A preview of changes. Nothing is built yet |
| **Apply** | Actually make the changes |
| **Destroy** | Delete everything this code created |
| **Module** | A reusable folder of Terraform code, like a recipe you share with others |

### The four commands you'll use 90% of the time

| Command | Meaning |
|---|---|
| `terraform init` | Get ready: download the plug-ins |
| `terraform plan` | Show me what would change |
| `terraform apply` | Do it |
| `terraform destroy` | Undo everything |

### Check yourself

1. What does `terraform plan` do, and does it change anything?
2. What is the state file for?
3. Why is Terraform better than clicking in the console for a team?

> **Tip:** Answers: 1) It previews the changes and changes nothing. 2) It's Terraform's record of what it built, so it knows what to update or delete. 3) The setup is written down, reviewable, repeatable and easy to delete.

## Why Infrastructure as Code

> **In simple words:** Infrastructure as Code means describing servers and networks in files instead of clicking, so the setup can be reviewed, repeated and undone.

| Click-ops | Infrastructure as Code |
|---|---|
| Undocumented, hard to repeat | The code *is* the documentation |
| Drift between environments | dev / staging / prod built from the same modules |
| No review | Changes go through pull requests, with `plan` output in review |
| Slow disaster recovery | `terraform apply` rebuilds everything |
| Forgotten resources cost money | `terraform destroy` removes everything it created |

Terraform is **declarative**: you describe *what*, not *how*. It builds a dependency graph and works out the order itself.

## Install and set up

> **In simple words:** Check Terraform is installed, and add the editor plug-in that colours and checks your `.tf` files.

Terraform was installed during **Workstation Setup**. Check it:

```bash
terraform -version
```

> **Tip:** Different projects often pin different Terraform versions. `tfenv` (`git clone https://github.com/tfutils/tfenv.git ~/.tfenv`) lets you switch with `tfenv use 1.x.y`. OpenTofu (`tofu`) is an open-source fork with the same workflow.

Install the **HashiCorp Terraform** VS Code extension for syntax highlighting, formatting and docs on hover.

## Core workflow: your first resource

> **In simple words:** Write a tiny file that creates one storage bucket, then go through init → plan → apply → destroy to see the whole cycle.

```bash
mkdir -p ~/code/tf-first && cd ~/code/tf-first
```

Create `main.tf`:

```hcl
terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Project   = "devops-launchpad"
      ManagedBy = "terraform"
    }
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "demo" {
  bucket = "tf-first-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_versioning" "demo" {
  bucket = aws_s3_bucket.demo.id
  versioning_configuration {
    status = "Enabled"
  }
}
```

Run the four core commands:

```bash
terraform init      # download providers, set up backend
terraform plan      # preview: + create, ~ update, - destroy
terraform apply     # make it real (type "yes")
terraform destroy   # tear it all down
```

Also useful:

```bash
terraform fmt -recursive   # format code
terraform validate         # syntax and type check
terraform state list       # what Terraform manages
terraform show             # current state in detail
terraform output           # print outputs
```

> **Why:** Always read the `plan`. A line saying `must be replaced` means *destroy and recreate*. For a database, that means data loss.

### Anatomy of a block

```hcl
resource "aws_s3_bucket" "demo" {   # resource "<TYPE>" "<LOCAL NAME>"
  bucket = "my-bucket"              # argument
}
# Reference it elsewhere as: aws_s3_bucket.demo.id / .arn / .bucket
```

## Variables, outputs and locals

> **In simple words:** Variables are blanks you fill in, outputs are answers Terraform prints at the end, and locals are short nicknames for values you reuse.

`variables.tf`:

```hcl
variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "allowed_ssh_cidrs" {
  type    = list(string)
  default = []
}
```

`locals.tf`:

```hcl
locals {
  name_prefix = "launchpad-${var.environment}"
  common_tags = {
    Environment = var.environment
    Owner       = "platform-team"
  }
}
```

`outputs.tf`:

```hcl
output "bucket_name" {
  value = aws_s3_bucket.demo.bucket
}
```

Set values in several ways (later sources override earlier ones):

```bash
terraform apply -var="environment=staging"
echo 'environment = "staging"' > staging.tfvars && terraform apply -var-file=staging.tfvars
export TF_VAR_environment=staging        # environment variable
# terraform.tfvars and *.auto.tfvars are loaded automatically
```

> **Warning:** Mark secrets `sensitive = true` and never commit `*.tfvars` files that contain them. Better still, read secrets from AWS Secrets Manager with a data source.

## State and remote backends

> **In simple words:** State is Terraform's notebook of what it built. Keeping it in a shared, locked S3 bucket stops teammates overwriting each other's work.

Terraform records what it created in **state** (`terraform.tfstate`). By default this is a local file. That's fine for learning, and dangerous for teams:

- It may contain secrets in plain text.
- Two people applying at once can corrupt it.
- Lose the file and Terraform forgets your infrastructure exists.

**Use a remote backend with locking.** On AWS that means S3. Terraform 1.10+ supports S3-native locking with `use_lockfile`, so no DynamoDB table is needed.

Create the state bucket once (bootstrap):

```bash
STATE_BUCKET=tfstate-$(aws sts get-caller-identity --query Account --output text)-us-east-1
aws s3api create-bucket --bucket $STATE_BUCKET --region us-east-1
aws s3api put-bucket-versioning --bucket $STATE_BUCKET --versioning-configuration Status=Enabled
echo $STATE_BUCKET
```

Then add a backend to your project and run `terraform init -migrate-state`:

```hcl
terraform {
  backend "s3" {
    bucket       = "tfstate-123456789012-us-east-1"   # your bucket
    key          = "launchpad/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

Useful state commands:

```bash
terraform state list
terraform state show aws_s3_bucket.demo
terraform state mv aws_s3_bucket.demo aws_s3_bucket.logs   # rename without recreating
terraform import aws_s3_bucket.existing my-existing-bucket # adopt existing resource
terraform plan -refresh-only                               # detect drift
```

> **Tip:** Add `.terraform/`, `*.tfstate*` and `*.tfvars` (when they hold secrets) to `.gitignore`. **Do** commit `.terraform.lock.hcl`, which pins provider versions.

## Data sources, count and for_each

> **In simple words:** Data sources **read** things that already exist. `count` and `for_each` create several similar things from one block, like a loop.

**Data sources** read existing information without managing it:

```hcl
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_caller_identity" "current" {}
```

**for_each** creates one resource per item in a map or set. Prefer it over `count`, because removing an item doesn't shift the others.

```hcl
variable "buckets" {
  type    = set(string)
  default = ["logs", "artifacts", "backups"]
}

resource "aws_s3_bucket" "this" {
  for_each = var.buckets
  bucket   = "${local.name_prefix}-${each.key}-${random_id.suffix.hex}"
}

output "bucket_arns" {
  value = { for k, b in aws_s3_bucket.this : k => b.arn }
}
```

**count** is good for on/off switches:

```hcl
resource "aws_eip" "nat" {
  count  = var.enable_nat ? 1 : 0
  domain = "vpc"
}
```

## Modules

> **In simple words:** A module is a reusable package of Terraform code, like a function, so you write a "web server" once and use it many times.

A **module** is a folder of `.tf` files with inputs (variables) and outputs. Modules are how you reuse code across environments and teams.

```text
tf-platform/
├── modules/
│   └── web-server/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── envs/
    ├── dev/
    │   ├── main.tf
    │   └── backend.tf
    └── prod/
        ├── main.tf
        └── backend.tf
```

`modules/web-server/main.tf`:

```hcl
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_security_group" "web" {
  name_prefix = "${var.name}-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.web.id]
  user_data              = <<-EOF
    #!/bin/bash
    dnf install -y nginx
    echo "<h1>${var.name}</h1>" > /usr/share/nginx/html/index.html
    systemctl enable --now nginx
  EOF
  tags = { Name = var.name }
}
```

`modules/web-server/variables.tf` and `outputs.tf`:

```hcl
variable "name"          { type = string }
variable "vpc_id"        { type = string }
variable "subnet_id"     { type = string }
variable "instance_type" {
  type    = string
  default = "t3.micro"
}

output "public_ip" { value = aws_instance.web.public_ip }
```

Use it, along with a module from the public registry:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name               = "launchpad-dev"
  cidr               = "10.0.0.0/16"
  azs                = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets    = ["10.0.11.0/24", "10.0.12.0/24"]
  enable_nat_gateway = false       # NAT costs money; enable when you need it
  map_public_ip_on_launch = true
}

module "web" {
  source    = "../../modules/web-server"
  name      = "launchpad-dev-web"
  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.public_subnets[0]
}

output "web_url" { value = "http://${module.web.public_ip}" }
```

```bash
cd envs/dev
terraform init && terraform apply
curl $(terraform output -raw web_url)
terraform destroy
```

> **Tip:** Browse [registry.terraform.io](https://registry.terraform.io/) before writing your own module. The `terraform-aws-modules` collection (vpc, eks, rds, iam) is the de facto standard. Always pin `version`.

## Environments: dev, staging, prod

> **In simple words:** How to build separate copies of the same setup for testing and for real users, without them interfering with each other.

Two common approaches:

| Approach | How | When |
|---|---|---|
| **Directory per environment** | `envs/dev`, `envs/prod`, each with its own backend key and tfvars, all calling shared modules | Most teams, and the clearest isolation |
| **Workspaces** | `terraform workspace new staging`. Same code, separate state | Small, nearly identical environments |

```bash
terraform workspace list
terraform workspace new staging
terraform workspace select staging
# inside code: terraform.workspace == "staging"
```

> **Note:** For bigger estates, teams add tools like **Terragrunt** or **Atlantis** / **HCP Terraform** to keep code DRY and run plans automatically on pull requests.

## Best practices and CI

> **In simple words:** Good habits, plus running `terraform plan` automatically on every pull request so changes get reviewed before they're applied.

- **Small, focused state files.** Separate network, cluster and apps so a mistake can't destroy everything.
- **Pin versions:** `required_version`, provider `version`, module `version`.
- **Never edit state by hand.** Use `terraform state` commands.
- **Protect critical resources** with `lifecycle { prevent_destroy = true }`.
- **Lint and scan:** `tflint`, `trivy config .` or `checkov -d .`.
- **Plan in CI, apply after review.** Use OIDC so CI assumes an AWS role, with no long-lived keys.

A minimal GitHub Actions pipeline:

```yaml
name: terraform
on:
  pull_request:
  push:
    branches: [main]
permissions:
  id-token: write
  contents: read
jobs:
  plan:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: envs/dev
    steps:
      - uses: actions/checkout@v7
      - uses: hashicorp/setup-terraform@v4
      - uses: aws-actions/configure-aws-credentials@v6
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-terraform
          aws-region: us-east-1
      - run: terraform fmt -check -recursive
      - run: terraform init -input=false
      - run: terraform validate
      - run: terraform plan -input=false -out=tfplan
      - if: github.ref == 'refs/heads/main'
        run: terraform apply -input=false tfplan
```

## Troubleshooting

> **In simple words:** The common Terraform errors and how to fix each one.

| Problem | Fix |
|---|---|
| `Error acquiring the state lock` | Someone else is applying, or a run crashed. Wait, then if needed `terraform force-unlock <ID>` |
| `No valid credential sources found` | `aws sts get-caller-identity`, `aws sso login`, check `AWS_PROFILE` |
| Plan shows unexpected replace | Look for `# forces replacement`. Some arguments can't change in place. |
| Resource exists but not in state | `terraform import` (or an `import {}` block) |
| Drift from manual console changes | `terraform plan -refresh-only`, then fix the code or re-apply |
| Provider version conflicts | `terraform init -upgrade`, check `.terraform.lock.hcl` |

Turn on debug logging with `TF_LOG=DEBUG terraform plan`.

## Lab: your own network and web tier

> **In simple words:** Practice time: build a network and two web servers with your own module, then destroy it all.

1. Bootstrap a versioned S3 state bucket and configure a backend with `use_lockfile = true`.
2. Build a VPC across 2 AZs with the registry module (public and private subnets, NAT disabled).
3. Write your own `web-server` module and deploy **two** instances using `for_each` over a map like `{ blue = "t3.micro", green = "t3.micro" }`.
4. Output both URLs and `curl` them.
5. Change the page content in user-data, run `plan`, and explain why the instance is (or isn't) replaced. Hint: look up `user_data_replace_on_change`.
6. Create a `prod.tfvars` with different names, deploy to a second state key, then destroy both environments.

### Cheat sheet

| Task | Command |
|---|---|
| Initialize | `terraform init` |
| Preview | `terraform plan -out=tfplan` |
| Apply saved plan | `terraform apply tfplan` |
| Destroy | `terraform destroy` |
| Format / validate | `terraform fmt -recursive` / `terraform validate` |
| One output | `terraform output -raw name` |
| Target one resource | `terraform apply -target=module.web` (debugging only) |
