# AWS VPC: Step-by-Step Creation

Build your own AWS network from scratch, one simple step at a time: choose an address range (CIDR), create a **VPC**, add **public and private subnets**, an **internet gateway**, a **NAT gateway** and **route tables**, protect it with **security groups**, and test it. Then connect several VPCs together with a **Transit Gateway**. Every step shows the **console clicks** and the matching **AWS CLI** commands.

> **Cost:** The VPC, subnets, route tables, internet gateway and security groups are **free**. The **NAT gateway** costs about $0.045/hour plus data processed, and a **Transit Gateway** about $0.05 per attachment per hour plus data (us-east-1). Delete them after practising. See [VPC pricing](https://aws.amazon.com/vpc/pricing/) and [Transit Gateway pricing](https://aws.amazon.com/transit-gateway/pricing/).

## Start here: VPC in simple words

> **In simple words:** A **VPC** is your own private network inside AWS, like your own **office building** in a big city. You decide how many addresses it has, split it into rooms (**subnets**), decide which rooms open to the street (**public**) and which don't (**private**), and put signs on every floor saying where traffic should go (**route tables**).

### Watch how it works

```svg Watch it work: a visitor's request coming in through the internet gateway, the app going out through NAT, and a direct attempt being kept out. The animation loops.
<svg viewBox="0 0 600 438" role="img" data-anim="aws-vpc" data-dur="36.72" data-starts="0 4.42 8.84 12.92 17.34 22.44 27.2 31.96" aria-label="Animated VPC flow. Coming in: a visitor&#x27;s request enters through the internet gateway, the public route table sends it to the load balancer in the public subnet, its security group allows port 443, the request goes into the private subnet where the app&#x27;s security group allows port 8000 from the load balancer only, and the app talks to the database over the local route. Going out: the app needs the internet, so it goes out through the NAT gateway and the internet gateway. Kept out: someone tries to reach the app directly, but it has no public IP and no route in.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<rect x="124" y="8" width="468" height="336" rx="12" class="dg-region"/>
<rect x="214" y="36" width="366" height="118" rx="12" fill="none" stroke="#10b981" stroke-width="1.5" stroke-dasharray="5 4"/>
<rect x="214" y="168" width="366" height="168" rx="12" fill="none" stroke="#3b82f6" stroke-width="1.5" stroke-dasharray="5 4"/>
<polyline points="58,175 156,175" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="142,175 142,96 292,96" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="292,96 292,236" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="292,236 292,302 492,302" fill="none" stroke-linejoin="round" stroke="#0d9488" stroke-width="1.8" stroke-dasharray="6 3" stroke-opacity=".7"/>
<polyline points="292,236 392,236 392,96 492,96" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="1.6" stroke-opacity=".8"/>
<polyline points="492,96 492,62 170,62 170,175" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="1.6" stroke-opacity=".8"/>
<rect x="130" y="15" width="129.6" height="18" rx="5" class="dg-box"/><text x="134" y="27" font-size="13" font-weight="800" fill="#f97316">VPC 10.10.0.0/16</text>
<rect x="347.7" y="42" width="226.3" height="16" rx="5" class="dg-box"/><text x="570" y="52" text-anchor="end" font-size="11" class="dg-muted">public 10.10.1.0/24 · 0.0.0.0/0 → IGW</text>
<rect x="335.9" y="174" width="238.1" height="16" rx="5" class="dg-box"/><text x="570" y="184" text-anchor="end" font-size="11" class="dg-muted">private 10.10.11.0/24 · 0.0.0.0/0 → NAT</text>
<g><rect x="8" y="146" width="100" height="58" rx="28" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1" keyTimes="0;0.1204;0.7407" calcMode="discrete" dur="36.72s" repeatCount="indefinite"/></rect><rect x="12" y="150" width="92" height="50" rx="25" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="58" y="171.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Internet</text><text x="58" y="187" text-anchor="middle" font-size="11" class="dg-muted">the world</text></g>
<g><rect x="108" y="146" width="96" height="58" rx="12" fill="#0ea5e9" fill-opacity=".18" stroke="#0ea5e9" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1;0" keyTimes="0;0.2407;0.7407;0.8704" calcMode="discrete" dur="36.72s" repeatCount="indefinite"/></rect><rect x="112" y="150" width="88" height="50" rx="9" class="dg-box" stroke="#0ea5e9" stroke-width="2.2"/><text x="156" y="171.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Internet</text><text x="156" y="187" text-anchor="middle" font-size="11" class="dg-muted">gateway</text></g>
<g><rect x="226" y="66" width="132" height="60" rx="12" fill="#c026d3" fill-opacity=".18" stroke="#c026d3" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1204;0.3519" calcMode="discrete" dur="36.72s" repeatCount="indefinite"/></rect><rect x="230" y="70" width="124" height="52" rx="9" class="dg-box" stroke="#c026d3" stroke-width="2.2"/><text x="292" y="92.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Load balancer</text><text x="292" y="108" text-anchor="middle" font-size="11" class="dg-muted">SG: 443 open</text></g>
<g><rect x="426" y="66" width="132" height="60" rx="12" fill="#0891b2" fill-opacity=".18" stroke="#0891b2" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6111;0.8704" calcMode="discrete" dur="36.72s" repeatCount="indefinite"/></rect><rect x="430" y="70" width="124" height="52" rx="9" class="dg-box" stroke="#0891b2" stroke-width="2.2"/><text x="492" y="92.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">NAT gateway</text><text x="492" y="108" text-anchor="middle" font-size="11" class="dg-muted">one-way out</text></g>
<g><rect x="226" y="206" width="132" height="60" rx="12" fill="#f59e0b" fill-opacity=".18" stroke="#f59e0b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3519;0.7407" calcMode="discrete" dur="36.72s" repeatCount="indefinite"/></rect><rect x="230" y="210" width="124" height="52" rx="9" class="dg-box" stroke="#f59e0b" stroke-width="2.2"/><text x="292" y="232.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">App server</text><text x="292" y="248" text-anchor="middle" font-size="11" class="dg-muted">SG: 8000 from LB</text></g>
<g><rect x="426" y="272" width="132" height="60" rx="12" fill="#2563eb" fill-opacity=".18" stroke="#2563eb" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4722;0.6111" calcMode="discrete" dur="36.72s" repeatCount="indefinite"/></rect><rect x="430" y="276" width="124" height="52" rx="9" class="dg-box" stroke="#2563eb" stroke-width="2.2"/><text x="492" y="298.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Database</text><text x="492" y="314" text-anchor="middle" font-size="11" class="dg-muted">SG: 5432 from app</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2407;0.3519" calcMode="discrete" dur="36.72s" repeatCount="indefinite"/><circle cx="354" cy="70" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M349.5,70 L353,73.5 L358.5,66.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3519;0.4722" calcMode="discrete" dur="36.72s" repeatCount="indefinite"/><circle cx="354" cy="210" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M349.5,210 L353,213.5 L358.5,206.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4722;0.6111" calcMode="discrete" dur="36.72s" repeatCount="indefinite"/><circle cx="554" cy="276" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M549.5,276 L553,279.5 L558.5,272.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8704" calcMode="discrete" dur="36.72s" repeatCount="indefinite"/><circle cx="214" cy="236" r="9.5" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M210,232 L218,240 M218,232 L210,240" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0072;0.1035" calcMode="discrete" dur="36.72s" repeatCount="indefinite"/><animateMotion path="M58,175 L156,175" keyPoints="0;0;1;1" keyTimes="0;0.0072;0.1035;1" calcMode="linear" dur="36.72s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1276;0.2239" calcMode="discrete" dur="36.72s" repeatCount="indefinite"/><animateMotion path="M156,175 L142,175 L142,96 L292,96" keyPoints="0;0;1;1" keyTimes="0;0.1276;0.2239;1" calcMode="linear" dur="36.72s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3591;0.4554" calcMode="discrete" dur="36.72s" repeatCount="indefinite"/><animateMotion path="M292,96 L292,236" keyPoints="0;0;1;1" keyTimes="0;0.3591;0.4554;1" calcMode="linear" dur="36.72s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4792;0.5347" calcMode="discrete" dur="36.72s" repeatCount="indefinite"/><animateMotion path="M292,236 L292,302 L492,302" keyPoints="0;0;1;1" keyTimes="0;0.4792;0.5347;1" calcMode="linear" dur="36.72s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5486;0.6014" calcMode="discrete" dur="36.72s" repeatCount="indefinite"/><animateMotion path="M492,302 L292,302 L292,236" keyPoints="0;0;1;1" keyTimes="0;0.5486;0.6014;1" calcMode="linear" dur="36.72s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6189;0.7226" calcMode="discrete" dur="36.72s" repeatCount="indefinite"/><animateMotion path="M292,236 L392,236 L392,96 L492,96" keyPoints="0;0;1;1" keyTimes="0;0.6189;0.7226;1" calcMode="linear" dur="36.72s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7485;0.8522" calcMode="discrete" dur="36.72s" repeatCount="indefinite"/><animateMotion path="M492,96 L492,62 L170,62 L170,175 L58,175" keyPoints="0;0;1;1" keyTimes="0;0.7485;0.8522;1" calcMode="linear" dur="36.72s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8781;0.9611" calcMode="discrete" dur="36.72s" repeatCount="indefinite"/><animateMotion path="M58,175 L142,175 L142,236 L204,236" keyPoints="0;0;1;1" keyTimes="0;0.8781;0.9611;1" calcMode="linear" dur="36.72s" repeatCount="indefinite"/><g><circle r="7" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M0,-3.5 V1 M0,3.2 V3.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/></g></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(20.4,362.5) scale(.8)"><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g><text x="31.8" y="366">request</text><g transform="translate(93.4,362.5) scale(.8)"><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g><text x="104.8" y="366">reply</text><g transform="translate(155.2,362.5) scale(.8)"><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g><text x="166.6" y="366">data</text><g transform="translate(211.4,362.5) scale(.8)"><g><circle r="7" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M0,-3.5 V1 M0,3.2 V3.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/></g></g><text x="222.8" y="366">blocked</text></g>
<rect x="12" y="378" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="378" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="36.72s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1204" calcMode="discrete" dur="36.72s" repeatCount="indefinite"/><circle cx="36" cy="406" r="14" fill="#6366f1"/><text x="36" y="411" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="401" font-size="14" font-weight="800" fill="#6366f1">A visitor&#x27;s request arrives</text><text x="578" y="401" text-anchor="end" font-size="10.5" class="dg-muted">Coming in · 1/8</text><text x="60" y="422" font-size="12.5" class="dg-text">It enters through the internet gateway: the VPC&#x27;s door to the internet.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1204;0.2407" calcMode="discrete" dur="36.72s" repeatCount="indefinite"/><circle cx="36" cy="406" r="14" fill="#6366f1"/><text x="36" y="411" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="401" font-size="14" font-weight="800" fill="#6366f1">The public route table sends it on</text><text x="578" y="401" text-anchor="end" font-size="10.5" class="dg-muted">Coming in · 2/8</text><text x="60" y="422" font-size="12.5" class="dg-text">Public subnets have the route 0.0.0.0/0 → internet gateway.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2407;0.3519" calcMode="discrete" dur="36.72s" repeatCount="indefinite"/><circle cx="36" cy="406" r="14" fill="#6366f1"/><text x="36" y="411" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="401" font-size="14" font-weight="800" fill="#6366f1">The load balancer&#x27;s lock checks the port</text><text x="578" y="401" text-anchor="end" font-size="10.5" class="dg-muted">Coming in · 3/8</text><text x="60" y="422" font-size="12.5" class="dg-text">Its security group allows port 443 from anywhere, so the request gets in.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3519;0.4722" calcMode="discrete" dur="36.72s" repeatCount="indefinite"/><circle cx="36" cy="406" r="14" fill="#6366f1"/><text x="36" y="411" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="401" font-size="14" font-weight="800" fill="#6366f1">Into the private subnet</text><text x="578" y="401" text-anchor="end" font-size="10.5" class="dg-muted">Coming in · 4/8</text><text x="60" y="422" font-size="12.5" class="dg-text">The app&#x27;s security group allows port 8000 only from the load balancer.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4722;0.6111" calcMode="discrete" dur="36.72s" repeatCount="indefinite"/><circle cx="36" cy="406" r="14" fill="#6366f1"/><text x="36" y="411" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="401" font-size="14" font-weight="800" fill="#6366f1">The app asks the database</text><text x="578" y="401" text-anchor="end" font-size="10.5" class="dg-muted">Coming in · 5/8</text><text x="60" y="422" font-size="12.5" class="dg-text">Inside the VPC the local route is used; the database lets only the app in.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6111;0.7407" calcMode="discrete" dur="36.72s" repeatCount="indefinite"/><circle cx="36" cy="406" r="14" fill="#0891b2"/><text x="36" y="411" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="401" font-size="14" font-weight="800" fill="#0891b2">The app needs something from the internet</text><text x="578" y="401" text-anchor="end" font-size="10.5" class="dg-muted">Going out · 6/8</text><text x="60" y="422" font-size="12.5" class="dg-text">A software update, say. Private subnets have no route to the gateway…</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7407;0.8704" calcMode="discrete" dur="36.72s" repeatCount="indefinite"/><circle cx="36" cy="406" r="14" fill="#0891b2"/><text x="36" y="411" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="401" font-size="14" font-weight="800" fill="#0891b2">…so it goes out through the NAT gateway</text><text x="578" y="401" text-anchor="end" font-size="10.5" class="dg-muted">Going out · 7/8</text><text x="60" y="422" font-size="12.5" class="dg-text">NAT uses its own public IP. Replies come back, but nobody can connect in.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8704" calcMode="discrete" dur="36.72s" repeatCount="indefinite"/><circle cx="36" cy="406" r="14" fill="#e11d48"/><text x="36" y="411" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="401" font-size="14" font-weight="800" fill="#e11d48">Someone tries to reach the app directly</text><text x="578" y="401" text-anchor="end" font-size="10.5" class="dg-muted">Kept out · 8/8</text><text x="60" y="422" font-size="12.5" class="dg-text">The app has no public IP and no route in, so the packet never arrives.</text></g>
</svg>
```

```steps
#6366f1 | Coming in | A visitor's request arrives | It enters through the internet gateway: the VPC's door to the internet.
#6366f1 | Coming in | The public route table sends it on | Public subnets have the route 0.0.0.0/0 → internet gateway.
#6366f1 | Coming in | The load balancer's lock checks the port | Its security group allows port 443 from anywhere, so the request gets in.
#6366f1 | Coming in | Into the private subnet | The app's security group allows port 8000 only from the load balancer.
#6366f1 | Coming in | The app asks the database | Inside the VPC the local route is used; the database lets only the app in.
#0891b2 | Going out | The app needs something from the internet | A software update, say. Private subnets have no route to the gateway…
#0891b2 | Going out | …so it goes out through the NAT gateway | NAT uses its own public IP. Replies come back, but nobody can connect in.
#e11d48 | Kept out | Someone tries to reach the app directly | The app has no public IP and no route in, so the packet never arrives.
```

### The building comparison

| Office building | AWS VPC |
|---|---|
| The building, with its own address range | **VPC**, with a CIDR like `10.10.0.0/16` |
| Floors or rooms | **Subnets**: each lives in one Availability Zone |
| Rooms with doors to the street | **Public subnets**: can be reached from the internet |
| Back-office rooms with no street door | **Private subnets**: not reachable from the internet |
| The main entrance | **Internet gateway (IGW)** |
| A one-way exit: staff can go out, visitors can't come in | **NAT gateway**: private servers can reach the internet, but not the other way |
| Signboards: "to the street → main entrance" | **Route tables** |
| A lock on each room's door | **Security group** (per server) |
| A guard on each floor | **Network ACL** (per subnet) |
| A central airport connecting many buildings | **Transit Gateway**: connects many VPCs and offices |

### What we'll build

```text
                              Internet
                                  │
                        ┌─────────▼─────────┐
                        │ Internet Gateway  │
 VPC 10.10.0.0/16       └─────────┬─────────┘
 ┌────────────────────────────────┼─────────────────────────────────┐
 │  AZ us-east-1a                 │             AZ us-east-1b        │
 │  ┌──────────────────────┐      │      ┌──────────────────────┐    │
 │  │ Public 10.10.1.0/24  │◀─────┴─────▶│ Public 10.10.2.0/24  │    │  route: 0.0.0.0/0 → IGW
 │  │   [NAT gateway]      │             │                      │    │
 │  └──────────┬───────────┘             └──────────────────────┘    │
 │             │ outbound only                                        │
 │  ┌──────────▼───────────┐             ┌──────────────────────┐    │
 │  │ Private 10.10.11.0/24│             │ Private 10.10.12.0/24│    │  route: 0.0.0.0/0 → NAT
 │  │   app / databases    │             │   app / databases    │    │
 │  └──────────────────────┘             └──────────────────────┘    │
 └───────────────────────────────────────────────────────────────────┘
```

### Check yourself

1. What makes a subnet "public"?
2. Why do private subnets need a NAT gateway?
3. What does a Transit Gateway do?

> **Tip:** Answers: 1) Its route table sends `0.0.0.0/0` (the internet) to an **internet gateway**. 2) So servers there can download updates and call APIs without being reachable from the internet. 3) It connects many VPCs (and on-premises networks) through one central hub.

