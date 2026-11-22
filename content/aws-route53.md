# Amazon Route 53: DNS

Route 53 is AWS's DNS service. It turns names like `app.example.com` into the addresses of your servers and load balancers. It can also register domains, check the health of your endpoints and route users to the healthiest or closest copy of your app. This guide covers DNS basics, hosted zones, record types, alias records, routing policies, health checks, HTTPS certificates and private DNS.

> **Cost:** A hosted zone costs **$0.50 per month** (the first 12 hours are free, so deleting a test zone quickly costs nothing). Standard queries cost about $0.40 per million, and **alias queries to AWS resources are free**. Domain registration is a yearly fee that depends on the TLD (`.com`, `.dev`…). See [Route 53 pricing](https://aws.amazon.com/route53/pricing/).

## Start here: DNS and Route 53 in simple words

> **In simple words:** DNS is the internet's **phone book**. People remember names (`shop.example.com`); computers need numbers (IP addresses). Route 53 is the place where you write the entries for your own domain, so the world can look them up.

### Watch how it works

```svg Watch it work: a resolver looking up shop.example.com step by step, caching the answer, and Route 53 failing over to a backup when health checks fail. The animation loops.
<svg viewBox="0 0 600 426" role="img" data-anim="aws-route53" aria-label="Animated DNS lookup with Route 53. Look up the name: the browser asks a DNS resolver, such as your ISP&#x27;s or 8.8.8.8, for shop.example.com. The resolver asks a root server, which points it to the .com servers. The .com servers point it to the name servers of your Route 53 hosted zone, such as ns-123.awsdns-45.com. Route 53 answers from the hosted zone: the alias record points at the load balancer, so it returns the load balancer&#x27;s IP addresses. Cache and connect: the resolver caches the answer for the TTL and gives it to the browser, which connects to the load balancer directly. Health check and failover: Route 53 health checkers call the primary every 30 seconds. When it fails 3 checks in a row it is marked unhealthy, and once the cached answer expires Route 53 answers with the backup site instead.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<polyline points="68,176 232,176 513,176" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="370,176 370,106 513,106" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="370,176 370,44 513,44" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="68,176 70,302" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="68,176 68,66" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="1.6" stroke-opacity=".8"/>
<polyline points="270,302 70,302" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="1.6" stroke-opacity=".8"/>
<polyline points="270,302 513,302 513,176" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="1.6" stroke-opacity=".8"/>
<rect x="12" y="40" width="112" height="52" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.878" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><rect x="8" y="36" width="120" height="60" rx="12" fill="#0891b2" fill-opacity=".18" stroke="#0891b2" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.878" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/></rect><rect x="12" y="40" width="112" height="52" rx="9" class="dg-box" stroke="#0891b2" stroke-width="2.2"/><text x="68" y="62.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Backup site</text><text x="68" y="78" text-anchor="middle" font-size="11" class="dg-muted">secondary</text></g>
<g><rect x="8" y="146" width="120" height="60" rx="28" fill="#6366f1" fill-opacity=".18" stroke="#6366f1" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1;0" keyTimes="0;0.1057;0.439;0.6504" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/></rect><rect x="12" y="150" width="112" height="52" rx="25" class="dg-box" stroke="#6366f1" stroke-width="2.2"/><text x="68" y="172.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Browser</text><text x="68" y="188" text-anchor="middle" font-size="11" class="dg-muted">shop.example.com</text></g>
<g><rect x="166" y="146" width="132" height="60" rx="12" fill="#0ea5e9" fill-opacity=".18" stroke="#0ea5e9" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.5447" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/></rect><rect x="170" y="150" width="124" height="52" rx="9" class="dg-box" stroke="#0ea5e9" stroke-width="2.2"/><text x="232" y="172.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">DNS resolver</text><text x="232" y="188" text-anchor="middle" font-size="11" class="dg-muted">your ISP / 8.8.8.8</text></g>
<g><rect x="436" y="18" width="154" height="52" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1057;0.2114" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/></rect><rect x="440" y="22" width="146" height="44" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="513" y="40.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Root servers</text><text x="513" y="56" text-anchor="middle" font-size="11" class="dg-muted">know .com</text></g>
<g><rect x="436" y="80" width="154" height="52" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2114;0.3252" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/></rect><rect x="440" y="84" width="146" height="44" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="513" y="102.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">.com servers</text><text x="513" y="118" text-anchor="middle" font-size="11" class="dg-muted">know example.com</text></g>
<g><rect x="436" y="142" width="154" height="68" rx="12" fill="#8c4fff" fill-opacity=".18" stroke="#8c4fff" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.3252;0.439;0.7642" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/></rect><rect x="440" y="146" width="146" height="60" rx="9" class="dg-box" stroke="#8c4fff" stroke-width="2.2"/><text x="513" y="165" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Route 53</text><text x="513" y="180.5" text-anchor="middle" font-size="11" class="dg-muted">hosted zone</text><text x="513" y="195.5" text-anchor="middle" font-size="11" class="dg-muted">example.com</text></g>
<g><rect x="8" y="272" width="124" height="60" rx="12" fill="#c026d3" fill-opacity=".18" stroke="#c026d3" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5447;0.878" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/></rect><rect x="12" y="276" width="116" height="52" rx="9" class="dg-box" stroke="#c026d3" stroke-width="2.2"/><text x="70" y="298.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Load balancer</text><text x="70" y="314" text-anchor="middle" font-size="11" class="dg-muted">web-alb · primary</text><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.7642" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><rect x="12" y="276" width="116" height="52" rx="9" fill="#e11d48"/><text x="70" y="306.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">unhealthy</text></g></g>
<g><rect x="196" y="272" width="148" height="60" rx="12" fill="#059669" fill-opacity=".18" stroke="#059669" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6504;0.878" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/></rect><rect x="200" y="276" width="140" height="52" rx="9" class="dg-box" stroke="#059669" stroke-width="2.2"/><text x="270" y="298.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Health checkers</text><text x="270" y="314" text-anchor="middle" font-size="11" class="dg-muted">every 30 s</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6504;0.7642" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><circle cx="128" cy="276" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M123.5,276 L127,279.5 L132.5,272.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7642;0.878" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><circle cx="128" cy="276" r="9.5" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M124,272 L132,280 M132,272 L124,280" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0063;0.0909" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M68,176 L232,176" keyPoints="0;0;1;1" keyTimes="0;0.0063;0.0909;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.111;0.1533" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M232,176 L370,176 L370,44 L513,44" keyPoints="0;0;1;1" keyTimes="0;0.111;0.1533;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1607;0.2029" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M513,44 L370,44 L370,176 L232,176" keyPoints="0;0;1;1" keyTimes="0;0.1607;0.2029;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2171;0.2626" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M232,176 L370,176 L370,106 L513,106" keyPoints="0;0;1;1" keyTimes="0;0.2171;0.2626;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2706;0.3161" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M513,106 L370,106 L370,176 L232,176" keyPoints="0;0;1;1" keyTimes="0;0.2706;0.3161;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3309;0.3764" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M232,176 L513,176" keyPoints="0;0;1;1" keyTimes="0;0.3309;0.3764;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3844;0.4299" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M513,176 L232,176" keyPoints="0;0;1;1" keyTimes="0;0.3844;0.4299;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4454;0.5299" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M232,176 L68,176" keyPoints="0;0;1;1" keyTimes="0;0.4454;0.5299;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5511;0.6356" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M68,176 L70,302" keyPoints="0;0;1;1" keyTimes="0;0.5511;0.6356;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6561;0.7016" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M270,302 L70,302" keyPoints="0;0;1;1" keyTimes="0;0.6561;0.7016;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7096;0.7551" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M70,302 L270,302" keyPoints="0;0;1;1" keyTimes="0;0.7096;0.7551;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7688;0.8052" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M270,302 L70,302" keyPoints="0;0;1;1" keyTimes="0;0.7688;0.8052;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8166;0.8689" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M270,302 L513,302 L513,176" keyPoints="0;0;1;1" keyTimes="0;0.8166;0.8689;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><g><circle r="7" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M0,-3.5 V1 M0,3.2 V3.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8829;0.9341" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M513,176 L232,176 L68,176" keyPoints="0;0;1;1" keyTimes="0;0.8829;0.9341;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.939;0.9902" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><animateMotion path="M68,176 L68,66" keyPoints="0;0;1;1" keyTimes="0;0.939;0.9902;1" calcMode="linear" dur="24.6s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(20.4,350.5) scale(.8)"><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g><text x="31.8" y="354">request</text><g transform="translate(93.4,350.5) scale(.8)"><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g><text x="104.8" y="354">DNS query</text><g transform="translate(177.6,350.5) scale(.8)"><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g><text x="189" y="354">answer</text><g transform="translate(245,350.5) scale(.8)"><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g><text x="256.4" y="354">health check</text><g transform="translate(346,350.5) scale(.8)"><g><circle r="7" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M0,-3.5 V1 M0,3.2 V3.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/></g></g><text x="357.4" y="354">unhealthy</text></g>
<rect x="12" y="366" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="366" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="24.6s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1057" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><circle cx="36" cy="394" r="14" fill="#6366f1"/><text x="36" y="399" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="389" font-size="14" font-weight="800" fill="#6366f1">The browser asks a resolver</text><text x="578" y="389" text-anchor="end" font-size="10.5" class="dg-muted">Look up the name · 1/9</text><text x="60" y="410" font-size="12.5" class="dg-text">Who is shop.example.com? A resolver, like your ISP&#x27;s or 8.8.8.8, finds out.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1057;0.2114" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><circle cx="36" cy="394" r="14" fill="#6366f1"/><text x="36" y="399" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="389" font-size="14" font-weight="800" fill="#6366f1">A root server points to .com</text><text x="578" y="389" text-anchor="end" font-size="10.5" class="dg-muted">Look up the name · 2/9</text><text x="60" y="410" font-size="12.5" class="dg-text">It doesn&#x27;t know the name, but it knows who runs .com.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2114;0.3252" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><circle cx="36" cy="394" r="14" fill="#6366f1"/><text x="36" y="399" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="389" font-size="14" font-weight="800" fill="#6366f1">.com points to Route 53</text><text x="578" y="389" text-anchor="end" font-size="10.5" class="dg-muted">Look up the name · 3/9</text><text x="60" y="410" font-size="12.5" class="dg-text">example.com&#x27;s NS records name your Route 53 servers, like ns-123.awsdns-45.com.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3252;0.439" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><circle cx="36" cy="394" r="14" fill="#6366f1"/><text x="36" y="399" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="389" font-size="14" font-weight="800" fill="#6366f1">Route 53 answers from your hosted zone</text><text x="578" y="389" text-anchor="end" font-size="10.5" class="dg-muted">Look up the name · 4/9</text><text x="60" y="410" font-size="12.5" class="dg-text">The alias record for shop.example.com returns the load balancer&#x27;s IPs.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.439;0.5447" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><circle cx="36" cy="394" r="14" fill="#059669"/><text x="36" y="399" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="389" font-size="14" font-weight="800" fill="#059669">The answer is cached for the TTL</text><text x="578" y="389" text-anchor="end" font-size="10.5" class="dg-muted">Cache and connect · 5/9</text><text x="60" y="410" font-size="12.5" class="dg-text">Until the TTL runs out, the resolver answers from its cache, with no lookups.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5447;0.6504" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><circle cx="36" cy="394" r="14" fill="#059669"/><text x="36" y="399" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="389" font-size="14" font-weight="800" fill="#059669">The browser connects to the site</text><text x="578" y="389" text-anchor="end" font-size="10.5" class="dg-muted">Cache and connect · 6/9</text><text x="60" y="410" font-size="12.5" class="dg-text">It uses the IP address directly. DNS is not in the path any more.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6504;0.7642" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><circle cx="36" cy="394" r="14" fill="#e11d48"/><text x="36" y="399" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="389" font-size="14" font-weight="800" fill="#e11d48">Route 53 checks the site every 30 s</text><text x="578" y="389" text-anchor="end" font-size="10.5" class="dg-muted">Health check and failover · 7/9</text><text x="60" y="410" font-size="12.5" class="dg-text">Health checkers call the primary. It answers, so it is healthy.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7642;0.878" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><circle cx="36" cy="394" r="14" fill="#e11d48"/><text x="36" y="399" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="389" font-size="14" font-weight="800" fill="#e11d48">The primary stops answering</text><text x="578" y="389" text-anchor="end" font-size="10.5" class="dg-muted">Health check and failover · 8/9</text><text x="60" y="410" font-size="12.5" class="dg-text">After 3 failed checks in a row, Route 53 marks it unhealthy.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.878" calcMode="discrete" dur="24.6s" repeatCount="indefinite"/><circle cx="36" cy="394" r="14" fill="#e11d48"/><text x="36" y="399" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">9</text><text x="60" y="389" font-size="14" font-weight="800" fill="#e11d48">Route 53 now answers with the backup</text><text x="578" y="389" text-anchor="end" font-size="10.5" class="dg-muted">Health check and failover · 9/9</text><text x="60" y="410" font-size="12.5" class="dg-text">Once the cached answer expires, visitors get the backup site instead.</text></g>
</svg>
```

### What happens when you open a website

```text
 You type shop.example.com
   │
   ▼
 Your computer asks a DNS resolver (your ISP, 8.8.8.8, or 1.1.1.1)
   │  "Who knows about .com?"            → root servers
   │  "Who knows about example.com?"     → .com servers → "ask Route 53: ns-123.awsdns-45.com"
   │  "What is shop.example.com?"        → Route 53 (your hosted zone)
   ▼
 Answer: 3.91.12.34 (cached for TTL seconds)  →  browser connects to that IP
```

### A real-life comparison

| Phone book | DNS / Route 53 |
|---|---|
| The whole phone book for a town | A **hosted zone** for `example.com` |
| One line: "Pizza Place → 555-1234" | A **record**: `shop.example.com → 3.91.12.34` |
| "This listing is valid until next year's edition" | **TTL**: how long others may cache the answer |
| Buying the right to be listed under a name | **Registering a domain** |
| A note: "for this business, see the other book" | An **NS record** (delegation) |

### Key words

| Word | Simple meaning |
|---|---|
| **Domain** | A name you own, such as `example.com` |
| **Hosted zone** | Route 53's container for all records of one domain |
| **Record** | One DNS entry: name, type, value, TTL |
| **TTL** | Seconds a resolver may cache the answer (60 = changes spread quickly) |
| **Name servers (NS)** | The servers that answer for your domain; Route 53 gives you four |
| **Apex / root** | The bare domain `example.com` (without `www`) |
| **Alias record** | A Route 53 feature that points a name at an AWS resource (ALB, CloudFront, S3 website), even at the apex |

### Check yourself

1. Why do we need DNS at all?
2. What does a TTL of 300 mean?
3. Which record type points a name to an IPv4 address?

> **Tip:** Answers: 1) People use names, computers connect to IP addresses. 2) Resolvers may cache the answer for 5 minutes, so changes can take up to 5 minutes to be seen. 3) An `A` record (`AAAA` for IPv6).

