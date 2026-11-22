# AWS Services in a Real Deployment

What does each AWS service actually **do** in a real company? This guide follows one made-up online shop, **ShopNow**, through a real production setup on AWS. For every service you get **when to use it**, **how ShopNow uses it**, and **what would go wrong without it**, in plain words. Then you watch the services work together at the moments that matter: a customer buying something, a new release going live, a big sale and a problem at 2 a.m.

> **Note:** ShopNow is made up, but its setup is typical of real companies running on AWS. There are no commands here: this page is about understanding. Every service card links to the hands-on guide where you build it yourself.

## Start here: meet ShopNow

> **In simple words:** ShopNow sells products online to customers across India. It must be **fast**, **always available**, **safe with payments and personal data**, and able to handle **10 times more visitors on sale days**. Each AWS service you'll meet solves one part of that.


### What ShopNow needs, and which service solves it

| ShopNow needs to… | AWS service |
|---|---|
| Give each team a safe, separate place to work | AWS accounts, IAM |
| Keep its servers on a private network | VPC, Transit Gateway, PrivateLink |
| Run its website and APIs, and scale them | EKS, ECS, EC2, Lambda, ECR |
| Let customers reach `shop.example.com` securely | Route 53, ACM, Load Balancer |
| Store orders, images and files | RDS/Aurora, S3, EFS, FSx |
| Keep passwords and keys secret | Secrets Manager, Parameter Store, KMS |
| Manage servers without logging in with keys | Systems Manager |
| Know when something breaks, and why | CloudWatch, SNS, SES, Firehose, OpenSearch |
| Never lose data | AWS Backup, DataSync |
| Change everything safely | Terraform, Atlantis, CI/CD, Argo CD |

### The big picture

```text
 Customer ─▶ Route 53 ─▶ Load balancer (HTTPS via ACM)
                               │
 ┌─ VPC in Mumbai, 3 Availability Zones ─────────────────┐
 │ EKS pods:  storefront · orders · payments             │
 │ ECS:       admin tool       EC2: reporting server     │
 │ Data:      Aurora database · EFS · FSx                │
 └───────────────────────────────────────────────────────┘
  Outside the VPC: S3 · Secrets Manager · KMS · CloudWatch
  OpenSearch · AWS Backup · Lambda · SES · SNS
```

**Region:** ShopNow runs in **Mumbai** (`ap-south-1`), close to its customers, across **3 Availability Zones** so one data center failing doesn't take the shop down. Backups are copied to a **second Region** (Hyderabad) in case a whole Region has a problem.

### Check yourself

1. Why does ShopNow use 3 Availability Zones instead of one?
2. Which part of the picture is the "front door" for customers?

> **Tip:** Answers: 1) If one data center has a power or network problem, the other two keep the shop running. 2) Route 53 (the address) and the load balancer (the door that spreads visitors across servers).

## One customer order, step by step

> **In simple words:** Before looking at services one by one, follow a single customer. Priya opens the shop, pays, and gets a confirmation email. In about two seconds, a dozen AWS services each do their small job.

### Watch how it works

