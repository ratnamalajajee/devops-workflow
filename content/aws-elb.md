# AWS Load Balancers and Their Types

Elastic Load Balancing (ELB) spreads incoming traffic across several servers, containers or IPs, so that no single machine is overloaded, unhealthy targets are skipped, and you can add or remove servers without users noticing. This guide compares the four types (**ALB, NLB, GWLB, Classic**), then builds an Application Load Balancer with path routing and HTTPS, and a Network Load Balancer, step by step.

> **Cost:** A load balancer is billed **per hour** (about $0.0225/hour for an ALB or NLB in us-east-1, roughly $16/month) plus a small usage charge (LCU/NLCU). The lab's EC2 instances add their own cost. **Delete everything at the end.** See [ELB pricing](https://aws.amazon.com/elasticloadbalancing/pricing/).

## Start here: load balancers in simple words

> **In simple words:** A load balancer is the **receptionist** at the front door. Visitors talk only to the receptionist, who sends each one to a free, healthy staff member behind the scenes. If someone goes home sick, the receptionist simply stops sending people to them.

### Watch how it works

```svg Watch it work: an HTTPS request routed by path to the right target group, then health checks taking a broken server out of rotation. The animation loops.
<svg viewBox="0 0 600 386" role="img" data-anim="aws-elb" data-dur="38.08" data-starts="0 4.42 8.84 13.94 18.36 23.46 28.22 32.98" aria-label="Animated Application Load Balancer flow. Route a request: a visitor connects to web-alb over HTTPS; the listener on port 443 uses an ACM certificate to decrypt the request. The path /api/orders matches the /api/* rule, so it is forwarded to the target group lab-api-tg, which picks the healthy target api-2 in AZ b, and the reply goes back to the visitor. A request for / matches no rule, so the listener&#x27;s default action forwards it to lab-web-tg, and web-1 in AZ a answers; requests are spread over healthy targets in both Availability Zones. Health checks: at a fixed interval the load balancer calls every target&#x27;s health check path, and all of them answer. Then web-1 fails 2 checks in a row; it is marked unhealthy and gets no new requests, so traffic for / flows around it to web-2 in AZ b until web-1 recovers.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<rect x="344" y="20" width="120" height="270" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.3" stroke-dasharray="3 4"/>
<rect x="472" y="20" width="120" height="270" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.3" stroke-dasharray="3 4"/>
<polyline points="48,160 166,160" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="166,53 166,160" fill="none" stroke-linejoin="round" stroke="#eab308" stroke-width="1.8" stroke-dasharray="3 3" stroke-opacity=".75"/>
<polyline points="166,160 228,160 228,80 286,80 404,80" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="286,80 286,128 532,128 532,80" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="228,160 228,240 286,240 404,240" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="286,240 286,192 532,192 532,240" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<rect x="350" y="26" width="31.6" height="16" rx="5" class="dg-box"/><text x="354" y="36" font-size="11" class="dg-muted">AZ a</text>
<rect x="478" y="26" width="31.6" height="16" rx="5" class="dg-box"/><text x="482" y="36" font-size="11" class="dg-muted">AZ b</text>
<g><rect x="4" y="130" width="88" height="60" rx="28" fill="#6366f1" fill-opacity=".18" stroke="#6366f1" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1161" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/></rect><rect x="8" y="134" width="80" height="52" rx="25" class="dg-box" stroke="#6366f1" stroke-width="2.2"/><text x="48" y="156.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Visitor</text><text x="48" y="172" text-anchor="middle" font-size="11" class="dg-muted">browser</text></g>
<g><rect x="112" y="26" width="108" height="54" rx="12" fill="#16a34a" fill-opacity=".18" stroke="#16a34a" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1161" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/></rect><rect x="116" y="30" width="100" height="46" rx="9" class="dg-box" stroke="#16a34a" stroke-width="2.2"/><text x="166" y="49.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">ACM</text><text x="166" y="65" text-anchor="middle" font-size="11" class="dg-muted">certificate</text></g>
<g><rect x="112" y="120" width="108" height="80" rx="12" fill="#c026d3" fill-opacity=".18" stroke="#c026d3" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1;0" keyTimes="0;0.2321;0.3661;0.4821" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/></rect><rect x="116" y="124" width="100" height="72" rx="9" class="dg-box" stroke="#c026d3" stroke-width="2.2"/><text x="166" y="149" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">web-alb</text><text x="166" y="164.5" text-anchor="middle" font-size="11" class="dg-muted">HTTPS :443</text><text x="166" y="179.5" text-anchor="middle" font-size="11" class="dg-muted">+ rules</text></g>
<g><rect x="236" y="53" width="100" height="54" rx="12" fill="#0891b2" fill-opacity=".18" stroke="#0891b2" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1161;0.3661" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/></rect><rect x="240" y="57" width="92" height="46" rx="9" class="dg-box" stroke="#0891b2" stroke-width="2.2"/><text x="286" y="76.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">lab-api-tg</text><text x="286" y="92" text-anchor="middle" font-size="11" class="dg-muted">/api/*</text></g>
<g><rect x="236" y="213" width="100" height="54" rx="12" fill="#0ea5e9" fill-opacity=".18" stroke="#0ea5e9" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.3661;0.6161;0.8661" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/></rect><rect x="240" y="217" width="92" height="46" rx="9" class="dg-box" stroke="#0ea5e9" stroke-width="2.2"/><text x="286" y="236.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">lab-web-tg</text><text x="286" y="252" text-anchor="middle" font-size="11" class="dg-muted">default</text></g>
<g><rect x="350" y="53" width="108" height="54" rx="12" fill="#f59e0b" fill-opacity=".18" stroke="#f59e0b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6161;0.7411" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/></rect><rect x="354" y="57" width="100" height="46" rx="9" class="dg-box" stroke="#f59e0b" stroke-width="2.2"/><text x="404" y="76.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">api-1</text><text x="404" y="92" text-anchor="middle" font-size="11" class="dg-muted">HTTP :80</text></g>
<g><rect x="478" y="53" width="108" height="54" rx="12" fill="#f59e0b" fill-opacity=".18" stroke="#f59e0b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.2321;0.3661;0.6161;0.7411" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/></rect><rect x="482" y="57" width="100" height="46" rx="9" class="dg-box" stroke="#f59e0b" stroke-width="2.2"/><text x="532" y="76.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">api-2</text><text x="532" y="92" text-anchor="middle" font-size="11" class="dg-muted">HTTP :80</text></g>
<g><rect x="350" y="213" width="108" height="54" rx="12" fill="#f59e0b" fill-opacity=".18" stroke="#f59e0b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4821;0.8661" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/></rect><rect x="354" y="217" width="100" height="46" rx="9" class="dg-box" stroke="#f59e0b" stroke-width="2.2"/><text x="404" y="236.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">web-1</text><text x="404" y="252" text-anchor="middle" font-size="11" class="dg-muted">nginx :80</text><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.7411" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><rect x="354" y="217" width="100" height="46" rx="9" fill="#e11d48"/><text x="404" y="244.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">unhealthy</text></g></g>
<g><rect x="478" y="213" width="108" height="54" rx="12" fill="#f59e0b" fill-opacity=".18" stroke="#f59e0b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.6161;0.7411;0.8661" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/></rect><rect x="482" y="217" width="100" height="46" rx="9" class="dg-box" stroke="#f59e0b" stroke-width="2.2"/><text x="532" y="236.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">web-2</text><text x="532" y="252" text-anchor="middle" font-size="11" class="dg-muted">nginx :80</text></g>
<g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1161" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><circle cx="216" cy="124" r="9.5" fill="#d97706" stroke="#fff" stroke-width="2"/><rect x="211.5" y="123" width="9" height="6.5" rx="1.2" fill="#fff"/><path d="M213.2,123 V121 A2.8,2.8 0 0 1 218.8,121 V123" fill="none" stroke="#fff" stroke-width="1.6"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6161;0.7411" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><circle cx="454" cy="57" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M449.5,57 L453,60.5 L458.5,53.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6161;0.7411" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><circle cx="582" cy="57" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M577.5,57 L581,60.5 L586.5,53.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6161;0.7411" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><circle cx="454" cy="217" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M449.5,217 L453,220.5 L458.5,213.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6161;0.7411" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><circle cx="582" cy="217" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M577.5,217 L581,220.5 L586.5,213.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7411;0.8661" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><circle cx="454" cy="217" r="9.5" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M450,213 L458,221 M458,213 L450,221" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.007;0.0998" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><animateMotion path="M48,160 L166,160" keyPoints="0;0;1;1" keyTimes="0;0.007;0.0998;1" calcMode="linear" dur="38.08s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.123;0.2159" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><animateMotion path="M166,160 L228,160 L228,80 L286,80" keyPoints="0;0;1;1" keyTimes="0;0.123;0.2159;1" calcMode="linear" dur="38.08s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2375;0.2857" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><animateMotion path="M286,80 L286,128 L532,128 L532,80" keyPoints="0;0;1;1" keyTimes="0;0.2375;0.2857;1" calcMode="linear" dur="38.08s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2938;0.358" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><animateMotion path="M532,80 L532,128 L286,128 L286,80 L286,80 L228,80 L228,160 L166,160 L48,160" keyPoints="0;0;1;1" keyTimes="0;0.2938;0.358;1" calcMode="linear" dur="38.08s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.373;0.4659" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><animateMotion path="M48,160 L166,160 L228,160 L228,240 L286,240" keyPoints="0;0;1;1" keyTimes="0;0.373;0.4659;1" calcMode="linear" dur="38.08s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4875;0.5304" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><animateMotion path="M286,240 L404,240" keyPoints="0;0;1;1" keyTimes="0;0.4875;0.5304;1" calcMode="linear" dur="38.08s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5411;0.608" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><animateMotion path="M404,240 L286,240 L228,240 L228,160 L166,160 L48,160" keyPoints="0;0;1;1" keyTimes="0;0.5411;0.608;1" calcMode="linear" dur="38.08s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6236;0.6911" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><animateMotion path="M286,80 L404,80" keyPoints="0;0;1;1" keyTimes="0;0.6236;0.6911;1" calcMode="linear" dur="38.08s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6236;0.6911" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><animateMotion path="M286,80 L286,128 L532,128 L532,80" keyPoints="0;0;1;1" keyTimes="0;0.6236;0.6911;1" calcMode="linear" dur="38.08s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6236;0.6911" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><animateMotion path="M286,240 L404,240" keyPoints="0;0;1;1" keyTimes="0;0.6236;0.6911;1" calcMode="linear" dur="38.08s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6236;0.6911" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><animateMotion path="M286,240 L286,192 L532,192 L532,240" keyPoints="0;0;1;1" keyTimes="0;0.6236;0.6911;1" calcMode="linear" dur="38.08s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7486;0.8161" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><animateMotion path="M286,240 L404,240" keyPoints="0;0;1;1" keyTimes="0;0.7486;0.8161;1" calcMode="linear" dur="38.08s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8714;0.9866" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><animateMotion path="M48,160 L166,160 L228,160 L228,240 L286,240 L286,192 L532,192 L532,240" keyPoints="0;0;1;1" keyTimes="0;0.8714;0.9866;1" calcMode="linear" dur="38.08s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(20.4,310.5) scale(.8)"><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g><text x="31.8" y="314">request</text><g transform="translate(93.4,310.5) scale(.8)"><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g><text x="104.8" y="314">reply</text><g transform="translate(155.2,310.5) scale(.8)"><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g><text x="166.6" y="314">health check</text></g>
<rect x="12" y="326" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="326" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="38.08s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1161" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#6366f1"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="349" font-size="14" font-weight="800" fill="#6366f1">A visitor connects over HTTPS</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">Route a request · 1/8</text><text x="60" y="370" font-size="12.5" class="dg-text">The listener on port 443 uses an ACM certificate to decrypt the request.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1161;0.2321" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#6366f1"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="349" font-size="14" font-weight="800" fill="#6366f1">/api/orders matches the /api/* rule</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">Route a request · 2/8</text><text x="60" y="370" font-size="12.5" class="dg-text">Rules are checked in priority order. This one forwards to lab-api-tg.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2321;0.3661" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#6366f1"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="349" font-size="14" font-weight="800" fill="#6366f1">A healthy API target answers</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">Route a request · 3/8</text><text x="60" y="370" font-size="12.5" class="dg-text">lab-api-tg picks api-2 in AZ b, and the reply goes back to the visitor.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3661;0.4821" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#6366f1"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="349" font-size="14" font-weight="800" fill="#6366f1">Everything else goes to lab-web-tg</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">Route a request · 4/8</text><text x="60" y="370" font-size="12.5" class="dg-text">/ matches no rule, so the listener&#x27;s default action forwards it.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4821;0.6161" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#6366f1"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="349" font-size="14" font-weight="800" fill="#6366f1">web-1 in AZ a answers this one</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">Route a request · 5/8</text><text x="60" y="370" font-size="12.5" class="dg-text">Requests are spread over the healthy targets in both AZs.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6161;0.7411" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#e11d48"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="349" font-size="14" font-weight="800" fill="#e11d48">The ALB health-checks every target</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">Health checks · 6/8</text><text x="60" y="370" font-size="12.5" class="dg-text">At a fixed interval it calls each target&#x27;s health check path. All answer.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7411;0.8661" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#e11d48"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="349" font-size="14" font-weight="800" fill="#e11d48">web-1 fails 2 checks in a row</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">Health checks · 7/8</text><text x="60" y="370" font-size="12.5" class="dg-text">It&#x27;s marked unhealthy and gets no new requests. It isn&#x27;t deleted.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8661" calcMode="discrete" dur="38.08s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#e11d48"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="349" font-size="14" font-weight="800" fill="#e11d48">Traffic flows around it</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">Health checks · 8/8</text><text x="60" y="370" font-size="12.5" class="dg-text">Requests for / now go only to web-2 in AZ b, until web-1 recovers.</text></g>
</svg>
```