## DNS basics with dig

> **In simple words:** `dig` asks DNS questions from your terminal. It's the first tool to reach for when "the website doesn't load".

```bash
sudo apt install -y dnsutils           # provides dig and nslookup (WSL/Ubuntu)

dig example.com                        # A records (IPv4)
dig example.com +short                 # just the answer
dig www.amazon.com CNAME +short        # alias name it points to
dig example.com MX +short              # mail servers
dig example.com NS +short              # name servers for the zone
dig example.com TXT +short             # verification and SPF records
dig @8.8.8.8 example.com +short        # ask a specific resolver
dig example.com +trace                 # follow root → .com → authoritative
```

In the answer section, the number after the name is the remaining **TTL** in seconds.

## Hosted zones: public and private

> **In simple words:** A hosted zone is the folder where all DNS records for one domain live. A **public** zone answers anyone on the internet. A **private** zone answers only inside your chosen VPCs.

Create a public hosted zone:

```bash
DOMAIN=example.com        # use a domain you own (or a subdomain like lab.yourdomain.com)
ZONE_ID=$(aws route53 create-hosted-zone --name $DOMAIN \
  --caller-reference "lab-$(date +%s)" \
  --hosted-zone-config Comment="DevOps lab" \
  --query 'HostedZone.Id' --output text | cut -d/ -f3)
echo $ZONE_ID

aws route53 get-hosted-zone --id $ZONE_ID --query 'DelegationSet.NameServers'
aws route53 list-resource-record-sets --hosted-zone-id $ZONE_ID --output table
```