```svg Watch it work: one ShopNow order, from Route 53 and the load balancer to the EKS pods, S3, Aurora, Secrets Manager, PrivateLink, KMS, SES, CloudWatch and OpenSearch. The animation loops.
<svg viewBox="0 0 600 432" role="img" data-anim="aws-real-deployment" data-dur="38.42" data-starts="0 4.76 9.18 13.6 18.7 23.8 28.56 33.66" aria-label="Animated ShopNow order, following one customer, Priya. Getting in: she types shop.example.com, and Route 53 answers with the address of the load balancer. The load balancer shows a certificate from ACM, so the browser shows the padlock. The load balancer sends the request to a healthy storefront pod on EKS, inside the VPC in Mumbai. Buying: product images come from S3, and prices and stock come from the Aurora database. When she pays, the payments service reads the payment partner&#x27;s API key from Secrets Manager and calls the partner privately through PrivateLink. The orders service writes order number 10452 to Aurora, and the data is encrypted with a KMS key. After the order: a confirmation email, Thanks Priya, your order #10452 is confirmed, goes out through SES. CloudWatch records the response time, and the request&#x27;s log line lands in OpenSearch. None of this needs a person, and it takes about two seconds.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<rect x="136" y="84" width="334" height="182" rx="12" class="dg-region"/>
<polyline points="124,37 140,37" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="68,60 68,130" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="124,152 150,152" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="304,130 304,60" fill="none" stroke-linejoin="round" stroke="#db2777" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="304,60 304,72 68,72 68,60" fill="none" stroke-linejoin="round" stroke="#db2777" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="198,174 198,290" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="198,229 256,229" fill="none" stroke-linejoin="round" stroke="#0d9488" stroke-width="1.8" stroke-dasharray="6 3" stroke-opacity=".7"/>
<polyline points="304,174 304,206" fill="none" stroke-linejoin="round" stroke="#0d9488" stroke-width="1.8" stroke-dasharray="6 3" stroke-opacity=".7"/>
<polyline points="304,252 304,290" fill="none" stroke-linejoin="round" stroke="#eab308" stroke-width="1.8" stroke-dasharray="3 3" stroke-opacity=".75"/>
<polyline points="484,231 410,231 410,174" fill="none" stroke-linejoin="round" stroke="#eab308" stroke-width="1.8" stroke-dasharray="3 3" stroke-opacity=".75"/>
<polyline points="458,152 484,152" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="536,130 536,60" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="68,174 68,290" fill="none" stroke-linejoin="round" stroke="#0d9488" stroke-width="1.8" stroke-dasharray="6 3" stroke-opacity=".7"/>
<polyline points="198,278 418,278 418,290" fill="none" stroke-linejoin="round" stroke="#64748b" stroke-width="1.8" stroke-dasharray="4 3" stroke-opacity=".7"/>
<rect x="142" y="91" width="99.2" height="18" rx="5" class="dg-box"/><text x="146" y="103" font-size="13" font-weight="800" fill="#f97316">VPC · Mumbai</text>
<rect x="12" y="14" width="112" height="46" rx="23" class="dg-box"/><g opacity="1"><animate attributeName="opacity" values="1;0.28;1;0.28" keyTimes="0;0.2389;0.7434;0.8761" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><rect x="8" y="10" width="120" height="54" rx="26" fill="#6366f1" fill-opacity=".18" stroke="#6366f1" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1;0" keyTimes="0;0.2389;0.7434;0.8761" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/></rect><rect x="12" y="14" width="112" height="46" rx="23" class="dg-box" stroke="#6366f1" stroke-width="2.2"/><text x="68" y="33.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Priya</text><text x="68" y="49" text-anchor="middle" font-size="11" class="dg-muted">shop.example.com</text></g>
<rect x="140" y="14" width="104" height="46" rx="9" class="dg-box"/><g opacity="1"><animate attributeName="opacity" values="1;0.28" keyTimes="0;0.1239" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><rect x="136" y="10" width="112" height="54" rx="12" fill="#7c3aed" fill-opacity=".18" stroke="#7c3aed" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1239" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/></rect><rect x="140" y="14" width="104" height="46" rx="9" class="dg-box" stroke="#7c3aed" stroke-width="2.2"/><text x="192" y="33.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Route 53</text><text x="192" y="49" text-anchor="middle" font-size="11" class="dg-muted">DNS</text></g>
<rect x="256" y="14" width="96" height="46" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1;0.28" keyTimes="0;0.7434;0.8761" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><rect x="252" y="10" width="104" height="54" rx="12" fill="#db2777" fill-opacity=".18" stroke="#db2777" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7434;0.8761" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/></rect><rect x="256" y="14" width="96" height="46" rx="9" class="dg-box" stroke="#db2777" stroke-width="2.2"/><text x="304" y="33.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">SES</text><text x="304" y="49" text-anchor="middle" font-size="11" class="dg-muted">email</text></g>
<rect x="484" y="14" width="104" height="46" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1;0.28" keyTimes="0;0.4867;0.6195" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><rect x="480" y="10" width="112" height="54" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4867;0.6195" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/></rect><rect x="484" y="14" width="104" height="46" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="536" y="33.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Partner</text><text x="536" y="49" text-anchor="middle" font-size="11" class="dg-muted">payment API</text></g>
<rect x="12" y="130" width="112" height="44" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1;0.28;1" keyTimes="0;0.1239;0.354;0.8761" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><rect x="8" y="126" width="120" height="52" rx="12" fill="#c026d3" fill-opacity=".18" stroke="#c026d3" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.1239;0.354;0.8761" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/></rect><rect x="12" y="130" width="112" height="44" rx="9" class="dg-box" stroke="#c026d3" stroke-width="2.2"/><text x="68" y="148.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Load balancer</text><text x="68" y="164" text-anchor="middle" font-size="11" class="dg-muted">ACM certificate</text></g>
<rect x="150" y="130" width="96" height="44" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1;0.28;1" keyTimes="0;0.2389;0.4867;0.8761" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><rect x="146" y="126" width="104" height="52" rx="12" fill="#3b82f6" fill-opacity=".18" stroke="#3b82f6" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.2389;0.4867;0.8761" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/></rect><rect x="150" y="130" width="96" height="44" rx="9" class="dg-box" stroke="#3b82f6" stroke-width="2.2"/><text x="198" y="148.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">storefront</text><text x="198" y="164" text-anchor="middle" font-size="11" class="dg-muted">EKS pod</text></g>
<rect x="256" y="130" width="96" height="44" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1;0.28" keyTimes="0;0.6195;0.8761" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><rect x="252" y="126" width="104" height="52" rx="12" fill="#3b82f6" fill-opacity=".18" stroke="#3b82f6" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6195;0.8761" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/></rect><rect x="256" y="130" width="96" height="44" rx="9" class="dg-box" stroke="#3b82f6" stroke-width="2.2"/><text x="304" y="148.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">orders</text><text x="304" y="164" text-anchor="middle" font-size="11" class="dg-muted">EKS pod</text></g>
<rect x="362" y="130" width="96" height="44" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1;0.28" keyTimes="0;0.4867;0.6195" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><rect x="358" y="126" width="104" height="52" rx="12" fill="#3b82f6" fill-opacity=".18" stroke="#3b82f6" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4867;0.6195" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/></rect><rect x="362" y="130" width="96" height="44" rx="9" class="dg-box" stroke="#3b82f6" stroke-width="2.2"/><text x="410" y="148.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">payments</text><text x="410" y="164" text-anchor="middle" font-size="11" class="dg-muted">EKS pod</text></g>
<rect x="256" y="206" width="96" height="46" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1;0.28;1;0.28" keyTimes="0;0.354;0.4867;0.6195;0.7434" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><rect x="252" y="202" width="104" height="54" rx="12" fill="#2563eb" fill-opacity=".18" stroke="#2563eb" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.354;0.4867;0.6195;0.7434" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/></rect><rect x="256" y="206" width="96" height="46" rx="9" class="dg-box" stroke="#2563eb" stroke-width="2.2"/><text x="304" y="225.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Aurora</text><text x="304" y="241" text-anchor="middle" font-size="11" class="dg-muted">prices, orders</text></g>
<rect x="484" y="130" width="104" height="44" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1;0.28" keyTimes="0;0.4867;0.6195" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><rect x="480" y="126" width="112" height="52" rx="12" fill="#0891b2" fill-opacity=".18" stroke="#0891b2" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4867;0.6195" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/></rect><rect x="484" y="130" width="104" height="44" rx="9" class="dg-box" stroke="#0891b2" stroke-width="2.2"/><text x="536" y="148.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">PrivateLink</text><text x="536" y="164" text-anchor="middle" font-size="11" class="dg-muted">private path</text></g>
<rect x="484" y="204" width="104" height="54" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1;0.28" keyTimes="0;0.4867;0.6195" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><rect x="480" y="200" width="112" height="62" rx="12" fill="#ca8a04" fill-opacity=".18" stroke="#ca8a04" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4867;0.6195" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/></rect><rect x="484" y="204" width="104" height="54" rx="9" class="dg-box" stroke="#ca8a04" stroke-width="2.2"/><text x="536" y="219" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Secrets</text><text x="536" y="236" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Manager</text><text x="536" y="251.5" text-anchor="middle" font-size="11" class="dg-muted">API key</text></g>
<rect x="12" y="290" width="112" height="46" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.8761" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><rect x="8" y="286" width="120" height="54" rx="12" fill="#059669" fill-opacity=".18" stroke="#059669" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8761" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/></rect><rect x="12" y="290" width="112" height="46" rx="9" class="dg-box" stroke="#059669" stroke-width="2.2"/><text x="68" y="309.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">CloudWatch</text><text x="68" y="325" text-anchor="middle" font-size="11" class="dg-muted">response time</text></g>
<rect x="150" y="290" width="96" height="46" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1;0.28" keyTimes="0;0.354;0.4867" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><rect x="146" y="286" width="104" height="54" rx="12" fill="#16a34a" fill-opacity=".18" stroke="#16a34a" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.354;0.4867" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/></rect><rect x="150" y="290" width="96" height="46" rx="9" class="dg-box" stroke="#16a34a" stroke-width="2.2"/><text x="198" y="309.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">S3</text><text x="198" y="325" text-anchor="middle" font-size="11" class="dg-muted">product images</text></g>
<rect x="256" y="290" width="96" height="46" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1;0.28" keyTimes="0;0.6195;0.7434" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><rect x="252" y="286" width="104" height="54" rx="12" fill="#eab308" fill-opacity=".18" stroke="#eab308" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6195;0.7434" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/></rect><rect x="256" y="290" width="96" height="46" rx="9" class="dg-box" stroke="#eab308" stroke-width="2.2"/><text x="304" y="309.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">KMS</text><text x="304" y="325" text-anchor="middle" font-size="11" class="dg-muted">encryption key</text></g>
<rect x="362" y="290" width="112" height="46" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.8761" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><rect x="358" y="286" width="120" height="54" rx="12" fill="#0d9488" fill-opacity=".18" stroke="#0d9488" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8761" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/></rect><rect x="362" y="290" width="112" height="46" rx="9" class="dg-box" stroke="#0d9488" stroke-width="2.2"/><text x="418" y="309.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">OpenSearch</text><text x="418" y="325" text-anchor="middle" font-size="11" class="dg-muted">log lines</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1239;0.2389" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><circle cx="124" cy="14" r="9.5" fill="#d97706" stroke="#fff" stroke-width="2"/><rect x="119.5" y="13" width="9" height="6.5" rx="1.2" fill="#fff"/><path d="M121.2,13 V11 A2.8,2.8 0 0 1 126.8,11 V13" fill="none" stroke="#fff" stroke-width="1.6"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2389;0.354" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><circle cx="246" cy="130" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M241.5,130 L245,133.5 L250.5,126.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6195;0.7434" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><circle cx="352" cy="206" r="9.5" fill="#d97706" stroke="#fff" stroke-width="2"/><rect x="347.5" y="205" width="9" height="6.5" rx="1.2" fill="#fff"/><path d="M349.2,205 V203 A2.8,2.8 0 0 1 354.8,203 V205" fill="none" stroke="#fff" stroke-width="1.6"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0062;0.052" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><animateMotion path="M68,37 L192,37" keyPoints="0;0;1;1" keyTimes="0;0.0062;0.052;1" calcMode="linear" dur="38.42s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0644;0.1115" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><animateMotion path="M192,37 L68,37" keyPoints="0;0;1;1" keyTimes="0;0.0644;0.1115;1" calcMode="linear" dur="38.42s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1308;0.2228" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><animateMotion path="M68,37 L68,152" keyPoints="0;0;1;1" keyTimes="0;0.1308;0.2228;1" calcMode="linear" dur="38.42s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2458;0.3379" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><animateMotion path="M68,152 L198,152" keyPoints="0;0;1;1" keyTimes="0;0.2458;0.3379;1" calcMode="linear" dur="38.42s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3606;0.4177" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><animateMotion path="M198,313 L198,152" keyPoints="0;0;1;1" keyTimes="0;0.3606;0.4177;1" calcMode="linear" dur="38.42s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4137;0.4761" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><animateMotion path="M304,229 L198,229 L198,152" keyPoints="0;0;1;1" keyTimes="0;0.4137;0.4761;1" calcMode="linear" dur="38.42s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.492;0.5398" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><animateMotion path="M536,231 L410,231 L410,152" keyPoints="0;0;1;1" keyTimes="0;0.492;0.5398;1" calcMode="linear" dur="38.42s" repeatCount="indefinite"/><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5478;0.6088" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><animateMotion path="M410,152 L536,152 L536,37" keyPoints="0;0;1;1" keyTimes="0;0.5478;0.6088;1" calcMode="linear" dur="38.42s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6257;0.6752" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><animateMotion path="M304,152 L304,229" keyPoints="0;0;1;1" keyTimes="0;0.6257;0.6752;1" calcMode="linear" dur="38.42s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6814;0.7285" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><animateMotion path="M304,313 L304,229" keyPoints="0;0;1;1" keyTimes="0;0.6814;0.7285;1" calcMode="linear" dur="38.42s" repeatCount="indefinite"/><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7487;0.7965" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><animateMotion path="M304,152 L304,37" keyPoints="0;0;1;1" keyTimes="0;0.7487;0.7965;1" calcMode="linear" dur="38.42s" repeatCount="indefinite"/><g><rect x="-9" y="-6" width="18" height="12" rx="2" fill="#db2777" stroke="#fff" stroke-width="1.6"/><path d="M-8,-5 L0,1 L8,-5" fill="none" stroke="#fff" stroke-width="1.4"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8071;0.8655" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><animateMotion path="M304,37 L304,72 L68,72 L68,37" keyPoints="0;0;1;1" keyTimes="0;0.8071;0.8655;1" calcMode="linear" dur="38.42s" repeatCount="indefinite"/><g><rect x="-9" y="-6" width="18" height="12" rx="2" fill="#db2777" stroke="#fff" stroke-width="1.6"/><path d="M-8,-5 L0,1 L8,-5" fill="none" stroke="#fff" stroke-width="1.4"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8835;0.9827" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><animateMotion path="M68,152 L68,313" keyPoints="0;0;1;1" keyTimes="0;0.8835;0.9827;1" calcMode="linear" dur="38.42s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8835;0.9827" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><animateMotion path="M198,152 L198,278 L418,278 L418,313" keyPoints="0;0;1;1" keyTimes="0;0.8835;0.9827;1" calcMode="linear" dur="38.42s" repeatCount="indefinite"/><g><rect x="-8" y="-6" width="16" height="12" rx="2" fill="#64748b" stroke="#fff" stroke-width="1.6"/><path d="M-5,-2 H5 M-5,2 H3" stroke="#fff" stroke-width="1.4"/></g></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(20.4,356.5) scale(.8)"><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g><text x="31.8" y="360">request</text><g transform="translate(93.4,356.5) scale(.8)"><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g><text x="104.8" y="360">reply</text><g transform="translate(156,356.5) scale(.8)"><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g><text x="168.2" y="360">images</text><g transform="translate(224.2,356.5) scale(.8)"><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g><text x="235.6" y="360">data / metrics</text><g transform="translate(337.2,356.5) scale(.8)"><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g><text x="350.2" y="360">key</text><g transform="translate(391,356.5) scale(.8)"><g><rect x="-9" y="-6" width="18" height="12" rx="2" fill="#db2777" stroke="#fff" stroke-width="1.6"/><path d="M-8,-5 L0,1 L8,-5" fill="none" stroke="#fff" stroke-width="1.4"/></g></g><text x="404" y="360">email</text><g transform="translate(455.2,356.5) scale(.8)"><g><rect x="-8" y="-6" width="16" height="12" rx="2" fill="#64748b" stroke="#fff" stroke-width="1.6"/><path d="M-5,-2 H5 M-5,2 H3" stroke="#fff" stroke-width="1.4"/></g></g><text x="467.4" y="360">log line</text></g>
<rect x="12" y="372" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="372" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="38.42s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1239" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><circle cx="36" cy="400" r="14" fill="#6366f1"/><text x="36" y="405" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="395" font-size="14" font-weight="800" fill="#6366f1">Priya types shop.example.com</text><text x="578" y="395" text-anchor="end" font-size="10.5" class="dg-muted">Getting in · 1/8</text><text x="60" y="416" font-size="12.5" class="dg-text">Route 53 answers with the address of the load balancer.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1239;0.2389" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><circle cx="36" cy="400" r="14" fill="#6366f1"/><text x="36" y="405" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="395" font-size="14" font-weight="800" fill="#6366f1">A secure connection</text><text x="578" y="395" text-anchor="end" font-size="10.5" class="dg-muted">Getting in · 2/8</text><text x="60" y="416" font-size="12.5" class="dg-text">The load balancer shows its ACM certificate, so the browser shows the padlock.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2389;0.354" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><circle cx="36" cy="400" r="14" fill="#6366f1"/><text x="36" y="405" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="395" font-size="14" font-weight="800" fill="#6366f1">Pick a server</text><text x="578" y="395" text-anchor="end" font-size="10.5" class="dg-muted">Getting in · 3/8</text><text x="60" y="416" font-size="12.5" class="dg-text">The load balancer sends her to a healthy storefront pod on EKS.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.354;0.4867" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><circle cx="36" cy="400" r="14" fill="#f97316"/><text x="36" y="405" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="395" font-size="14" font-weight="800" fill="#f97316">The product page</text><text x="578" y="395" text-anchor="end" font-size="10.5" class="dg-muted">Buying · 4/8</text><text x="60" y="416" font-size="12.5" class="dg-text">Product images come from S3; prices and stock come from Aurora.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4867;0.6195" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><circle cx="36" cy="400" r="14" fill="#f97316"/><text x="36" y="405" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="395" font-size="14" font-weight="800" fill="#f97316">Priya pays</text><text x="578" y="395" text-anchor="end" font-size="10.5" class="dg-muted">Buying · 5/8</text><text x="60" y="416" font-size="12.5" class="dg-text">payments gets the API key from Secrets Manager, then calls it via PrivateLink.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6195;0.7434" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><circle cx="36" cy="400" r="14" fill="#f97316"/><text x="36" y="405" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="395" font-size="14" font-weight="800" fill="#f97316">Save the order</text><text x="578" y="395" text-anchor="end" font-size="10.5" class="dg-muted">Buying · 6/8</text><text x="60" y="416" font-size="12.5" class="dg-text">orders writes order #10452 to Aurora. The data is encrypted with a KMS key.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7434;0.8761" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><circle cx="36" cy="400" r="14" fill="#059669"/><text x="36" y="405" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="395" font-size="14" font-weight="800" fill="#059669">The confirmation email</text><text x="578" y="395" text-anchor="end" font-size="10.5" class="dg-muted">After the order · 7/8</text><text x="60" y="416" font-size="12.5" class="dg-text">&quot;Thanks Priya, your order #10452 is confirmed.&quot; goes out through SES.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8761" calcMode="discrete" dur="38.42s" repeatCount="indefinite"/><circle cx="36" cy="400" r="14" fill="#059669"/><text x="36" y="405" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="395" font-size="14" font-weight="800" fill="#059669">Watched all the time</text><text x="578" y="395" text-anchor="end" font-size="10.5" class="dg-muted">After the order · 8/8</text><text x="60" y="416" font-size="12.5" class="dg-text">CloudWatch records the response time; the log line lands in OpenSearch.</text></g>
</svg>
```

