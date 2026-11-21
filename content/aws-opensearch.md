# Log Pipeline with Amazon Data Firehose and OpenSearch

Build a **central log pipeline** on AWS: collect logs from every server and pod with **Fluent Bit**, batch and deliver them with **Amazon Data Firehose**, store and index them in an **Amazon OpenSearch Service** domain, and search them in **OpenSearch Dashboards**. Each step shows the **console clicks** and the matching **AWS CLI** commands, then the guide covers security, retention, alarms and the production setup.

> **Cost:** OpenSearch bills **per instance-hour plus storage, even when nobody sends or searches anything**. The lab domain (one `t3.small.search` node, 10 GiB gp3) costs about **$0.036/hour** (roughly $26/month) plus **$0.122 per GB-month** of gp3 storage. Firehose costs about **$0.029 per GB ingested** (first 500 TB/month), and each record is rounded up to the next **5 KB**. Delivery into a VPC adds $0.01 per GB and $0.01 per hour per AZ. Prices are for us-east-1. **Delete the domain when you finish.** See [OpenSearch Service pricing](https://aws.amazon.com/opensearch-service/pricing/) and [Data Firehose pricing](https://aws.amazon.com/firehose/pricing/).

## Start here: a log pipeline in simple words

> **In simple words:** Every server and every pod writes its own log files. When something breaks at 3 a.m., you don't want to log in to 20 machines and `grep` each one. A **log pipeline** copies every log line into **one searchable place**, so you can ask "show me all ERROR lines from the payment service in the last hour, on every server" and get the answer in seconds.

### Watch how it works

```svg Watch it work: Fluent Bit shipping app logs to Firehose, Firehose loading them into a daily OpenSearch index with failures kept in S3, a search in Dashboards, and ISM deleting an old index. The animation loops.
<svg viewBox="0 0 600 436" role="img" data-anim="aws-opensearch" aria-label="Animated log pipeline. Ship the logs: app pods on an EKS node write log lines to stdout, and the app on an EC2 instance writes them to files under /var/log/my-app. Fluent Bit, a DaemonSet pod on each EKS node and an agent on the EC2 instance, reads the new lines and sends them in batches to the Firehose stream app-logs-stream with PutRecordBatch. Firehose buffers the records for 60 seconds or 5 MiB, whichever comes first, then bulk-loads them into today&#x27;s index, app-logs-2026-11-08, in the OpenSearch domain logs-lab. When OpenSearch still refuses a record after 300 seconds of retries, Firehose writes it to the S3 backup bucket instead. Search: you open OpenSearch Dashboards, choose the index pattern app-logs-* in Discover and search for level:ERROR; the matching lines from every server and pod come back in seconds. Clean up: the Index State Management policy delete-old-logs moves every index to its delete state when it is 7 days old, so the old index app-logs-2026-11-01 is deleted and the disk never fills up.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<rect x="6" y="8" width="236" height="108" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="5 4"/>
<rect x="6" y="200" width="236" height="108" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="5 4"/>
<rect x="420" y="8" width="174" height="334" rx="12" fill="none" stroke="#ff9900" stroke-width="2" stroke-dasharray="7 4"/>
<polyline points="66,70 181,70" fill="none" stroke-linejoin="round" stroke="#64748b" stroke-width="1.8" stroke-dasharray="4 3" stroke-opacity=".7"/>
<polyline points="66,262 181,262" fill="none" stroke-linejoin="round" stroke="#64748b" stroke-width="1.8" stroke-dasharray="4 3" stroke-opacity=".7"/>
<polyline points="181,70 259,70 259,167 340,167" fill="none" stroke-linejoin="round" stroke="#64748b" stroke-width="1.8" stroke-dasharray="4 3" stroke-opacity=".7"/>
<polyline points="181,262 259,262 259,167" fill="none" stroke-linejoin="round" stroke="#64748b" stroke-width="1.8" stroke-dasharray="4 3" stroke-opacity=".7"/>
<polyline points="340,167 507,167" fill="none" stroke-linejoin="round" stroke="#0d9488" stroke-width="1.8" stroke-dasharray="6 3" stroke-opacity=".7"/>
<polyline points="340,167 340,288" fill="none" stroke-linejoin="round" stroke="#e11d48" stroke-width="1.6" stroke-dasharray="3 4" stroke-opacity=".6"/>
<polyline points="340,65 507,65" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="507,65 507,167" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="507,305 507,229" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<rect x="12" y="14" width="55.2" height="16" rx="5" class="dg-box"/><text x="16" y="24" font-size="11" class="dg-muted">EKS node</text>
<rect x="12" y="206" width="78.8" height="16" rx="5" class="dg-box"/><text x="16" y="216" font-size="11" class="dg-muted">EC2 instance</text>
<rect x="426" y="15" width="152.4" height="18" rx="5" class="dg-box"/><text x="430" y="27" font-size="13" font-weight="800" fill="#ff9900">OpenSearch logs-lab</text>
<g><rect x="12" y="40" width="108" height="60" rx="12" fill="#2563eb" fill-opacity=".18" stroke="#2563eb" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1161" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/></rect><rect x="16" y="44" width="100" height="52" rx="9" class="dg-box" stroke="#2563eb" stroke-width="2.2"/><text x="66" y="66.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">App pods</text><text x="66" y="82" text-anchor="middle" font-size="11" class="dg-muted">log to stdout</text></g>
<g><rect x="126" y="40" width="110" height="60" rx="12" fill="#0d9488" fill-opacity=".18" stroke="#0d9488" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.25" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/></rect><rect x="130" y="44" width="102" height="52" rx="9" class="dg-box" stroke="#0d9488" stroke-width="2.2"/><text x="181" y="66.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Fluent Bit</text><text x="181" y="82" text-anchor="middle" font-size="11" class="dg-muted">DaemonSet pod</text></g>
<g><rect x="12" y="232" width="108" height="60" rx="12" fill="#2563eb" fill-opacity=".18" stroke="#2563eb" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1161" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/></rect><rect x="16" y="236" width="100" height="52" rx="9" class="dg-box" stroke="#2563eb" stroke-width="2.2"/><text x="66" y="258.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">App</text><text x="66" y="274" text-anchor="middle" font-size="11" class="dg-muted">/var/log/my-app</text></g>
<g><rect x="126" y="232" width="110" height="60" rx="12" fill="#0d9488" fill-opacity=".18" stroke="#0d9488" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.25" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/></rect><rect x="130" y="236" width="102" height="52" rx="9" class="dg-box" stroke="#0d9488" stroke-width="2.2"/><text x="181" y="258.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Fluent Bit</text><text x="181" y="274" text-anchor="middle" font-size="11" class="dg-muted">tails *.log</text></g>
<g><rect x="272" y="36" width="136" height="58" rx="28" fill="#6366f1" fill-opacity=".18" stroke="#6366f1" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5089;0.7589" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/></rect><rect x="276" y="40" width="128" height="50" rx="25" class="dg-box" stroke="#6366f1" stroke-width="2.2"/><text x="340" y="61.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">You</text><text x="340" y="77" text-anchor="middle" font-size="11" class="dg-muted">search level:ERROR</text></g>
<g><rect x="272" y="134" width="136" height="66" rx="12" fill="#f97316" fill-opacity=".18" stroke="#f97316" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1161;0.5089" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/></rect><rect x="276" y="138" width="128" height="58" rx="9" class="dg-box" stroke="#f97316" stroke-width="2.2"/><text x="340" y="156" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Firehose</text><text x="340" y="171.5" text-anchor="middle" font-size="11" class="dg-muted">app-logs-stream</text><text x="340" y="186.5" text-anchor="middle" font-size="11" class="dg-muted">buffer 60 s / 5 MiB</text></g>
<g><rect x="272" y="258" width="136" height="60" rx="12" fill="#059669" fill-opacity=".18" stroke="#059669" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3839;0.5089" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/></rect><rect x="276" y="262" width="128" height="52" rx="9" class="dg-box" stroke="#059669" stroke-width="2.2"/><text x="340" y="284.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">S3 backup</text><text x="340" y="300" text-anchor="middle" font-size="11" class="dg-muted">failed records</text></g>
<g><rect x="428" y="36" width="158" height="58" rx="12" fill="#6366f1" fill-opacity=".18" stroke="#6366f1" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5089;0.7589" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/></rect><rect x="432" y="40" width="150" height="50" rx="9" class="dg-box" stroke="#6366f1" stroke-width="2.2"/><text x="507" y="61.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Dashboards</text><text x="507" y="77" text-anchor="middle" font-size="11" class="dg-muted">Discover · app-logs-*</text></g>
<g><rect x="428" y="138" width="158" height="58" rx="12" fill="#0891b2" fill-opacity=".18" stroke="#0891b2" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.25;0.3839;0.5089;0.7589" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/></rect><rect x="432" y="142" width="150" height="50" rx="9" class="dg-box" stroke="#0891b2" stroke-width="2.2"/><text x="507" y="163.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Today&#x27;s index</text><text x="507" y="179" text-anchor="middle" font-size="11" class="dg-muted">app-logs-2026-11-08</text></g>
<g><rect x="428" y="200" width="158" height="58" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7589;0.8839" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/></rect><rect x="432" y="204" width="150" height="50" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="507" y="225.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Old index</text><text x="507" y="241" text-anchor="middle" font-size="11" class="dg-muted">app-logs-2026-11-01</text><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8839" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/><rect x="432" y="204" width="150" height="50" rx="9" fill="#e11d48"/><text x="507" y="233.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">deleted</text></g></g>
<g><rect x="428" y="276" width="158" height="58" rx="12" fill="#e11d48" fill-opacity=".18" stroke="#e11d48" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.7589" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/></rect><rect x="432" y="280" width="150" height="50" rx="9" class="dg-box" stroke="#e11d48" stroke-width="2.2"/><text x="507" y="301.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">ISM policy</text><text x="507" y="317" text-anchor="middle" font-size="11" class="dg-muted">delete after 7 days</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3839;0.5089" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/><circle cx="420" cy="167" r="9.5" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M416,163 L424,171 M424,163 L416,171" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6339;0.7589" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/><circle cx="404" cy="40" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M399.5,40 L403,43.5 L408.5,36.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8839" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/><circle cx="582" cy="204" r="9.5" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M578,200 L586,208 M586,200 L578,208" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.007;0.0998" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/><animateMotion path="M66,70 L181,70" keyPoints="0;0;1;1" keyTimes="0;0.007;0.0998;1" calcMode="linear" dur="22.4s" repeatCount="indefinite"/><g><rect x="-8" y="-6" width="16" height="12" rx="2" fill="#64748b" stroke="#fff" stroke-width="1.6"/><path d="M-5,-2 H5 M-5,2 H3" stroke="#fff" stroke-width="1.4"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.007;0.0998" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/><animateMotion path="M66,262 L181,262" keyPoints="0;0;1;1" keyTimes="0;0.007;0.0998;1" calcMode="linear" dur="22.4s" repeatCount="indefinite"/><g><rect x="-8" y="-6" width="16" height="12" rx="2" fill="#64748b" stroke="#fff" stroke-width="1.6"/><path d="M-5,-2 H5 M-5,2 H3" stroke="#fff" stroke-width="1.4"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1241;0.2312" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/><animateMotion path="M181,70 L259,70 L259,167 L340,167" keyPoints="0;0;1;1" keyTimes="0;0.1241;0.2312;1" calcMode="linear" dur="22.4s" repeatCount="indefinite"/><g><rect x="-8" y="-6" width="16" height="12" rx="2" fill="#64748b" stroke="#fff" stroke-width="1.6"/><path d="M-5,-2 H5 M-5,2 H3" stroke="#fff" stroke-width="1.4"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1241;0.2312" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/><animateMotion path="M181,262 L259,262 L259,167 L340,167" keyPoints="0;0;1;1" keyTimes="0;0.1241;0.2312;1" calcMode="linear" dur="22.4s" repeatCount="indefinite"/><g><rect x="-8" y="-6" width="16" height="12" rx="2" fill="#64748b" stroke="#fff" stroke-width="1.6"/><path d="M-5,-2 H5 M-5,2 H3" stroke="#fff" stroke-width="1.4"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2634;0.333" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/><animateMotion path="M340,167 L507,167" keyPoints="0;0;1;1" keyTimes="0;0.2634;0.333;1" calcMode="linear" dur="22.4s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2768;0.3464" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/><animateMotion path="M340,167 L507,167" keyPoints="0;0;1;1" keyTimes="0;0.2768;0.3464;1" calcMode="linear" dur="22.4s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2902;0.3598" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/><animateMotion path="M340,167 L507,167" keyPoints="0;0;1;1" keyTimes="0;0.2902;0.3598;1" calcMode="linear" dur="22.4s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3889;0.4339" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/><animateMotion path="M340,167 L420,167" keyPoints="0;0;1;1" keyTimes="0;0.3889;0.4339;1" calcMode="linear" dur="22.4s" repeatCount="indefinite"/><g><circle r="7" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M0,-3.5 V1 M0,3.2 V3.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4439;0.4964" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/><animateMotion path="M340,167 L340,288" keyPoints="0;0;1;1" keyTimes="0;0.4439;0.4964;1" calcMode="linear" dur="22.4s" repeatCount="indefinite"/><g><circle r="7" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M0,-3.5 V1 M0,3.2 V3.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5139;0.5652" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/><animateMotion path="M340,65 L507,65" keyPoints="0;0;1;1" keyTimes="0;0.5139;0.5652;1" calcMode="linear" dur="22.4s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5714;0.6214" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/><animateMotion path="M507,65 L507,167" keyPoints="0;0;1;1" keyTimes="0;0.5714;0.6214;1" calcMode="linear" dur="22.4s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6389;0.6902" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/><animateMotion path="M507,167 L507,65" keyPoints="0;0;1;1" keyTimes="0;0.6389;0.6902;1" calcMode="linear" dur="22.4s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6964;0.7464" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/><animateMotion path="M507,65 L340,65" keyPoints="0;0;1;1" keyTimes="0;0.6964;0.7464;1" calcMode="linear" dur="22.4s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7664;0.8664" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/><animateMotion path="M507,305 L507,229" keyPoints="0;0;1;1" keyTimes="0;0.7664;0.8664;1" calcMode="linear" dur="22.4s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(21.2,360.5) scale(.8)"><g><rect x="-8" y="-6" width="16" height="12" rx="2" fill="#64748b" stroke="#fff" stroke-width="1.6"/><path d="M-5,-2 H5 M-5,2 H3" stroke="#fff" stroke-width="1.4"/></g></g><text x="33.4" y="364">log line</text><g transform="translate(100.6,360.5) scale(.8)"><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g><text x="112" y="364">batch</text><g transform="translate(162.4,360.5) scale(.8)"><g><circle r="7" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M0,-3.5 V1 M0,3.2 V3.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/></g></g><text x="173.8" y="364">failed record</text><g transform="translate(269,360.5) scale(.8)"><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g><text x="280.4" y="364">search / policy</text><g transform="translate(386.8,360.5) scale(.8)"><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g><text x="398.2" y="364">results</text></g>
<rect x="12" y="376" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="376" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="22.4s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1161" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/><circle cx="36" cy="404" r="14" fill="#0d9488"/><text x="36" y="409" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="399" font-size="14" font-weight="800" fill="#0d9488">Apps write log lines</text><text x="578" y="399" text-anchor="end" font-size="10.5" class="dg-muted">Ship the logs · 1/8</text><text x="60" y="420" font-size="12.5" class="dg-text">Pods on EKS write to stdout; the app on EC2 writes files in /var/log/my-app.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1161;0.25" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/><circle cx="36" cy="404" r="14" fill="#0d9488"/><text x="36" y="409" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="399" font-size="14" font-weight="800" fill="#0d9488">Fluent Bit collects and sends them</text><text x="578" y="399" text-anchor="end" font-size="10.5" class="dg-muted">Ship the logs · 2/8</text><text x="60" y="420" font-size="12.5" class="dg-text">One per node (a DaemonSet on EKS). It sends batches with PutRecordBatch.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.25;0.3839" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/><circle cx="36" cy="404" r="14" fill="#0d9488"/><text x="36" y="409" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="399" font-size="14" font-weight="800" fill="#0d9488">Firehose buffers, then bulk-loads</text><text x="578" y="399" text-anchor="end" font-size="10.5" class="dg-muted">Ship the logs · 3/8</text><text x="60" y="420" font-size="12.5" class="dg-text">After 60 seconds or 5 MiB, whichever comes first, into today&#x27;s daily index.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3839;0.5089" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/><circle cx="36" cy="404" r="14" fill="#0d9488"/><text x="36" y="409" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="399" font-size="14" font-weight="800" fill="#0d9488">Records that fail go to S3</text><text x="578" y="399" text-anchor="end" font-size="10.5" class="dg-muted">Ship the logs · 4/8</text><text x="60" y="420" font-size="12.5" class="dg-text">If OpenSearch still refuses a record after 300 s of retries, it lands in S3.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5089;0.6339" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/><circle cx="36" cy="404" r="14" fill="#6366f1"/><text x="36" y="409" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="399" font-size="14" font-weight="800" fill="#6366f1">You search in OpenSearch Dashboards</text><text x="578" y="399" text-anchor="end" font-size="10.5" class="dg-muted">Search · 5/8</text><text x="60" y="420" font-size="12.5" class="dg-text">In Discover, pick the index pattern app-logs-* and type level:ERROR.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6339;0.7589" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/><circle cx="36" cy="404" r="14" fill="#6366f1"/><text x="36" y="409" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="399" font-size="14" font-weight="800" fill="#6366f1">Every ERROR line comes back in seconds</text><text x="578" y="399" text-anchor="end" font-size="10.5" class="dg-muted">Search · 6/8</text><text x="60" y="420" font-size="12.5" class="dg-text">From every server and pod, in one place. No need to log in to 20 machines.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7589;0.8839" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/><circle cx="36" cy="404" r="14" fill="#e11d48"/><text x="36" y="409" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="399" font-size="14" font-weight="800" fill="#e11d48">An ISM policy checks every index</text><text x="578" y="399" text-anchor="end" font-size="10.5" class="dg-muted">Clean up · 7/8</text><text x="60" y="420" font-size="12.5" class="dg-text">delete-old-logs: each index starts hot and moves to delete at 7 days old.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8839" calcMode="discrete" dur="22.4s" repeatCount="indefinite"/><circle cx="36" cy="404" r="14" fill="#e11d48"/><text x="36" y="409" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="399" font-size="14" font-weight="800" fill="#e11d48">The old index is deleted</text><text x="578" y="399" text-anchor="end" font-size="10.5" class="dg-muted">Clean up · 8/8</text><text x="60" y="420" font-size="12.5" class="dg-text">app-logs-2026-11-01 is gone, so the disk never fills up and writes keep working.</text></g>
</svg>
```

### The whole pipeline at a glance

```flow
📄 | Apps write logs | Pods on EKS and services on EC2 write lines to files or to stdout.
🐦 | Fluent Bit collects | A small agent on every node reads new lines, adds labels (host, pod, namespace) and sends them in batches.
🚚 | Amazon Data Firehose delivers | Buffers records, can transform them with Lambda, retries on errors, and backs up failed (or all) records to S3.
🔎 | OpenSearch indexes | Stores each log line as a JSON document in a daily index, so every word and field is searchable.
📊 | Dashboards shows | You search, filter and chart the logs in OpenSearch Dashboards (Discover).
🧹 | Retention cleans up | An Index State Management policy deletes indices older than N days, so the disk never fills up.
```

### The library comparison

| Library | Log pipeline |
|---|---|
| Couriers collect new books from every office | **Fluent Bit** on every server or Kubernetes node |
| A van that leaves when it is full, or every few minutes | **Firehose** and its **buffer** (size or time, whichever comes first) |
| Books that can't be shelved go to a storage room | **S3 backup** of failed records |
| The library building, with its librarians | The OpenSearch **domain** (cluster) and its **nodes** |
| One shelf per day of newspapers | An **index**, e.g. `app-logs-2026-11-08` |
| Boxes on a shelf, and photocopies kept in another room | **Shards**, and their **replicas** on other nodes |
| The catalogue computer | **OpenSearch Dashboards** |

### Key words

| Word | Meaning |
|---|---|
| **Amazon Data Firehose** | A managed service that delivers streaming data to S3, OpenSearch, Splunk and more. It was called **Amazon Kinesis Data Firehose** before. The API calls each pipe a **delivery stream**; the console says **Firehose stream** |
| **Domain** | AWS's name for an OpenSearch **cluster**: its nodes, disks and settings |
| **Data node / dedicated master node** | Data nodes store and search data. Dedicated master nodes only manage the cluster, which keeps big clusters stable |
| **Index and document** | An index is a collection of JSON documents, like a table. Logs usually get one index per day |
| **Shard and replica** | An index is split into **primary shards**; each **replica** is a copy of a primary on a **different** node |
| **Index pattern** | A name with a wildcard, like `app-logs-*`, that tells Dashboards which indices to search together |
| **Fine-grained access control (FGAC)** | OpenSearch's own users, roles and permissions, down to index, document and field level |
| **Master user** | The first admin user of the domain (not the same thing as master nodes) |
| **ISM** | Index State Management: rules that act on indices by age or size, e.g. delete after 7 days |

### Check yourself

1. Why does a single-node domain often show a **yellow** status?
2. What does Firehose do with a record that OpenSearch refuses?
3. You can sign in to Dashboards, but Firehose gets `403` errors. What is missing?

> **Tip:** Answers: 1) A replica must live on a different node than its primary, and there is no second node, so replicas stay unassigned. 2) It retries for the retry duration (default 300 seconds), then writes the record to the S3 backup bucket under `AmazonOpenSearchService-failed/`. 3) The Firehose IAM role is not **mapped** to an OpenSearch role inside fine-grained access control.