Every new zone comes with two records:
- **NS**: the four Route 53 name servers for this zone, such as `ns-123.awsdns-45.com`.
- **SOA**: technical information about the zone.

AWS docs: [Working with hosted zones](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zones-working-with.html)

## Get a domain and point it to Route 53

> **In simple words:** Records in Route 53 only matter once the world knows Route 53 is in charge of your domain. You either **buy** the domain in Route 53 (automatic) or tell your **existing registrar** to use Route 53's name servers.

| Situation | What to do |
|---|---|
| **Buy a new domain in Route 53** | **Route 53 → Registered domains → Register domains.** A hosted zone is created and linked automatically |
| **Domain bought elsewhere** (GoDaddy, Namecheap…) | At the registrar, replace its name servers with the **four NS values** from your hosted zone |
| **Use only a subdomain** (e.g. `aws.company.com`) | Create a zone for `aws.company.com`, then add an **NS record** for `aws` in the parent zone with Route 53's four name servers |

Check that delegation works. It can take up to 48 hours, but usually minutes:

```bash
dig $DOMAIN NS +short                 # should list the awsdns-* servers
dig $DOMAIN NS +trace | tail -8
```

> **Tip:** Lower the TTL of records at your old DNS provider to 300 a day **before** switching, so a mistake is short-lived.

