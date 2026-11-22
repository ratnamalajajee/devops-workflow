# Monitoring Stack on EKS: Runbook

A copy-paste runbook for a complete monitoring stack on an EKS cluster: **metrics** with Prometheus, **logs** with Fluent Bit and Loki, **traces** with Jaeger, **database query metrics** with an SQL exporter, and **Grafana** on top for dashboards and email alerts, plus CloudWatch through an IAM role. The values files are the ones from a working setup, with only the project-specific values replaced, so you can download them, set a handful of values and install.

> **Note:** New to Prometheus and Grafana? Read [Prometheus and Grafana](#/tool/prometheus-grafana) first. It explains metrics, PromQL and alerts in simple words, and uses the all-in-one kube-prometheus-stack chart. This runbook installs each part as its own Helm chart instead, which is what the working setup uses.

## Start here: the monitoring stack in simple words

> **In simple words:** Three kinds of signals tell you how your apps are doing. **Metrics** are numbers over time (CPU, requests per second, slow queries): Prometheus collects them. **Logs** are the lines your apps print: Fluent Bit picks them up on every node and stores them in Loki. **Traces** follow one request through all your services: your apps send them to Jaeger. **Grafana** shows all three in one place, reads AWS metrics from CloudWatch, and emails you when something is wrong.

### Watch how it works

```svg Watch it work: logs going through Fluent Bit to Loki, Prometheus scraping metrics and slow database queries, traces reaching Jaeger, and Grafana bringing it all together with CloudWatch and email alerts. The animation loops.
<svg viewBox="0 0 600 506" role="img" data-anim="eks-monitoring-stack" data-dur="42.84" data-starts="0 4.42 8.84 13.94 19.04 23.46 28.56 33.32 38.08" aria-label="Animated monitoring stack on EKS. Logs: your app prints a log line, Fluent Bit on that node reads it and sends it to Loki with namespace, pod and container labels, and Loki keeps it for 30 days. Metrics: Prometheus scrapes annotated pods and Services, node-exporter and kube-state-metrics; the SQL exporter reads slow-query statistics from Aurora PostgreSQL and Prometheus scrapes it every 15 seconds. Traces: your app sends OpenTelemetry traces to Jaeger, which keeps them for 72 hours. See and alert: Grafana queries Loki, Prometheus and Jaeger, reads CloudWatch through an IAM role for its service account, you open it through an internal load balancer, and when an alert fires Grafana sends an email through Amazon SES.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<rect x="8" y="60" width="584" height="292" rx="12" class="dg-region"/>
<polyline points="77,117 350,117" fill="none" stroke-linejoin="round" stroke="#64748b" stroke-width="1.8" stroke-dasharray="4 3" stroke-opacity=".7"/>
<polyline points="350,117 506,117" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="1.6" stroke-opacity=".8"/>
<polyline points="77,212 350,212" fill="none" stroke-linejoin="round" stroke="#0d9488" stroke-width="1.8" stroke-dasharray="6 3" stroke-opacity=".7"/>
<polyline points="350,307 278,307 278,225 266,225" fill="none" stroke-linejoin="round" stroke="#0d9488" stroke-width="1.8" stroke-dasharray="6 3" stroke-opacity=".7"/>
<polyline points="350,392 350,307" fill="none" stroke-linejoin="round" stroke="#0d9488" stroke-width="1.8" stroke-dasharray="6 3" stroke-opacity=".7"/>
<polyline points="77,307 211,307" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="211,187 211,160 506,160" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="1.6" stroke-opacity=".8"/>
<polyline points="211,332 211,344 470,344 470,332" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="1.6" stroke-opacity=".8"/>
<polyline points="515,92 515,48" fill="none" stroke-linejoin="round" stroke="#eab308" stroke-width="1.8" stroke-dasharray="3 3" stroke-opacity=".75"/>
<polyline points="456,92 456,28 410,28" fill="none" stroke-linejoin="round" stroke="#db2777" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="512,332 512,370" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<rect x="14" y="67" width="266.4" height="18" rx="5" class="dg-box"/><text x="18" y="79" font-size="13" font-weight="800" fill="#f97316">EKS cluster · namespace monitoring</text>
<g><rect x="18" y="88" width="118" height="248" rx="12" fill="#10b981" fill-opacity=".18" stroke="#10b981" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1;0;1;0" keyTimes="0;0.1032;0.2063;0.3254;0.4444;0.5476" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/></rect><rect x="22" y="92" width="110" height="240" rx="9" class="dg-box" stroke="#10b981" stroke-width="2.2"/><text x="77" y="201" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Your apps</text><text x="77" y="216.5" text-anchor="middle" font-size="11" class="dg-muted">logs, metrics</text><text x="77" y="231.5" text-anchor="middle" font-size="11" class="dg-muted">and traces</text></g>
<g><rect x="152" y="88" width="118" height="58" rx="12" fill="#0ea5e9" fill-opacity=".18" stroke="#0ea5e9" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.2063" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/></rect><rect x="156" y="92" width="110" height="50" rx="9" class="dg-box" stroke="#0ea5e9" stroke-width="2.2"/><text x="211" y="113.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Fluent Bit</text><text x="211" y="129" text-anchor="middle" font-size="11" class="dg-muted">on every node</text></g>
<g><rect x="152" y="183" width="118" height="58" rx="12" fill="#e6522c" fill-opacity=".18" stroke="#e6522c" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.2063;0.4444;0.5476;0.6667" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/></rect><rect x="156" y="187" width="110" height="50" rx="9" class="dg-box" stroke="#e6522c" stroke-width="2.2"/><text x="211" y="208.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Prometheus</text><text x="211" y="224" text-anchor="middle" font-size="11" class="dg-muted">30 days</text></g>
<g><rect x="152" y="278" width="118" height="58" rx="12" fill="#7c3aed" fill-opacity=".18" stroke="#7c3aed" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4444;0.6667" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/></rect><rect x="156" y="282" width="110" height="50" rx="9" class="dg-box" stroke="#7c3aed" stroke-width="2.2"/><text x="211" y="303.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Jaeger</text><text x="211" y="319" text-anchor="middle" font-size="11" class="dg-muted">traces, 72 h</text></g>
<g><rect x="286" y="88" width="128" height="58" rx="12" fill="#ca8a04" fill-opacity=".18" stroke="#ca8a04" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.1032;0.2063;0.5476;0.6667" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/></rect><rect x="290" y="92" width="120" height="50" rx="9" class="dg-box" stroke="#ca8a04" stroke-width="2.2"/><text x="350" y="113.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Loki</text><text x="350" y="129" text-anchor="middle" font-size="11" class="dg-muted">logs, 30 days</text></g>
<g><rect x="286" y="178" width="128" height="68" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2063;0.3254" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/></rect><rect x="290" y="182" width="120" height="60" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="350" y="201" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Exporters</text><text x="350" y="216.5" text-anchor="middle" font-size="11" class="dg-muted">node-exporter</text><text x="350" y="231.5" text-anchor="middle" font-size="11" class="dg-muted">kube-state-metrics</text></g>
<g><rect x="286" y="278" width="128" height="58" rx="12" fill="#2563eb" fill-opacity=".18" stroke="#2563eb" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3254;0.4444" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/></rect><rect x="290" y="282" width="120" height="50" rx="9" class="dg-box" stroke="#2563eb" stroke-width="2.2"/><text x="350" y="303.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">SQL exporter</text><text x="350" y="319" text-anchor="middle" font-size="11" class="dg-muted">slow queries</text></g>
<g><rect x="430" y="88" width="152" height="248" rx="12" fill="#f46800" fill-opacity=".18" stroke="#f46800" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.5476" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/></rect><rect x="434" y="92" width="144" height="240" rx="9" class="dg-box" stroke="#f46800" stroke-width="2.2"/><text x="506" y="201" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Grafana</text><text x="506" y="216.5" text-anchor="middle" font-size="11" class="dg-muted">dashboards</text><text x="506" y="231.5" text-anchor="middle" font-size="11" class="dg-muted">and alerts</text></g>
<g><rect x="286" y="4" width="128" height="48" rx="12" fill="#db2777" fill-opacity=".18" stroke="#db2777" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8889" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/></rect><rect x="290" y="8" width="120" height="40" rx="9" class="dg-box" stroke="#db2777" stroke-width="2.2"/><text x="350" y="24.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Email</text><text x="350" y="40" text-anchor="middle" font-size="11" class="dg-muted">Amazon SES</text></g>
<g><rect x="448" y="4" width="134" height="48" rx="12" fill="#e7157b" fill-opacity=".18" stroke="#e7157b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6667;0.7778" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/></rect><rect x="452" y="8" width="126" height="40" rx="9" class="dg-box" stroke="#e7157b" stroke-width="2.2"/><text x="515" y="24.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">CloudWatch</text><text x="515" y="40" text-anchor="middle" font-size="11" class="dg-muted">IAM role (IRSA)</text></g>
<g><rect x="286" y="366" width="128" height="52" rx="12" fill="#1d4ed8" fill-opacity=".18" stroke="#1d4ed8" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3254;0.4444" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/></rect><rect x="290" y="370" width="120" height="44" rx="9" class="dg-box" stroke="#1d4ed8" stroke-width="2.2"/><text x="350" y="388.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Aurora / RDS</text><text x="350" y="404" text-anchor="middle" font-size="11" class="dg-muted">PostgreSQL</text></g>
<g><rect x="442" y="366" width="140" height="52" rx="12" fill="#6366f1" fill-opacity=".18" stroke="#6366f1" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7778;0.8889" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/></rect><rect x="446" y="370" width="132" height="44" rx="9" class="dg-box" stroke="#6366f1" stroke-width="2.2"/><text x="512" y="388.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">You</text><text x="512" y="404" text-anchor="middle" font-size="11" class="dg-muted">grafana.example.com</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6667;0.7778" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/><circle cx="578" cy="8" r="9.5" fill="#d97706" stroke="#fff" stroke-width="2"/><rect x="573.5" y="7" width="9" height="6.5" rx="1.2" fill="#fff"/><path d="M575.2,7 V5 A2.8,2.8 0 0 1 580.8,5 V7" fill="none" stroke="#fff" stroke-width="1.6"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0062;0.0887" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/><animateMotion path="M77,117 L211,117" keyPoints="0;0;1;1" keyTimes="0;0.0062;0.0887;1" calcMode="linear" dur="42.84s" repeatCount="indefinite"/><g><rect x="-8" y="-6" width="16" height="12" rx="2" fill="#64748b" stroke="#fff" stroke-width="1.6"/><path d="M-5,-2 H5 M-5,2 H3" stroke="#fff" stroke-width="1.4"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1094;0.1919" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/><animateMotion path="M211,117 L350,117" keyPoints="0;0;1;1" keyTimes="0;0.1094;0.1919;1" calcMode="linear" dur="42.84s" repeatCount="indefinite"/><g><rect x="-8" y="-6" width="16" height="12" rx="2" fill="#64748b" stroke="#fff" stroke-width="1.6"/><path d="M-5,-2 H5 M-5,2 H3" stroke="#fff" stroke-width="1.4"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2111;0.2563" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/><animateMotion path="M211,212 L77,212" keyPoints="0;0;1;1" keyTimes="0;0.2111;0.2563;1" calcMode="linear" dur="42.84s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2659;0.3159" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/><animateMotion path="M77,212 L211,212" keyPoints="0;0;1;1" keyTimes="0;0.2659;0.3159;1" calcMode="linear" dur="42.84s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2111;0.2563" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/><animateMotion path="M211,212 L350,212" keyPoints="0;0;1;1" keyTimes="0;0.2111;0.2563;1" calcMode="linear" dur="42.84s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2659;0.3159" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/><animateMotion path="M350,212 L211,212" keyPoints="0;0;1;1" keyTimes="0;0.2659;0.3159;1" calcMode="linear" dur="42.84s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3302;0.3754" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/><animateMotion path="M350,392 L350,307" keyPoints="0;0;1;1" keyTimes="0;0.3302;0.3754;1" calcMode="linear" dur="42.84s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3849;0.4349" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/><animateMotion path="M350,307 L278,307 L278,225 L211,225" keyPoints="0;0;1;1" keyTimes="0;0.3849;0.4349;1" calcMode="linear" dur="42.84s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4506;0.5332" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/><animateMotion path="M77,307 L211,307" keyPoints="0;0;1;1" keyTimes="0;0.4506;0.5332;1" calcMode="linear" dur="42.84s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5548;0.65" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/><animateMotion path="M350,117 L506,117" keyPoints="0;0;1;1" keyTimes="0;0.5548;0.65;1" calcMode="linear" dur="42.84s" repeatCount="indefinite"/><g><rect x="-8" y="-6" width="16" height="12" rx="2" fill="#64748b" stroke="#fff" stroke-width="1.6"/><path d="M-5,-2 H5 M-5,2 H3" stroke="#fff" stroke-width="1.4"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5548;0.65" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/><animateMotion path="M211,187 L211,160 L506,160" keyPoints="0;0;1;1" keyTimes="0;0.5548;0.65;1" calcMode="linear" dur="42.84s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5548;0.65" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/><animateMotion path="M211,332 L211,344 L470,344 L470,332" keyPoints="0;0;1;1" keyTimes="0;0.5548;0.65;1" calcMode="linear" dur="42.84s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6711;0.7133" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/><animateMotion path="M515,92 L515,28" keyPoints="0;0;1;1" keyTimes="0;0.6711;0.7133;1" calcMode="linear" dur="42.84s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7222;0.7689" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/><animateMotion path="M515,28 L515,92" keyPoints="0;0;1;1" keyTimes="0;0.7222;0.7689;1" calcMode="linear" dur="42.84s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7822;0.8244" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/><animateMotion path="M512,392 L512,212" keyPoints="0;0;1;1" keyTimes="0;0.7822;0.8244;1" calcMode="linear" dur="42.84s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8333;0.88" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/><animateMotion path="M512,212 L512,392" keyPoints="0;0;1;1" keyTimes="0;0.8333;0.88;1" calcMode="linear" dur="42.84s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8956;0.9844" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/><animateMotion path="M456,92 L456,28 L350,28" keyPoints="0;0;1;1" keyTimes="0;0.8956;0.9844;1" calcMode="linear" dur="42.84s" repeatCount="indefinite"/><g><rect x="-9" y="-6" width="18" height="12" rx="2" fill="#db2777" stroke="#fff" stroke-width="1.6"/><path d="M-8,-5 L0,1 L8,-5" fill="none" stroke="#fff" stroke-width="1.4"/></g></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(21.2,430.5) scale(.8)"><g><rect x="-8" y="-6" width="16" height="12" rx="2" fill="#64748b" stroke="#fff" stroke-width="1.6"/><path d="M-5,-2 H5 M-5,2 H3" stroke="#fff" stroke-width="1.4"/></g></g><text x="33.4" y="434">log line</text><g transform="translate(100.6,430.5) scale(.8)"><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g><text x="112" y="434">scrape</text><g transform="translate(168,430.5) scale(.8)"><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g><text x="179.4" y="434">metrics</text><g transform="translate(241,430.5) scale(.8)"><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g><text x="252.4" y="434">trace</text><g transform="translate(302.8,430.5) scale(.8)"><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g><text x="314.2" y="434">request</text><g transform="translate(375.8,430.5) scale(.8)"><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g><text x="387.2" y="434">reply</text><g transform="translate(439.2,430.5) scale(.8)"><g><rect x="-9" y="-6" width="18" height="12" rx="2" fill="#db2777" stroke="#fff" stroke-width="1.6"/><path d="M-8,-5 L0,1 L8,-5" fill="none" stroke="#fff" stroke-width="1.4"/></g></g><text x="452.2" y="434">email</text></g>
<rect x="12" y="446" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="446" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="42.84s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1032" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/><circle cx="36" cy="474" r="14" fill="#ca8a04"/><text x="36" y="479" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="469" font-size="14" font-weight="800" fill="#ca8a04">Your app prints a log line</text><text x="578" y="469" text-anchor="end" font-size="10.5" class="dg-muted">Logs · 1/9</text><text x="60" y="490" font-size="12.5" class="dg-text">Fluent Bit on that node reads it from /var/log/containers.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1032;0.2063" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/><circle cx="36" cy="474" r="14" fill="#ca8a04"/><text x="36" y="479" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="469" font-size="14" font-weight="800" fill="#ca8a04">Fluent Bit sends it to Loki</text><text x="578" y="469" text-anchor="end" font-size="10.5" class="dg-muted">Logs · 2/9</text><text x="60" y="490" font-size="12.5" class="dg-text">With namespace, pod and container labels. Loki keeps 30 days.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2063;0.3254" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/><circle cx="36" cy="474" r="14" fill="#e6522c"/><text x="36" y="479" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="469" font-size="14" font-weight="800" fill="#e6522c">Prometheus scrapes metrics</text><text x="578" y="469" text-anchor="end" font-size="10.5" class="dg-muted">Metrics · 3/9</text><text x="60" y="490" font-size="12.5" class="dg-text">From annotated pods and Services, node-exporter and kube-state-metrics.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3254;0.4444" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/><circle cx="36" cy="474" r="14" fill="#e6522c"/><text x="36" y="479" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="469" font-size="14" font-weight="800" fill="#e6522c">Slow database queries become metrics</text><text x="578" y="469" text-anchor="end" font-size="10.5" class="dg-muted">Metrics · 4/9</text><text x="60" y="490" font-size="12.5" class="dg-text">The SQL exporter reads Aurora&#x27;s statistics; Prometheus scrapes it every 15 s.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4444;0.5476" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/><circle cx="36" cy="474" r="14" fill="#7c3aed"/><text x="36" y="479" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="469" font-size="14" font-weight="800" fill="#7c3aed">Your app sends a trace</text><text x="578" y="469" text-anchor="end" font-size="10.5" class="dg-muted">Traces · 5/9</text><text x="60" y="490" font-size="12.5" class="dg-text">OpenTelemetry (OTLP) to Jaeger, which keeps each request&#x27;s path for 72 h.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5476;0.6667" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/><circle cx="36" cy="474" r="14" fill="#6366f1"/><text x="36" y="479" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="469" font-size="14" font-weight="800" fill="#6366f1">Grafana queries all three</text><text x="578" y="469" text-anchor="end" font-size="10.5" class="dg-muted">See and alert · 6/9</text><text x="60" y="490" font-size="12.5" class="dg-text">Loki for logs, Prometheus for metrics, Jaeger for traces, linked by trace ID.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6667;0.7778" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/><circle cx="36" cy="474" r="14" fill="#6366f1"/><text x="36" y="479" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="469" font-size="14" font-weight="800" fill="#6366f1">It reads CloudWatch with an IAM role</text><text x="578" y="469" text-anchor="end" font-size="10.5" class="dg-muted">See and alert · 7/9</text><text x="60" y="490" font-size="12.5" class="dg-text">IRSA gives Grafana short-lived, read-only CloudWatch and Logs access.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7778;0.8889" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/><circle cx="36" cy="474" r="14" fill="#6366f1"/><text x="36" y="479" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="469" font-size="14" font-weight="800" fill="#6366f1">You open grafana.example.com</text><text x="578" y="469" text-anchor="end" font-size="10.5" class="dg-muted">See and alert · 8/9</text><text x="60" y="490" font-size="12.5" class="dg-text">Through an internal ALB with your ACM certificate: everything in one place.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8889" calcMode="discrete" dur="42.84s" repeatCount="indefinite"/><circle cx="36" cy="474" r="14" fill="#6366f1"/><text x="36" y="479" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">9</text><text x="60" y="469" font-size="14" font-weight="800" fill="#6366f1">An alert fires and you get an email</text><text x="578" y="469" text-anchor="end" font-size="10.5" class="dg-muted">See and alert · 9/9</text><text x="60" y="490" font-size="12.5" class="dg-text">For example a pod crash-looping for 5 minutes, sent through Amazon SES.</text></g>
</svg>
```

```steps
#ca8a04 | Logs | Your app prints a log line | Fluent Bit on that node reads it from /var/log/containers.
#ca8a04 | Logs | Fluent Bit sends it to Loki | With namespace, pod and container labels. Loki keeps 30 days.
#e6522c | Metrics | Prometheus scrapes metrics | From annotated pods and Services, node-exporter and kube-state-metrics.
#e6522c | Metrics | Slow database queries become metrics | The SQL exporter reads Aurora's statistics; Prometheus scrapes it every 15 s.
#7c3aed | Traces | Your app sends a trace | OpenTelemetry (OTLP) to Jaeger, which keeps each request's path for 72 h.
#6366f1 | See and alert | Grafana queries all three | Loki for logs, Prometheus for metrics, Jaeger for traces, linked by trace ID.
#6366f1 | See and alert | It reads CloudWatch with an IAM role | IRSA gives Grafana short-lived, read-only CloudWatch and Logs access.
#6366f1 | See and alert | You open grafana.example.com | Through an internal ALB with your ACM certificate: everything in one place.
#6366f1 | See and alert | An alert fires and you get an email | For example a pod crash-looping for 5 minutes, sent through Amazon SES.
```

### What gets installed

Everything runs in the `monitoring` namespace. The versions are the ones the working setup was tested with.

| Release | Chart | Version | What it does | Keeps data |
|---|---|---|---|---|
| `prometheus` | prometheus-community/prometheus | 27.50.1 | Metrics: scrapes Kubernetes, nodes, pods and services; evaluates alert rules. Includes node-exporter, kube-state-metrics and Pushgateway | 30 days, 50 GiB disk |
| `grafana` | grafana/grafana | 10.5.15 | Dashboards, Explore, alerting, email through Amazon SES; reads CloudWatch with an IAM role | 20 GiB disk |
| `loki` | grafana/loki | 6.55.0 | Log store, one pod (SingleBinary) | 30 days, 50 GiB disk |
| `fluent-bit` | fluent/fluent-bit | 0.58.1 | Log collector, one pod per node; sends container and kubelet logs to Loki | Nothing (forwards) |
| `jaeger` | jaegertracing/jaeger | 4.x | Traces: receives OpenTelemetry (OTLP) and stores them | 72 hours, 20 GiB disk |
| `sql-exporter` | burningalchemist/sql-exporter | 0.18.x | Turns slow, long-running and blocked PostgreSQL queries into metrics | Nothing (Prometheus keeps them) |

### How they connect

```text
 your pods ──stdout──▶ Fluent Bit (every node) ──▶ Loki ─────────────┐
 your pods ◀─scrape── Prometheus ◀─scrape── node-exporter, KSM        │
                          ▲ scrape (15 s)                             ├──▶ Grafana ──▶ you (internal ALB, HTTPS)
                          └── SQL exporter ──▶ Aurora / RDS PostgreSQL│         ├──▶ CloudWatch (IAM role, IRSA)
 your pods ──OTLP──▶ Jaeger ──────────────────────────────────────────┘         └──▶ email (Amazon SES)
```

## Before you start

> **In simple words:** The stack needs a working EKS cluster with a few add-ons: a way to create disks, a way to create load balancers, and an identity provider so pods can use IAM roles. You also need a certificate and DNS name for Grafana, and an email sender in Amazon SES.

### What you need

| Need | Why | How to check | Set it up |
|---|---|---|---|
| EKS cluster, `kubectl` pointed at it | Everything installs into it | `kubectl get nodes` | [EKS cluster runbook](#/tool/eks-cluster) |
| Helm 3 or later | Installs the charts | `helm version` | [Workstation setup](#/tool/setup) |
| EBS CSI driver and a storage class | Prometheus, Grafana, Loki and Jaeger keep data on disks | `kubectl get storageclass` | [EKS runbook: EBS CSI driver](#/tool/eks-cluster/install-the-ebs-csi-driver-block-storage) |
| AWS Load Balancer Controller | Creates the internal ALB for Grafana | `kubectl -n kube-system get deploy aws-load-balancer-controller` | [EKS runbook: Load Balancer Controller](#/tool/eks-cluster/install-the-aws-load-balancer-controller) |
| IAM OIDC provider for the cluster | Lets Grafana's pod use an IAM role (IRSA) | `aws iam list-open-id-connect-providers` | `eksctl utils associate-iam-oidc-provider --cluster $CLUSTER_NAME --approve` |
| ACM certificate and a DNS name | HTTPS for `grafana.example.com` | `aws acm list-certificates` | [Route 53 and ACM](#/tool/aws-route53/https-certificates-with-acm-and-dns-validation) |
| Amazon SES sender and SMTP credentials | Alert emails | SES console → Identities | [SNS and SES guide](#/tool/aws-sns-ses) |
| Aurora or RDS PostgreSQL (optional) | Only for the SQL exporter | | [RDS guide](#/tool/aws-rds) |

### Set your values once

```bash
export AWS_REGION=us-east-1                        # CHANGE
export CLUSTER_NAME=my-cluster                     # CHANGE: your EKS cluster
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export MON_URL=https://devops-workflow.pages.dev/assets/monitoring

aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
kubectl config current-context                     # make sure it's the right cluster
```

### Download the files

```bash
mkdir -p ~/monitoring/dashboards && cd ~/monitoring
for f in prometheus-values.yaml grafana-values.yaml loki-values.yaml fluent-bit-values.yaml \
         jaeger-values.yaml jaeger-badger-pvc.yaml sql-exporter-values.yaml \
         grafana-cloudwatch-trust-policy.json grafana-cloudwatch-policy.json; do
  curl -fsSLO "$MON_URL/$f"
done
for f in cluster-logs-loki.json aurora-long-running-queries.json; do
  curl -fsSL -o "dashboards/$f" "$MON_URL/dashboards/$f"
done
ls -1
```

Every value you must change is marked `CHANGE` or `REPLACE_WITH_…`. See them all at once:

```bash
grep -n "CHANGE\|REPLACE_WITH\|my-eks-qa" *.yaml
```

Two quick changes you'll almost always make:

```bash
# 1. A name for this cluster; Prometheus adds it to every metric as tenant="..."
sed -i "s/my-eks-qa/$CLUSTER_NAME/g" prometheus-values.yaml

# 2. The storage class. The working setup uses gp2; newer clusters often only have gp3.
kubectl get storageclass
sed -i 's/: gp2 /: gp3 /' *.yaml                    # only if you have no gp2
```

> **Tip:** On a Mac, write `sed -i ''` instead of `sed -i`. Keep the edited files in Git (without secrets) so the next setup is a copy, not a rewrite.

## Step 1: Add the Helm repositories

> **In simple words:** Helm downloads charts from repositories. Add the five repositories once, refresh them, and create the namespace everything goes into.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add fluent https://fluent.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo add burningalchemist https://burningalchemist.github.io/sql_exporter
helm repo update

kubectl create namespace monitoring
```

Check which versions are available before you pin a different one:

```bash
helm search repo prometheus-community/prometheus --versions | head -5
```

## Step 2: Prometheus for metrics

> **In simple words:** Prometheus visits a list of addresses every minute and stores the numbers it finds there. The values file tells it what to visit: the Kubernetes API, every node, every container, and any pod or Service that asks to be scraped with an annotation. It also holds the alert rules, keeps 30 days of data, and stops at 45 GB so the 50 GiB disk never fills up.

### What it scrapes

| Job | What it scrapes | How often | How a target opts in |
|---|---|---|---|
| `prometheus` | Prometheus itself | 1 min | Always |
| `kubernetes-apiservers` | The Kubernetes API server | 1 min | Always |
| `kubernetes-nodes` | The kubelet on every node | 1 min | Always |
| `kubernetes-nodes-cadvisor` | CPU and memory of every container | 1 min | Always |
| `kubernetes-service-endpoints` | Services, including node-exporter and kube-state-metrics | 1 min | Service annotation `prometheus.io/scrape: "true"` |
| `kubernetes-service-endpoints-fast` | Services that need detail | **15 s** | Also `prometheus.io/scrape_fast: "true"` |
| `kubernetes-service-endpoints-slow` | Expensive Services | 5 min | `prometheus.io/scrape_slow: "true"` |
| `kubernetes-pods` | Pods | 1 min | Pod annotation `prometheus.io/scrape: "true"` |
| `kubernetes-pods-slow` | Expensive pods | 5 min | `prometheus.io/scrape_slow: "true"` |
| `prometheus-pushgateway` | Pushgateway, where batch jobs push their metrics | 1 min | Comes with the chart |
| `kubernetes-services` | HTTP checks through a blackbox exporter | 1 min | `prometheus.io/probe: "true"` (needs a blackbox exporter, not installed here) |

Every series also gets the label `tenant="<your cluster name>"`, so one Grafana can tell several clusters apart.

**Let Prometheus find your app.** Add annotations to its Service (or pod):

```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8000"           # the port that serves metrics
    prometheus.io/path: "/metrics"       # default is /metrics
    # prometheus.io/scrape_fast: "true"  # every 15 s instead of every minute
```

### The alert rules

| Alert | Fires when | For | Severity |
|---|---|---|---|
| `KubePodCrashLooping` | A container is in CrashLoopBackOff | 5 min | warning |
| `KubePodNotReady` | A pod stays Pending or Unknown | 10 min | warning |
| `KubePodOOMKilled` | A container was killed for using too much memory | at once | critical |
| `KubePodFrequentRestarts` | More than 5 restarts in 15 minutes | 5 min | warning |
| `KubeHPAMaxedOut` | An autoscaler runs at 90% or more of its maximum | 5 min | warning |

How these alerts reach you is covered in [Step 9: alerts and email](#/tool/eks-monitoring-stack/step-9-alerts-and-email).

### The values file

Download: [prometheus-values.yaml](https://devops-workflow.pages.dev/assets/monitoring/prometheus-values.yaml)

```yaml
# Prometheus for EKS: metrics, scrape jobs and alert rules.
# Chart: prometheus-community/prometheus 27.50.1
#   helm upgrade --install prometheus prometheus-community/prometheus --version 27.50.1 \
#     -n monitoring --create-namespace -f prometheus-values.yaml
# Before you use it:
#   - replace my-eks-qa with a name for this cluster (added to every metric as tenant=...)
#   - check every line marked CHANGE
# Images come from the chart defaults. To use a private mirror, set image.registry/repository/tag
# on server, configmapReload.prometheus, kube-state-metrics, prometheus-node-exporter and
# prometheus-pushgateway.
#
alertmanager:
  enabled: false              # true = Prometheus alert rules are emailed (needs the SMTP secret)
  persistence:
    size: 2Gi
    storageClass: gp2                   # CHANGE: kubectl get storageclass
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 100m
      memory: 128Mi
  extraSecretMounts:
    - name: smtp-credentials
      mountPath: /etc/alertmanager/secrets/smtp
      secretName: alertmanager-smtp-credentials
      readOnly: true
  config:
    global:
      smtp_smarthost: 'email-smtp.us-east-1.amazonaws.com:587'   # CHANGE: your SES Region
      smtp_from: 'alerts@example.com'          # CHANGE: an SES-verified sender
      smtp_auth_username: 'REPLACE_WITH_SES_SMTP_USERNAME'   # CHANGE: from SES > SMTP settings
      smtp_auth_password_file: '/etc/alertmanager/secrets/smtp/smtp-password'
      smtp_require_tls: true
    route:
      receiver: email-alerts
      group_by: ['alertname', 'namespace']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 3h
    receivers:
      - name: email-alerts
        email_configs:
          - to: 'oncall@example.com'           # CHANGE: comma-separated list
            send_resolved: true
configmapReload:
  prometheus:
    enabled: true
    name: configmap-reload
kube-state-metrics:
  enabled: true
  resources: {}
prometheus-node-exporter:
  enabled: true
prometheus-pushgateway:
  enabled: true
server:
  persistentVolume:
    accessModes:
    - ReadWriteOnce
    enabled: true
    size: 50Gi
    storageClass: gp2                   # CHANGE: kubectl get storageclass
  resources:
    limits:
      cpu: 1000m
      memory: 4Gi
    requests:
      cpu: 500m
      memory: 2Gi
  retention: 30d
  retentionSize: 45GB
serverFiles:
  alerting_rules.yml:
    groups:
    - name: pod-health
      rules:
      - alert: KubePodCrashLooping
        expr: kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"} == 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash looping"
          description: "Container {{ $labels.container }} in pod {{ $labels.namespace }}/{{ $labels.pod }} has been in CrashLoopBackOff for more than 5 minutes."
      - alert: KubePodNotReady
        expr: kube_pod_status_phase{phase=~"Pending|Unknown"} == 1
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} not ready"
          description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} has been in phase {{ $labels.phase }} for more than 10 minutes."
      - alert: KubePodOOMKilled
        expr: kube_pod_container_status_last_terminated_reason{reason="OOMKilled"} == 1
        labels:
          severity: critical
        annotations:
          summary: "Container {{ $labels.container }} in {{ $labels.namespace }}/{{ $labels.pod }} was OOMKilled"
          description: "Container {{ $labels.container }} in pod {{ $labels.namespace }}/{{ $labels.pod }} was killed due to an out-of-memory condition."
      - alert: KubePodFrequentRestarts
        expr: increase(kube_pod_container_status_restarts_total[15m]) > 5
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.container }} in {{ $labels.namespace }}/{{ $labels.pod }} restarting frequently"
          description: "Container {{ $labels.container }} in pod {{ $labels.namespace }}/{{ $labels.pod }} has restarted {{ $value }} times in the last 15 minutes."
    - name: hpa-saturation
      rules:
      - alert: KubeHPAMaxedOut
        expr: kube_horizontalpodautoscaler_status_current_replicas / kube_horizontalpodautoscaler_spec_max_replicas >= 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "HPA {{ $labels.namespace }}/{{ $labels.horizontalpodautoscaler }} near max replicas"
          description: "HPA {{ $labels.namespace }}/{{ $labels.horizontalpodautoscaler }} is running at {{ $value | humanizePercentage }} of its max replica count."
  prometheus.yml:
    scrape_configs:
    - job_name: prometheus
      static_configs:
      - labels:
          tenant: my-eks-qa
        targets:
        - localhost:9090
    - bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
      job_name: kubernetes-apiservers
      kubernetes_sd_configs:
      - role: endpoints
      relabel_configs:
      - replacement: my-eks-qa
        target_label: tenant
      - action: keep
        regex: default;kubernetes;https
        source_labels:
        - __meta_kubernetes_namespace
        - __meta_kubernetes_service_name
        - __meta_kubernetes_endpoint_port_name
      scheme: https
      tls_config:
        ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    - bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
      job_name: kubernetes-nodes
      kubernetes_sd_configs:
      - role: node
      relabel_configs:
      - replacement: my-eks-qa
        target_label: tenant
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)
      - replacement: kubernetes.default.svc:443
        target_label: __address__
      - regex: (.+)
        replacement: /api/v1/nodes/$1/proxy/metrics
        source_labels:
        - __meta_kubernetes_node_name
        target_label: __metrics_path__
      scheme: https
      tls_config:
        ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    - bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
      job_name: kubernetes-nodes-cadvisor
      kubernetes_sd_configs:
      - role: node
      relabel_configs:
      - replacement: my-eks-qa
        target_label: tenant
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)
      - replacement: kubernetes.default.svc:443
        target_label: __address__
      - regex: (.+)
        replacement: /api/v1/nodes/$1/proxy/metrics/cadvisor
        source_labels:
        - __meta_kubernetes_node_name
        target_label: __metrics_path__
      scheme: https
      tls_config:
        ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    - honor_labels: true
      job_name: kubernetes-service-endpoints
      kubernetes_sd_configs:
      - role: endpoints
      relabel_configs:
      - replacement: my-eks-qa
        target_label: tenant
      - action: keep
        regex: true
        source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_scrape
      - action: drop
        regex: true
        source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_scrape_slow
      - action: drop
        regex: true
        source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_scrape_fast
      - action: replace
        regex: (https?)
        source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_scheme
        target_label: __scheme__
      - action: replace
        regex: (.+)
        source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_path
        target_label: __metrics_path__
      - action: replace
        regex: (.+?)(?::\d+)?;(\d+)
        replacement: $1:$2
        source_labels:
        - __address__
        - __meta_kubernetes_service_annotation_prometheus_io_port
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_service_annotation_prometheus_io_param_(.+)
        replacement: __param_$1
      - action: labelmap
        regex: __meta_kubernetes_service_label_(.+)
      - action: replace
        source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - action: replace
        source_labels:
        - __meta_kubernetes_service_name
        target_label: service
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_node_name
        target_label: node
    - honor_labels: true
      job_name: kubernetes-service-endpoints-fast
      kubernetes_sd_configs:
      - role: endpoints
      scrape_interval: 15s
      relabel_configs:
      - replacement: my-eks-qa
        target_label: tenant
      - action: keep
        regex: true
        source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_scrape_fast
      - action: replace
        regex: (https?)
        source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_scheme
        target_label: __scheme__
      - action: replace
        regex: (.+)
        source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_path
        target_label: __metrics_path__
      - action: replace
        regex: (.+?)(?::\d+)?;(\d+)
        replacement: $1:$2
        source_labels:
        - __address__
        - __meta_kubernetes_service_annotation_prometheus_io_port
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_service_annotation_prometheus_io_param_(.+)
        replacement: __param_$1
      - action: labelmap
        regex: __meta_kubernetes_service_label_(.+)
      - action: replace
        source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - action: replace
        source_labels:
        - __meta_kubernetes_service_name
        target_label: service
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_node_name
        target_label: node
    - honor_labels: true
      job_name: kubernetes-service-endpoints-slow
      kubernetes_sd_configs:
      - role: endpoints
      relabel_configs:
      - replacement: my-eks-qa
        target_label: tenant
      - action: keep
        regex: true
        source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_scrape_slow
      - action: replace
        regex: (https?)
        source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_scheme
        target_label: __scheme__
      - action: replace
        regex: (.+)
        source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_path
        target_label: __metrics_path__
      - action: replace
        regex: (.+?)(?::\d+)?;(\d+)
        replacement: $1:$2
        source_labels:
        - __address__
        - __meta_kubernetes_service_annotation_prometheus_io_port
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_service_annotation_prometheus_io_param_(.+)
        replacement: __param_$1
      - action: labelmap
        regex: __meta_kubernetes_service_label_(.+)
      - action: replace
        source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - action: replace
        source_labels:
        - __meta_kubernetes_service_name
        target_label: service
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_node_name
        target_label: node
      scrape_interval: 5m
      scrape_timeout: 30s
    - honor_labels: true
      job_name: prometheus-pushgateway
      kubernetes_sd_configs:
      - role: service
      relabel_configs:
      - replacement: my-eks-qa
        target_label: tenant
      - action: keep
        regex: pushgateway
        source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_probe
    - honor_labels: true
      job_name: kubernetes-services
      kubernetes_sd_configs:
      - role: service
      metrics_path: /probe
      params:
        module:
        - http_2xx
      relabel_configs:
      - replacement: my-eks-qa
        target_label: tenant
      - action: keep
        regex: true
        source_labels:
        - __meta_kubernetes_service_annotation_prometheus_io_probe
      - source_labels:
        - __address__
        target_label: __param_target
      - replacement: blackbox
        target_label: __address__
      - source_labels:
        - __param_target
        target_label: instance
      - action: labelmap
        regex: __meta_kubernetes_service_label_(.+)
      - source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: service
    - honor_labels: true
      job_name: kubernetes-pods
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - replacement: my-eks-qa
        target_label: tenant
      - action: keep
        regex: true
        source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_scrape
      - action: drop
        regex: true
        source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_scrape_slow
      - action: replace
        regex: (https?)
        source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_scheme
        target_label: __scheme__
      - action: replace
        regex: (.+)
        source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_path
        target_label: __metrics_path__
      - action: replace
        regex: (\d+);(([A-Fa-f0-9]{1,4}::?){1,7}[A-Fa-f0-9]{1,4})
        replacement: '[$2]:$1'
        source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_port
        - __meta_kubernetes_pod_ip
        target_label: __address__
      - action: replace
        regex: (\d+);((([0-9]+?)(\.|$)){4})
        replacement: $2:$1
        source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_port
        - __meta_kubernetes_pod_ip
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_annotation_prometheus_io_param_(.+)
        replacement: __param_$1
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - action: replace
        source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_name
        target_label: pod
      - action: drop
        regex: Pending|Succeeded|Failed|Completed
        source_labels:
        - __meta_kubernetes_pod_phase
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_node_name
        target_label: node
    - honor_labels: true
      job_name: kubernetes-pods-slow
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - replacement: my-eks-qa
        target_label: tenant
      - action: keep
        regex: true
        source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_scrape_slow
      - action: replace
        regex: (https?)
        source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_scheme
        target_label: __scheme__
      - action: replace
        regex: (.+)
        source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_path
        target_label: __metrics_path__
      - action: replace
        regex: (\d+);(([A-Fa-f0-9]{1,4}::?){1,7}[A-Fa-f0-9]{1,4})
        replacement: '[$2]:$1'
        source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_port
        - __meta_kubernetes_pod_ip
        target_label: __address__
      - action: replace
        regex: (\d+);((([0-9]+?)(\.|$)){4})
        replacement: $2:$1
        source_labels:
        - __meta_kubernetes_pod_annotation_prometheus_io_port
        - __meta_kubernetes_pod_ip
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_annotation_prometheus_io_param_(.+)
        replacement: __param_$1
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - action: replace
        source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_name
        target_label: pod
      - action: drop
        regex: Pending|Succeeded|Failed|Completed
        source_labels:
        - __meta_kubernetes_pod_phase
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_node_name
        target_label: node
      scrape_interval: 5m
      scrape_timeout: 30s
serviceAccounts:
  server:
    name: amp-iamproxy-ingest-service-account
```

The server's service account is called `amp-iamproxy-ingest-service-account`, the name AWS uses for sending metrics to Amazon Managed Service for Prometheus. Nothing is sent there with this file; the name just lets you add `remote_write` later without renaming.

### Install and check

```bash
helm upgrade --install prometheus prometheus-community/prometheus --version 27.50.1 \
  -n monitoring -f prometheus-values.yaml

kubectl -n monitoring get pods
# prometheus-server-…            2/2 Running   (server + config reloader)
# prometheus-kube-state-metrics-… 1/1 Running
# prometheus-prometheus-node-exporter-… one per node
# prometheus-prometheus-pushgateway-…

kubectl -n monitoring port-forward svc/prometheus-server 9090:80
```

Open `http://localhost:9090` → **Status → Target health**: the jobs above should be `UP`. In **Query**, try `up == 0` (anything that can't be scraped) and `count by (job) (up)`.

## Step 3: Grafana for dashboards

> **In simple words:** Grafana is the window onto everything. The values file connects it to Prometheus, Loki and Jaeger from the start, sends email through Amazon SES, gives its pod an IAM role for CloudWatch, keeps its settings on a disk, and puts it behind an **internal** load balancer, so only people inside your network or VPN can open it.

### What's in the values file

| Setting | Why |
|---|---|
| `datasources` | Prometheus (default), Loki and Jaeger are added automatically. Log lines with `trace_id=…` link to the trace in Jaeger, and traces link back to their logs |
| `smtp` and `grafana.ini.smtp` | Email through Amazon SES. The SMTP user and password come from the Secret `grafana-smtp-credentials` |
| `unified_alerting` | Grafana's own alerting, with contact points and notification policies |
| `serviceAccount.annotations` | The IAM role Grafana uses to read CloudWatch (Step 4) |
| `strategy: Recreate` | The disk can be attached to only one pod. Recreate stops the old pod before starting the new one, so upgrades don't get stuck |
| `ingress` | An internal ALB with your ACM certificate; health check on `/login`; 300 s idle timeout for long queries |
| `persistence` | 20 GiB disk for Grafana's database: dashboards, users, alert rules |

Download: [grafana-values.yaml](https://devops-workflow.pages.dev/assets/monitoring/grafana-values.yaml)

```yaml
# Grafana for EKS: data sources (Prometheus, Loki, Jaeger), email through Amazon SES,
# an IAM role for CloudWatch, and an internal ALB.
# Chart: grafana/grafana 10.5.15
#   helm upgrade --install grafana grafana/grafana --version 10.5.15 -n monitoring -f grafana-values.yaml
# Needs first: the Secret grafana-smtp-credentials (keys user, password) and the IAM role
# grafana-cloudwatch-role. Check every line marked CHANGE.
#
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: Loki
      type: loki
      uid: loki
      access: proxy
      url: http://loki-gateway.monitoring.svc.cluster.local:80
      jsonData:
        maxLines: 1000
        derivedFields:
          - datasourceUid: jaeger
            matcherRegex: 'trace_id=(\w+)'
            name: TraceID
            url: '$${__value.raw}'
    - name: Prometheus
      type: prometheus
      access: proxy
      isDefault: true
      url: http://prometheus-server.monitoring.svc.cluster.local   # <release>-server; the release is "prometheus"
    - name: Jaeger
      type: jaeger
      uid: jaeger
      access: proxy
      url: http://jaeger.monitoring.svc.cluster.local:16686
      jsonData:
        tracesToLogsV2:
          datasourceUid: loki
          filterByTraceID: false
          filterBySpanID: false
          customQuery: true
          query: '{job="fluentbit"} | json | line_format "{{.log}}" |~ "$${__trace.traceId}"'
smtp:
  existingSecret: grafana-smtp-credentials
  userKey: user
  passwordKey: password
grafana.ini:
  smtp:
    enabled: true
    host: 'email-smtp.us-east-1.amazonaws.com:587'   # CHANGE: your SES Region
    from_address: 'alerts@example.com'          # CHANGE: an SES-verified sender
    from_name: 'Grafana Alerts'
    startTLS_policy: 'MandatoryStartTLS'
  unified_alerting:
    enabled: true
autoscaling:
  behavior: {}
  enabled: false
  maxReplicas: 20
  minReplicas: 2
  targetCPU: "65"
  targetMemory: "65"
headlessService: false
serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::REPLACE_WITH_ACCOUNT_ID:role/grafana-cloudwatch-role   # CHANGE
strategy:
  type: Recreate               # the disk is ReadWriteOnce: stop the old pod before the new one starts
ingress:
  annotations:
    alb.ingress.kubernetes.io/certificate-arn: REPLACE_WITH_ACM_CERTIFICATE_ARN   # CHANGE: one ARN, or several comma-separated
    alb.ingress.kubernetes.io/group.name: REPLACE_WITH_ALB_GROUP_NAME   # optional: share one internal ALB; delete the line for its own ALB
    alb.ingress.kubernetes.io/healthcheck-path: /login
    alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=300
    alb.ingress.kubernetes.io/scheme: internal
    alb.ingress.kubernetes.io/target-type: ip
    kubernetes.io/ingress.class: alb
  enabled: true
  hosts:
  - grafana.example.com                  # CHANGE: your Grafana hostname
  path: /
  pathType: Prefix
persistence:
  accessModes:
  - ReadWriteOnce
  enabled: true
  size: 20Gi
  storageClassName: gp2                 # CHANGE: kubectl get storageclass
  type: pvc
replicas: 1
resources:
  limits:
    cpu: 1000m
    memory: 1.5Gi
  requests:
    cpu: 500m
    memory: 500Mi
service:
  type: NodePort
```

### Create the email secret, then install

Create SMTP credentials in the **SES console → SMTP settings → Create SMTP credentials**. The username looks like an access key; keep both values only in this Secret, never in a values file.

```bash
read -rp  "SES SMTP username: " SMTP_USER
read -rsp "SES SMTP password: " SMTP_PASS; echo
kubectl -n monitoring create secret generic grafana-smtp-credentials \
  --from-literal=user="$SMTP_USER" --from-literal=password="$SMTP_PASS"

sed -i "s/REPLACE_WITH_ACCOUNT_ID/$ACCOUNT_ID/" grafana-values.yaml
grep -n "REPLACE_WITH\|CHANGE" grafana-values.yaml       # certificate ARN, ALB group, hostname, sender

helm upgrade --install grafana grafana/grafana --version 10.5.15 -n monitoring -f grafana-values.yaml
kubectl -n monitoring rollout status deploy/grafana
```

### Sign in

```bash
kubectl -n monitoring get secret grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo   # user: admin
kubectl -n monitoring get ingress grafana          # ADDRESS = the internal ALB's DNS name
```

Point `grafana.example.com` at that address with an alias record in your **private** hosted zone (see [Route 53 alias records](#/tool/aws-route53/alias-records-point-names-at-aws-resources)). Until DNS is ready, use `kubectl -n monitoring port-forward svc/grafana 3000:80` and open `http://localhost:3000`.

> **Warning:** Change the admin password after the first sign-in (or create named users and disable the admin login). Everyone who can sign in can see all logs, including any secrets an app prints.

## Step 4: Let Grafana read CloudWatch

> **In simple words:** Grafana needs to read AWS metrics (RDS, load balancers, and so on) and CloudWatch Logs. Instead of storing an AWS key, its Kubernetes service account gets an **IAM role** (IRSA): AWS gives the pod short-lived credentials, and only for read-only CloudWatch and Logs calls.

The trust policy says "only the `grafana` service account in the `monitoring` namespace of this cluster may use this role". Fill it in from your cluster's OIDC issuer:

```bash
OIDC_PROVIDER=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION \
  --query 'cluster.identity.oidc.issuer' --output text | sed 's|^https://||')
sed -e "s|ACCOUNT_ID|$ACCOUNT_ID|" -e "s|OIDC_PROVIDER|$OIDC_PROVIDER|g" \
  grafana-cloudwatch-trust-policy.json > trust-policy.json
cat trust-policy.json

aws iam create-role --role-name grafana-cloudwatch-role --assume-role-policy-document file://trust-policy.json
aws iam put-role-policy --role-name grafana-cloudwatch-role --policy-name grafana-cloudwatch-read \
  --policy-document file://grafana-cloudwatch-policy.json
```

Download: [grafana-cloudwatch-trust-policy.json](https://devops-workflow.pages.dev/assets/monitoring/grafana-cloudwatch-trust-policy.json) · [grafana-cloudwatch-policy.json](https://devops-workflow.pages.dev/assets/monitoring/grafana-cloudwatch-policy.json)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/OIDC_PROVIDER"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "OIDC_PROVIDER:sub": "system:serviceaccount:monitoring:grafana",
          "OIDC_PROVIDER:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:DescribeAlarmsForMetric",
        "cloudwatch:DescribeAlarmHistory",
        "cloudwatch:DescribeAlarms",
        "cloudwatch:ListMetrics",
        "cloudwatch:GetMetricData",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:GetInsightRuleReport",
        "tag:GetResources",
        "logs:DescribeLogGroups",
        "logs:GetLogGroupFields",
        "logs:StartQuery",
        "logs:StopQuery",
        "logs:GetQueryResults",
        "logs:GetLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
```

The service account already carries the role's ARN (from the values file), so nothing needs restarting. If you add or change that annotation later, restart Grafana: `kubectl -n monitoring rollout restart deploy/grafana`.

**Add the data source:** Grafana → **Connections → Data sources → Add → CloudWatch**. Authentication provider **AWS SDK Default**, default Region your Region → **Save & test**. To keep it in code instead, add this to the `datasources` list in `grafana-values.yaml` and run the `helm upgrade` again:

```yaml
    - name: CloudWatch
      type: cloudwatch
      jsonData:
        authType: default
        defaultRegion: us-east-1          # CHANGE
```

## Step 5: Logs with Loki and Fluent Bit

> **In simple words:** Every container writes its logs to a file on its node. **Fluent Bit** runs on every node (a DaemonSet), reads those files and the kubelet's own logs, adds the namespace, pod and container names, and sends them to **Loki**. Loki stores them for 30 days, and Grafana searches them.

Download: [loki-values.yaml](https://devops-workflow.pages.dev/assets/monitoring/loki-values.yaml) · [fluent-bit-values.yaml](https://devops-workflow.pages.dev/assets/monitoring/fluent-bit-values.yaml)

```yaml
# Loki for EKS: one Loki pod (SingleBinary) with a 50 GiB disk, 30 days of logs.
# Chart: grafana/loki 6.55.0
#   helm upgrade --install loki grafana/loki --version 6.55.0 -n monitoring -f loki-values.yaml
# Grafana and Fluent Bit talk to the service loki-gateway.
#
deploymentMode: SingleBinary

loki:
  auth_enabled: false
  commonConfig:
    replication_factor: 1
  storage:
    type: filesystem
  schemaConfig:
    configs:
      - from: "2024-01-01"
        store: tsdb
        object_store: filesystem
        schema: v13
        index:
          prefix: loki_index_
          period: 24h
  limits_config:
    reject_old_samples: true
    reject_old_samples_max_age: 168h
    retention_period: 720h
    volume_enabled: true
  compactor:
    retention_enabled: true
    delete_request_store: filesystem

read:
  replicas: 0
write:
  replicas: 0
backend:
  replicas: 0

singleBinary:
  replicas: 1
  persistence:
    enabled: true
    storageClass: gp2                 # CHANGE: kubectl get storageclass
    size: 50Gi
    accessModes:
      - ReadWriteOnce
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1000m
      memory: 2Gi

gateway:
  enabled: true

test:
  enabled: false
lokiCanary:
  enabled: false
minio:
  enabled: false
chunksCache:
  enabled: false
resultsCache:
  enabled: false
```

```yaml
# Fluent Bit for EKS: a DaemonSet on every node; container logs and kubelet logs to Loki.
# Chart: fluent/fluent-bit 0.58.1
#   helm upgrade --install fluent-bit fluent/fluent-bit --version 0.58.1 -n monitoring -f fluent-bit-values.yaml
#
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi

tolerations:
  - operator: Exists
    effect: NoSchedule
  - operator: Exists
    effect: NoExecute

config:
  service: |
    [SERVICE]
        Daemon Off
        Flush {{ .Values.flush }}
        Log_Level {{ .Values.logLevel }}
        Parsers_File /fluent-bit/etc/parsers.conf
        Parsers_File /fluent-bit/etc/conf/custom_parsers.conf
        HTTP_Server On
        HTTP_Listen 0.0.0.0
        HTTP_Port {{ .Values.metricsPort }}
        Health_Check On

  inputs: |
    [INPUT]
        Name tail
        Path /var/log/containers/*.log
        multiline.parser docker, cri
        Tag kube.*
        Mem_Buf_Limit 5MB
        Skip_Long_Lines On

    [INPUT]
        Name systemd
        Tag host.*
        Systemd_Filter _SYSTEMD_UNIT=kubelet.service
        Read_From_Tail On

  filters: |
    [FILTER]
        Name kubernetes
        Match kube.*
        Merge_Log On
        Keep_Log Off
        K8S-Logging.Parser On
        K8S-Logging.Exclude On

  outputs: |
    [OUTPUT]
        Name loki
        Match kube.*
        Host loki-gateway.monitoring.svc.cluster.local
        Port 80
        Labels job=fluentbit
        Label_Keys $kubernetes['namespace_name'],$kubernetes['pod_name'],$kubernetes['container_name']
        Remove_Keys kubernetes,stream
        Line_Format json

    [OUTPUT]
        Name loki
        Match host.*
        Host loki-gateway.monitoring.svc.cluster.local
        Port 80
        Labels job=fluentbit,log_type=host
        Line_Format json

  customParsers: |
    [PARSER]
        Name docker_no_time
        Format json
        Time_Keep Off
        Time_Key time
        Time_Format %Y-%m-%dT%H:%M:%S.%L
```

| Setting | Why |
|---|---|
| Loki `deploymentMode: SingleBinary` | One Loki pod does everything; simple and enough for one cluster's logs. The read, write and backend parts are set to 0 replicas |
| Loki `retention_period: 720h` | Keep 30 days; the compactor deletes older chunks |
| Loki `reject_old_samples_max_age: 168h` | Refuse lines older than 7 days (for example when an old log file is re-read) |
| Fluent Bit `tolerations` | Run on every node, even tainted ones, so no node's logs are missed |
| Fluent Bit `tail` input | Reads `/var/log/containers/*.log` (docker and cri formats) |
| Fluent Bit `systemd` input | Also ships the kubelet's logs, with the label `log_type=host` |
| Fluent Bit `loki` outputs | Labels `job=fluentbit` plus namespace, pod and container names |

```bash
helm upgrade --install loki grafana/loki --version 6.55.0 -n monitoring -f loki-values.yaml
helm upgrade --install fluent-bit fluent/fluent-bit --version 0.58.1 -n monitoring -f fluent-bit-values.yaml

kubectl -n monitoring get pods -l app.kubernetes.io/name=loki     # loki-0 Running
kubectl -n monitoring get ds fluent-bit                           # DESIRED = READY = number of nodes
```

**Check:** Grafana → **Explore** → data source **Loki** → `{job="fluentbit"}` shows lines from all namespaces; `{job="fluentbit", namespace_name="monitoring"}` shows only that namespace. Import the **Cluster Logs (Loki)** dashboard in [Step 8](#/tool/eks-monitoring-stack/step-8-import-the-dashboards).

## Step 6: Traces with Jaeger

> **In simple words:** A trace is the story of one request: which services it went through and how long each one took. Your apps send traces with **OpenTelemetry** (OTLP) to Jaeger. Jaeger keeps them for 72 hours on its own disk, and Grafana can jump from a slow trace to that request's log lines.

Download: [jaeger-badger-pvc.yaml](https://devops-workflow.pages.dev/assets/monitoring/jaeger-badger-pvc.yaml) · [jaeger-values.yaml](https://devops-workflow.pages.dev/assets/monitoring/jaeger-values.yaml)

```yaml
# Disk for Jaeger's Badger storage. Create it before installing Jaeger.
#
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jaeger-badger-data
  namespace: monitoring
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp2                 # CHANGE: kubectl get storageclass
  resources:
    requests:
      storage: 20Gi
```

```yaml
# Jaeger v2 for EKS: receives OTLP traces (4317 gRPC, 4318 HTTP), keeps them 72 h on a Badger disk.
# Chart: jaegertracing/jaeger 4.x (pin the version you test; see the guide)
#   kubectl apply -f jaeger-badger-pvc.yaml
#   helm upgrade --install jaeger jaegertracing/jaeger --version 4.16.1 -n monitoring -f jaeger-values.yaml
#
jaeger:
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
  extraVolumes:
    - name: badger-data
      persistentVolumeClaim:
        claimName: jaeger-badger-data
  extraVolumeMounts:
    - name: badger-data
      mountPath: /badger

userconfig:
  service:
    extensions: [jaeger_storage, jaeger_query, healthcheckv2]
    pipelines:
      traces:
        receivers: [otlp]
        processors: [batch]
        exporters: [jaeger_storage_exporter]
    telemetry:
      resource:
        service.name: jaeger
      metrics:
        level: detailed
        readers:
          - pull:
              exporter:
                prometheus:
                  host: 0.0.0.0
                  port: 8888
      logs:
        level: info
  extensions:
    healthcheckv2:
      use_v2: true
      http: {}
    jaeger_query:
      storage:
        traces: primary_store
    jaeger_storage:
      backends:
        primary_store:
          badger:
            directories:
              keys: "/badger/keys"
              values: "/badger/values"
            ephemeral: false
            ttl:
              spans: 72h
  receivers:
    otlp:
      protocols:
        grpc: {}
        http: {}
  processors:
    batch: {}
  exporters:
    jaeger_storage_exporter:
      trace_storage: primary_store
```

The values use the **Jaeger v2** format (built on the OpenTelemetry Collector), which needs chart **4.x**. The working setup's notes don't record the exact chart version: 4.16.1 is the latest at the time of writing. Run `helm ls -n monitoring` on an existing cluster to see what it runs, and pin that.

```bash
kubectl apply -f jaeger-badger-pvc.yaml
helm upgrade --install jaeger jaegertracing/jaeger --version 4.16.1 -n monitoring -f jaeger-values.yaml

kubectl -n monitoring get pods,svc | grep jaeger
kubectl -n monitoring port-forward svc/jaeger 16686:16686          # Jaeger UI: http://localhost:16686
```

**Send traces from your app.** Most OpenTelemetry SDKs read these variables:

```yaml
env:
  - name: OTEL_SERVICE_NAME
    value: orders-service                                          # CHANGE: your service name
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: http://jaeger.monitoring.svc.cluster.local:4318         # OTLP over HTTP (gRPC is 4317)
```

**Logs ↔ traces:** if your app prints the trace ID in its log lines as `trace_id=<id>`, Grafana shows a **TraceID** link next to that line (the `derivedFields` setting in the Loki data source). From a trace, **Logs for this span** runs a Loki search for that trace ID (the `tracesToLogsV2` setting).

## Step 7: Database query metrics with the SQL exporter

> **In simple words:** CloudWatch tells you the database is busy, but not **which query** is the problem. The SQL exporter connects to Aurora or RDS PostgreSQL every 15 seconds, asks PostgreSQL's own statistics views, and turns the answers into metrics: queries running longer than 5 seconds, the slowest queries on average, the queries using the most time in total, and queries blocked by another session.

### Prepare the database

`pg_stat_statements` must be loaded and created. On Aurora and RDS PostgreSQL it's usually in `shared_preload_libraries` already; check, then create the extension and a read-only monitoring user:

```sql
SHOW shared_preload_libraries;                       -- should include pg_stat_statements
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;   -- in the database you want to watch
CREATE USER sql_exporter WITH PASSWORD 'CHANGE_ME';
GRANT pg_monitor TO sql_exporter;                    -- read all sessions and query statistics
```

If `pg_stat_statements` is missing from the list, add it to the DB **cluster parameter group** and reboot the writer during a quiet time.

The exporter's pod must reach the database on port 5432: allow the EKS nodes' (or pods') security group in the database's security group.

### Store the connection string, then install

```bash
read -rsp "Password for sql_exporter: " DB_PASS; echo
DB_HOST=my-aurora.cluster-abc123.us-east-1.rds.amazonaws.com     # CHANGE: cluster (writer) or reader endpoint
kubectl -n monitoring create secret generic sql-exporter-aurora-dsn \
  --from-literal=dsn="postgres://sql_exporter:${DB_PASS}@${DB_HOST}:5432/appdb?sslmode=require"
```

A password with special characters (`@`, `/`, `:`, `?`, `#`) must be URL-encoded in the DSN.

Download: [sql-exporter-values.yaml](https://devops-workflow.pages.dev/assets/monitoring/sql-exporter-values.yaml)

```yaml
# SQL exporter for Aurora / RDS PostgreSQL: long-running, slowest, costliest and blocked queries.
# Chart: burningalchemist/sql-exporter 0.18.x (pin the version you test; see the guide)
#   helm upgrade --install sql-exporter burningalchemist/sql-exporter --version 0.18.15 -n monitoring -f sql-exporter-values.yaml
# Needs first: the Secret sql-exporter-aurora-dsn (key dsn) and pg_stat_statements on the database.
# Prometheus scrapes it every 15 s through the prometheus.io/scrape_fast annotation.
#
image:
  repository: burningalchemist/sql_exporter

service:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/scrape_fast: "true"
    prometheus.io/port: "9399"

serviceMonitor:
  enabled: false

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi

env:
  SQLEXPORTER_TARGET_DSN:
    from:
      kind: Secret
      name: sql-exporter-aurora-dsn
      key: dsn

config:
  global:
    scrape_timeout: 10s
    max_connections: 3
    max_idle_connections: 3

  target:
    data_source_name: '${SQLEXPORTER_TARGET_DSN}'
    collectors:
      - collector_long_running_queries
      - collector_query_stats
      - collector_query_stats_by_total_time
      - collector_blocking_queries

  collectors:
    - collector_name: collector_long_running_queries
      metrics:
        - metric_name: sql_long_running_query_duration_seconds
          type: gauge
          help: 'Duration in seconds of currently running queries, only queries active for more than 5 seconds are included'
          key_labels:
            - "pid"
            - "usename"
            - "datname"
            - "application_name"
            - "state"
            - "client_ip"
            - "query"
          values:
            - "duration_seconds"
          query_ref: long_running_queries
      queries:
        - query_name: long_running_queries
          query: |
            SELECT
              pid,
              usename,
              datname,
              COALESCE(application_name, '') AS application_name,
              state,
              COALESCE(client_addr::text, '') AS client_ip,
              EXTRACT(EPOCH FROM (now() - query_start))::float AS duration_seconds,
              LEFT(query, 200) AS query
            FROM pg_stat_activity
            WHERE state != 'idle'
              AND query_start IS NOT NULL
              AND pid != pg_backend_pid()
              AND now() - query_start > interval '5 seconds'
            ORDER BY duration_seconds DESC
            LIMIT 10;

    - collector_name: collector_query_stats
      metrics:
        - metric_name: sql_query_mean_exec_time_ms
          type: gauge
          help: 'Mean execution time in milliseconds for this query since stats were last reset (requires pg_stat_statements)'
          key_labels:
            - "queryid"
            - "query"
          values:
            - "mean_exec_time_ms"
          query_ref: query_stats
        - metric_name: sql_query_calls_total
          type: gauge
          help: 'Number of times this query has been executed since stats were last reset (requires pg_stat_statements)'
          key_labels:
            - "queryid"
            - "query"
          values:
            - "calls"
          query_ref: query_stats
        - metric_name: sql_query_max_exec_time_ms
          type: gauge
          help: 'Maximum execution time in milliseconds observed for this query (requires pg_stat_statements)'
          key_labels:
            - "queryid"
            - "query"
          values:
            - "max_exec_time_ms"
          query_ref: query_stats
      queries:
        - query_name: query_stats
          query: |
            SELECT
              queryid::text AS queryid,
              LEFT(query, 200) AS query,
              calls,
              round(mean_exec_time::numeric, 2) AS mean_exec_time_ms,
              round(max_exec_time::numeric, 2) AS max_exec_time_ms
            FROM pg_stat_statements
            WHERE mean_exec_time > 100
            ORDER BY mean_exec_time DESC
            LIMIT 20;

    - collector_name: collector_query_stats_by_total_time
      metrics:
        - metric_name: sql_query_total_exec_time_seconds
          type: gauge
          help: 'Total cumulative execution time in seconds across all calls to this query since stats were last reset (requires pg_stat_statements) - identifies queries costing the most overall DB load, not just the slowest per-call'
          key_labels:
            - "queryid"
            - "query"
          values:
            - "total_time_seconds"
          query_ref: query_stats_by_total_time
        - metric_name: sql_query_by_total_time_calls_total
          type: gauge
          help: 'Number of times this query has been executed since stats were last reset (requires pg_stat_statements)'
          key_labels:
            - "queryid"
            - "query"
          values:
            - "calls"
          query_ref: query_stats_by_total_time
        - metric_name: sql_query_by_total_time_rows_total
          type: gauge
          help: 'Total number of rows returned/affected across all calls to this query (requires pg_stat_statements)'
          key_labels:
            - "queryid"
            - "query"
          values:
            - "rows"
          query_ref: query_stats_by_total_time
      queries:
        - query_name: query_stats_by_total_time
          query: |
            SELECT
              queryid::text AS queryid,
              LEFT(query, 200) AS query,
              calls,
              rows,
              round((total_exec_time / 1000)::numeric, 2) AS total_time_seconds
            FROM pg_stat_statements
            ORDER BY total_exec_time DESC
            LIMIT 10;

    - collector_name: collector_blocking_queries
      metrics:
        - metric_name: sql_blocking_query_duration_seconds
          type: gauge
          help: 'Duration in seconds that a query has been blocked waiting on another session'
          key_labels:
            - "blocked_pid"
            - "blocked_user"
            - "blocking_pid"
            - "blocking_user"
            - "blocked_statement"
            - "blocking_statement"
          values:
            - "blocked_duration_seconds"
          query_ref: blocking_queries
      queries:
        - query_name: blocking_queries
          query: |
            SELECT
              blocked_activity.pid AS blocked_pid,
              blocked_activity.usename AS blocked_user,
              blocking_activity.pid AS blocking_pid,
              blocking_activity.usename AS blocking_user,
              LEFT(blocked_activity.query, 150) AS blocked_statement,
              LEFT(blocking_activity.query, 150) AS blocking_statement,
              EXTRACT(EPOCH FROM (now() - blocked_activity.query_start))::float AS blocked_duration_seconds
            FROM pg_catalog.pg_locks blocked_locks
            JOIN pg_catalog.pg_stat_activity blocked_activity
              ON blocked_activity.pid = blocked_locks.pid
            JOIN pg_catalog.pg_locks blocking_locks
              ON blocking_locks.locktype = blocked_locks.locktype
              AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
              AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
              AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
              AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
              AND blocking_locks.pid != blocked_locks.pid
              AND blocking_locks.granted
            JOIN pg_catalog.pg_stat_activity blocking_activity
              ON blocking_activity.pid = blocking_locks.pid
            WHERE NOT blocked_locks.granted;
```

| Metric | What it tells you |
|---|---|
| `sql_long_running_query_duration_seconds` | Queries running for more than 5 s right now (top 10), with user, database, client and the first 200 characters of the query |
| `sql_query_mean_exec_time_ms`, `sql_query_max_exec_time_ms`, `sql_query_calls_total` | The 20 slowest queries on average (mean over 100 ms) |
| `sql_query_total_exec_time_seconds` | The 10 queries that cost the database the most time in total |
| `sql_blocking_query_duration_seconds` | Sessions waiting for a lock, and who holds it |

```bash
helm upgrade --install sql-exporter burningalchemist/sql-exporter --version 0.18.15 \
  -n monitoring -f sql-exporter-values.yaml

kubectl -n monitoring port-forward svc/sql-exporter 9399:9399 &
curl -s localhost:9399/metrics | grep '^sql_' | head
```

As with Jaeger, the notes don't record the chart version: 0.18.15 is current at the time of writing. The Service carries `prometheus.io/scrape_fast: "true"`, so Prometheus collects it every 15 seconds with no extra setup. In Prometheus, `sql_long_running_query_duration_seconds` should appear within a minute.

> **Warning:** These metrics contain the start of each query's text and database user names. Anyone who can open Grafana can read them, so never put secrets inside SQL literals.

## Step 8: Import the dashboards

> **In simple words:** A dashboard is a saved page of graphs. Import a JSON file (or a grafana.com ID), pick which data source it should use, and it's ready. Keep the JSON files in Git so the next cluster gets the same dashboards in minutes.

| Dashboard | Data source | Get it |
|---|---|---|
| **Cluster Logs (Loki)**: log volume by namespace, and logs filtered by namespace, pod, container and text | Loki | [cluster-logs-loki.json](https://devops-workflow.pages.dev/assets/monitoring/dashboards/cluster-logs-loki.json) |
| **Aurora Postgres - Long Running Queries**: running-now, slowest, costliest and blocking queries | Prometheus | [aurora-long-running-queries.json](https://devops-workflow.pages.dev/assets/monitoring/dashboards/aurora-long-running-queries.json) |
| **AWS RDS**: CPU, connections, IOPS, latency, storage from CloudWatch | CloudWatch | grafana.com dashboard **707**, by Monitoring Artist |
| **Kubernetes overviews**: cluster, nodes, Deployments, pods, Services, StatefulSets | Prometheus | Export them from your Grafana and keep them in Git, or start from a community Kubernetes dashboard on grafana.com |

**Import a JSON file:** Grafana → **Dashboards → New → Import** → **Upload dashboard JSON file** → choose the data source when it asks (`DS_LOKI` or `DS_PROMETHEUS`) → **Import**.

**Import by ID:** same page, type `707` in **Find and import dashboards**, **Load**, pick the CloudWatch data source.

**Export one to keep:** open the dashboard → **Share → Export** → turn on **Export for sharing externally** → **Save to file**. "Externally" replaces your data source IDs with inputs, so the file works in any Grafana.

## Step 9: Alerts and email

> **In simple words:** The alert rules from Step 2 run inside Prometheus. To turn a firing alert into an email you need a sender: either Prometheus's **Alertmanager**, or **Grafana's own alerting**. Both send through Amazon SES. The working setup has Grafana's email ready and the Alertmanager settings prepared but switched off.

### Where alerts are today

- Prometheus evaluates the rules: see **Alerts** at `http://localhost:9090` (port-forward from Step 2).
- Grafana shows them under **Alerting → Alert rules** (as data source-managed rules).
- With `alertmanager.enabled: false`, nothing is emailed for these rules yet.

### Option A: turn on Alertmanager (emails for the Prometheus rules)

The values file already has the route (group by alert name and namespace; repeat every 3 hours) and an email receiver with `send_resolved: true`. Give it the SMTP password, fill in the sender, SMTP username and recipients, and switch it on:

```bash
kubectl -n monitoring create secret generic alertmanager-smtp-credentials \
  --from-literal=smtp-password="$SMTP_PASS"

# in prometheus-values.yaml: alertmanager.enabled: true, smtp_from, smtp_auth_username, to
helm upgrade --install prometheus prometheus-community/prometheus --version 27.50.1 \
  -n monitoring -f prometheus-values.yaml
kubectl -n monitoring get pods | grep alertmanager                  # prometheus-alertmanager-0 Running
```

### Option B: Grafana-managed alerts

SMTP is already set up in Grafana (Step 3). Go to **Alerting → Contact points → Add**: type **Email**, your team's addresses, **Test**. Then **Alerting → Alert rules → New** on any Prometheus, Loki or CloudWatch query, and point the **notification policy** at that contact point. This also covers things Prometheus doesn't see, such as an RDS CPU alarm from CloudWatch or "more than 50 ERROR lines in 5 minutes" from Loki.

### Test it

```bash
kubectl run crashme --image=busybox:1.36 --restart=Always -- sh -c 'exit 1'
# after about 5 minutes: KubePodCrashLooping fires
kubectl delete pod crashme                                          # then you get the "resolved" email
```

> **Note:** A new SES account starts in the **sandbox**: it can only send to verified addresses. Verify your test recipients, or request production access in the SES console.

## Verify the whole stack

> **In simple words:** Check each part once, from the bottom up: pods and disks, then each data source in Grafana, then a real query against each one. Ten minutes now saves a confusing incident later.

```bash
kubectl -n monitoring get pods                   # all Running, READY n/n
kubectl -n monitoring get pvc                    # all Bound: prometheus-server, grafana, storage-loki-0, jaeger-badger-data
kubectl -n monitoring get ingress grafana        # ADDRESS filled in
helm ls -n monitoring                            # the six releases and their chart versions
```

| Check | Where | Expected |
|---|---|---|
| Prometheus targets | Prometheus → Status → Target health | Kubernetes jobs `UP` |
| Data sources | Grafana → Connections → Data sources → each → **Save & test** | Prometheus, Loki, Jaeger and CloudWatch all succeed |
| Metrics | Explore → Prometheus → `sum by (namespace) (kube_pod_info)` | Pod count per namespace |
| Logs | Explore → Loki → `{job="fluentbit"}` | Recent lines |
| Traces | Explore → Jaeger → Search | Your services (after an app sends traces) |
| Database | Explore → Prometheus → `sql_query_calls_total` | Query statistics |
| Email | Alerting → Contact points → Test | An email arrives |

## Day-2: upgrades, disks and images

> **In simple words:** Keep the values files and versions in Git. Upgrading is the same `helm upgrade --install` command with a new `--version`; rolling back is `helm rollback`. Watch the disks, because a full disk stops Prometheus or Loki from storing anything.

**Upgrade one part:**

```bash
helm search repo grafana/grafana --versions | head -5               # read the chart's release notes first
helm upgrade --install grafana grafana/grafana --version <new> -n monitoring -f grafana-values.yaml
helm history grafana -n monitoring
helm rollback grafana <revision> -n monitoring                      # if something breaks
```

**Disks and retention:**

| Part | Disk | Limit in the values | If it fills |
|---|---|---|---|
| Prometheus | 50 GiB | `retention: 30d`, `retentionSize: 45GB` (whichever comes first) | Raise both, or drop high-cardinality metrics |
| Loki | 50 GiB | `retention_period: 720h` | Lower retention or grow the disk |
| Grafana | 20 GiB | Dashboards and settings only | Rarely an issue |
| Jaeger | 20 GiB | `ttl.spans: 72h` | Lower the TTL, or sample fewer traces in the apps |

To grow a disk, the storage class needs `allowVolumeExpansion: true`. Then raise the size in the values file and run `helm upgrade`, or `kubectl -n monitoring edit pvc <name>` for disks a chart doesn't manage.

**Private image registry:** if the cluster can't pull from public registries, copy the images to your own ECR (for example with ECR pull-through cache, see the [ECR guide](#/tool/aws-ecr/pull-through-cache-and-replication)), then set `image.registry`, `image.repository` and `image.tag` for each component. The comment at the top of `prometheus-values.yaml` lists which ones.

## Troubleshooting

> **In simple words:** Most problems are one of four things: a disk that can't be created, a pod that can't reach another service, a permission that's missing, or an email that SES refuses. Start with `kubectl -n monitoring get pods,pvc` and the logs of whatever isn't Ready.

| What you see | Likely cause | Fix |
|---|---|---|
| PVCs stay `Pending` | No storage class with that name, or no EBS CSI driver | `kubectl get storageclass`; set the right class in the values files; install the EBS CSI driver |
| New Grafana pod stuck in `ContainerCreating`, event `Multi-Attach error` | Rolling update with a ReadWriteOnce disk: the old pod still holds it | `strategy: Recreate` (already in the values). Quick fix: scale the old ReplicaSet to 0 |
| Grafana Ingress has no ADDRESS | Load Balancer Controller missing, private subnets not tagged, or a wrong certificate ARN | `kubectl -n monitoring describe ingress grafana` and the controller's logs |
| CloudWatch data source: `not authorized to perform sts:AssumeRoleWithWebIdentity` | Trust policy doesn't match the service account, or the OIDC provider is missing | The `sub` must be `system:serviceaccount:monitoring:grafana` (namespace and release name). `kubectl -n monitoring get sa grafana -o yaml` shows the role annotation |
| CloudWatch data source: `AccessDenied` on a call | That action isn't in the role's policy | Add it to `grafana-cloudwatch-policy.json` and run `put-role-policy` again |
| No logs in Loki | Fluent Bit can't reach `loki-gateway`, or Loki isn't Ready | `kubectl -n monitoring logs ds/fluent-bit --tail 50`; `kubectl -n monitoring get pods -l app.kubernetes.io/name=loki` |
| Loki logs `entry too far behind` or `greater than max age` | Old lines re-read from disk | Expected for lines older than 7 days (`reject_old_samples_max_age`) |
| Prometheus target `DOWN` with `connection refused` | Wrong port or path annotation | Check `prometheus.io/port` and `prometheus.io/path` on that Service or pod |
| Prometheus pod `OOMKilled` | Too many series (often a label with IDs in it) | Raise the memory limit, and drop or relabel the noisy metrics |
| SQL exporter: `relation "pg_stat_statements" does not exist` | Extension not created in that database | `CREATE EXTENSION pg_stat_statements;` as shown in Step 7 |
| SQL exporter can't connect | Security group, wrong host, or SSL | Allow 5432 from the cluster; keep `sslmode=require`; check the DSN's URL-encoding |
| Jaeger shows no services | Apps send to the wrong port, or don't send at all | OTLP HTTP is 4318, gRPC 4317; check the app's OpenTelemetry variables |
| Emails don't arrive | SES sandbox, unverified sender, wrong Region in the SMTP host, or wrong Secret keys | SES console; `kubectl -n monitoring logs deploy/grafana \| grep -i smtp` |

## Clean up

> **In simple words:** Uninstall the charts, then decide about the disks: deleting them deletes all stored metrics, logs and traces. Finally remove the IAM role.

```bash
helm uninstall sql-exporter jaeger fluent-bit loki grafana prometheus -n monitoring
kubectl -n monitoring get pvc                       # disks are kept by default
kubectl -n monitoring delete pvc --all              # deletes all stored data
kubectl delete namespace monitoring

aws iam delete-role-policy --role-name grafana-cloudwatch-role --policy-name grafana-cloudwatch-read
aws iam delete-role --role-name grafana-cloudwatch-role
```

## Cheat sheet

> **In simple words:** The install order, every command in one place, and where to look first when something is wrong.

| Task | Command |
|---|---|
| Install or update Prometheus | `helm upgrade --install prometheus prometheus-community/prometheus --version 27.50.1 -n monitoring -f prometheus-values.yaml` |
| Install or update Grafana | `helm upgrade --install grafana grafana/grafana --version 10.5.15 -n monitoring -f grafana-values.yaml` |
| Install or update Loki | `helm upgrade --install loki grafana/loki --version 6.55.0 -n monitoring -f loki-values.yaml` |
| Install or update Fluent Bit | `helm upgrade --install fluent-bit fluent/fluent-bit --version 0.58.1 -n monitoring -f fluent-bit-values.yaml` |
| Install or update Jaeger | `kubectl apply -f jaeger-badger-pvc.yaml` then `helm upgrade --install jaeger jaegertracing/jaeger --version 4.16.1 -n monitoring -f jaeger-values.yaml` |
| Install or update the SQL exporter | `helm upgrade --install sql-exporter burningalchemist/sql-exporter --version 0.18.15 -n monitoring -f sql-exporter-values.yaml` |
| Grafana admin password | `kubectl -n monitoring get secret grafana -o jsonpath='{.data.admin-password}' \| base64 -d` |
| Open Prometheus | `kubectl -n monitoring port-forward svc/prometheus-server 9090:80` |
| Open Grafana | `kubectl -n monitoring port-forward svc/grafana 3000:80` |
| Open Jaeger | `kubectl -n monitoring port-forward svc/jaeger 16686:16686` |
| What is installed | `helm ls -n monitoring` |
| Roll back a release | `helm rollback <release> <revision> -n monitoring` |

**Install order:** Step 1 repositories → 2 Prometheus → 3 Grafana (Secret first) → 4 IAM role for CloudWatch → 5 Loki and Fluent Bit → 6 Jaeger (PVC first) → 7 SQL exporter (database user and Secret first) → 8 dashboards → 9 alerts.

Official docs: [Prometheus chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus) · [Grafana chart](https://github.com/grafana/helm-charts/tree/main/charts/grafana) · [Loki Helm install](https://grafana.com/docs/loki/latest/setup/install/helm/) · [Fluent Bit Loki output](https://docs.fluentbit.io/manual/pipeline/outputs/loki) · [Jaeger Helm charts](https://github.com/jaegertracing/helm-charts) · [sql_exporter](https://github.com/burningalchemist/sql_exporter) · [Grafana CloudWatch data source](https://grafana.com/docs/grafana/latest/datasources/aws-cloudwatch/) · [IAM roles for service accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) · [Amazon SES SMTP](https://docs.aws.amazon.com/ses/latest/dg/send-email-smtp.html)