## Choose your CIDR (address range)

> **In simple words:** A **CIDR** like `10.10.0.0/16` describes a block of IP addresses. The number after the `/` sets the size: **the smaller the number, the bigger the block**. Pick a range that's big enough for the future and **doesn't overlap** with your other networks.

### How big is each size?

| CIDR suffix | Number of addresses | Typical use |
|---|---|---|
| `/16` | 65,536 | A whole VPC (the largest AWS allows) |
| `/20` | 4,096 | A big subnet (e.g. EKS worker nodes and pods) |
| `/22` | 1,024 | A medium subnet |
| `/24` | 256 | A typical subnet |
| `/26` | 64 | A small subnet |
| `/28` | 16 | The smallest AWS allows (e.g. Transit Gateway attachment subnets) |

AWS **reserves 5 addresses in every subnet** (the first four and the last one), so a `/24` gives you 251 usable IPs.

### Rules for picking a VPC CIDR

1. **Use a private range** (RFC 1918): `10.0.0.0/8`, `172.16.0.0/12` or `192.168.0.0/16`. Most companies use `10.x.x.x`.
2. **The VPC size must be between `/16` and `/28`.** `/16` is a good default: plenty of room to grow.
3. **Never overlap** with other VPCs, your office network or VPN ranges. Overlapping networks **can't be connected** later with peering or a Transit Gateway.
4. **Give each environment its own block**, for example:

| Environment | VPC CIDR |
|---|---|
| dev | `10.10.0.0/16` |
| staging | `10.20.0.0/16` |
| prod | `10.30.0.0/16` |
| shared services | `10.40.0.0/16` |

5. **Plan for Kubernetes.** On EKS every pod gets a VPC IP, so give EKS subnets `/20` or larger.
6. You can **add more CIDRs later** (a secondary CIDR), but you can't change the first one.

### Splitting the VPC into subnets

A simple plan for `10.10.0.0/16`: public subnets use `10.10.1.x` and `10.10.2.x`, private subnets `10.10.11.x` and `10.10.12.x`. The pattern makes it obvious what an IP is just by looking at it.

| Subnet | AZ | CIDR | Usable IPs |
|---|---|---|---|
| public-a | us-east-1a | `10.10.1.0/24` | 251 |
| public-b | us-east-1b | `10.10.2.0/24` | 251 |
| private-a | us-east-1a | `10.10.11.0/24` | 251 |
| private-b | us-east-1b | `10.10.12.0/24` | 251 |

Let Python do the subnet maths for you:

```bash
python3 -c "import ipaddress; [print(n) for n in list(ipaddress.ip_network('10.10.0.0/16').subnets(new_prefix=24))[:4]]"
python3 -c "import ipaddress; n=ipaddress.ip_network('10.10.11.0/24'); print(n.num_addresses, n[0], n[-1])"
python3 -c "import ipaddress; print(ipaddress.ip_network('10.10.0.0/16').overlaps(ipaddress.ip_network('10.20.0.0/16')))"   # False = safe
```