AWS docs: [Registering a new domain](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/domain-register.html)

## Record types and creating records

> **In simple words:** Each record type answers a different question: "what's the IPv4 address?" (A), "what other name is this?" (CNAME), "where does mail go?" (MX). You create them in the console, or by sending a small JSON "change batch".

| Type | Points to | Example |
|---|---|---|
| **A** | IPv4 address | `app.example.com → 3.91.12.34` |
| **AAAA** | IPv6 address | `app.example.com → 2600:1f18::1` |
| **CNAME** | Another name (not allowed at the apex) | `www.example.com → example.com` |
| **Alias** (Route 53 only) | An AWS resource: ALB, NLB, CloudFront, S3 website, API Gateway, another record | `example.com → my-alb-123.us-east-1.elb.amazonaws.com` |
| **MX** | Mail servers, with priority | `10 mail.example.com` |
| **TXT** | Text, used for domain verification, SPF and DKIM | `"v=spf1 include:amazonses.com ~all"` |
| **NS** | Name servers for a (sub)domain | Delegation |
| **CAA** | Which certificate authorities may issue certificates | `0 issue "amazon.com"` |
| **SRV** | Service host and port | Some apps and VoIP |

Create an `A` record for the web server from the [EC2 lab](#/tool/ec2-website). `UPSERT` means "create or update":

```bash
cat > a-record.json <<EOF
{
  "Comment": "web server",
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "web.$DOMAIN",
      "Type": "A",
      "TTL": 60,
      "ResourceRecords": [{ "Value": "3.91.12.34" }]
    }
  }]
}
EOF
CHANGE_ID=$(aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID \
  --change-batch file://a-record.json --query ChangeInfo.Id --output text)
aws route53 wait resource-record-sets-changed --id $CHANGE_ID     # PENDING → INSYNC
dig web.$DOMAIN +short
curl -I http://web.$DOMAIN
```

Use `"Action": "DELETE"` with the **exact same** record to remove it.

AWS docs: [Supported DNS record types](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/ResourceRecordTypes.html)

## Alias records: point names at AWS resources

> **In simple words:** Load balancers and CloudFront don't have fixed IPs; they have DNS names that can change underneath. An **alias** record follows them automatically, works at the bare domain (`example.com`), and Route 53 doesn't charge for these lookups.

| | CNAME | Alias |
|---|---|---|
| Works at the apex (`example.com`)? | **No** | **Yes** |
| Targets | Any DNS name | AWS resources and records in the same zone |
| Query cost | Charged | **Free** for AWS resource targets |
| TTL | You set it | Taken from the target |

Point the apex and `www` at an Application Load Balancer (see the [Load Balancers guide](#/tool/aws-elb)):

```bash
ALB_DNS=$(aws elbv2 describe-load-balancers --names web-alb --query 'LoadBalancers[0].DNSName' --output text)
ALB_ZONE=$(aws elbv2 describe-load-balancers --names web-alb --query 'LoadBalancers[0].CanonicalHostedZoneId' --output text)

cat > alias.json <<EOF
{
  "Changes": [
    { "Action": "UPSERT", "ResourceRecordSet": { "Name": "$DOMAIN", "Type": "A",
      "AliasTarget": { "HostedZoneId": "$ALB_ZONE", "DNSName": "dualstack.$ALB_DNS", "EvaluateTargetHealth": true } } },
    { "Action": "UPSERT", "ResourceRecordSet": { "Name": "www.$DOMAIN", "Type": "A",
      "AliasTarget": { "HostedZoneId": "$ALB_ZONE", "DNSName": "dualstack.$ALB_DNS", "EvaluateTargetHealth": true } } }
  ]
}
EOF
aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch file://alias.json
```

`HostedZoneId` in an alias is the **target's** zone ID (the load balancer's canonical zone), not your own zone's ID. That's the most common mistake.

AWS docs: [Choosing between alias and non-alias records](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-choosing-alias-non-alias.html)

## Routing policies

> **In simple words:** A routing policy decides **which answer** Route 53 gives when a name has several possible targets: always the same one, a percentage split, the closest Region, or the healthy backup when the main site is down.

| Policy | How it picks the answer | Typical use |
|---|---|---|
| **Simple** | One record, maybe several IPs | Most records |
| **Weighted** | Splits traffic by weight (e.g. 90/10) | Canary releases, A/B tests, gradual migrations |
| **Latency** | The Region with the lowest latency for the user | Multi-Region apps |
| **Failover** | Primary while healthy, otherwise secondary | Disaster recovery, maintenance pages |
| **Geolocation** | The user's country or continent | Legal or content rules per country |
| **Geoproximity** | Distance, with an adjustable "bias" | Shifting traffic between Regions |
| **Multivalue answer** | Up to 8 healthy records at random | Simple client-side load spreading |
| **IP-based** | The user's IP ranges (CIDR) | Routing by ISP or network |

Weighted example: send 90% to the current version and 10% to the new one. Records with the same name need different `SetIdentifier` values:

```json
{
  "Changes": [
    { "Action": "UPSERT", "ResourceRecordSet": { "Name": "api.example.com", "Type": "A", "SetIdentifier": "blue",
      "Weight": 90, "TTL": 60, "ResourceRecords": [{ "Value": "3.91.12.34" }] } },
    { "Action": "UPSERT", "ResourceRecordSet": { "Name": "api.example.com", "Type": "A", "SetIdentifier": "green",
      "Weight": 10, "TTL": 60, "ResourceRecords": [{ "Value": "54.12.88.7" }] } }
  ]
}
```

Run `for i in $(seq 20); do dig api.example.com +short @<one-of-your-ns>; done | sort | uniq -c` to see the split.

AWS docs: [Choosing a routing policy](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy.html)

## Health checks and failover

> **In simple words:** Route 53 can call your website every 30 seconds from around the world. If it stops answering, Route 53 stops sending people there and answers with the backup instead.

```bash
HC_ID=$(aws route53 create-health-check --caller-reference "hc-$(date +%s)" \
  --health-check-config '{
    "Type": "HTTP", "FullyQualifiedDomainName": "web.example.com", "Port": 80,
    "ResourcePath": "/", "RequestInterval": 30, "FailureThreshold": 3
  }' --query HealthCheck.Id --output text)
aws route53 get-health-check-status --health-check-id $HC_ID --query 'HealthCheckObservations[].StatusReport.Status'
```

Failover pair: the primary uses the health check, and the secondary can be an S3 static "we'll be back" page:

```json
{
  "Changes": [
    { "Action": "UPSERT", "ResourceRecordSet": { "Name": "app.example.com", "Type": "A",
      "SetIdentifier": "primary", "Failover": "PRIMARY", "TTL": 60, "HealthCheckId": "HEALTH_CHECK_ID",
      "ResourceRecords": [{ "Value": "3.91.12.34" }] } },
    { "Action": "UPSERT", "ResourceRecordSet": { "Name": "app.example.com", "Type": "A",
      "SetIdentifier": "secondary", "Failover": "SECONDARY", "TTL": 60,
      "ResourceRecords": [{ "Value": "54.12.88.7" }] } }
  ]
}
```

Stop nginx on the primary server, wait about 2 minutes, and `dig app.example.com +short` returns the secondary.

Health checks cost about **$0.50 per month** each (AWS endpoints), and more with optional features.

AWS docs: [Creating health checks](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-failover.html)

## HTTPS certificates with ACM and DNS validation

> **In simple words:** To serve HTTPS on a load balancer or CloudFront, you need a certificate. **AWS Certificate Manager (ACM)** issues them for free. You prove you own the domain by adding one DNS record, and if the domain is in Route 53, that's one click.

```bash
CERT_ARN=$(aws acm request-certificate --domain-name $DOMAIN \
  --subject-alternative-names "*.$DOMAIN" --validation-method DNS \
  --query CertificateArn --output text)

aws acm describe-certificate --certificate-arn $CERT_ARN \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord'     # the CNAME to create
```

Easiest way: in the **ACM console**, open the certificate and click **Create records in Route 53**. Then:

```bash
aws acm wait certificate-validated --certificate-arn $CERT_ARN       # usually a few minutes
aws acm describe-certificate --certificate-arn $CERT_ARN --query Certificate.Status
```

Keep the validation CNAME in place: ACM uses it to **renew automatically**.

> **Note:** Certificates for a load balancer must be in the **same Region** as the load balancer. Certificates for **CloudFront** must be requested in **us-east-1**.

AWS docs: [ACM DNS validation](https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html)

## Private hosted zones

> **In simple words:** Give internal services friendly names (`db.internal.company`) that only work inside your VPC and are invisible on the internet.

```bash
VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
PRIV_ZONE=$(aws route53 create-hosted-zone --name internal.lab \
  --caller-reference "priv-$(date +%s)" \
  --vpc VPCRegion=$AWS_REGION,VPCId=$VPC_ID \
  --hosted-zone-config Comment="internal names",PrivateZone=true \
  --query 'HostedZone.Id' --output text | cut -d/ -f3)
```

Add records the same way, for example `db.internal.lab → 172.31.20.15`. From an EC2 instance in that VPC, `dig db.internal.lab +short` answers; from your laptop it doesn't.

The VPC must have **DNS resolution** and **DNS hostnames** enabled (default VPCs do).

AWS docs: [Private hosted zones](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zones-private.html)

## Troubleshooting

> **In simple words:** Work from the top: is Route 53 in charge of the domain (NS)? Does the record exist? Is an old answer cached (TTL)? Is the target itself healthy?

| Symptom | Check / fix |
|---|---|
| Records exist but the internet doesn't see them | Registrar NS ≠ hosted zone NS. Compare `dig domain NS +short` with the zone's NS record |
| Old IP still returned | Caching. Wait for the TTL; test against a Route 53 name server directly: `dig @ns-123.awsdns-45.com name` |
| `CNAME` at `example.com` rejected | CNAME isn't allowed at the apex. Use an **alias** record |
| Alias to the ALB doesn't resolve | Wrong `HostedZoneId` (it must be the ALB's canonical zone ID) |
| `NXDOMAIN` | The name doesn't exist. Check for typos and a missing trailing subdomain |
| HTTPS certificate stuck "Pending validation" | The validation CNAME is missing or in the wrong zone |
| Failover never triggers | No health check attached to the PRIMARY record, or the health check is targeting the wrong path or port |

Online tools such as [dnschecker.org](https://dnschecker.org) show what resolvers around the world currently see.

## Clean up

> **In simple words:** A hosted zone can only be deleted once it contains nothing but its default NS and SOA records.

```bash
# delete your records (same JSON as creating, with "Action": "DELETE")
sed 's/"UPSERT"/"DELETE"/' a-record.json > a-delete.json
aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch file://a-delete.json

aws route53 delete-health-check --health-check-id $HC_ID
aws route53 delete-hosted-zone --id $ZONE_ID
aws route53 delete-hosted-zone --id $PRIV_ZONE
aws acm delete-certificate --certificate-arn $CERT_ARN     # once nothing uses it
```

Domains you **registered** renew yearly unless you turn off auto-renew under **Registered domains**.

## Lab: a real domain for your app

> **In simple words:** Practice time: give the web server from the EC2 lab a proper name, then make it fail over to a backup page.

1. Create a public hosted zone for a domain or subdomain you control, and delegate it (NS records at the registrar or parent zone).
2. Create `web.<domain>` as an **A record** to your EC2 web server with TTL 60. `curl http://web.<domain>` works.
3. Request an **ACM certificate** for `<domain>` and `*.<domain>` with DNS validation, and wait until it's **Issued**.
4. Put an **ALB** in front of the server (Load Balancers guide), attach the certificate, and point `<domain>` and `www.<domain>` at it with **alias** records. Open `https://<domain>`.
5. Create a **health check** and a **failover** pair: primary = the ALB, secondary = an S3 static "maintenance" page. Stop the web server and watch DNS switch over.
6. Create a **private** zone `internal.lab` and resolve a name from inside the VPC only.
7. Clean up everything except the registered domain.

### Cheat sheet

| Task | Command |
|---|---|
| Look up a name | `dig name +short` / `dig name NS +short` |
| Create zone | `aws route53 create-hosted-zone --name d --caller-reference $(date +%s)` |
| List records | `aws route53 list-resource-record-sets --hosted-zone-id Z` |
| Create/update record | `aws route53 change-resource-record-sets --hosted-zone-id Z --change-batch file://c.json` |
| Wait for change | `aws route53 wait resource-record-sets-changed --id C` |
| Free HTTPS cert | `aws acm request-certificate --domain-name d --validation-method DNS` |