```steps
#6366f1 | Getting in | Priya types shop.example.com | Route 53 answers with the address of the load balancer.
#6366f1 | Getting in | A secure connection | The load balancer shows its ACM certificate, so the browser shows the padlock.
#6366f1 | Getting in | Pick a server | The load balancer sends her to a healthy storefront pod on EKS.
#f97316 | Buying | The product page | Product images come from S3; prices and stock come from Aurora.
#f97316 | Buying | Priya pays | payments gets the API key from Secrets Manager, then calls it via PrivateLink.
#f97316 | Buying | Save the order | orders writes order #10452 to Aurora. The data is encrypted with a KMS key.
#059669 | After the order | The confirmation email | "Thanks Priya, your order #10452 is confirmed." goes out through SES.
#059669 | After the order | Watched all the time | CloudWatch records the response time; the log line lands in OpenSearch.
```

```flow
🌐 | Find the shop | Priya types `shop.example.com`. **Route 53** answers with the load balancer's address.
🔒 | Secure connection | The **load balancer** shows a certificate from **ACM**, so the browser shows the padlock.
⚖️ | Pick a server | The load balancer sends the request to a healthy **storefront** pod on **EKS**.
🖼️ | Product page | Product images come from **S3**; prices and stock come from the **Aurora** database.
🔑 | Pay | The **payments** service reads the payment partner's API key from **Secrets Manager** and calls the partner privately through **PrivateLink**.
🧾 | Save the order | The **orders** service writes the order to **Aurora**. The data is encrypted with a **KMS** key.
📧 | Confirmation | A message goes out through **SES**: "Thanks Priya, your order #10452 is confirmed."
📈 | Watched | **CloudWatch** records the response time; the request's log line lands in **OpenSearch**.
```