```steps
#6366f1 | Route a request | A visitor connects over HTTPS | The listener on port 443 uses an ACM certificate to decrypt the request.
#6366f1 | Route a request | /api/orders matches the /api/* rule | Rules are checked in priority order. This one forwards to lab-api-tg.
#6366f1 | Route a request | A healthy API target answers | lab-api-tg picks api-2 in AZ b, and the reply goes back to the visitor.
#6366f1 | Route a request | Everything else goes to lab-web-tg | / matches no rule, so the listener's default action forwards it.
#6366f1 | Route a request | web-1 in AZ a answers this one | Requests are spread over the healthy targets in both AZs.
#e11d48 | Health checks | The ALB health-checks every target | At a fixed interval it calls each target's health check path. All answer.
#e11d48 | Health checks | web-1 fails 2 checks in a row | It's marked unhealthy and gets no new requests. It isn't deleted.
#e11d48 | Health checks | Traffic flows around it | Requests for / now go only to web-2 in AZ b, until web-1 recovers.
```

### What it gives you

```text
                 users
                   │  one address: my-alb-123.us-east-1.elb.amazonaws.com
                   ▼
          ┌──────────────────┐
          │  Load balancer   │   listener :80 / :443  →  rules  →  target group
          └───┬─────────┬────┘
   healthy ✓  │         │  ✓ healthy         ✗ unhealthy (skipped)
          ┌───▼───┐ ┌───▼───┐            ┌───────┐
          │ web-1 │ │ web-2 │            │ web-3 │
          │ AZ a  │ │ AZ b  │            │ AZ a  │
          └───────┘ └───────┘            └───────┘
```