AWS docs: [VPC CIDR blocks](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-cidr-blocks.html) · [Subnet CIDR blocks](https://docs.aws.amazon.com/vpc/latest/userguide/subnet-sizing.html)

## Quick way: the console wizard

> **In simple words:** The AWS console can build the whole network (VPC, subnets, gateways and route tables) from one form. It's great for a first try. The next steps then build the same thing by hand, so you understand every piece.

1. Open the **VPC console** → **Create VPC**.
2. Choose **VPC and more**.
3. **Name tag auto-generation:** `demo`.
4. **IPv4 CIDR block:** `10.10.0.0/16`.
5. **Number of Availability Zones:** `2`.
6. **Number of public subnets:** `2`. **Number of private subnets:** `2`.
7. **Customize subnet CIDR blocks:** enter the CIDRs from the plan above.
8. **NAT gateways:** `In 1 AZ` (cheaper for learning; production uses `1 per AZ`).
9. **VPC endpoints:** `S3 Gateway` (free, and saves NAT costs for S3 traffic).
10. **DNS options:** keep both **Enable DNS hostnames** and **Enable DNS resolution** ticked.
11. Click **Create VPC**. The preview on the right shows exactly what will be created.

AWS docs: [Create a VPC](https://docs.aws.amazon.com/vpc/latest/userguide/create-vpc.html)

## Step 1: Create the VPC

> **In simple words:** Create the empty network with its address range, and turn on DNS so servers get names as well as IPs.

**Console:** VPC console → **Your VPCs** → **Create VPC** → **VPC only** → Name `demo-vpc`, IPv4 CIDR `10.10.0.0/16` → **Create VPC**. Then **Actions → Edit VPC settings** → tick **Enable DNS hostnames** → **Save**.

**CLI:**

```bash
export AWS_REGION=us-east-1

VPC_ID=$(aws ec2 create-vpc --cidr-block 10.10.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=demo-vpc}]' \
  --query Vpc.VpcId --output text)

aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support '{"Value":true}'
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames '{"Value":true}'

echo "VPC: $VPC_ID"
```

A new VPC automatically gets a **main route table**, a **default security group** and a **default network ACL**.

## Step 2: Create public and private subnets

> **In simple words:** Split the VPC into four subnets: two public and two private, one of each in two Availability Zones. If one AZ (data center) has a problem, the other keeps working.

**Console:** **Subnets** → **Create subnet** → choose `demo-vpc` → add four subnets with the names, AZs and CIDRs from the plan → **Create subnet**. Then select each **public** subnet → **Actions → Edit subnet settings** → tick **Enable auto-assign public IPv4 address**.

**CLI:**

```bash
AZ1=${AWS_REGION}a
AZ2=${AWS_REGION}b

mk_subnet() {   # name cidr az
  aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block "$2" --availability-zone "$3" \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$1}]" \
    --query Subnet.SubnetId --output text
}

PUB1=$(mk_subnet public-a  10.10.1.0/24  $AZ1)
PUB2=$(mk_subnet public-b  10.10.2.0/24  $AZ2)
PRIV1=$(mk_subnet private-a 10.10.11.0/24 $AZ1)
PRIV2=$(mk_subnet private-b 10.10.12.0/24 $AZ2)

# servers launched in public subnets get a public IP automatically
aws ec2 modify-subnet-attribute --subnet-id $PUB1 --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id $PUB2 --map-public-ip-on-launch

aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID \
  --query 'Subnets[].[Tags[?Key==`Name`]|[0].Value,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch]' --output table
```

At this point, **all four subnets are still private**: nothing connects them to the internet yet. The next steps change that.

## Step 3: Create the internet gateway

> **In simple words:** The internet gateway is the VPC's **main entrance to the internet**. Create it, then attach it to your VPC. A VPC can have only one.

**Console:** **Internet gateways** → **Create internet gateway** → Name `demo-igw` → **Create** → **Actions → Attach to VPC** → `demo-vpc`.

**CLI:**

```bash
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=demo-igw}]' \
  --query InternetGateway.InternetGatewayId --output text)

aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
```

AWS docs: [Internet gateways](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html)

## Step 4: Create the public route table

> **In simple words:** A route table is the **signboard** for a subnet. The public one says: "addresses inside the VPC stay inside; **everything else (`0.0.0.0/0`) goes to the internet gateway**." Attaching it to a subnet is what makes that subnet public.

**Console:** **Route tables** → **Create route table** → Name `public-rt`, VPC `demo-vpc` → **Create**. Then:
- **Routes** tab → **Edit routes** → **Add route**: Destination `0.0.0.0/0`, Target **Internet Gateway** `demo-igw` → **Save**.
- **Subnet associations** tab → **Edit subnet associations** → tick `public-a` and `public-b` → **Save**.

**CLI:**

```bash
PUB_RT=$(aws ec2 create-route-table --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=public-rt}]' \
  --query RouteTable.RouteTableId --output text)

aws ec2 create-route --route-table-id $PUB_RT --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
aws ec2 associate-route-table --route-table-id $PUB_RT --subnet-id $PUB1
aws ec2 associate-route-table --route-table-id $PUB_RT --subnet-id $PUB2
```

The public route table now has two routes:

| Destination | Target | Meaning |
|---|---|---|
| `10.10.0.0/16` | `local` | Traffic inside the VPC stays inside (added automatically) |
| `0.0.0.0/0` | `igw-…` | Everything else goes to the internet |

AWS docs: [Route tables](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html)

## Step 5: Create the NAT gateway

> **In simple words:** Private servers still need to go **out** to the internet (to download updates, call APIs, pull images) while staying unreachable from outside. A **NAT gateway** is that one-way exit. It **sits in a public subnet** and needs a fixed public IP (an Elastic IP).

**Console:** **NAT gateways** → **Create NAT gateway** → Name `demo-nat`, **Subnet: `public-a`** (a public one!), Connectivity **Public**, **Allocate Elastic IP** → **Create**. Wait until the status is **Available** (1–3 minutes).

**CLI:**

```bash
EIP_ALLOC=$(aws ec2 allocate-address --domain vpc \
  --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=demo-nat-eip}]' \
  --query AllocationId --output text)

NAT_ID=$(aws ec2 create-nat-gateway --subnet-id $PUB1 --allocation-id $EIP_ALLOC \
  --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=demo-nat}]' \
  --query NatGateway.NatGatewayId --output text)

aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_ID
echo "NAT ready: $NAT_ID"
```

> **Warning:** The most common VPC mistake is putting the NAT gateway in a **private** subnet. It must live in a **public** subnet, because it needs the internet gateway itself.

**Production tip:** create **one NAT gateway per AZ** (each private subnet uses the NAT in its own AZ), so one AZ failing doesn't cut internet access for the others. For learning, one is enough.

AWS docs: [NAT gateways](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html)

## Step 6: Create the private route table

> **In simple words:** The private subnets get their own signboard: "everything outside the VPC goes to the **NAT gateway**." They can go out, but nothing can come in from the internet.

**Console:** **Route tables** → **Create route table** → Name `private-rt`, VPC `demo-vpc` → **Create**. Then:
- **Routes** → **Edit routes** → **Add route**: `0.0.0.0/0` → **NAT Gateway** `demo-nat` → **Save**.
- **Subnet associations** → tick `private-a` and `private-b` → **Save**.

**CLI:**

```bash
PRIV_RT=$(aws ec2 create-route-table --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=private-rt}]' \
  --query RouteTable.RouteTableId --output text)

aws ec2 create-route --route-table-id $PRIV_RT --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT_ID
aws ec2 associate-route-table --route-table-id $PRIV_RT --subnet-id $PRIV1
aws ec2 associate-route-table --route-table-id $PRIV_RT --subnet-id $PRIV2
```

Check both route tables:

```bash
aws ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC_ID \
  --query 'RouteTables[].{Name:Tags[?Key==`Name`]|[0].Value,Routes:Routes[].[DestinationCidrBlock,GatewayId,NatGatewayId]}' --output json
```

**Bonus, free, and it saves NAT costs:** a **gateway endpoint for S3** sends S3 traffic straight to S3 instead of through the NAT gateway:

```bash
aws ec2 create-vpc-endpoint --vpc-id $VPC_ID --vpc-endpoint-type Gateway \
  --service-name com.amazonaws.$AWS_REGION.s3 --route-table-ids $PRIV_RT
```

AWS docs: [Gateway endpoints for S3](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-s3.html)

> **Tip:** Interface endpoints (for SSM, ECR, Secrets Manager and more) and sharing your own service privately with another account are covered in [VPC endpoints and PrivateLink](#/tool/aws-privatelink).

## Step 7: Security groups and network ACLs

> **In simple words:** Route tables decide **where** traffic can go. **Security groups** decide **who is allowed in**, server by server. A good pattern is layers: the internet can reach only the web tier, the web tier only the app tier, the app tier only the database.

```text
 Internet ──443──▶ [ web-sg ] ──8080──▶ [ app-sg ] ──5432──▶ [ db-sg ]
```

**CLI:**

```bash
WEB_SG=$(aws ec2 create-security-group --vpc-id $VPC_ID --group-name web-sg --description "web tier" --query GroupId --output text)
APP_SG=$(aws ec2 create-security-group --vpc-id $VPC_ID --group-name app-sg --description "app tier" --query GroupId --output text)
DB_SG=$(aws ec2 create-security-group --vpc-id $VPC_ID --group-name db-sg  --description "database tier" --query GroupId --output text)

aws ec2 authorize-security-group-ingress --group-id $WEB_SG --protocol tcp --port 443  --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $APP_SG --protocol tcp --port 8080 --source-group $WEB_SG
aws ec2 authorize-security-group-ingress --group-id $DB_SG  --protocol tcp --port 5432 --source-group $APP_SG
```

Allowing a **security group** as the source (instead of an IP range) means "any server in that group". It keeps working as servers come and go.

| | Security group | Network ACL |
|---|---|---|
| Protects | One server (its network card) | A whole subnet |
| Rules | Allow only | Allow **and** deny |
| Return traffic | Allowed automatically (stateful) | Needs its own rule (stateless) |
| Default | Inbound denied, outbound allowed | The default NACL allows everything |
| Use it for | Almost everything | Extra subnet-wide blocks, e.g. a bad IP range |

AWS docs: [Security groups](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html) · [Network ACLs](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html)

## Step 8: Test your VPC

> **In simple words:** Prove it works: a server in a **public** subnet should be reachable from the internet, and a server in a **private** subnet should **not** be reachable but should still get out to the internet through the NAT gateway.

Launch one small instance in each tier. The private one uses **Session Manager** (an IAM role with `AmazonSSMManagedInstanceCore`, as in the [EC2 lab](#/tool/ec2-website)) because it has no public IP:

```bash
AMI_ID=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query Parameter.Value --output text)

aws ec2 authorize-security-group-ingress --group-id $WEB_SG --protocol tcp --port 80 --cidr 0.0.0.0/0

PUBLIC_VM=$(aws ec2 run-instances --image-id $AMI_ID --instance-type t3.micro --subnet-id $PUB1 \
  --security-group-ids $WEB_SG \
  --user-data '#!/bin/bash
dnf install -y nginx && systemctl enable --now nginx' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=public-test}]' \
  --query 'Instances[0].InstanceId' --output text)

PRIVATE_VM=$(aws ec2 run-instances --image-id $AMI_ID --instance-type t3.micro --subnet-id $PRIV1 \
  --security-group-ids $APP_SG --iam-instance-profile Name=ec2-ssm-lab-role \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=private-test}]' \
  --query 'Instances[0].InstanceId' --output text)

aws ec2 wait instance-status-ok --instance-ids $PUBLIC_VM $PRIVATE_VM
aws ec2 describe-instances --instance-ids $PUBLIC_VM $PRIVATE_VM \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`]|[0].Value,PrivateIpAddress,PublicIpAddress]' --output table
```

| Test | Command | Expected result |
|---|---|---|
| Public server reachable | `curl -I http://<public-ip>` from your laptop | `HTTP/1.1 200 OK` |
| Private server has **no public IP** | The table above | `PublicIpAddress` = `None` |
| Private server can get out | `aws ssm start-session --target $PRIVATE_VM`, then `curl -s https://checkip.amazonaws.com` | Shows the **NAT gateway's Elastic IP** |
| Inside the VPC works | From the private server: `curl -I http://<public-server-private-ip>` | `200 OK` (if `web-sg` allows it from `app-sg`) |

The `ec2-ssm-lab-role` comes from the [EC2 lab](#/tool/ec2-website) or the [IAM guide](#/tool/aws-iam).

## Transit Gateway: connect many VPCs

> **In simple words:** With two VPCs you can connect them directly (**VPC peering**). With five, ten or fifty VPCs, plus offices and VPNs, direct links become a mess. A **Transit Gateway** is a **central hub**: every VPC connects once to the hub, and the hub routes traffic between them.

```text
   Without a hub (peering)              With a Transit Gateway
   VPC-A ── VPC-B                        VPC-A   VPC-B   VPC-C
     │  ╲  ╱  │                              ╲    │    ╱
     │   ╳    │   every pair needs                [ TGW ] ── VPN / Direct Connect (office)
     │  ╱  ╲  │   its own link                   ╱    │    ╲
   VPC-C ── VPC-D                        VPC-D   VPC-E   shared-services
```

| | VPC peering | Transit Gateway |
|---|---|---|
| Connects | Exactly two VPCs | Many VPCs, VPNs, Direct Connect |
| Traffic through a third VPC | Not allowed (no transitive routing) | Yes, the hub routes everything |
| Cost | No hourly fee; you pay for data transfer | Hourly per attachment, plus data |
| Best for | A few VPCs | Many VPCs, multi-account, hybrid networks |

**Requirement:** connected VPCs **must not have overlapping CIDRs**. That's why CIDR planning matters.

### Step T1: Create a second VPC to connect

```bash
VPC_B=$(aws ec2 create-vpc --cidr-block 10.20.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=demo-vpc-b}]' --query Vpc.VpcId --output text)
B_PRIV1=$(aws ec2 create-subnet --vpc-id $VPC_B --cidr-block 10.20.11.0/24 --availability-zone $AZ1 \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=b-private-a}]' --query Subnet.SubnetId --output text)
B_PRIV2=$(aws ec2 create-subnet --vpc-id $VPC_B --cidr-block 10.20.12.0/24 --availability-zone $AZ2 \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=b-private-b}]' --query Subnet.SubnetId --output text)
B_RT=$(aws ec2 create-route-table --vpc-id $VPC_B \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=b-private-rt}]' --query RouteTable.RouteTableId --output text)
aws ec2 associate-route-table --route-table-id $B_RT --subnet-id $B_PRIV1
aws ec2 associate-route-table --route-table-id $B_RT --subnet-id $B_PRIV2
```

### Step T2: Create the Transit Gateway

**Console:** VPC console → **Transit gateways** → **Create transit gateway** → Name `demo-tgw`, keep **Default route table association** and **Default route table propagation** ticked → **Create**. Wait for **Available** (a few minutes).

**CLI:**

```bash
TGW_ID=$(aws ec2 create-transit-gateway --description "demo hub" \
  --options AmazonSideAsn=64512,DefaultRouteTableAssociation=enable,DefaultRouteTablePropagation=enable,DnsSupport=enable \
  --tag-specifications 'ResourceType=transit-gateway,Tags=[{Key=Name,Value=demo-tgw}]' \
  --query TransitGateway.TransitGatewayId --output text)

until [ "$(aws ec2 describe-transit-gateways --transit-gateway-ids $TGW_ID \
  --query 'TransitGateways[0].State' --output text)" = "available" ]; do sleep 15; done
echo "TGW ready: $TGW_ID"
```

With **association** and **propagation** on, every attached VPC is added to the hub's route table automatically, so the hub learns each VPC's CIDR by itself.

### Step T3: Attach both VPCs to the Transit Gateway

An attachment puts a small network card in one subnet **per AZ** of the VPC.

**Console:** **Transit gateway attachments** → **Create transit gateway attachment** → Transit gateway `demo-tgw`, type **VPC**, VPC `demo-vpc`, subnets `private-a` and `private-b` → **Create**. Repeat for `demo-vpc-b`.

**CLI:**

```bash
ATT_A=$(aws ec2 create-transit-gateway-vpc-attachment --transit-gateway-id $TGW_ID \
  --vpc-id $VPC_ID --subnet-ids $PRIV1 $PRIV2 \
  --tag-specifications 'ResourceType=transit-gateway-attachment,Tags=[{Key=Name,Value=att-vpc-a}]' \
  --query TransitGatewayVpcAttachment.TransitGatewayAttachmentId --output text)

ATT_B=$(aws ec2 create-transit-gateway-vpc-attachment --transit-gateway-id $TGW_ID \
  --vpc-id $VPC_B --subnet-ids $B_PRIV1 $B_PRIV2 \
  --tag-specifications 'ResourceType=transit-gateway-attachment,Tags=[{Key=Name,Value=att-vpc-b}]' \
  --query TransitGatewayVpcAttachment.TransitGatewayAttachmentId --output text)

for ATT in $ATT_A $ATT_B; do
  until [ "$(aws ec2 describe-transit-gateway-vpc-attachments --transit-gateway-attachment-ids $ATT \
    --query 'TransitGatewayVpcAttachments[0].State' --output text)" = "available" ]; do sleep 15; done
done
echo "Both VPCs attached"
```

**Production tip:** create small dedicated `/28` subnets just for Transit Gateway attachments, so they never compete for IPs with your servers.

### Step T4: Add routes in each VPC pointing to the Transit Gateway

The hub knows both VPCs, but each VPC's **own** route table must also send the other VPC's traffic to the hub:

**Console:** In `private-rt` (VPC A): **Edit routes → Add route** `10.20.0.0/16` → **Transit Gateway** `demo-tgw`. In `b-private-rt` (VPC B): add `10.10.0.0/16` → `demo-tgw`.

**CLI:**

```bash
aws ec2 create-route --route-table-id $PRIV_RT --destination-cidr-block 10.20.0.0/16 --transit-gateway-id $TGW_ID
aws ec2 create-route --route-table-id $B_RT    --destination-cidr-block 10.10.0.0/16 --transit-gateway-id $TGW_ID
```

Check what the hub has learned:

```bash
TGW_RT=$(aws ec2 describe-transit-gateways --transit-gateway-ids $TGW_ID \
  --query 'TransitGateways[0].Options.AssociationDefaultRouteTableId' --output text)
aws ec2 search-transit-gateway-routes --transit-gateway-route-table-id $TGW_RT \
  --filters Name=state,Values=active --query 'Routes[].[DestinationCidrBlock,Type,State]' --output table
# expect 10.10.0.0/16 and 10.20.0.0/16, type "propagated"
```

### Step T5: Allow and test the traffic

Routes open the path; **security groups** still decide who may connect. Allow the other VPC's range, then test from a server in VPC A to one in VPC B:

```bash
aws ec2 authorize-security-group-ingress --group-id $APP_SG --protocol icmp --port -1 --cidr 10.20.0.0/16
# on the VPC B server's security group: allow ICMP (or your app port) from 10.10.0.0/16
# then, from the private server in VPC A (via Session Manager):
SERVER_B_IP=10.20.11.25      # replace with the private IP of a server in VPC B
ping -c 3 $SERVER_B_IP
```

The complete path is: **server A → VPC A route table → Transit Gateway → TGW route table → VPC B → server B**, and the same way back.

| Going further | How |
|---|---|
| Other AWS accounts | Share the Transit Gateway with **AWS RAM**, then attach their VPCs |
| Office or datacenter | Add a **Site-to-Site VPN** or **Direct Connect** attachment to the same hub |
| Keep dev and prod apart | Use separate **TGW route tables** with only the routes each group may use |
| Shared internet egress | One "egress VPC" with NAT gateways, and a `0.0.0.0/0` route in the TGW pointing to it |

AWS docs: [What is Transit Gateway?](https://docs.aws.amazon.com/vpc/latest/tgw/what-is-transit-gateway.html) · [Get started tutorial](https://docs.aws.amazon.com/vpc/latest/tgw/tgw-getting-started.html) · [VPC attachments](https://docs.aws.amazon.com/vpc/latest/tgw/tgw-vpc-attachments.html) · [VPC peering](https://docs.aws.amazon.com/vpc/latest/peering/what-is-vpc-peering.html)

## Troubleshooting

> **In simple words:** When something can't connect, follow the path one hop at a time: **route table → gateway → security group → network ACL → the server itself**. One of them is missing a rule.

| Problem | Likely cause | Fix |
|---|---|---|
| Can't reach the public server | No public IP; the subnet isn't associated with `public-rt`; the security group lacks port 80/443 | Check the instance's public IP, the subnet's route table, the inbound rules |
| Private server can't reach the internet | NAT gateway in a **private** subnet; `private-rt` has no `0.0.0.0/0 → NAT` route; NAT not *Available* | Recreate the NAT in a public subnet; add the route; check the NAT status |
| "Route table not associated" surprises | Subnets without an explicit association use the VPC's **main** route table | Associate every subnet explicitly |
| `InvalidVpc.Range` / CIDR errors | CIDR outside `/16`–`/28`, or a subnet outside the VPC range or overlapping another subnet | Re-plan the CIDRs (use the Python check) |
| Can't attach a VPC to the TGW, or traffic doesn't flow | Overlapping CIDRs between the VPCs | Use non-overlapping ranges. Overlap can't be fixed later without re-creating |
| TGW attached but no traffic | Missing route in the **VPC's** route table, or no propagation in the TGW route table | Add the VPC route to `tgw-…`; check `search-transit-gateway-routes` |
| Ping works one way only | Security group or NACL on the other side, or a missing return route | Allow traffic on both sides; add routes in both VPCs |
| Instances have no DNS names | `enableDnsHostnames` is off | Turn on both DNS attributes on the VPC |
| Unexpected bill | NAT gateway data processing, idle Transit Gateway attachments, unused Elastic IPs | Add an S3 gateway endpoint; delete what you don't use |

Turn on **VPC Flow Logs** (VPC → Flow logs → Create) to see which traffic is accepted and rejected. That's the best tool for network mysteries.

## Clean up

> **In simple words:** Delete in reverse order: servers first, then the paid gateways, then the free network pieces, and the VPC last. AWS refuses to delete a VPC that still has things inside it.

```bash
# servers
aws ec2 terminate-instances --instance-ids $PUBLIC_VM $PRIVATE_VM
aws ec2 wait instance-terminated --instance-ids $PUBLIC_VM $PRIVATE_VM

# Transit Gateway (attachments first, then the hub)
aws ec2 delete-transit-gateway-vpc-attachment --transit-gateway-attachment-id $ATT_A
aws ec2 delete-transit-gateway-vpc-attachment --transit-gateway-attachment-id $ATT_B
sleep 120
aws ec2 delete-transit-gateway --transit-gateway-id $TGW_ID

# NAT gateway, then release its Elastic IP (an unused EIP still costs money)
aws ec2 delete-nat-gateway --nat-gateway-id $NAT_ID
aws ec2 wait nat-gateway-deleted --nat-gateway-ids $NAT_ID
aws ec2 release-address --allocation-id $EIP_ALLOC

# internet gateway
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID

# endpoints, security groups, subnets, route tables, VPCs
for EP in $(aws ec2 describe-vpc-endpoints --filters Name=vpc-id,Values=$VPC_ID --query 'VpcEndpoints[].VpcEndpointId' --output text); do
  aws ec2 delete-vpc-endpoints --vpc-endpoint-ids $EP; done
for SG in $WEB_SG $APP_SG $DB_SG; do aws ec2 delete-security-group --group-id $SG; done
for S in $PUB1 $PUB2 $PRIV1 $PRIV2 $B_PRIV1 $B_PRIV2; do aws ec2 delete-subnet --subnet-id $S; done
for RT in $PUB_RT $PRIV_RT $B_RT; do aws ec2 delete-route-table --route-table-id $RT; done
aws ec2 delete-vpc --vpc-id $VPC_ID
aws ec2 delete-vpc --vpc-id $VPC_B
```

The console shortcut: **Your VPCs → select → Actions → Delete VPC** removes most pieces in one go, once the NAT gateway, instances and Transit Gateway attachments are gone.

In real projects, build all of this with **Terraform** (the `terraform-aws-modules/vpc/aws` module creates a VPC like this in about 15 lines). See the [Terraform guide](#/tool/terraform).

## Lab and cheat sheet

> **In simple words:** Practice time: build the network by hand once, break it on purpose, fix it, and connect it to a second VPC.

1. Plan CIDRs for dev (`10.10.0.0/16`) and staging (`10.20.0.0/16`), and prove they don't overlap with the Python one-liner.
2. Build the dev VPC with 2 public and 2 private subnets, an IGW, a NAT gateway and both route tables, using the CLI.
3. Launch a public and a private server, and run all four tests from Step 8.
4. **Break it:** remove the `0.0.0.0/0` route from `private-rt`. The private server can't reach the internet. Put it back.
5. Add the free S3 gateway endpoint and run `aws s3 ls` from the private server.
6. Create a Transit Gateway, attach a second VPC, add the routes, and ping between the VPCs.
7. Turn on VPC Flow Logs and find one ACCEPT and one REJECT record.
8. Clean up everything, and check that no NAT gateway, Elastic IP or Transit Gateway is left.

### Cheat sheet

| Task | Command |
|---|---|
| Create VPC | `aws ec2 create-vpc --cidr-block 10.10.0.0/16` |
| Create subnet | `aws ec2 create-subnet --vpc-id V --cidr-block 10.10.1.0/24 --availability-zone us-east-1a` |
| Public IPs on launch | `aws ec2 modify-subnet-attribute --subnet-id S --map-public-ip-on-launch` |
| Internet gateway | `aws ec2 create-internet-gateway` + `attach-internet-gateway --vpc-id V` |
| Route to internet | `aws ec2 create-route --route-table-id R --destination-cidr-block 0.0.0.0/0 --gateway-id IGW` |
| NAT gateway | `aws ec2 create-nat-gateway --subnet-id PUBLIC_SUBNET --allocation-id EIP` |
| Route via NAT | `aws ec2 create-route --route-table-id R --destination-cidr-block 0.0.0.0/0 --nat-gateway-id NAT` |
| Link subnet to route table | `aws ec2 associate-route-table --route-table-id R --subnet-id S` |
| Transit Gateway | `aws ec2 create-transit-gateway` + `create-transit-gateway-vpc-attachment` |
| Route via TGW | `aws ec2 create-route --route-table-id R --destination-cidr-block 10.20.0.0/16 --transit-gateway-id TGW` |