None of this needs a person. The rest of this guide explains each service in that chain, and the ones working behind the scenes.

## Foundation: accounts, permissions and encryption

> **In simple words:** Before running anything, ShopNow sets up **who can do what** and **how data is locked**. Get this right on day one and everything built later is safer.

### AWS accounts: separate rooms for each environment

| **What it is** | A separate, isolated space in AWS with its own resources, users and bill |
|---|---|
| **Use it when** | You want dev, staging and production completely separated, with their own bills and permissions |
| **In ShopNow** | Four accounts: **dev**, **staging**, **prod** and **shared services** (CI/CD tools, logs). A mistake in dev can never delete anything in prod |
| **Without it** | One account for everything: a developer testing a script could stop the live shop, and the bill is one big mix |
| **Hands-on** | [Create your AWS account](#/tool/aws-account) |

### IAM: who is allowed to do what

| **What it is** | The service that controls who (people and programs) can do what in your account |
|---|---|
| **Use it when** | Always. Every person, server and program needs an identity with only the permissions it needs |
| **In ShopNow** | Engineers sign in with company single sign-on and get **read-only** in prod by default. The orders pods get a **role** that can read only the `orders` secrets and write only to the invoices bucket |
| **Without it** | Shared passwords and access keys with full admin rights; one leaked key exposes everything |
| **Hands-on** | [AWS IAM](#/tool/aws-iam) |

### KMS: the keys that lock the data

| **What it is** | A managed service that creates and guards the keys used to encrypt your data |
|---|---|
| **Use it when** | Data must be encrypted at rest (databases, disks, buckets, secrets), and you want control and an audit trail of who used the key |
| **In ShopNow** | One customer managed key per data type. Aurora, S3 invoices, EBS disks and secrets are all encrypted. Every use of a key is logged |
| **Without it** | A copied disk or snapshot could be read by anyone who gets it; auditors would fail the payment-security review |
| **Hands-on** | [AWS KMS](#/tool/aws-kms) |

## Network: private, connected and safe

> **In simple words:** ShopNow's servers live on a **private network** that the internet can't reach directly. Only the load balancer faces the internet. Private links connect ShopNow's networks to each other, to the office, and to partners.

### VPC: ShopNow's private network

| **What it is** | Your own private network inside AWS |
|---|---|
| **Use it when** | Any time you run servers, containers or databases on AWS |
| **In ShopNow** | Prod VPC `10.30.0.0/16` in Mumbai with **public subnets** (only load balancers and NAT gateways) and **private subnets** (EKS nodes, Aurora, EFS) in 3 Availability Zones |
| **Without it** | Databases and servers exposed to the internet, waiting to be attacked |
| **Hands-on** | [AWS VPC](#/tool/aws-vpc) |

### Transit Gateway: one hub for all networks

| **What it is** | A central router that connects many VPCs and on-premises networks |
|---|---|
| **Use it when** | You have several VPCs (and maybe an office VPN) that need to talk to each other |
| **In ShopNow** | Dev, staging, prod and shared-services VPCs plus the office VPN all connect to **one Transit Gateway**. Route tables keep dev from reaching prod |
| **Without it** | A tangle of one-to-one links that gets harder to manage with every new VPC |
| **Hands-on** | [VPC guide: Transit Gateway](#/tool/aws-vpc/transit-gateway-connect-many-vpcs) |

### VPC endpoints and PrivateLink: private doors to services

| **What it is** | Private connections from your VPC to AWS services, or to services run by other companies |
|---|---|
| **Use it when** | Private servers need AWS services (S3, ECR, Systems Manager) or a partner's service **without going over the internet** |
| **In ShopNow** | A free **S3 gateway endpoint** carries image and invoice traffic privately (and cuts NAT costs). The payment partner shares its API through **PrivateLink**, so card data never crosses the public internet |
| **Without it** | Traffic goes out through NAT to the internet: slower, more expensive, and harder to secure |
| **Hands-on** | [VPC endpoints and PrivateLink](#/tool/aws-privatelink) |

## Running the application

> **In simple words:** ShopNow runs most of its software as **containers on Kubernetes (EKS)**, small internal tools on **ECS**, a few old applications on plain **EC2 servers**, and tiny event-driven jobs on **Lambda**. Each fits a different kind of work.

```compare
🚢 EKS / ECS (containers) | ⚡ Lambda (functions)
Long-running services that are always on | Short jobs that run only when something happens
Website, APIs, background workers | Resize an image, stop servers at night, send a report
You choose the size and scaling rules | AWS runs it; you pay per run
```

### Amazon ECR: the shelf for container images

| **What it is** | A private registry (storage shelf) for your container images |
|---|---|
| **Use it when** | You build container images and need a private, secure place to store them close to where they run |
| **In ShopNow** | Every build pushes an image like `orders:2.4.0` to ECR. ECR **scans it for known vulnerabilities**; old images are cleaned up automatically by a lifecycle rule |
| **Without it** | Images on a public registry or a self-run server: slower pulls, rate limits, and no built-in scanning |
| **Hands-on** | [Amazon ECR](#/tool/aws-ecr) |

### Amazon EKS: runs the shop's containers

| **What it is** | Managed Kubernetes: AWS runs the control plane, you run your containers |
|---|---|
| **Use it when** | You run many services (microservices) that need automatic restarts, scaling and rolling updates |
| **In ShopNow** | The **storefront**, **orders** and **payments** services run as pods. If a pod crashes, Kubernetes replaces it. On sale days it adds pods and EC2 nodes automatically |
| **Without it** | Engineers restarting crashed apps by hand at night, and buying servers for the busiest day of the year |
| **Hands-on** | [EKS cluster setup](#/tool/eks-cluster) · [Kubernetes](#/tool/kubernetes) |

### Amazon ECS on Fargate: simple containers without a cluster to manage

| **What it is** | AWS's own, simpler container service; Fargate runs the containers without servers to manage |
|---|---|
| **Use it when** | You have a few containers and don't need all of Kubernetes |
| **In ShopNow** | The internal **admin tool** for the support team and the **Atlantis** server that runs Terraform both run as Fargate tasks: no servers to patch |
| **Without it** | A full Kubernetes cluster to run two small apps, or EC2 servers to patch every month |
| **Hands-on** | [Amazon ECS](#/tool/aws-ecs) · [Atlantis on AWS](#/tool/atlantis-aws) |

### Amazon EC2: plain virtual servers

| **What it is** | Virtual servers you rent by the second |
|---|---|
| **Use it when** | Software needs a full server: old applications, Windows software, special licences, or the nodes under EKS |
| **In ShopNow** | A Windows server runs the **finance reporting** software that can't run in containers. EKS nodes are also EC2 instances, added and removed automatically |
| **Without it** | No home for software that doesn't fit containers |
| **Hands-on** | [Website on EC2](#/tool/ec2-website) |

### AWS Lambda and EventBridge: small jobs that run on events or a timetable

| **What it is** | Lambda runs your code without servers; EventBridge starts it on an event or a schedule |
|---|---|
| **Use it when** | A short task should run **when something happens** (a file arrives, an alarm fires) or **on a schedule**, and you don't want a server waiting all day |
| **In ShopNow** | When a seller uploads a product photo to S3, a Lambda function makes thumbnails. Every evening at 8 p.m. an **EventBridge schedule** stops the dev servers, and starts them at 9 a.m., saving about half the dev bill |
| **Without it** | A server running 24 hours a day just to do a few seconds of work |
| **Hands-on** | [Lambda and EventBridge](#/tool/aws-lambda) |

## Getting customers in: DNS, HTTPS and load balancing

> **In simple words:** Three services work as a team at the front door: **Route 53** gives the shop its name, **ACM** gives it the padlock, and the **load balancer** spreads visitors across healthy servers.

### Amazon Route 53: the shop's address book

| **What it is** | The AWS DNS service: it turns names like shop.example.com into addresses |
|---|---|
| **Use it when** | You need a domain name that points to your app, or private names inside your network |
| **In ShopNow** | `shop.example.com` points to the load balancer with an **alias record**. Private names like `orders.internal` help services find each other |
| **Without it** | Customers would have to type an AWS-generated address nobody can remember |
| **Hands-on** | [Amazon Route 53](#/tool/aws-route53) |

### AWS Certificate Manager (ACM): the free padlock

| **What it is** | Free TLS certificates for HTTPS, renewed automatically |
|---|---|
| **Use it when** | Anything is served over HTTPS (it always should be) |
| **In ShopNow** | One certificate for `shop.example.com` and `*.shop.example.com`, attached to the load balancer. **ACM renews it automatically** |
| **Without it** | Browsers show "Not secure", and a forgotten renewal takes the whole site down |
| **Hands-on** | [Load balancers: HTTPS with ACM](#/tool/aws-elb/https-with-a-free-acm-certificate) |

### Elastic Load Balancing: the front door

| **What it is** | Spreads incoming traffic across healthy servers or pods |
|---|---|
| **Use it when** | More than one server or pod serves the same app, or you need HTTPS, health checks and path-based routing |
| **In ShopNow** | One **Application Load Balancer** sends `/api/*` to the orders service and everything else to the storefront. It only sends traffic to pods that pass their **health check** |
| **Without it** | One server takes all the traffic; when it fails, the shop goes down |
| **Hands-on** | [Load balancers](#/tool/aws-elb) |

## Storing data

> **In simple words:** Different data needs different storage. **Orders** go in a database, **images and documents** go in S3, **files shared by many servers** go on EFS or FSx. Picking the right one keeps the shop fast and the bill small.

```compare
🗄️ Database (Aurora) | 🪣 Objects (S3)
Rows and tables you search and update: orders, customers, stock | Whole files you store and fetch: images, invoices, backups
Many small reads and writes per second | Huge amounts of data at a low price
```

### Amazon RDS and Aurora: the orders database

| **What it is** | Managed relational databases; Aurora is the AWS-built engine compatible with PostgreSQL and MySQL |
|---|---|
| **Use it when** | You need a relational database (PostgreSQL, MySQL, SQL Server) without running the database server yourself |
| **In ShopNow** | **Aurora PostgreSQL** holds customers, orders and stock. A **writer** handles orders; **reader** copies serve reports and searches. If the writer's zone fails, a reader takes over in about a minute. Backups allow **restore to any second** in the last 14 days |
| **Without it** | A database on a self-managed server: manual patching, manual backups, and hours of downtime when the disk dies |
| **Hands-on** | [RDS and Aurora](#/tool/aws-rds) |

### Amazon S3: unlimited storage for files

| **What it is** | Object storage: keep any number of files of any size and pay per GB stored |
|---|---|
| **Use it when** | You store files of any size: images, documents, logs, backups, data exports |
| **In ShopNow** | Product images, invoice PDFs, old logs and Terraform state. A **lifecycle rule** moves invoices older than a year to a cheap archive class. **Versioning** protects against accidental deletes |
| **Without it** | Disks filling up on servers, and files lost when a server is replaced |
| **Hands-on** | [Amazon S3](#/tool/aws-s3) |

### Amazon EFS and FSx: shared drives

| **What it is** | Shared network file systems that many servers can use at the same time |
|---|---|
| **Use it when** | Several servers or pods need to read and write **the same files at the same time**, like a network drive |
| **In ShopNow** | **EFS** holds bulk-upload files from sellers, read by several worker pods at once. **FSx for NetApp ONTAP** hosts the finance team's old Windows file shares, moved from the office storage box |
| **Without it** | Each server sees only its own disk; files uploaded to one pod are invisible to the others |
| **Hands-on** | [EFS and FSx](#/tool/aws-efs-fsx) |

## Secrets and configuration

> **In simple words:** Passwords and settings must never be written inside the code. **Secrets Manager** keeps the sensitive ones, **Parameter Store** keeps the everyday settings, and both hand them to the app when it starts.

### AWS Secrets Manager: the safe for passwords and keys

| **What it is** | An encrypted safe for passwords, API keys and certificates, with automatic rotation |
|---|---|
| **Use it when** | Your app needs a password, API key, token or certificate |
| **In ShopNow** | The Aurora password is created by RDS in Secrets Manager and **rotated automatically**. The payment partner's API key is stored here too. Pods read them through their IAM role |
| **Without it** | Passwords in Git or config files, the same password for years, and painful changes when someone leaves |
| **Hands-on** | [Secrets Manager](#/tool/aws-secrets) |

### Systems Manager Parameter Store: settings and feature switches

| **What it is** | A store for settings and feature switches, in plain text or encrypted |
|---|---|
| **Use it when** | You have settings that differ per environment, or switches you want to flip without a new release |
| **In ShopNow** | Values like `/shopnow/prod/max-cart-items` and a **feature flag** `/shopnow/prod/new-checkout = on/off`. Turning the flag off removes a broken feature in seconds (see the 2 a.m. story below) |
| **Without it** | A full code release just to change one number |
| **Hands-on** | [Systems Manager: Parameter Store](#/tool/aws-ssm) |

## Operating servers

> **In simple words:** Even with containers, some servers remain. **Systems Manager** lets engineers reach them, run commands and patch them **without SSH keys or open ports**, and every action is logged.

### AWS Systems Manager: remote control for servers

| **What it is** | A toolbox to reach, patch and automate servers without SSH |
|---|---|
| **Use it when** | You manage EC2 or on-premises servers and want secure access, patching and automation |
| **In ShopNow** | Engineers open a shell on the finance server with **Session Manager** (no port 22, no keys). **Patch Manager** installs security updates every month in a maintenance window. **Run Command** collects log files from many servers at once |
| **Without it** | SSH keys copied around the team, a bastion server to maintain, and servers missing patches |
| **Hands-on** | [AWS Systems Manager](#/tool/aws-ssm) |

## Watching the shop: monitoring, alerts and logs

> **In simple words:** You can't fix what you can't see. **CloudWatch** watches numbers and raises alarms, **SNS** tells the right people, **SES** sends emails to customers, and **Firehose with OpenSearch** lets engineers search every log line.

### Amazon CloudWatch: the shop's health monitor

| **What it is** | Metrics, alarms, logs and dashboards for everything running in AWS |
|---|---|
| **Use it when** | Always: every service sends metrics here, and you set alarms on the ones that matter |
| **In ShopNow** | A **dashboard** shows orders per minute, error rate, response time and database load. **Alarms** fire on load balancer 5XX errors, slow responses, high Aurora CPU and low free storage |
| **Without it** | Customers report the outage on social media before the team notices |
| **Hands-on** | [Amazon CloudWatch](#/tool/aws-cloudwatch) |

### Amazon SNS: telling the right people

| **What it is** | A notification service that sends one message to many subscribers at once |
|---|---|
| **Use it when** | One event (an alarm, a failed backup) must reach several people or systems at once |
| **In ShopNow** | Every critical alarm goes to an SNS topic that **emails the on-call engineer**, posts to the team's **Slack channel** and pages the phone |
| **Without it** | Alarms that nobody sees |
| **Hands-on** | [SNS and SES](#/tool/aws-sns-ses) |

### Amazon SES: emails to customers

| **What it is** | The AWS service for sending email from your applications |
|---|---|
| **Use it when** | Your app sends email: order confirmations, password resets, invoices |
| **In ShopNow** | Order confirmations come from `orders@shop.example.com`. **DKIM, SPF and DMARC** records prove the email is genuine, so it reaches the inbox, not spam. Bounces are tracked to keep the sender reputation clean |
| **Without it** | Running your own mail server, and emails landing in spam |
| **Hands-on** | [SNS and SES](#/tool/aws-sns-ses) |

### Amazon Data Firehose and OpenSearch: search every log line

| **What it is** | Firehose streams data into storage; OpenSearch indexes it so you can search and chart it |
|---|---|
| **Use it when** | Many servers and pods produce logs and you need to search them all in one place, quickly |
| **In ShopNow** | **Fluent Bit** on every EKS node sends container logs to **Firehose**, which delivers them to **OpenSearch**. Support searches "order 10452" and sees every log line from every service for that order. Logs older than 30 days are deleted automatically |
| **Without it** | Logging in to dozens of pods one by one to read logs that may already be gone |
| **Hands-on** | [Firehose and OpenSearch](#/tool/aws-opensearch) |

## Protecting and moving data

> **In simple words:** Things go wrong: a bad release deletes rows, someone removes a file, a Region has an outage. **AWS Backup** keeps restorable copies, and **DataSync** moves large amounts of files safely, for example when leaving an old data center.

### AWS Backup: one place for every backup

| **What it is** | One service to schedule, copy, lock and restore backups across AWS |
|---|---|
| **Use it when** | You must be able to restore databases, disks and file systems, and prove it to auditors |
| **In ShopNow** | One **backup plan** covers everything tagged `backup=daily`: Aurora, EFS and EBS. Backups are kept 35 days, **copied to Hyderabad** each night, and the vault is **locked** so nobody (not even an admin) can delete them early. A **restore test** runs every month |
| **Without it** | Different backup scripts per service, nobody sure they work, and ransomware able to delete the backups too |
| **Hands-on** | [AWS Backup and DataSync](#/tool/aws-backup) |

### AWS DataSync: moving lots of files safely

| **What it is** | Copies large collections of files quickly and checks that every file arrived intact |
|---|---|
| **Use it when** | You migrate or regularly copy large file collections between on-premises storage and AWS, or between AWS storage services |
| **In ShopNow** | When the office storage box was retired, DataSync copied **4 TB of finance files** to FSx over a weekend, **checked every file**, and then synced changes until the switch-over |
| **Without it** | Weeks of manual copying, with no proof that every file arrived intact |
| **Hands-on** | [AWS Backup and DataSync](#/tool/aws-backup) |

## Changing things safely: infrastructure and releases

> **In simple words:** All of the above is created and changed **from code**, reviewed in pull requests, and released by pipelines. Nobody clicks around in the production console.

| Tool | Job at ShopNow | Hands-on |
|---|---|---|
| **Terraform** | Describes VPCs, EKS, Aurora, buckets and roles as code | [Terraform](#/tool/terraform) |
| **Atlantis** | Runs `terraform plan` on every pull request and `apply` after approval | [Atlantis on AWS](#/tool/atlantis-aws) |
| **GitHub Actions / Jenkins** | Build, test and scan the code, then push the image to ECR | [GitHub Actions](#/tool/github-actions) · [Jenkins DevSecOps](#/tool/jenkins-devsecops) |
| **Argo CD** | Deploys the new image to EKS from Git, and rolls back with a Git revert | [Argo CD](#/tool/argocd) |

## Real-time deployment: releasing a new version

> **In simple words:** Here is a real release of the **orders** service, version 2.4, on a normal Tuesday morning. Watch which AWS service does what, minute by minute.

```flow
👩‍💻 | 10:00 Merge | A developer merges the pull request for orders 2.4 after review.
🔨 | 10:01 Build | **GitHub Actions** builds the image, runs tests and security scans, and pushes `orders:2.4.0` to **ECR**, which scans it again.
💾 | 10:08 Safety copy | Before a database change, an on-demand **AWS Backup** of Aurora is taken, so it can be restored if the migration goes wrong.
🧪 | 10:10 Staging | **Argo CD** deploys 2.4 to staging **EKS**. Pods read their settings from **Parameter Store** and their database password from **Secrets Manager**.
✅ | 10:25 Approve | Smoke tests pass. A lead approves the production release in Git.
🚀 | 10:30 Production | **Argo CD** starts a rolling update: new pods start, pass the **load balancer** health check, and only then old pods stop. Customers notice nothing.
📈 | 10:35 Watch | The team watches the **CloudWatch** dashboard: error rate and response time stay normal. **OpenSearch** shows no new errors.
↻ If an alarm fires instead, **SNS** alerts the team and Argo CD rolls back to 2.3 with a Git revert, in about two minutes.
```

**What changed in AWS itself?** For this release, nothing: the infrastructure was already there. If the release had needed something new (say, a new S3 bucket), that change would have gone through **Atlantis** in its own pull request first, a day earlier.

## Real-time scaling: the big sale day

> **In simple words:** At 12:00 on sale day, visitors jump from 2,000 to 20,000 at once. Nobody adds servers by hand: each service scales by itself, then shrinks back after the sale.

| Time | What happens | Service doing it |
|---|---|---|
| Day before | The team raises the minimum number of pods and nodes, and reserves extra load balancer capacity for the planned spike | **EKS**, **Load balancer** |
| 12:00 | Traffic jumps 10× | **Load balancer** spreads it across all healthy pods |
| 12:01 | CPU rises on storefront pods; Kubernetes adds pods | **EKS** (pod autoscaler) |
| 12:02 | Pods need more room; new EC2 nodes start in about a minute | **EC2** via EKS node autoscaling |
| 12:05 | Read traffic grows; an extra **Aurora reader** is added | **Aurora** replica auto scaling |
| 12:10 | 50,000 product photo views per minute | **S3** (no limit to manage) |
| 12:15 | Order confirmations: 3,000 emails in 10 minutes | **SES** |
| All day | The team watches orders per minute and errors | **CloudWatch** dashboard |
| 18:00 | Traffic drops; extra pods, nodes and readers are removed | All of the above, automatically |

**Result:** the shop paid for the extra capacity for about six hours, not for the whole year. This is the cloud's "stop guessing capacity" advantage in action (see [What is DevOps and the Cloud?](#/tool/devops-intro)).

## Real-time incident: 2 a.m. problem

> **In simple words:** At 2 a.m. something goes wrong. Watch how the services help one sleepy engineer find and fix it in 15 minutes, and how the team learns from it the next day.

```flow
🚨 | 02:04 Alarm | **CloudWatch** alarm: Aurora CPU above 90% for 5 minutes, and checkout response time 4 seconds.
📱 | 02:04 Alert | **SNS** pages the on-call engineer and posts in Slack.
🔐 | 02:07 Look | The engineer signs in with read access through **IAM** single sign-on and opens the **CloudWatch** dashboard.
🔎 | 02:10 Find | In **OpenSearch**, the slow-query logs all point to the new "recommended for you" feature.
🔀 | 02:12 Fix | The engineer turns the feature flag off in **Parameter Store**. The pods pick it up within a minute, with no release needed.
📉 | 02:16 Recover | Aurora CPU drops to 30%; the alarm goes back to OK and **SNS** sends "resolved".
📝 | Next day | A blameless review: the team adds a database index and a load test before turning the feature back on.
```

**Why no data was lost:** even in the worst case, **AWS Backup** and Aurora's point-in-time restore could bring the database back to any second before the problem.

## Which service do I need?

> **In simple words:** A quick lookup: start from what you need to do, and find the service and its guide.

| I need to… | Use | Guide |
|---|---|---|
| Separate dev and prod safely | AWS accounts | [Account](#/tool/aws-account) |
| Give a person or app permissions | IAM | [IAM](#/tool/aws-iam) |
| Build a private network | VPC | [VPC](#/tool/aws-vpc) |
| Connect many VPCs and the office | Transit Gateway | [VPC](#/tool/aws-vpc/transit-gateway-connect-many-vpcs) |
| Reach AWS or a partner privately | VPC endpoints, PrivateLink | [PrivateLink](#/tool/aws-privatelink) |
| Store container images | ECR | [ECR](#/tool/aws-ecr) |
| Run many containerised services | EKS | [EKS](#/tool/eks-cluster) |
| Run a few containers simply | ECS on Fargate | [ECS](#/tool/aws-ecs) |
| Run a full server | EC2 | [EC2](#/tool/ec2-website) |
| Run code on an event or schedule | Lambda, EventBridge | [Lambda](#/tool/aws-lambda) |
| Give my app a domain name | Route 53 | [Route 53](#/tool/aws-route53) |
| Serve HTTPS and spread traffic | ACM, Load Balancer | [Load balancers](#/tool/aws-elb) |
| Store orders and customers | RDS / Aurora | [RDS](#/tool/aws-rds) |
| Store files, images, backups | S3 | [S3](#/tool/aws-s3) |
| Share files between servers | EFS, FSx | [EFS and FSx](#/tool/aws-efs-fsx) |
| Keep passwords out of code | Secrets Manager | [Secrets](#/tool/aws-secrets) |
| Change a setting without a release | Parameter Store | [Systems Manager](#/tool/aws-ssm) |
| Encrypt data with my own keys | KMS | [KMS](#/tool/aws-kms) |
| Reach and patch servers without SSH | Systems Manager | [Systems Manager](#/tool/aws-ssm) |
| See health and get alarms | CloudWatch | [CloudWatch](#/tool/aws-cloudwatch) |
| Notify the team | SNS | [SNS and SES](#/tool/aws-sns-ses) |
| Email customers | SES | [SNS and SES](#/tool/aws-sns-ses) |
| Search all logs | Firehose, OpenSearch | [OpenSearch](#/tool/aws-opensearch) |
| Back up and restore everything | AWS Backup | [Backup](#/tool/aws-backup) |
| Move terabytes of files | DataSync | [Backup and DataSync](#/tool/aws-backup) |

### Check yourself

1. A seller uploads a photo and thumbnails must be created. Which service, and why not a server?
2. Checkout is slow because of one new feature. What's the fastest safe fix in ShopNow?
3. Where does ShopNow keep the database password, and how does the app get it?
4. Why are backups copied to a second Region and locked?

> **Tip:** Answers: 1) Lambda, triggered by the S3 upload: it runs only when needed, so no server sits idle. 2) Turn the feature flag off in Parameter Store; no release needed. 3) In Secrets Manager, rotated automatically; pods read it with their IAM role. 4) So a Region-wide problem, a mistake or ransomware can't destroy every copy.

**Next:** pick any service above and do its hands-on guide, or follow the [roadmap](#/roadmap) in order.