- **High availability:** targets spread across Availability Zones, so one data center failing doesn't take the app down.
- **Health checks:** broken targets get no traffic.
- **Scaling:** add targets (by hand or with Auto Scaling) behind the same address.
- **Security:** only the load balancer is public; servers stay private, and HTTPS can be handled once at the load balancer.

### Key words

| Word | Simple meaning |
|---|---|
| **Listener** | The port and protocol the load balancer listens on, such as HTTP 80 or HTTPS 443 |
| **Rule** | "If the path is `/api/*`, send to the API servers" (ALB only) |
| **Target group** | A list of destinations plus a health check |
| **Target** | One destination: an EC2 instance, an IP address, a Lambda function, or another ALB |
| **Health check** | A regular test request; failing targets are taken out of rotation |
| **Internet-facing / internal** | Reachable from the internet, or only inside the VPC |
| **Layer 7 / Layer 4** | Understands HTTP (URLs, headers) / only sees TCP/UDP connections |

### Check yourself

1. Why don't users connect to the servers directly?
2. What happens to a target whose health check fails?
3. Which load balancer type understands URLs and paths?

> **Tip:** Answers: 1) One stable address, automatic failover, scaling and better security. 2) It stops receiving traffic until it's healthy again. 3) The Application Load Balancer (Layer 7).