## Before you start: tools, variables and the plan

> **In simple words:** Check your tools, set a few shell variables once, and look at what you are going to build. Keep the same terminal open for the whole guide, because later steps reuse these variables.

You need the AWS CLI v2 signed in as an admin user (see [Create your AWS account](#/tool/aws-account) and [Workstation setup](#/tool/setup)), plus `curl` and `python3`.

```bash
aws --version && curl --version | head -1 && python3 --version

export AWS_REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
DOMAIN=logs-lab                            # OpenSearch domain name (3 to 28 chars, lowercase)
STREAM=app-logs-stream                     # Firehose stream name
INDEX=app-logs                             # index prefix; Firehose adds the date
BUCKET=my-app-firehose-backup-$ACCOUNT_ID  # S3 bucket for failed records
FH_ROLE=firehose-to-opensearch-role        # IAM role that Firehose uses
SECRET_NAME=opensearch/logs-lab/master     # where the admin password lives
OS_USER=admin
```

### What we'll build

```text
  laptop: aws firehose put-record    Fluent Bit (EKS / EC2)
                 │                            │
                 └─────────────┬──────────────┘
                               ▼
        ┌──────────────────────────────┐
        │ Firehose stream              │──failed──▶ S3 bucket
        │ app-logs-stream (60 s/5 MiB) │
        └──────────────┬───────────────┘
                       ▼ HTTPS, IAM role mapped in FGAC
        ┌──────────────────────────────┐
        │ OpenSearch domain logs-lab   │
        │ index app-logs-2026-11-08    │
        └──────────────┬───────────────┘
                       ▼
          OpenSearch Dashboards (you)
```

The lab uses **one `t3.small.search` node**, the smallest current instance type. AWS marks T3 as **not recommended for production**: it can't use UltraWarm, cold storage, Auto-Tune or Multi-AZ with standby, and is limited to 10 nodes ([Supported instance types](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/supported-instance-types.html)). The production section shows what changes for real workloads.

## Step 1: Store the admin password in Secrets Manager

> **In simple words:** The domain's first admin (the **master user**) signs in with a username and password. Generate a strong password, keep it in **Secrets Manager** instead of a text file, and read it from there whenever you need it.

OpenSearch needs a strong master password: at least 8 characters with an uppercase letter, a lowercase letter, a number and a special character. We exclude a few characters that are awkward in JSON and URLs.

**Console:** **Secrets Manager** → **Store a new secret** → **Other type of secret** → keys `username` = `admin` and `password` = a strong password → Name `opensearch/logs-lab/master` → **Store**.

**CLI:**

```bash
OS_PASS=$(aws secretsmanager get-random-password --password-length 20 \
  --require-each-included-type --exclude-characters '"/\@:' \
  --query RandomPassword --output text)

aws secretsmanager create-secret --name $SECRET_NAME \
  --description "OpenSearch master user for the logs lab" \
  --secret-string "{\"username\":\"$OS_USER\",\"password\":\"$OS_PASS\"}"

# later, in a new terminal, read it back like this:
OS_PASS=$(aws secretsmanager get-secret-value --secret-id $SECRET_NAME --query SecretString --output text \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["password"])')
```

More about secrets and who may read them: the [Secrets Manager guide](#/tool/aws-secrets).

## Step 2: Create the OpenSearch domain

> **In simple words:** Create a one-node cluster with a small disk, turn on all three kinds of encryption, and switch on **fine-grained access control** with the admin user from Step 1. Creating a domain takes a while, so start it now.

**Console:** **Amazon OpenSearch Service** → **Domains** → **Create domain**, then:

1. **Domain name** `logs-lab`, creation method **Standard create**, use case **Custom**, template **Dev/test**.
2. **Deployment option:** **Domain without standby**, **1-AZ**. **Version:** OpenSearch **2.19** (or the newest offered; Dashboards menus may then differ slightly).
3. **Data nodes:** `t3.small.search`, **1** node, EBS **gp3**, **10** GiB. Leave dedicated master nodes off.
4. **Network:** **Public access** (fine for a password-protected lab; production uses VPC access).
5. **Fine-grained access control:** on → **Create master user** → `admin` and the password from Step 1.
6. **Access policy:** configure a domain-level policy and paste the JSON from the CLI block below.
7. Tick **Require HTTPS for all traffic to the domain**, **Node-to-node encryption** and **Enable encryption of data at rest**. Fine-grained access control requires all three. Then **Create**.

**CLI:**

```bash
# access policy: IAM principals of this account (if their own IAM policy allows it)
cat > domain-policy.json <<EOF
{ "Version": "2012-10-17",
  "Statement": [{ "Effect": "Allow", "Principal": { "AWS": "arn:aws:iam::${ACCOUNT_ID}:root" },
    "Action": "es:ESHttp*", "Resource": "arn:aws:es:${AWS_REGION}:${ACCOUNT_ID}:domain/${DOMAIN}/*" }] }
EOF

# master user in the internal user database, kept in a file so the password isn't in the command line
cat > security.json <<EOF
{ "Enabled": true, "InternalUserDatabaseEnabled": true,
  "MasterUserOptions": { "MasterUserName": "${OS_USER}", "MasterUserPassword": "${OS_PASS}" } }
EOF

aws opensearch create-domain --domain-name $DOMAIN \
  --engine-version OpenSearch_2.19 \
  --cluster-config InstanceType=t3.small.search,InstanceCount=1,DedicatedMasterEnabled=false,ZoneAwarenessEnabled=false \
  --ebs-options EBSEnabled=true,VolumeType=gp3,VolumeSize=10 \
  --encryption-at-rest-options Enabled=true \
  --node-to-node-encryption-options Enabled=true \
  --domain-endpoint-options EnforceHTTPS=true,TLSSecurityPolicy=Policy-Min-TLS-1-2-PFS-2023-10 \
  --advanced-security-options file://security.json \
  --access-policies file://domain-policy.json \
  --query 'DomainStatus.ARN' --output text
rm -f security.json

echo "Waiting for the endpoint (about 15 to 30 minutes)..."
until [ "$(aws opensearch describe-domain --domain-name $DOMAIN \
  --query 'DomainStatus.Endpoint' --output text)" != "None" ]; do sleep 60; done
OS_URL="https://$(aws opensearch describe-domain --domain-name $DOMAIN --query DomainStatus.Endpoint --output text)"
echo "Domain ready: $OS_URL"
```

Two things to know: **after you enable fine-grained access control, you can't disable it**, and with the account in the access policy, requests signed with IAM (like Firehose's) are checked by IAM **and** FGAC, while username-and-password requests are checked by FGAC only.

AWS docs: [Creating domains](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/createupdatedomains.html) · [Fine-grained access control](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/fgac.html) · [Tutorial: internal user database and HTTP basic authentication](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/fgac-http-auth.html)

## Step 3: Say hello to the cluster and add an index template

> **In simple words:** Talk to OpenSearch with `curl` and the admin password. Check that the cluster is healthy, then create an **index template**: a rule that says "every new `app-logs-*` index gets 1 shard, 0 replicas, and a real date field called `@timestamp`".

By default, OpenSearch Service gives every new index **5 primary shards and 1 replica**. That is far too many for a lab, and the replica can't be placed on a single node. In production, AWS suggests shards of about **30 to 50 GiB** for log workloads ([Choosing the number of shards](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/bp-sharding.html)).

```bash
curl -s -u "$OS_USER:$OS_PASS" "$OS_URL"                       # name and version
curl -s -u "$OS_USER:$OS_PASS" "$OS_URL/_cluster/health?pretty"  # look at "status"

curl -s -u "$OS_USER:$OS_PASS" -X PUT "$OS_URL/_index_template/app-logs" \
  -H 'Content-Type: application/json' -d '{
  "index_patterns": ["app-logs-*"],
  "template": {
    "settings": { "number_of_shards": 1, "number_of_replicas": 0 },
    "mappings": { "properties": { "@timestamp": { "type": "date" } } }
  }
}'
```

Health colours: **green** means every shard is placed; **yellow** means some **replicas** have no node to live on (normal on one node if replicas are above 0); **red** means a **primary** shard is missing, so some data can't be searched or written. The template only affects **new** indices, so create it before the first log arrives.

## Step 4: S3 backup bucket, error log group and the Firehose role

> **In simple words:** Firehose needs three things before it can work: a **bucket** for records it could not deliver, a **log group** for its error messages, and an **IAM role** that allows it to write to all of them and to your domain.

**Console:** you can skip this step: the Firehose wizard in Step 6 can create the role, and you can pick or create the bucket there.

**CLI:**

```bash
aws s3api create-bucket --bucket $BUCKET          # us-east-1 needs no LocationConstraint
aws logs create-log-group --log-group-name /aws/kinesisfirehose/$STREAM
aws logs create-log-stream --log-group-name /aws/kinesisfirehose/$STREAM --log-stream-name DestinationDelivery
aws logs put-retention-policy --log-group-name /aws/kinesisfirehose/$STREAM --retention-in-days 7
cat > firehose-trust.json <<EOF
{ "Version": "2012-10-17",
  "Statement": [{ "Effect": "Allow", "Principal": { "Service": "firehose.amazonaws.com" },
                  "Action": "sts:AssumeRole" }] }
EOF

cat > firehose-policy.json <<EOF
{ "Version": "2012-10-17",
  "Statement": [
    { "Sid": "OpenSearch", "Effect": "Allow",
      "Action": ["es:DescribeDomain", "es:DescribeDomains", "es:DescribeDomainConfig",
                 "es:ESHttpPost", "es:ESHttpPut", "es:ESHttpGet"],
      "Resource": ["arn:aws:es:${AWS_REGION}:${ACCOUNT_ID}:domain/${DOMAIN}",
                   "arn:aws:es:${AWS_REGION}:${ACCOUNT_ID}:domain/${DOMAIN}/*"] },
    { "Sid": "S3Backup", "Effect": "Allow",
      "Action": ["s3:AbortMultipartUpload", "s3:GetBucketLocation", "s3:GetObject",
                 "s3:ListBucket", "s3:ListBucketMultipartUploads", "s3:PutObject"],
      "Resource": ["arn:aws:s3:::${BUCKET}", "arn:aws:s3:::${BUCKET}/*"] },
    { "Sid": "ErrorLogs", "Effect": "Allow", "Action": ["logs:PutLogEvents"],
      "Resource": "arn:aws:logs:${AWS_REGION}:${ACCOUNT_ID}:log-group:/aws/kinesisfirehose/${STREAM}:log-stream:*" } ] }
EOF

FH_ROLE_ARN=$(aws iam create-role --role-name $FH_ROLE \
  --assume-role-policy-document file://firehose-trust.json --query Role.Arn --output text)
aws iam put-role-policy --role-name $FH_ROLE --policy-name firehose-to-opensearch \
  --policy-document file://firehose-policy.json
echo "Role: $FH_ROLE_ARN"
```

AWS's own example limits `es:ESHttpGet` to a few paths (`_nodes`, `_stats`, the index mappings); the wider `domain/*` is fine for a lab. More on roles: the [IAM guide](#/tool/aws-iam). AWS docs: [Controlling access with Firehose](https://docs.aws.amazon.com/firehose/latest/dev/controlling-access.html)

## Step 5: Map the Firehose role inside OpenSearch

> **In simple words:** With fine-grained access control there are **two locks**. IAM lets Firehose **reach** the domain; OpenSearch's own security then asks "**who are you, and what may you do?**". Create an OpenSearch role that may write to `app-logs*` indices, and **map** the Firehose IAM role to it as a **backend role**. Without this, every write fails with `403`.

**Console (Dashboards):** open `$OS_URL/_dashboards`, sign in as `admin` → menu **☰** → **Security** → **Roles** → **Create role** → name `firehose_writer`, cluster permissions `cluster_composite_ops` and `cluster_monitor`, index pattern `app-logs*` with `create_index`, `manage`, `crud` → **Create**. Then **Mapped users** → **Manage mapping** → **Backend roles**: paste the Firehose role ARN → **Map**.

**CLI (the security REST API):**

```bash
curl -s -u "$OS_USER:$OS_PASS" -X PUT "$OS_URL/_plugins/_security/api/roles/firehose_writer" \
  -H 'Content-Type: application/json' -d '{
  "cluster_permissions": ["cluster_composite_ops", "cluster_monitor"],
  "index_permissions": [{ "index_patterns": ["app-logs*"],
                          "allowed_actions": ["create_index", "manage", "crud"] }]
}'

curl -s -u "$OS_USER:$OS_PASS" -X PUT "$OS_URL/_plugins/_security/api/rolesmapping/firehose_writer" \
  -H 'Content-Type: application/json' -d "{\"backend_roles\": [\"$FH_ROLE_ARN\"]}"

curl -s -u "$OS_USER:$OS_PASS" "$OS_URL/_plugins/_security/api/rolesmapping/firehose_writer?pretty"
```

The master user is mapped to the built-in `all_access` and `security_manager` roles. For people, map `opensearch_dashboards_user` plus a read role for their indices (for example `readall`).

> **Warning:** A `PUT` to `rolesmapping/ROLE` **replaces** the whole mapping. Before changing `all_access` or `security_manager`, `GET` the current mapping and keep the master user in it, or you can lock yourself out.

## Step 6: Create the Firehose stream

> **In simple words:** Now connect the pipe: records come in through the Firehose API (**Direct PUT**), wait in the buffer for up to 60 seconds or 5 MiB, and are written to a daily index `app-logs-YYYY-MM-DD`. Records that still fail after 5 minutes of retries go to S3.

**Console:** **Amazon Data Firehose** → **Create Firehose stream** → Source **Direct PUT**, Destination **Amazon OpenSearch Service** → name `app-logs-stream` → **Destination settings**: domain `logs-lab`, index `app-logs`, rotate **every day**, retry duration `300` s, buffer `5` MiB / `60` s → **Backup settings**: **Failed data only**, your bucket, prefix `backup/` → **Advanced settings**: CloudWatch error logging on, existing role `firehose-to-opensearch-role` → **Create Firehose stream**.

**CLI:**

```bash
DOMAIN_ARN=$(aws opensearch describe-domain --domain-name $DOMAIN --query DomainStatus.ARN --output text)

cat > firehose-destination.json <<EOF
{
  "RoleARN": "${FH_ROLE_ARN}",
  "DomainARN": "${DOMAIN_ARN}",
  "IndexName": "${INDEX}",
  "IndexRotationPeriod": "OneDay",
  "BufferingHints": { "IntervalInSeconds": 60, "SizeInMBs": 5 },
  "RetryOptions": { "DurationInSeconds": 300 },
  "S3BackupMode": "FailedDocumentsOnly",
  "S3Configuration": { "RoleARN": "${FH_ROLE_ARN}", "BucketARN": "arn:aws:s3:::${BUCKET}",
                       "Prefix": "backup/", "CompressionFormat": "UNCOMPRESSED" },
  "CloudWatchLoggingOptions": { "Enabled": true,
    "LogGroupName": "/aws/kinesisfirehose/${STREAM}", "LogStreamName": "DestinationDelivery" }
}
EOF

sleep 15   # give the new IAM role a moment to become usable
aws firehose create-delivery-stream --delivery-stream-name $STREAM --delivery-stream-type DirectPut \
  --amazonopensearchservice-destination-configuration file://firehose-destination.json

until [ "$(aws firehose describe-delivery-stream --delivery-stream-name $STREAM \
  --query DeliveryStreamDescription.DeliveryStreamStatus --output text)" = "ACTIVE" ]; do sleep 15; done
echo "Firehose stream is ACTIVE"
```

| Setting | Value here | Range and default | Why |
|---|---|---|---|
| `IndexRotationPeriod` | `OneDay` | `NoRotation`, `OneHour`, `OneDay`, `OneWeek`, `OneMonth` | One index per day makes "delete after N days" easy |
| `BufferingHints` | 60 s, 5 MiB | 0 to 900 s, 1 to 100 MiB (defaults 300 s, 5 MiB) | Whichever is reached first triggers a delivery. Shorter means fresher logs, more requests |
| `RetryOptions` | 300 s | 0 to 7200 s (default 300) | How long to keep retrying a failing domain before giving up on a batch |
| `S3BackupMode` | `FailedDocumentsOnly` | or `AllDocuments` | `AllDocuments` keeps a cheap raw copy of **every** log in S3. **It can't be changed later** |

### Optional: transform records with Lambda

Firehose can pass every batch to a **Lambda function** before delivery, to wrap plain text in JSON, add fields or remove secrets. The function must return every `recordId` with a result of `Ok`, `Dropped` or `ProcessingFailed`:

```python
import base64
import json

def lambda_handler(event, context):
    output = []
    for record in event["records"]:
        line = base64.b64decode(record["data"]).decode("utf-8")
        try:
            doc = json.loads(line)
        except json.JSONDecodeError:
            doc = {"message": line}              # plain text: wrap it in JSON
        doc.pop("password", None)                # never index secrets
        doc.setdefault("env", "dev")
        output.append({
            "recordId": record["recordId"],
            "result": "Ok",                      # or "Dropped" / "ProcessingFailed"
            "data": base64.b64encode(json.dumps(doc).encode("utf-8")).decode("utf-8"),
        })
    return {"records": output}
```

Turn it on under the stream's **Transform records** setting (in the API: a `ProcessingConfiguration` with a processor of type `Lambda` and its `LambdaArn`). The Firehose role then also needs `lambda:InvokeFunction` and `lambda:GetFunctionConfiguration`. See the [Lambda guide](#/tool/aws-lambda).

AWS docs: [Configure destination settings](https://docs.aws.amazon.com/firehose/latest/dev/create-destination.html) · [Index rotation](https://docs.aws.amazon.com/firehose/latest/dev/es-index-rotation.html) · [Transform source data](https://docs.aws.amazon.com/firehose/latest/dev/data-transformation.html)

## Step 7: Send test records

> **In simple words:** Pretend to be an application and push a few JSON log lines into Firehose yourself. Each record must be **one JSON document**. The AWS CLI v2 expects record data to be **base64-encoded** by default, so either encode it, or tell the CLI that you pass raw text.

**Option A: base64-encode the data yourself.**

```bash
for LEVEL in INFO INFO WARN ERROR INFO; do
  DOC="{\"@timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"service\":\"my-app\",\"level\":\"$LEVEL\",\"message\":\"test log line at level $LEVEL\"}"
  B64=$(printf '%s' "$DOC" | base64 | tr -d '\n')
  aws firehose put-record --delivery-stream-name $STREAM \
    --record "{\"Data\":\"$B64\"}" --query RecordId --output text
done
```

**Option B: pass raw JSON with `--cli-binary-format raw-in-base64-out`.**

```bash
aws firehose put-record --delivery-stream-name $STREAM --cli-binary-format raw-in-base64-out \
  --record '{"Data":"{\"@timestamp\":\"2026-11-08T10:00:00Z\",\"service\":\"my-app\",\"level\":\"ERROR\",\"message\":\"payment failed\"}"}'
```

Wait for the buffer (about a minute), then look:

```bash
sleep 90
curl -s -u "$OS_USER:$OS_PASS" "$OS_URL/_cat/indices/app-logs-*?v"                # one index per day
curl -s -u "$OS_USER:$OS_PASS" "$OS_URL/app-logs-*/_search?q=level:ERROR&pretty"   # only ERROR lines
aws s3 ls s3://$BUCKET/backup/ --recursive                                        # empty = nothing failed
```

The stream's **Monitoring** tab shows `IncomingRecords` and `DeliveryToAmazonOpenSearchService.Success`. If records come in but nothing reaches OpenSearch, go to Troubleshooting.

## Step 8: Find your logs in OpenSearch Dashboards

> **In simple words:** Dashboards is the website on top of OpenSearch. Tell it which indices to read (an **index pattern**) and which field holds the time, then use **Discover** to search your logs like a search engine.

1. Run `echo "$OS_URL/_dashboards"`, open the address, and sign in as `admin` with the password from Step 1.
2. Choose **Explore on my own**. If asked for a tenant, choose **Global** (shared) or **Private** (only you).
3. Menu **☰** → **Dashboards Management** → **Index patterns** → **Create index pattern** → `app-logs-*` → **Next step** → time field `@timestamp` → **Create index pattern**.
4. Menu **☰** → **Discover** → choose `app-logs-*` → time range **Last 1 hour**.
5. Type `level:ERROR` in the search bar and press Enter. Add `service`, `level` and `message` as columns. Other searches (DQL): `level:ERROR and service:my-app`, `message:"payment failed"`, `kubernetes.namespace_name:prod and not level:INFO`.

Save useful searches with **Save**, chart them with **Visualize** (for example errors per service per hour), and pin them on a **Dashboard** for the team.

## Step 9: Delete old indices automatically (ISM)

> **In simple words:** Logs grow every day, and a full disk **blocks all writes**. An **Index State Management** policy works like a cleaner with a calendar: every index starts in a "hot" state and moves to "delete" when it is 7 days old.

Save this policy as `ism-policy.json`:

```json
{
  "policy": {
    "description": "Delete app log indices 7 days after they are created",
    "default_state": "hot",
    "states": [
      { "name": "hot", "actions": [],
        "transitions": [{ "state_name": "delete", "conditions": { "min_index_age": "7d" } }] },
      { "name": "delete", "actions": [{ "delete": {} }], "transitions": [] }
    ],
    "ism_template": [{ "index_patterns": ["app-logs-*"], "priority": 100 }]
  }
}
```

**Console (Dashboards):** menu **☰** → **Index Management** → **State management policies** → **Create policy** → **JSON editor** → paste, policy ID `delete-old-logs` → **Create**.

**CLI:**

```bash
curl -s -u "$OS_USER:$OS_PASS" -X PUT "$OS_URL/_plugins/_ism/policies/delete-old-logs" \
  -H 'Content-Type: application/json' -d @ism-policy.json

# ism_template only catches NEW indices; attach the policy to the ones that already exist
curl -s -u "$OS_USER:$OS_PASS" -X POST "$OS_URL/_plugins/_ism/add/app-logs-*" \
  -H 'Content-Type: application/json' -d '{"policy_id": "delete-old-logs"}'

curl -s -u "$OS_USER:$OS_PASS" "$OS_URL/_plugins/_ism/explain/app-logs-*?pretty"   # state of each index
```

ISM checks each index every **5 to 8 minutes**, so a deletion can happen a few minutes late. Production policies often add a middle step, such as `read_only` after 2 days or a move to UltraWarm (not available on T3).

AWS docs: [Index State Management](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/ism.html) · [ISM in the OpenSearch documentation](https://docs.opensearch.org/latest/im-plugin/ism/index/)

## Step 10: Ship real logs with Fluent Bit

> **In simple words:** Fluent Bit is the courier on every machine. It **tails** log files, turns each line into a JSON record, adds labels, and calls Firehose's `PutRecordBatch` API through its built-in **`kinesis_firehose`** output. It needs only one IAM permission: `firehose:PutRecordBatch` on your stream.

Give the identity that runs Fluent Bit (the EC2 instance role, or the pod's role on EKS) an IAM policy that allows `firehose:PutRecordBatch` on `arn:aws:firehose:us-east-1:111111111111:deliverystream/app-logs-stream` (your account ID and stream name).

### On EC2: a config file

Install the `fluent-bit` package for your distribution ([Linux packages](https://docs.fluentbit.io/manual/installation/downloads/linux)), put this in `/etc/fluent-bit/fluent-bit.conf`, then run `sudo systemctl restart fluent-bit`:

```text
[INPUT]
    Name   tail
    Path   /var/log/my-app/*.log
    Tag    my-app

[OUTPUT]
    Name             kinesis_firehose
    Match            *
    region           us-east-1
    delivery_stream  app-logs-stream
    time_key         @timestamp
    time_key_format  %Y-%m-%dT%H:%M:%S.%3NZ
```

`time_key` adds the event time to each record as `@timestamp`, matching the index template and the index pattern. Optional keys: `role_arn` (assume a role, for example to reach a stream in another account) and `compression` (leave it off for OpenSearch, which needs plain JSON).

### On EKS: the Helm chart

The official chart runs Fluent Bit as a **DaemonSet** (one pod per node) that tails `/var/log/containers/*.log` with the tag `kube.*` and adds Kubernetes labels (namespace, pod, container). Give its service account the IAM permission with **IRSA** (the annotation below) or **EKS Pod Identity** (an association instead of the annotation); see [EKS cluster](#/tool/eks-cluster). Save as `fluent-bit-values.yaml`:

```yaml
serviceAccount:
  create: true
  name: fluent-bit
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::111111111111:role/fluent-bit-firehose
config:
  outputs: |
    [OUTPUT]
        Name             kinesis_firehose
        Match            kube.*
        region           us-east-1
        delivery_stream  app-logs-stream
        time_key         @timestamp
        time_key_format  %Y-%m-%dT%H:%M:%S.%3NZ
```

```bash
helm repo add fluent https://fluent.github.io/helm-charts && helm repo update
helm upgrade --install fluent-bit fluent/fluent-bit -n logging --create-namespace -f fluent-bit-values.yaml
kubectl -n logging logs daemonset/fluent-bit --tail=20    # look for kinesis_firehose errors
```

Docs: [Fluent Bit Firehose output](https://docs.fluentbit.io/manual/data-pipeline/outputs/firehose) · [Fluent Bit Helm charts](https://github.com/fluent/helm-charts)

### What about CloudWatch Logs?

AWS **does not support CloudWatch Logs → Firehose → OpenSearch**: a subscription filter packs many log events into one Firehose record, and OpenSearch needs one document per record. For logs already in CloudWatch Logs (Lambda, API Gateway, the CloudWatch agent), either use CloudWatch's own **Create Amazon OpenSearch Service subscription filter** (log group → **Actions** → **Subscription filters**), which creates a small Lambda function that writes to the domain (map its role in FGAC, like Step 5), or send them through Firehose to **S3** as a cheap archive (see the [CloudWatch guide](#/tool/aws-cloudwatch/step-8-subscription-filters-stream-logs-somewhere-else-optional)). AWS docs: [Send CloudWatch Logs to Firehose](https://docs.aws.amazon.com/firehose/latest/dev/writing-with-cloudwatch-logs.html) · [Stream CloudWatch Logs to OpenSearch](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_OpenSearch_Stream.html)

## Production: private VPC, more nodes, more zones

> **In simple words:** The lab domain has a public address and one node. A production log cluster lives **inside your VPC** (no public address at all), spreads its nodes across **three Availability Zones**, and has **three dedicated master nodes**, so losing one server or one zone loses no logs.

| Setting | Production choice | Why |
|---|---|---|
| Network | **VPC access**, one private subnet per AZ, a security group allowing 443 from your VPC | No internet path to your logs |
| Data nodes | 3 or more, e.g. `r7g.large.search` (about $0.178/hour each) | Room for replicas and node failures |
| Zones | Zone awareness with 3 AZs, or **Multi-AZ with standby** | One AZ can fail without losing data |
| Dedicated master nodes | **3** (AWS recommends 3; never an even number) | Cluster management keeps working while data nodes are busy |
| Storage and replicas | gp3 with free space to spare, 1 replica or more | Writes stop when disks are nearly full |
| People | SAML or Cognito sign-in, FGAC roles per team | Each team sees only its own indices |

With the CLI, the differences from Step 2 are mainly `--cluster-config 'InstanceType=r7g.large.search,InstanceCount=3,DedicatedMasterEnabled=true,DedicatedMasterType=m7g.large.search,DedicatedMasterCount=3,ZoneAwarenessEnabled=true,ZoneAwarenessConfig={AvailabilityZoneCount=3}'` and `--vpc-options SubnetIds=…,SecurityGroupIds=…` (subnets and a security group from the [VPC guide](#/tool/aws-vpc)). Size the instances from your daily log volume and retention: [Sizing domains](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/sizing-domains.html) · [Dedicated master nodes](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/managedomains-dedicatedmasternodes.html) · [Multi-AZ domains](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/managedomains-multiaz.html).

For a VPC domain, the Firehose destination also needs a `VpcConfiguration` (`SubnetIds`, `SecurityGroupIds`, `RoleARN`), its role needs extra `ec2:` network-interface permissions, and the subnets need free IP addresses.

### Reaching Dashboards in a private VPC

A VPC domain's endpoint (`DomainStatus.Endpoints.vpc`) answers only inside the VPC. Two common ways in:

1. **Session Manager port forwarding** through a small EC2 instance in the VPC: no SSH and no public IP (see the [Systems Manager guide](#/tool/aws-ssm/step-3-session-manager-a-shell-without-ssh)). Allow port 443 from that instance to the domain's security group, then:

```bash
JUMP_ID=i-0123456789abcdef0     # a private instance managed by Systems Manager
PROD=logs-prod                  # your VPC domain
VPC_ENDPOINT=$(aws opensearch describe-domain --domain-name $PROD --query 'DomainStatus.Endpoints.vpc' --output text)

aws ssm start-session --target $JUMP_ID \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"$VPC_ENDPOINT\"],\"portNumber\":[\"443\"],\"localPortNumber\":[\"8443\"]}"
# keep it running, then open https://localhost:8443/_dashboards in your browser
```

The browser warns about the certificate, because it was issued for the AWS host name, not `localhost`. That is expected for this tunnel.

2. **A VPN** (AWS Client VPN or your company VPN) that routes into the VPC, so the endpoint works directly.

AWS docs: [OpenSearch domains in a VPC](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/vpc.html)

## Alarms that keep the pipeline healthy

> **In simple words:** A log cluster fails quietly: the disk fills up, writes are blocked, and you only notice when you need the logs. A few **CloudWatch alarms** on the domain (namespace `AWS/ES`) and on Firehose warn you first. Alarm basics are in the [CloudWatch guide](#/tool/aws-cloudwatch/step-4-create-a-cpu-alarm-that-emails-you).

| Metric | AWS recommendation | Means |
|---|---|---|
| `ClusterStatus.red` | Maximum >= 1 for 1 minute, 1 time | A primary shard is missing |
| `ClusterStatus.yellow` | Maximum >= 1 for 1 minute, 5 times in a row | A replica is missing (normal on 1 node with replicas) |
| `FreeStorageSpace` | Minimum <= 25% of each node's storage (value in **MiB**) | The disk is filling up |
| `ClusterIndexWritesBlocked` | >= 1 for 5 minutes, 1 time | The cluster refuses writes |
| `JVMMemoryPressure` | Maximum >= 95% for 1 minute, 3 times | Out-of-memory risk: scale up |
| `CPUUtilization` | Maximum >= 80% for 15 minutes, 3 times | Sustained overload: bigger or more nodes |
| Firehose `DeliveryToAmazonOpenSearchService.DataFreshness` | Your choice, e.g. above 900 seconds | Records are waiting too long: delivery is failing |

```bash
EMAIL=you@example.com
TOPIC_ARN=$(aws sns create-topic --name logs-lab-alerts --query TopicArn --output text)
aws sns subscribe --topic-arn $TOPIC_ARN --protocol email --notification-endpoint $EMAIL   # confirm the email

os_alarm() {   # name metric statistic operator threshold period periods
  aws cloudwatch put-metric-alarm --alarm-name "$DOMAIN-$1" \
    --namespace AWS/ES --metric-name "$2" --statistic "$3" \
    --dimensions Name=DomainName,Value=$DOMAIN Name=ClientId,Value=$ACCOUNT_ID \
    --comparison-operator "$4" --threshold "$5" --period "$6" --evaluation-periods "$7" \
    --alarm-actions $TOPIC_ARN
}
os_alarm cluster-red    ClusterStatus.red         Maximum GreaterThanOrEqualToThreshold 1    60  1
os_alarm writes-blocked ClusterIndexWritesBlocked Maximum GreaterThanOrEqualToThreshold 1    300 1
os_alarm low-storage    FreeStorageSpace          Minimum LessThanOrEqualToThreshold    2560 60  1
os_alarm jvm-pressure   JVMMemoryPressure         Maximum GreaterThanOrEqualToThreshold 95   60  3
os_alarm cpu-high       CPUUtilization            Maximum GreaterThanOrEqualToThreshold 80   900 3

aws cloudwatch put-metric-alarm --alarm-name "$STREAM-freshness" \
  --namespace AWS/Firehose --metric-name DeliveryToAmazonOpenSearchService.DataFreshness \
  --dimensions Name=DeliveryStreamName,Value=$STREAM --statistic Maximum \
  --comparison-operator GreaterThanThreshold --threshold 900 --period 300 --evaluation-periods 1 \
  --alarm-actions $TOPIC_ARN
```

`2560` MiB is 25% of the lab's 10 GiB disk. To send alarms to chat as well, see [SNS and SES](#/tool/aws-sns-ses). AWS docs: [Recommended CloudWatch alarms](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/cloudwatch-alarms.html) · [Firehose metrics](https://docs.aws.amazon.com/firehose/latest/dev/monitoring-with-cloudwatch-metrics.html)

## OpenSearch Serverless: the no-cluster option

> **In simple words:** With a **domain** you rent servers and manage their size. With **OpenSearch Serverless** you create a **collection** and AWS adds or removes capacity for you. Firehose can deliver to both. Pick by how steady your log volume is and how much you want to manage.

```compare
🖥️ OpenSearch Service domain | ☁️ OpenSearch Serverless collection
You choose instance types, node count and disks | No nodes: capacity is measured in OCUs and scales automatically
Billed per instance-hour plus EBS storage, even when idle | Billed per OCU-hour (about $0.24) plus storage (about $0.024 per GB-month)
Full control: ISM, shards, plugins, versions | Fewer knobs; the "Time series" collection type is made for logs
Users and roles inside OpenSearch (FGAC) | Access through AWS policies: data access, network and encryption policies
Usually cheapest for steady, predictable volume | Good for spiky or unknown volume, or teams that don't want to run clusters
```

Serverless can have a minimum OCU charge depending on how the collection is set up, so check the [pricing page](https://aws.amazon.com/opensearch-service/pricing/) before using it for a small lab. AWS docs: [What is OpenSearch Serverless?](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/serverless-overview.html)

## Troubleshooting

> **In simple words:** Follow the log line: did it reach **Firehose** (`IncomingRecords`)? Did Firehose reach **OpenSearch** (error log group, S3 failed folder)? Did OpenSearch **accept** it (permissions, mapping, disk)? Can you **see** it (index pattern, time range)?

| Problem | Likely cause | Fix |
|---|---|---|
| Firehose errors with `403` / `no permissions for [indices:data/write/bulk]` | The Firehose role is not mapped in fine-grained access control | Map the role ARN as a backend role (Step 5) and check the index pattern `app-logs*` |
| `DeliveryToAmazonOpenSearchService.AuthFailure` or access denied | The role's IAM policy or the domain access policy doesn't allow `es:ESHttpPost` and `es:ESHttpPut` | Fix both policies (Steps 2 and 4) |
| No index appears | Buffer not flushed yet; records never arrived; delivery failing | Wait 60+ seconds; check `IncomingRecords`; read the `/aws/kinesisfirehose/app-logs-stream` log group and `backup/AmazonOpenSearchService-failed/` in S3 |
| `mapper_parsing_exception` in failed records | Not valid JSON, or a field changed type (e.g. `status` was a number, now text) | Send one JSON document per record, keep field types stable, or fix it with a Lambda transform |
| Cluster **yellow** on a single node | Replicas can't be placed on the same node as their primary | Set replicas to 0 (template, plus `PUT app-logs-*/_settings` with `{"index":{"number_of_replicas":0}}`) or add nodes |
| Cluster **red** | A primary shard is unassigned (disk full, node lost) | `GET _cluster/allocation/explain` and `GET _cat/shards?v`; free disk or add nodes |
| `ClusterIndexWritesBlocked` / `ClusterBlockException` | Storage is almost full, so OpenSearch blocks writes | Delete old indices (ISM), increase the EBS size; writes resume once space is free |
| Dashboards login fails | Wrong password, or the master user is an IAM ARN without Cognito or SAML | Read the secret again, or reset it with **Actions → Edit security configuration** |
| Discover shows nothing | Wrong time range; `@timestamp` mapped as text because the index was made before the template | Widen the time range; tomorrow's index uses the template |
| `curl` times out on a VPC domain | Your laptop is outside the VPC | Use the Session Manager tunnel or a VPN |
| Fluent Bit logs `AccessDeniedException` | The node or pod role lacks `firehose:PutRecordBatch` | Add the permission; check the IRSA annotation or the Pod Identity association |

AWS docs: [Firehose: data not delivered to OpenSearch](https://docs.aws.amazon.com/firehose/latest/dev/data-not-delivered-to-es.html) · [Unassigned shards (re:Post)](https://repost.aws/knowledge-center/opensearch-unassigned-shards)

## Clean up

> **In simple words:** The domain costs money every hour, so delete it first, then the stream, the bucket, the role, the logs, the secret and the alarms. No other guide needs them.

```bash
aws firehose delete-delivery-stream --delivery-stream-name $STREAM
aws opensearch delete-domain --domain-name $DOMAIN --query 'DomainStatus.Deleted'
aws s3 rm s3://$BUCKET --recursive
aws s3api delete-bucket --bucket $BUCKET
aws iam delete-role-policy --role-name $FH_ROLE --policy-name firehose-to-opensearch
aws iam delete-role --role-name $FH_ROLE
aws logs delete-log-group --log-group-name /aws/kinesisfirehose/$STREAM
aws secretsmanager delete-secret --secret-id $SECRET_NAME --force-delete-without-recovery
aws cloudwatch delete-alarms --alarm-names "$DOMAIN-cluster-red" "$DOMAIN-writes-blocked" \
  "$DOMAIN-low-storage" "$DOMAIN-jvm-pressure" "$DOMAIN-cpu-high" "$STREAM-freshness"
aws sns delete-topic --topic-arn $TOPIC_ARN
helm uninstall fluent-bit -n logging        # only if you installed it on EKS
rm -f domain-policy.json firehose-trust.json firehose-policy.json firehose-destination.json ism-policy.json

aws opensearch list-domain-names --query 'DomainNames[].DomainName'   # the domain disappears after a few minutes
```

In real projects, build all of this with **Terraform** (`aws_opensearch_domain` and `aws_kinesis_firehose_delivery_stream`), with the master password in Secrets Manager. See the [Terraform guide](#/tool/terraform).

## Lab and cheat sheet

> **In simple words:** Practice time: build the pipeline, send logs, break it on purpose, read the error, fix it, and clean up.

1. Create the domain and the index template, and check that `_cluster/health` is `green`.
2. Create the bucket, role, FGAC mapping and Firehose stream; send test records with both put-record options.
3. Find the ERROR records in Discover and save the search.
4. **Break it:** delete the mapping (`DELETE _plugins/_security/api/rolesmapping/firehose_writer`), send a record, and find the `403` in the Firehose log group and, after the 5-minute retry, the record under `backup/AmazonOpenSearchService-failed/`. Map the role again.
5. **Break it differently:** send `{"@timestamp":"not-a-date"}` and find the `mapper_parsing_exception`.
6. Create the ISM policy with `min_index_age` of `1d`, and check `_plugins/_ism/explain` the next day.
7. Install Fluent Bit on EC2 (or EKS), find real logs in Discover, create the alarms, then clean up and check that no domain, stream or bucket is left.

### Cheat sheet

| Task | Command |
|---|---|
| Create domain | `aws opensearch create-domain --domain-name D --engine-version OpenSearch_2.19 --cluster-config InstanceType=t3.small.search,InstanceCount=1 …` |
| Cluster health | `curl -u admin:PASS https://ENDPOINT/_cluster/health?pretty` |
| List indices / search | `curl -u admin:PASS "https://ENDPOINT/_cat/indices?v"` · `…/app-logs-*/_search?q=level:ERROR` |
| Map an IAM role | `PUT _plugins/_security/api/rolesmapping/ROLE` with `{"backend_roles":["ROLE_ARN"]}` |
| ISM policy | `PUT _plugins/_ism/policies/ID` · attach: `POST _plugins/_ism/add/INDEX` |
| Create stream | `aws firehose create-delivery-stream --delivery-stream-name S --amazonopensearchservice-destination-configuration file://dest.json` |
| Send a record | `aws firehose put-record --delivery-stream-name S --cli-binary-format raw-in-base64-out --record '{"Data":"{…}"}'` |
| Tunnel to a VPC domain | `aws ssm start-session --target I --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters …` |
| Delete | `aws firehose delete-delivery-stream …` · `aws opensearch delete-domain --domain-name D` |