## The four types compared

> **In simple words:** **ALB** for websites and APIs, **NLB** for raw speed, fixed IPs or non-HTTP traffic, **GWLB** for firewall appliances, and **Classic** only for old setups you haven't migrated yet.

| | **Application LB (ALB)** | **Network LB (NLB)** | **Gateway LB (GWLB)** | **Classic LB (CLB)** |
|---|---|---|---|---|
| Layer | 7 (HTTP/HTTPS, gRPC, WebSocket) | 4 (TCP, UDP, TLS) | 3 (IP packets, GENEVE) | 4 and 7 (basic) |
| Routing by path, host, header, query | **Yes** | No | No | No |
| Static IP / Elastic IP per AZ | No (DNS name only) | **Yes** | n/a | No |
| Keeps the client's source IP | Via the `X-Forwarded-For` header | **Yes**, by default for instance targets | Yes | Via proxy protocol |
| Performance | Very high | **Extreme**, millions of requests/sec, very low latency | High | Legacy |
| TLS / HTTPS termination | Yes | Yes (TLS listener) | No | Yes |
| Targets | Instances, IPs, Lambda | Instances, IPs, ALB | Appliance instances or IPs | Instances |
| Typical use | Websites, REST APIs, microservices, Kubernetes Ingress | Games, IoT, databases, gRPC/TCP services, needs a fixed IP, PrivateLink | Third-party firewalls and inspection appliances | Old EC2-Classic-era apps. **Avoid for new work** |

**How to choose:**

```text
 Is it HTTP/HTTPS and you want path/host routing or Lambda targets?   → ALB
 Need TCP/UDP, a static IP, extreme throughput, or PrivateLink?        → NLB
 Inserting a firewall / IDS appliance into network traffic?            → GWLB
 Building something new?                                               → never Classic
```

AWS docs: [What is Elastic Load Balancing?](https://docs.aws.amazon.com/elasticloadbalancing/latest/userguide/what-is-load-balancing.html) · [ALB](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html) · [NLB](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/introduction.html) · [GWLB](https://docs.aws.amazon.com/elasticloadbalancing/latest/gateway/introduction.html) · [Classic](https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/introduction.html)

## Prepare two web servers in two AZs

> **In simple words:** A load balancer needs something to balance. Launch two small web servers in different Availability Zones, each showing its own name, so you can see the traffic alternate.

```bash
export AWS_REGION=us-east-1
VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
read SUBNET_A SUBNET_B <<< $(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID Name=default-for-az,Values=true \
  --query 'Subnets[0:2].SubnetId' --output text)

# Security groups: the ALB accepts the internet; instances accept ONLY the ALB
ALB_SG=$(aws ec2 create-security-group --group-name lab-alb-sg --description "ALB" --vpc-id $VPC_ID --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $ALB_SG --protocol tcp --port 80  --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $ALB_SG --protocol tcp --port 443 --cidr 0.0.0.0/0

WEB_SG=$(aws ec2 create-security-group --group-name lab-web-sg --description "web behind ALB" --vpc-id $VPC_ID --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $WEB_SG --protocol tcp --port 80 --source-group $ALB_SG

cat > web-user-data.sh <<'EOF'
#!/bin/bash
dnf install -y nginx
TOKEN=$(curl -sX PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
md() { curl -sH "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/$1; }
echo "<h1>Hello from $(md instance-id) in $(md placement/availability-zone)</h1>" > /usr/share/nginx/html/index.html
mkdir -p /usr/share/nginx/html/api && echo '{"service":"api","host":"'$(md instance-id)'"}' > /usr/share/nginx/html/api/index.html
systemctl enable --now nginx
EOF

AMI_ID=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 --query Parameter.Value --output text)
for SUBNET in $SUBNET_A $SUBNET_B; do
  aws ec2 run-instances --image-id $AMI_ID --instance-type t3.micro --subnet-id $SUBNET \
    --security-group-ids $WEB_SG --user-data file://web-user-data.sh \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=lb-lab-web}]' \
    --query 'Instances[0].InstanceId' --output text
done
INSTANCES=$(aws ec2 describe-instances --filters Name=tag:Name,Values=lb-lab-web Name=instance-state-name,Values=pending,running \
  --query 'Reservations[].Instances[].InstanceId' --output text)
aws ec2 wait instance-running --instance-ids $INSTANCES
echo $INSTANCES
```

Notice the web servers' security group only allows port 80 **from the ALB's security group**. Nobody can bypass the load balancer.

## Build an Application Load Balancer

> **In simple words:** Four pieces, in order: a **target group** (who receives traffic and how to health-check them), the **load balancer** itself, a **listener** (which port to listen on), and the **targets** registered in the group.

```bash
# 1. Target group with a health check
TG_ARN=$(aws elbv2 create-target-group --name lab-web-tg --protocol HTTP --port 80 --vpc-id $VPC_ID \
  --target-type instance --health-check-path / --health-check-interval-seconds 15 \
  --healthy-threshold-count 2 --unhealthy-threshold-count 2 \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

# 2. Register the instances
aws elbv2 register-targets --target-group-arn $TG_ARN \
  --targets $(for i in $INSTANCES; do printf "Id=%s " $i; done)

# 3. The load balancer (internet-facing, two AZs)
read ALB_ARN ALB_DNS <<< $(aws elbv2 create-load-balancer --name web-alb --type application --scheme internet-facing \
  --subnets $SUBNET_A $SUBNET_B --security-groups $ALB_SG \
  --query 'LoadBalancers[0].[LoadBalancerArn,DNSName]' --output text)

# 4. Listener: HTTP 80 → forward to the target group
HTTP_LISTENER=$(aws elbv2 create-listener --load-balancer-arn $ALB_ARN --protocol HTTP --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN --query 'Listeners[0].ListenerArn' --output text)

aws elbv2 wait load-balancer-available --load-balancer-arns $ALB_ARN
aws elbv2 describe-target-health --target-group-arn $TG_ARN \
  --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State,TargetHealth.Reason]' --output table
```

When both targets show `healthy`:

```bash
for i in $(seq 6); do curl -s http://$ALB_DNS/; echo; done
# Hello from i-0aaa… in us-east-1a
# Hello from i-0bbb… in us-east-1b   ← requests alternate between servers
```

Now stop nginx on one instance (Session Manager: `sudo systemctl stop nginx`). Within about 30 seconds it turns `unhealthy`, and **all** traffic goes to the other server. Start it again, and it rejoins.

In the console, the same thing is **EC2 → Load Balancers → Create → Application Load Balancer**, filling in the same four pieces.

AWS docs: [Target groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html) · [Listeners](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-listeners.html)

## Path-based and host-based routing

> **In simple words:** One ALB can serve many apps. Rules look at the request (path `/api/*`, host `admin.example.com`, a header…) and send it to a different target group. Rules are checked in priority order, and the listener's **default action** handles everything else.

```bash
# A second target group for the "API" (here the same instances, serving /api/)
API_TG=$(aws elbv2 create-target-group --name lab-api-tg --protocol HTTP --port 80 --vpc-id $VPC_ID \
  --health-check-path /api/ --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 register-targets --target-group-arn $API_TG --targets $(for i in $INSTANCES; do printf "Id=%s " $i; done)

# Path rule: /api/* → API target group
aws elbv2 create-rule --listener-arn $HTTP_LISTENER --priority 10 \
  --conditions Field=path-pattern,Values='/api/*' \
  --actions Type=forward,TargetGroupArn=$API_TG

# Host rule: admin.example.com → fixed response (handy for maintenance pages)
aws elbv2 create-rule --listener-arn $HTTP_LISTENER --priority 20 \
  --conditions Field=host-header,Values='admin.example.com' \
  --actions '[{"Type":"fixed-response","FixedResponseConfig":{"StatusCode":"503","ContentType":"text/plain","MessageBody":"Admin is under maintenance"}}]'

curl -s http://$ALB_DNS/api/
curl -s -H "Host: admin.example.com" http://$ALB_DNS/
aws elbv2 describe-rules --listener-arn $HTTP_LISTENER --query 'Rules[].[Priority,Conditions[0].Field,Actions[0].Type]' --output table
```

| Condition | Example |
|---|---|
| `path-pattern` | `/api/*`, `/images/*` |
| `host-header` | `api.example.com`, `*.example.com` |
| `http-header` | `X-Canary: true` |
| `query-string` | `?version=2` |
| `http-request-method` | `POST` |
| `source-ip` | `203.0.113.0/24` |

| Action | Does |
|---|---|
| `forward` | Send to one target group, or **weighted** across several (canary releases) |
| `redirect` | Return 301/302 to another URL (e.g. HTTP → HTTPS) |
| `fixed-response` | Return a static status and body |
| `authenticate-oidc` / `authenticate-cognito` | Make users log in before reaching the app |

## HTTPS with a free ACM certificate

> **In simple words:** Add a port 443 listener with a certificate, and redirect plain HTTP to HTTPS. The servers behind the ALB can keep speaking plain HTTP inside the VPC.

You need a domain and an **issued ACM certificate in the same Region**. See the [Route 53 guide](#/tool/aws-route53), step "HTTPS certificates with ACM".

```bash
CERT_ARN=arn:aws:acm:us-east-1:111122223333:certificate/xxxx   # your issued certificate

HTTPS_LISTENER=$(aws elbv2 create-listener --load-balancer-arn $ALB_ARN --protocol HTTPS --port 443 \
  --certificates CertificateArn=$CERT_ARN --ssl-policy ELBSecurityPolicy-TLS13-1-2-2021-06 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN --query 'Listeners[0].ListenerArn' --output text)

# Redirect all HTTP to HTTPS
aws elbv2 modify-listener --listener-arn $HTTP_LISTENER --default-actions \
  '[{"Type":"redirect","RedirectConfig":{"Protocol":"HTTPS","Port":"443","StatusCode":"HTTP_301"}}]'
```

Then point your domain at the ALB with a Route 53 **alias** record, and open `https://your-domain`.

## Network Load Balancer example

> **In simple words:** An NLB passes TCP connections straight through, extremely fast, with **one fixed IP per AZ** that never changes. That's handy when a partner must allow-list your IP, or for non-HTTP protocols.

```bash
NLB_TG=$(aws elbv2 create-target-group --name lab-nlb-tg --protocol TCP --port 80 --vpc-id $VPC_ID \
  --target-type instance --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 register-targets --target-group-arn $NLB_TG --targets $(for i in $INSTANCES; do printf "Id=%s " $i; done)

NLB_SG=$(aws ec2 create-security-group --group-name lab-nlb-sg --description "NLB" --vpc-id $VPC_ID --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $NLB_SG --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $WEB_SG --protocol tcp --port 80 --source-group $NLB_SG

read NLB_ARN NLB_DNS <<< $(aws elbv2 create-load-balancer --name web-nlb --type network --scheme internet-facing \
  --subnets $SUBNET_A $SUBNET_B --security-groups $NLB_SG \
  --query 'LoadBalancers[0].[LoadBalancerArn,DNSName]' --output text)
aws elbv2 create-listener --load-balancer-arn $NLB_ARN --protocol TCP --port 80 \
  --default-actions Type=forward,TargetGroupArn=$NLB_TG
aws elbv2 wait load-balancer-available --load-balancer-arns $NLB_ARN

dig $NLB_DNS +short          # one static IP per AZ
curl -s http://$NLB_DNS/
```

- Use `--subnet-mappings SubnetId=…,AllocationId=eipalloc-…` to give each AZ **your own Elastic IP**.
- NLBs keep the **client's real IP** for instance targets. The server sees the user's address, not the load balancer's.
- A **TLS listener** on an NLB can terminate HTTPS too, without HTTP-level routing.

AWS docs: [NLB security groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/load-balancer-security-groups.html)

## Health checks, stickiness and other settings

> **In simple words:** A few target group settings decide how quickly bad servers are removed, whether a user keeps hitting the same server, and how gently servers are taken out during deployments.

| Setting | What it does | Good default |
|---|---|---|
| Health check path / port / codes | What "healthy" means, e.g. `GET /health` → `200` | A cheap endpoint that also checks dependencies lightly |
| Interval and thresholds | How fast unhealthy targets are detected | 15s interval, 2 healthy / 2 unhealthy |
| **Deregistration delay** | Time to finish in-flight requests before a target is removed | 30–60s (default 300s is often too slow for deployments) |
| **Stickiness** | Sends the same user to the same target (cookie) | Off, unless the app keeps session state in memory |
| **Cross-zone load balancing** | Spreads evenly across all targets in all AZs | On (always on for ALB; optional for NLB) |
| **Slow start** | Ramps traffic gradually to new targets | 30–60s for apps with cold caches |
| **Access logs** | Every request written to S3 | On in production |

```bash
aws elbv2 modify-target-group --target-group-arn $TG_ARN --health-check-path /health --matcher HttpCode=200
aws elbv2 modify-target-group-attributes --target-group-arn $TG_ARN --attributes \
  Key=deregistration_delay.timeout_seconds,Value=30 \
  Key=stickiness.enabled,Value=true Key=stickiness.type,Value=lb_cookie
```

AWS docs: [Health checks](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html)

## Load balancers with Auto Scaling, ECS and Kubernetes

> **In simple words:** In real setups you rarely register servers by hand. Auto Scaling groups, ECS services and Kubernetes controllers add and remove targets for you automatically.

| Platform | How targets get registered |
|---|---|
| **EC2 Auto Scaling group** | Pass `--target-group-arns` when creating the ASG. New instances join automatically, and failing ones are replaced |
| **ECS service** | `--load-balancers targetGroupArn=…,containerName=…,containerPort=…` (target type `ip` for Fargate). See the [ECS guide](#/tool/aws-ecs) |
| **EKS (Kubernetes)** | The **AWS Load Balancer Controller** creates an **ALB for each Ingress** and an **NLB for each Service** of `type: LoadBalancer` |

Kubernetes Ingress that becomes an ALB (with the controller installed):

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:111122223333:certificate/xxxx
    alb.ingress.kubernetes.io/ssl-redirect: "443"
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port:
                  number: 80
```

And a Service that becomes an NLB:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: tcp-app
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: external
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
spec:
  type: LoadBalancer
  selector:
    app: tcp-app
  ports:
    - port: 80
      targetPort: 8080
```

The controller needs AWS permissions through **Pod Identity or IRSA** (see the [IAM guide](#/tool/aws-iam)).

AWS docs: [AWS Load Balancer Controller](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html)

## Troubleshooting

> **In simple words:** The HTTP error code tells you where to look. **502/503/504** errors come from the load balancer and mean the problem is between it and your servers. Unhealthy targets explain most of them.

| Symptom | Meaning / fix |
|---|---|
| **503 Service Unavailable** | No healthy targets in the group, or no targets at all. Check `describe-target-health` |
| **502 Bad Gateway** | The target closed the connection or sent an invalid response. Check app logs, keep-alive timeouts and crashes |
| **504 Gateway Timeout** | The target didn't answer in time. A slow app or a blocked security group (ALB → target port) |
| Targets stuck `unhealthy` | Health check path returns non-200, the wrong port, or the **target's security group doesn't allow the LB** |
| `Target.Timeout` in health reason | Security group or NACL blocking. Allow the LB's security group on the target port |
| Can't reach the ALB at all | Its security group doesn't allow 80/443 from the internet, or it's `internal` |
| HTTPS listener fails to create | Certificate in a different Region, or not yet issued |
| Users lose their session | The app keeps sessions in memory. Enable stickiness, or better, store sessions in Redis or DynamoDB |

```bash
aws elbv2 describe-target-health --target-group-arn $TG_ARN --output table
aws elbv2 describe-load-balancers --names web-alb --query 'LoadBalancers[0].State'
aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name HTTPCode_ELB_5XX_Count \
  --dimensions Name=LoadBalancer,Value=$(echo $ALB_ARN | cut -d/ -f2-) \
  --start-time $(date -u -d '-1 hour' +%FT%TZ) --end-time $(date -u +%FT%TZ) --period 300 --statistics Sum
```

## Clean up

> **In simple words:** Delete in reverse order: load balancers (listeners and rules go with them), then target groups, instances and security groups. Load balancers bill every hour they exist.

```bash
aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN
aws elbv2 delete-load-balancer --load-balancer-arn $NLB_ARN
aws elbv2 wait load-balancers-deleted --load-balancer-arns $ALB_ARN $NLB_ARN
for tg in $TG_ARN $API_TG $NLB_TG; do aws elbv2 delete-target-group --target-group-arn $tg; done

aws ec2 terminate-instances --instance-ids $INSTANCES
aws ec2 wait instance-terminated --instance-ids $INSTANCES
for sg in $WEB_SG $ALB_SG $NLB_SG; do aws ec2 delete-security-group --group-id $sg; done

aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'   # should be empty
```

If a security group refuses to delete, wait a minute: the load balancer's network interfaces take a little while to disappear.

## Lab: highly available website

> **In simple words:** Practice time: build a two-AZ website behind an ALB with HTTPS, routing rules and a failure test.

1. Launch two web servers in two AZs whose security group allows port 80 **only** from the ALB.
2. Create an ALB with a target group and a health check on `/`. Refresh the DNS name and watch it alternate between servers.
3. Add a rule sending `/api/*` to a second target group.
4. Stop nginx on one server: it goes unhealthy and users see no errors. Start it again.
5. With a domain: request an ACM certificate, add an HTTPS listener, redirect HTTP → HTTPS, and create a Route 53 alias record.
6. Create an NLB for the same servers and note its static IPs with `dig`.
7. Explain in your own words when you'd choose ALB vs NLB vs GWLB.
8. Clean up everything.

### Cheat sheet

| Task | Command |
|---|---|
| Create target group | `aws elbv2 create-target-group --name tg --protocol HTTP --port 80 --vpc-id vpc` |
| Register targets | `aws elbv2 register-targets --target-group-arn TG --targets Id=i-1 Id=i-2` |
| Create ALB / NLB | `aws elbv2 create-load-balancer --name n --type application\|network --subnets s1 s2` |
| Listener | `aws elbv2 create-listener --load-balancer-arn LB --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=TG` |
| Path rule | `aws elbv2 create-rule --listener-arn L --priority 10 --conditions Field=path-pattern,Values='/api/*' --actions Type=forward,TargetGroupArn=TG2` |
| Target health | `aws elbv2 describe-target-health --target-group-arn TG` |
