# Helm: Deploy an App per Environment

Real applications run in several environments (dev, staging, production) that need the **same app with different settings**: more replicas in prod, debug logging in dev, a different hostname everywhere. With Helm you write the Kubernetes manifests **once** as a chart, and keep one small **values file per environment**. This guide builds a complete chart for the sample app, deploys it to three environments, and covers upgrades, rollbacks, secrets, Argo CD and publishing the chart to ECR.

> **Note:** You need a Kubernetes cluster (the kind cluster from the [Kubernetes guide](#/tool/kubernetes), with ingress-nginx), `kubectl`, `helm` (version 3 or 4), and the **sample app** image from [CI/CD Basics](#/tool/cicd-basics).

## Start here: Helm and environment config in simple words

> **In simple words:** A Helm **chart** is a set of Kubernetes YAML files with blanks in them. A **values file** fills in the blanks. Use the same chart for every environment, and give each environment its own values file with only the settings that differ.

### Watch how it works

```svg Watch it work: one chart plus a values file per environment rendered, linted and installed into three namespaces, then a bad upgrade rolled back. The animation loops.
<svg viewBox="0 0 600 426" role="img" data-anim="helm-environments" aria-label="Animated Helm flow. One chart, three environments: the chart charts/hello-app has templates with blanks such as .Values.replicaCount, and values.yaml fills them with defaults shared by every environment, such as 1 replica and LOG_LEVEL info. Each environment has a small file with only what differs: values-dev.yaml with debug logging, values-staging.yaml with 2 replicas, and values-prod.yaml with 3 to 10 replicas through an HPA and LOG_LEVEL warn. Later files win over values.yaml. Before deploying, helm lint and helm template show the final YAML without touching the cluster. Then helm upgrade --install with -n hello-dev and -f values-dev.yaml creates the release hello-app, revision 1, in the namespace hello-dev on the kind cluster lab. The same command with the staging and prod values files creates the release in hello-staging and hello-prod. Bad upgrade and rollback: helm upgrade with --set image.tag=1.1.0 creates revision 2 in hello-dev. The pods start, but users get errors, and helm history lists revisions 1 and 2. helm rollback hello-app 1 brings back revision 1&#x27;s settings as a new revision 3, and dev is healthy again.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<rect x="8" y="8" width="200" height="324" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="5 4"/>
<rect x="370" y="8" width="222" height="324" rx="12" fill="none" stroke="#3b82f6" stroke-width="1.5" stroke-dasharray="5 4"/>
<rect x="380" y="222" width="202" height="100" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.3" stroke-dasharray="3 4"/>
<polyline points="108,60 222,60 222,296 196,296" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="196,118 222,118" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="196,184 222,184" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="196,240 222,240" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="222,123 294,123" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="294,123 294,212" fill="none" stroke-linejoin="round" stroke="#0ea5e9" stroke-width="1.8" stroke-dasharray="2 3" stroke-opacity=".75"/>
<polyline points="294,123 481,123" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="481,61 364,61 364,185 481,185" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<rect x="14" y="14" width="102.4" height="16" rx="5" class="dg-box"/><text x="18" y="24" font-size="11" class="dg-muted">charts/hello-app</text>
<rect x="376" y="14" width="102.4" height="16" rx="5" class="dg-box"/><text x="380" y="24" font-size="11" class="dg-muted">kind cluster lab</text>
<rect x="386" y="228" width="108.3" height="16" rx="5" class="dg-box"/><text x="390" y="238" font-size="11" class="dg-muted">hello-dev history</text>
<g><rect x="16" y="32" width="184" height="56" rx="12" fill="#0f766e" fill-opacity=".18" stroke="#0f766e" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1182" calcMode="discrete" dur="22s" repeatCount="indefinite"/></rect><rect x="20" y="36" width="176" height="48" rx="9" class="dg-box" stroke="#0f766e" stroke-width="2.2"/><text x="108" y="56.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">templates/</text><text x="108" y="72" text-anchor="middle" font-size="11" class="dg-muted">{{ .Values.x }} blanks</text></g>
<g><rect x="16" y="92" width="184" height="52" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1182" calcMode="discrete" dur="22s" repeatCount="indefinite"/></rect><rect x="20" y="96" width="176" height="44" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="108" y="114.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">values.yaml</text><text x="108" y="130" text-anchor="middle" font-size="11" class="dg-muted">defaults: 1 replica, info</text></g>
<g><rect x="16" y="158" width="184" height="52" rx="12" fill="#0ea5e9" fill-opacity=".18" stroke="#0ea5e9" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.1182;0.2455;0.3636;0.4909" calcMode="discrete" dur="22s" repeatCount="indefinite"/></rect><rect x="20" y="162" width="176" height="44" rx="9" class="dg-box" stroke="#0ea5e9" stroke-width="2.2"/><text x="108" y="180.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">values-dev.yaml</text><text x="108" y="196" text-anchor="middle" font-size="11" class="dg-muted">LOG_LEVEL: debug</text></g>
<g><rect x="16" y="214" width="184" height="52" rx="12" fill="#d97706" fill-opacity=".18" stroke="#d97706" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.1182;0.2455;0.4909;0.6273" calcMode="discrete" dur="22s" repeatCount="indefinite"/></rect><rect x="20" y="218" width="176" height="44" rx="9" class="dg-box" stroke="#d97706" stroke-width="2.2"/><text x="108" y="236.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">values-staging.yaml</text><text x="108" y="252" text-anchor="middle" font-size="11" class="dg-muted">replicaCount: 2</text></g>
<g><rect x="16" y="270" width="184" height="52" rx="12" fill="#7c3aed" fill-opacity=".18" stroke="#7c3aed" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.1182;0.2455;0.4909;0.6273" calcMode="discrete" dur="22s" repeatCount="indefinite"/></rect><rect x="20" y="274" width="176" height="44" rx="9" class="dg-box" stroke="#7c3aed" stroke-width="2.2"/><text x="108" y="292.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">values-prod.yaml</text><text x="108" y="308" text-anchor="middle" font-size="11" class="dg-muted">3–10 replicas (HPA), warn</text></g>
<g><rect x="232" y="92" width="124" height="62" rx="12" fill="#2563eb" fill-opacity=".18" stroke="#2563eb" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1;0;1;0;1" keyTimes="0;0.1182;0.2455;0.4909;0.6273;0.7455;0.8636" calcMode="discrete" dur="22s" repeatCount="indefinite"/></rect><rect x="236" y="96" width="116" height="54" rx="9" class="dg-box" stroke="#2563eb" stroke-width="2.2"/><text x="294" y="119.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">helm</text><text x="294" y="135" text-anchor="middle" font-size="11" class="dg-muted">upgrade --install</text></g>
<g><rect x="232" y="178" width="124" height="68" rx="12" fill="#0d9488" fill-opacity=".18" stroke="#0d9488" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2455;0.3636" calcMode="discrete" dur="22s" repeatCount="indefinite"/></rect><rect x="236" y="182" width="116" height="60" rx="9" class="dg-box" stroke="#0d9488" stroke-width="2.2"/><text x="294" y="201" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">helm template</text><text x="294" y="216.5" text-anchor="middle" font-size="11" class="dg-muted">+ helm lint</text><text x="294" y="231.5" text-anchor="middle" font-size="11" class="dg-muted">no cluster needed</text></g>
<g><rect x="382" y="32" width="198" height="58" rx="12" fill="#0ea5e9" fill-opacity=".18" stroke="#0ea5e9" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.3636;0.4909;0.6273" calcMode="discrete" dur="22s" repeatCount="indefinite"/></rect><rect x="386" y="36" width="190" height="50" rx="9" class="dg-box" stroke="#0ea5e9" stroke-width="2.2"/><text x="481" y="57.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">hello-dev</text><text x="481" y="73" text-anchor="middle" font-size="11" class="dg-muted">1 pod · LOG_LEVEL=debug</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7455;0.8636" calcMode="discrete" dur="22s" repeatCount="indefinite"/><rect x="386" y="36" width="190" height="50" rx="9" fill="#e11d48"/><text x="481" y="65.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">✕ 1.1.0: users get errors</text></g></g>
<rect x="386" y="98" width="190" height="50" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.4909" calcMode="discrete" dur="22s" repeatCount="indefinite"/><rect x="382" y="94" width="198" height="58" rx="12" fill="#d97706" fill-opacity=".18" stroke="#d97706" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4909;0.6273" calcMode="discrete" dur="22s" repeatCount="indefinite"/></rect><rect x="386" y="98" width="190" height="50" rx="9" class="dg-box" stroke="#d97706" stroke-width="2.2"/><text x="481" y="119.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">hello-staging</text><text x="481" y="135" text-anchor="middle" font-size="11" class="dg-muted">2 pods · LOG_LEVEL=info</text></g>
<rect x="386" y="160" width="190" height="50" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.4909" calcMode="discrete" dur="22s" repeatCount="indefinite"/><rect x="382" y="156" width="198" height="58" rx="12" fill="#7c3aed" fill-opacity=".18" stroke="#7c3aed" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4909;0.6273" calcMode="discrete" dur="22s" repeatCount="indefinite"/></rect><rect x="386" y="160" width="190" height="50" rx="9" class="dg-box" stroke="#7c3aed" stroke-width="2.2"/><text x="481" y="181.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">hello-prod</text><text x="481" y="197" text-anchor="middle" font-size="11" class="dg-muted">3–10 pods (HPA) · warn</text></g>
<rect x="390" y="252" width="56" height="46" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.3636" calcMode="discrete" dur="22s" repeatCount="indefinite"/><rect x="386" y="248" width="64" height="54" rx="12" fill="#059669" fill-opacity=".18" stroke="#059669" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.3636;0.4909;0.7455;0.8636" calcMode="discrete" dur="22s" repeatCount="indefinite"/></rect><rect x="390" y="252" width="56" height="46" rx="9" class="dg-box" stroke="#059669" stroke-width="2.2"/><text x="418" y="271.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">rev 1</text><text x="418" y="287" text-anchor="middle" font-size="11" class="dg-muted">1.0.0</text></g>
<rect x="456" y="252" width="56" height="46" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.6273" calcMode="discrete" dur="22s" repeatCount="indefinite"/><rect x="452" y="248" width="64" height="54" rx="12" fill="#d97706" fill-opacity=".18" stroke="#d97706" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6273;0.8636" calcMode="discrete" dur="22s" repeatCount="indefinite"/></rect><rect x="456" y="252" width="56" height="46" rx="9" class="dg-box" stroke="#d97706" stroke-width="2.2"/><text x="484" y="271.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">rev 2</text><text x="484" y="287" text-anchor="middle" font-size="11" class="dg-muted">1.1.0</text><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.7455" calcMode="discrete" dur="22s" repeatCount="indefinite"/><rect x="456" y="252" width="56" height="46" rx="9" fill="#e11d48"/><text x="484" y="279.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">✕ 1.1.0</text></g></g>
<rect x="522" y="252" width="56" height="46" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.8636" calcMode="discrete" dur="22s" repeatCount="indefinite"/><rect x="518" y="248" width="64" height="54" rx="12" fill="#059669" fill-opacity=".18" stroke="#059669" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8636" calcMode="discrete" dur="22s" repeatCount="indefinite"/></rect><rect x="522" y="252" width="56" height="46" rx="9" class="dg-box" stroke="#059669" stroke-width="2.2"/><text x="550" y="271.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">rev 3</text><text x="550" y="287" text-anchor="middle" font-size="11" class="dg-muted">1.0.0</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.3636;0.6273;0.8636" calcMode="discrete" dur="22s" repeatCount="indefinite"/><circle cx="576" cy="36" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M571.5,36 L575,39.5 L580.5,32.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.4909" calcMode="discrete" dur="22s" repeatCount="indefinite"/><circle cx="576" cy="98" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M571.5,98 L575,101.5 L580.5,94.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.4909" calcMode="discrete" dur="22s" repeatCount="indefinite"/><circle cx="576" cy="160" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M571.5,160 L575,163.5 L580.5,156.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2455;0.3636" calcMode="discrete" dur="22s" repeatCount="indefinite"/><circle cx="352" cy="182" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M347.5,182 L351,185.5 L356.5,178.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0071;0.1016" calcMode="discrete" dur="22s" repeatCount="indefinite"/><animateMotion path="M108,60 L222,60 L222,123 L294,123" keyPoints="0;0;1;1" keyTimes="0;0.0071;0.1016;1" calcMode="linear" dur="22s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0071;0.1016" calcMode="discrete" dur="22s" repeatCount="indefinite"/><animateMotion path="M108,118 L222,118 L222,123 L294,123" keyPoints="0;0;1;1" keyTimes="0;0.0071;0.1016;1" calcMode="linear" dur="22s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1258;0.2276" calcMode="discrete" dur="22s" repeatCount="indefinite"/><animateMotion path="M108,184 L222,184 L222,123 L294,123" keyPoints="0;0;1;1" keyTimes="0;0.1258;0.2276;1" calcMode="linear" dur="22s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1258;0.2276" calcMode="discrete" dur="22s" repeatCount="indefinite"/><animateMotion path="M108,240 L222,240 L222,123 L294,123" keyPoints="0;0;1;1" keyTimes="0;0.1258;0.2276;1" calcMode="linear" dur="22s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1258;0.2276" calcMode="discrete" dur="22s" repeatCount="indefinite"/><animateMotion path="M108,296 L222,296 L222,123 L294,123" keyPoints="0;0;1;1" keyTimes="0;0.1258;0.2276;1" calcMode="linear" dur="22s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2525;0.3471" calcMode="discrete" dur="22s" repeatCount="indefinite"/><animateMotion path="M294,123 L294,212" keyPoints="0;0;1;1" keyTimes="0;0.2525;0.3471;1" calcMode="linear" dur="22s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.37;0.4171" calcMode="discrete" dur="22s" repeatCount="indefinite"/><animateMotion path="M108,184 L222,184 L222,123 L294,123" keyPoints="0;0;1;1" keyTimes="0;0.37;0.4171;1" calcMode="linear" dur="22s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4247;0.4782" calcMode="discrete" dur="22s" repeatCount="indefinite"/><animateMotion path="M294,123 L364,123 L364,61 L481,61" keyPoints="0;0;1;1" keyTimes="0;0.4247;0.4782;1" calcMode="linear" dur="22s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4977;0.5482" calcMode="discrete" dur="22s" repeatCount="indefinite"/><animateMotion path="M108,240 L222,240 L222,123 L294,123" keyPoints="0;0;1;1" keyTimes="0;0.4977;0.5482;1" calcMode="linear" dur="22s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4977;0.5482" calcMode="discrete" dur="22s" repeatCount="indefinite"/><animateMotion path="M108,296 L222,296 L222,123 L294,123" keyPoints="0;0;1;1" keyTimes="0;0.4977;0.5482;1" calcMode="linear" dur="22s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5564;0.6136" calcMode="discrete" dur="22s" repeatCount="indefinite"/><animateMotion path="M294,123 L481,123" keyPoints="0;0;1;1" keyTimes="0;0.5564;0.6136;1" calcMode="linear" dur="22s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5564;0.6136" calcMode="discrete" dur="22s" repeatCount="indefinite"/><animateMotion path="M294,123 L364,123 L364,185 L481,185" keyPoints="0;0;1;1" keyTimes="0;0.5564;0.6136;1" calcMode="linear" dur="22s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6344;0.7289" calcMode="discrete" dur="22s" repeatCount="indefinite"/><animateMotion path="M294,123 L364,123 L364,61 L481,61" keyPoints="0;0;1;1" keyTimes="0;0.6344;0.7289;1" calcMode="linear" dur="22s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8718;0.9809" calcMode="discrete" dur="22s" repeatCount="indefinite"/><animateMotion path="M294,123 L364,123 L364,61 L481,61" keyPoints="0;0;1;1" keyTimes="0;0.8718;0.9809;1" calcMode="linear" dur="22s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(21.2,350.5) scale(.8)"><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g><text x="33.4" y="354">templates + values</text><g transform="translate(156.6,350.5) scale(.8)"><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g><text x="168" y="354">helm command</text><g transform="translate(257.6,350.5) scale(.8)"><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g><text x="269" y="354">render and check</text></g>
<rect x="12" y="366" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="366" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="22s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1182" calcMode="discrete" dur="22s" repeatCount="indefinite"/><circle cx="36" cy="394" r="14" fill="#2563eb"/><text x="36" y="399" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="389" font-size="14" font-weight="800" fill="#2563eb">One chart, written once</text><text x="578" y="389" text-anchor="end" font-size="10.5" class="dg-muted">One chart, three envs · 1/8</text><text x="60" y="410" font-size="12.5" class="dg-text">Templates have {{ .Values.x }} blanks. values.yaml fills in the defaults.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1182;0.2455" calcMode="discrete" dur="22s" repeatCount="indefinite"/><circle cx="36" cy="394" r="14" fill="#2563eb"/><text x="36" y="399" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="389" font-size="14" font-weight="800" fill="#2563eb">Each environment adds only what differs</text><text x="578" y="389" text-anchor="end" font-size="10.5" class="dg-muted">One chart, three envs · 2/8</text><text x="60" y="410" font-size="12.5" class="dg-text">values-dev.yaml says LOG_LEVEL: debug. Later files win over values.yaml.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2455;0.3636" calcMode="discrete" dur="22s" repeatCount="indefinite"/><circle cx="36" cy="394" r="14" fill="#2563eb"/><text x="36" y="399" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="389" font-size="14" font-weight="800" fill="#2563eb">Render and lint before deploying</text><text x="578" y="389" text-anchor="end" font-size="10.5" class="dg-muted">One chart, three envs · 3/8</text><text x="60" y="410" font-size="12.5" class="dg-text">helm lint and helm template show the final YAML. The cluster is untouched.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3636;0.4909" calcMode="discrete" dur="22s" repeatCount="indefinite"/><circle cx="36" cy="394" r="14" fill="#2563eb"/><text x="36" y="399" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="389" font-size="14" font-weight="800" fill="#2563eb">helm upgrade --install into hello-dev</text><text x="578" y="389" text-anchor="end" font-size="10.5" class="dg-muted">One chart, three envs · 4/8</text><text x="60" y="410" font-size="12.5" class="dg-text">-f values-dev.yaml creates release hello-app, revision 1, in hello-dev.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4909;0.6273" calcMode="discrete" dur="22s" repeatCount="indefinite"/><circle cx="36" cy="394" r="14" fill="#2563eb"/><text x="36" y="399" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="389" font-size="14" font-weight="800" fill="#2563eb">The same command for staging and prod</text><text x="578" y="389" text-anchor="end" font-size="10.5" class="dg-muted">One chart, three envs · 5/8</text><text x="60" y="410" font-size="12.5" class="dg-text">Only the namespace and the values file change. Each gets its own release.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6273;0.7455" calcMode="discrete" dur="22s" repeatCount="indefinite"/><circle cx="36" cy="394" r="14" fill="#e11d48"/><text x="36" y="399" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="389" font-size="14" font-weight="800" fill="#e11d48">Upgrade dev to 1.1.0</text><text x="578" y="389" text-anchor="end" font-size="10.5" class="dg-muted">Bad upgrade, rollback · 6/8</text><text x="60" y="410" font-size="12.5" class="dg-text">helm upgrade … --set image.tag=1.1.0 creates revision 2 in hello-dev.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7455;0.8636" calcMode="discrete" dur="22s" repeatCount="indefinite"/><circle cx="36" cy="394" r="14" fill="#e11d48"/><text x="36" y="399" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="389" font-size="14" font-weight="800" fill="#e11d48">Revision 2 is broken</text><text x="578" y="389" text-anchor="end" font-size="10.5" class="dg-muted">Bad upgrade, rollback · 7/8</text><text x="60" y="410" font-size="12.5" class="dg-text">The pods start, but users get errors. helm history lists revisions 1 and 2.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8636" calcMode="discrete" dur="22s" repeatCount="indefinite"/><circle cx="36" cy="394" r="14" fill="#e11d48"/><text x="36" y="399" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="389" font-size="14" font-weight="800" fill="#e11d48">helm rollback hello-app 1 -n hello-dev</text><text x="578" y="389" text-anchor="end" font-size="10.5" class="dg-muted">Bad upgrade, rollback · 8/8</text><text x="60" y="410" font-size="12.5" class="dg-text">Revision 1&#x27;s settings come back as a new revision 3. Dev is healthy again.</text></g>
</svg>
```

### How the pieces fit

```text
                    charts/hello-app/
 templates/*.yaml   (Deployment, Service, Ingress, ConfigMap, HPA … with {{ .Values.x }} blanks)
        +
 values.yaml        (defaults shared by every environment)
        +
 values-dev.yaml  │ values-staging.yaml │ values-prod.yaml   (only what differs)
        │                  │                     │
   helm upgrade       helm upgrade          helm upgrade
        ▼                  ▼                     ▼
  namespace hello-dev  hello-staging         hello-prod
  1 replica, debug     2 replicas, info      3–10 replicas (HPA), warn, secret, TLS
```

### A real-life comparison

Think of a **form letter**: one letter template with blanks such as *Dear ___, your order ___*. Each customer gets the same letter with different details filled in. The chart is the template, and each environment's values file holds the details.

### Key words

| Word | Simple meaning |
|---|---|
| **Chart** | A folder with `Chart.yaml`, `values.yaml` and `templates/`, describing one app |
| **Template** | A Kubernetes YAML file with placeholders like `{{ .Values.replicaCount }}` |
| **Values** | The settings that fill the placeholders |
| **Release** | One installed copy of a chart, with a name, in a namespace (e.g. `hello-app` in `hello-prod`) |
| **Revision** | Each install or upgrade of a release gets a number, which makes rollback possible |
| **Override** | A later values file (or `--set`) replacing a setting from an earlier one |

### Check yourself

1. Why not copy the YAML files once per environment instead?
2. If `values.yaml` says `replicaCount: 1` and `values-prod.yaml` says `3`, which wins in prod?
3. What is a release?

> **Tip:** Answers: 1) Copies drift apart. A fix made in one copy gets forgotten in the others, and with a chart every environment shares the same templates. 2) `values-prod.yaml`, because later files override earlier ones. 3) One installed instance of a chart, in a namespace, with its own revision history.

## Chart layout

> **In simple words:** One folder holds everything: the chart description, the shared defaults, one file per environment, and the templates.

```text
charts/hello-app/
├── Chart.yaml                 name, chart version, app version
├── values.yaml                defaults for ALL environments
├── values-dev.yaml            dev overrides
├── values-staging.yaml        staging overrides
├── values-prod.yaml           prod overrides
└── templates/
    ├── _helpers.tpl           reusable snippets: names and labels
    ├── configmap.yaml         non-secret settings → environment variables
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml           only if ingress.enabled
    ├── hpa.yaml               only if autoscaling.enabled
    ├── serviceaccount.yaml
    └── NOTES.txt              message printed after install
```

```bash
mkdir -p ~/code/hello-app/charts/hello-app/templates && cd ~/code/hello-app
```

> **Tip:** `helm create hello-app` generates a similar skeleton. Writing the files yourself (below) means you understand every line before you rely on it.

## Write the chart: Chart.yaml and default values

> **In simple words:** `Chart.yaml` names the chart and its versions. `values.yaml` holds the safe defaults every environment starts from, so environment files stay short.

`charts/hello-app/Chart.yaml`:

```yaml
apiVersion: v2
name: hello-app
description: Sample web app deployed with environment-specific values
type: application
version: 0.1.0          # chart version: bump when templates change
appVersion: "1.0.0"     # app version: the default image tag
```

`charts/hello-app/values.yaml`:

```yaml
# Defaults shared by every environment. Environment files override only what differs.
environment: base

replicaCount: 1

image:
  repository: hello-app
  tag: ""                       # empty = use appVersion from Chart.yaml
  pullPolicy: IfNotPresent

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  create: true
  name: ""
  annotations: {}               # e.g. eks.amazonaws.com/role-arn for IRSA

containerPort: 8000

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: false
  className: nginx
  host: ""
  annotations: {}
  tls: []                       # e.g. [{ secretName: hello-tls, hosts: [hello.example.com] }]

# Non-secret settings: rendered into a ConfigMap and exposed as environment variables
config:
  LOG_LEVEL: info
  FEATURE_NEW_UI: "false"

# Name of a Secret created OUTSIDE the chart; its keys become environment variables
existingSecret: ""

resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    memory: 128Mi

autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70

probes:
  path: /health

podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000               # the sample image's non-root user

podAnnotations: {}
nodeSelector: {}
tolerations: []
affinity: {}
```

## Write the chart: templates

> **In simple words:** Templates are ordinary Kubernetes YAML with `{{ }}` placeholders. `_helpers.tpl` defines names and labels once, so every template uses the same ones.

`charts/hello-app/templates/_helpers.tpl`:

```text
{{- define "hello-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "hello-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "hello-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "hello-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "hello-app.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "hello-app.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
environment: {{ .Values.environment }}
{{- end }}

{{- define "hello-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "hello-app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
```

`charts/hello-app/templates/configmap.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "hello-app.fullname" . }}
  labels:
    {{- include "hello-app.labels" . | nindent 4 }}
data:
  APP_ENV: {{ .Values.environment | quote }}
  {{- range $key, $value := .Values.config }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
```

`charts/hello-app/templates/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "hello-app.fullname" . }}
  labels:
    {{- include "hello-app.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "hello-app.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "hello-app.selectorLabels" . | nindent 8 }}
      annotations:
        # restart pods automatically when the config changes
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      serviceAccountName: {{ include "hello-app.serviceAccountName" . }}
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.containerPort }}
          env:
            - name: APP_VERSION
              value: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
          envFrom:
            - configMapRef:
                name: {{ include "hello-app.fullname" . }}
            {{- if .Values.existingSecret }}
            - secretRef:
                name: {{ .Values.existingSecret }}
            {{- end }}
          readinessProbe:
            httpGet:
              path: {{ .Values.probes.path }}
              port: http
          livenessProbe:
            httpGet:
              path: {{ .Values.probes.path }}
              port: http
            initialDelaySeconds: 10
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          securityContext:
            allowPrivilegeEscalation: false
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

`charts/hello-app/templates/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "hello-app.fullname" . }}
  labels:
    {{- include "hello-app.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  selector:
    {{- include "hello-app.selectorLabels" . | nindent 4 }}
  ports:
    - name: http
      port: {{ .Values.service.port }}
      targetPort: http
```

`charts/hello-app/templates/ingress.yaml`:

```yaml
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "hello-app.fullname" . }}
  labels:
    {{- include "hello-app.labels" . | nindent 4 }}
  {{- with .Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  ingressClassName: {{ .Values.ingress.className }}
  {{- with .Values.ingress.tls }}
  tls:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  rules:
    - host: {{ required "ingress.host is required when ingress.enabled is true" .Values.ingress.host | quote }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ include "hello-app.fullname" . }}
                port:
                  name: http
{{- end }}
```

`charts/hello-app/templates/hpa.yaml`:

```yaml
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "hello-app.fullname" . }}
  labels:
    {{- include "hello-app.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "hello-app.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
{{- end }}
```

`charts/hello-app/templates/serviceaccount.yaml`:

```yaml
{{- if .Values.serviceAccount.create }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "hello-app.serviceAccountName" . }}
  labels:
    {{- include "hello-app.labels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
```

`charts/hello-app/templates/NOTES.txt`:

```text
{{ .Chart.Name }} {{ .Values.image.tag | default .Chart.AppVersion }} is deployed to namespace {{ .Release.Namespace }} ({{ .Values.environment }}).

Try it:
  kubectl -n {{ .Release.Namespace }} port-forward svc/{{ include "hello-app.fullname" . }} 8080:{{ .Values.service.port }}
  curl http://localhost:8080/
{{- if .Values.ingress.enabled }}
  or open http://{{ .Values.ingress.host }}/
{{- end }}
```

| Template trick | What it does |
|---|---|
| `{{- include "hello-app.labels" . \| nindent 4 }}` | Reuses the label block, indented 4 spaces |
| `{{- if .Values.ingress.enabled }}` | Creates the resource only when switched on |
| `{{ .Values.image.tag \| default .Chart.AppVersion }}` | Falls back to the chart's app version when no tag is given |
| `required "…" .Values.ingress.host` | Stops with a clear error if a mandatory value is missing |
| `checksum/config` annotation | Changes when the ConfigMap changes, so pods restart and pick up new settings |
| `{{- with .Values.x }} … {{- end }}` | Adds a block only if the value isn't empty |

## Environment-specific values

> **In simple words:** Each environment file lists only the settings that differ from the defaults. Reading three short files tells you exactly how the environments differ.

`charts/hello-app/values-dev.yaml`:

```yaml
environment: dev
replicaCount: 1
image:
  tag: "1.0.0"
config:
  LOG_LEVEL: debug
  FEATURE_NEW_UI: "true"        # try new features in dev first
resources:
  requests:
    cpu: 25m
    memory: 64Mi
ingress:
  enabled: true
  host: hello-dev.localtest.me
```

`charts/hello-app/values-staging.yaml`:

```yaml
environment: staging
replicaCount: 2
image:
  tag: "1.0.0"
config:
  LOG_LEVEL: info
  FEATURE_NEW_UI: "true"
ingress:
  enabled: true
  host: hello-staging.localtest.me
```

`charts/hello-app/values-prod.yaml`:

```yaml
environment: prod
image:
  tag: "1.0.0"                   # promoted only after staging passes
config:
  LOG_LEVEL: warn
  FEATURE_NEW_UI: "false"        # not released to production yet
existingSecret: hello-secrets    # created separately, never stored in Git
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    memory: 256Mi
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
affinity:
  podAntiAffinity:               # spread pods across nodes
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          topologyKey: kubernetes.io/hostname
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: hello-app
ingress:
  enabled: true
  host: hello.localtest.me
  # on EKS with a real domain, for example:
  # className: alb
  # host: hello.example.com
  # annotations:
  #   alb.ingress.kubernetes.io/scheme: internal
  #   alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...
```

How the environments end up different:

| Setting | dev | staging | prod |
|---|---|---|---|
| Replicas | 1 | 2 | 3–10 (autoscaled) |
| `LOG_LEVEL` | debug | info | warn |
| `FEATURE_NEW_UI` | true | true | false |
| CPU / memory request | 25m / 64Mi | 50m / 64Mi (default) | 100m / 128Mi |
| Secret | none | none | `hello-secrets` |
| Spread across nodes | no | no | yes |
| Host | hello-dev.localtest.me | hello-staging.localtest.me | hello.localtest.me |

**How Helm merges values:** files are applied left to right (`-f values.yaml -f values-prod.yaml`), and later files win. **Maps merge** key by key (the `config` map in prod keeps keys it doesn't mention). **Lists are replaced** whole. `--set key=value` beats every file. `values.yaml` inside the chart is always loaded first, automatically.

## Render and lint before deploying

> **In simple words:** Helm can show you the final YAML for any environment **without touching the cluster**. Always look at it before deploying. Most mistakes are visible right there.

```bash
cd ~/code/hello-app
CHART=charts/hello-app

helm lint $CHART -f $CHART/values-dev.yaml
helm lint $CHART -f $CHART/values-prod.yaml

# full rendered output for one environment
helm template hello-app $CHART -n hello-prod -f $CHART/values-prod.yaml | less

# exactly what differs between dev and prod
diff <(helm template hello-app $CHART -f $CHART/values-dev.yaml) \
     <(helm template hello-app $CHART -f $CHART/values-prod.yaml)

# just the effective values for an environment
helm template hello-app $CHART -f $CHART/values-prod.yaml --show-only templates/configmap.yaml
```

> **Tip:** The **helm-diff** plugin (`helm plugin install https://github.com/databus23/helm-diff`) shows what an upgrade *would* change in the cluster: `helm diff upgrade hello-app $CHART -n hello-prod -f $CHART/values-prod.yaml`.

## Deploy to dev, staging and prod

> **In simple words:** The same command deploys every environment. Only the namespace and the values file change. `upgrade --install` installs the first time and upgrades after that.

Load the sample image into kind (built in [CI/CD Basics](#/tool/cicd-basics) as `hello-app:local`):

```bash
docker tag hello-app:local hello-app:1.0.0
kind load docker-image hello-app:1.0.0 --name lab
```

Prod expects a Secret. Create it outside the chart, so it never lands in Git:

```bash
kubectl create namespace hello-prod
kubectl create secret generic hello-secrets -n hello-prod --from-literal=DB_PASSWORD='change-me'
```

Deploy all three. In Helm 4, use `--rollback-on-failure`; in Helm 3 the same flag is called `--atomic`:

```bash
for ENV in dev staging prod; do
  helm upgrade --install hello-app $CHART \
    --namespace hello-$ENV --create-namespace \
    -f $CHART/values-$ENV.yaml \
    --wait --timeout 5m --rollback-on-failure
done

helm list -A
kubectl get deploy,hpa,ingress -n hello-prod
```

Check that each environment really got its own settings:

```bash
for ENV in dev staging prod; do
  echo "== $ENV"
  kubectl -n hello-$ENV exec deploy/hello-app -- sh -c 'echo "APP_ENV=$APP_ENV LOG_LEVEL=$LOG_LEVEL FEATURE_NEW_UI=$FEATURE_NEW_UI"'
  HOST=$([ "$ENV" = prod ] && echo hello.localtest.me || echo "hello-$ENV.localtest.me")
  curl -s "http://$HOST/"; echo
done
kubectl -n hello-prod exec deploy/hello-app -- sh -c 'test -n "$DB_PASSWORD" && echo "secret mounted"'
```

The prod URL is `hello.localtest.me`; dev and staging use `hello-dev.` and `hello-staging.`. `*.localtest.me` resolves to `127.0.0.1`, so with kind's port 80 mapping all three open in your browser.

## Upgrade, history and rollback

> **In simple words:** Every `helm upgrade` creates a new numbered revision. If a release goes wrong, Helm can roll back to any earlier revision with one command.

Release a new version to dev only, without editing files:

```bash
docker tag hello-app:local hello-app:1.1.0 && kind load docker-image hello-app:1.1.0 --name lab

helm upgrade hello-app $CHART -n hello-dev -f $CHART/values-dev.yaml \
  --set image.tag=1.1.0 --wait --rollback-on-failure

helm history hello-app -n hello-dev
helm get values hello-app -n hello-dev            # the values in effect (including --set)
helm get manifest hello-app -n hello-dev | head -40
```

Roll back:

```bash
helm rollback hello-app 1 -n hello-dev --wait      # back to revision 1
helm history hello-app -n hello-dev               # rollback is recorded as a NEW revision
```

**Change config only:** edit `LOG_LEVEL` in `values-staging.yaml` and run the same `helm upgrade`. The `checksum/config` annotation changes, so the pods restart with the new value, with no image change needed.

| Flag | Why |
|---|---|
| `--wait` | Don't report success until pods are actually ready |
| `--timeout 5m` | How long `--wait` may take |
| `--rollback-on-failure` (Helm 3: `--atomic`) | If the upgrade fails or times out, return to the previous revision automatically |
| `--set image.tag=…` | One-off override, ideal for CI deploying a fresh build to dev |

## Secrets per environment

> **In simple words:** Never put passwords in values files: they end up in Git. The chart only **names** a Secret (`existingSecret`), and each environment's Secret is created separately: by hand, by a secrets operator, or by your pipeline.

| Option | How | Good for |
|---|---|---|
| `kubectl create secret` | As in the deploy step, per namespace | Learning, small teams |
| **External Secrets Operator** | An `ExternalSecret` resource pulls values from AWS Secrets Manager or SSM into a Kubernetes Secret | Production on AWS (recommended) |
| **Sealed Secrets** / **SOPS** | Encrypted secrets that *are* safe to commit | GitOps without an external vault |

Example `ExternalSecret` that creates `hello-secrets` in prod from AWS Secrets Manager (with the operator installed and a `ClusterSecretStore` named `aws-secrets-manager`):

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: hello-secrets
  namespace: hello-prod
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: aws-secrets-manager
  target:
    name: hello-secrets
  data:
    - secretKey: DB_PASSWORD
      remoteRef:
        key: prod/hello-app
        property: db_password
```

## Deploy every environment with Argo CD

> **In simple words:** Instead of running `helm upgrade` by hand, put the chart in Git and let Argo CD deploy one Application per environment, each using its own values file. An **ApplicationSet** creates all three from one definition.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: hello-app
  namespace: argocd
spec:
  goTemplate: true
  generators:
    - list:
        elements:
          - env: dev
          - env: staging
          - env: prod
  template:
    metadata:
      name: 'hello-app-{{.env}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/your-org/gitops.git     # CHANGE: repo containing charts/hello-app
        targetRevision: main
        path: charts/hello-app
        helm:
          releaseName: hello-app
          valueFiles:
            - values.yaml
            - 'values-{{.env}}.yaml'
      destination:
        server: https://kubernetes.default.svc
        namespace: 'hello-{{.env}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

**Promotion becomes a pull request:** CI (or a developer) changes `image.tag` in `values-staging.yaml`; after testing, the same tag is copied into `values-prod.yaml`. Argo CD deploys each change, and Git records who promoted what and when.

Many teams keep production on **manual sync**. Use a separate Application for prod, or the ApplicationSet `templatePatch` field to drop `automated` for the `prod` element. See the [Argo CD guide](#/tool/argocd) and the [Argo CD on EKS runbook](#/tool/argocd-eks).

## Package and publish the chart to ECR

> **In simple words:** Charts can be stored in a registry just like Docker images. Amazon ECR supports Helm charts (OCI format), so other teams and Argo CD can install a specific chart version without cloning your repo.

```bash
export AWS_REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY=$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

aws ecr create-repository --repository-name charts/hello-app --region $AWS_REGION
aws ecr get-login-password --region $AWS_REGION | helm registry login --username AWS --password-stdin $REGISTRY

helm package charts/hello-app                      # → hello-app-0.1.0.tgz (version from Chart.yaml)
helm push hello-app-0.1.0.tgz oci://$REGISTRY/charts

# install straight from the registry, still with an environment file
helm upgrade --install hello-app oci://$REGISTRY/charts/hello-app --version 0.1.0 \
  -n hello-staging -f charts/hello-app/values-staging.yaml --wait
```

Bump `version` in `Chart.yaml` every time the templates change. Chart versions should be immutable, just like image tags.

## Troubleshooting

> **In simple words:** Render the chart first (`helm template`), then compare what's running (`helm get values` / `helm get manifest`). Most problems are a value that didn't apply the way you expected.

| Problem | Fix |
|---|---|
| `Error: INSTALLATION FAILED: … context deadline exceeded` | Pods never became ready within `--timeout`. Check `kubectl describe pod` and logs. With `--rollback-on-failure`, Helm has already rolled back |
| `UPGRADE FAILED: another operation … is in progress` | A previous release is stuck `pending-upgrade`. Run `helm history`, then `helm rollback <release> <last-good-revision>` |
| A value "doesn't apply" | Wrong file order, or an indentation mistake in the values file. Check with `helm get values <release> -n <ns> --all` |
| `nil pointer evaluating interface {}` | A template reads a nested value that doesn't exist. Add it to `values.yaml` with a default |
| `ingress.host is required…` | That's the `required` check working. Set the host in that environment's file |
| `CreateContainerConfigError` | Missing ConfigMap or Secret (e.g. `hello-secrets` not created in that namespace), or `runAsNonRoot` with an image whose user isn't numeric |
| Config changed but pods didn't restart | The `checksum/config` annotation is missing from the Deployment template |
| HPA shows `<unknown>` targets | `metrics-server` isn't installed, or the container has no CPU request |
| `helm push` → `401 Unauthorized` | The `helm registry login` token expired (12 hours). Log in again |

```bash
helm status hello-app -n hello-prod
helm get values hello-app -n hello-prod --all
helm template hello-app $CHART -f $CHART/values-prod.yaml --debug | less
```

## Clean up, lab and cheat sheet

> **In simple words:** Remove the releases and namespaces, then practise building and promoting a change through all three environments yourself.

```bash
for ENV in dev staging prod; do helm uninstall hello-app -n hello-$ENV; kubectl delete namespace hello-$ENV; done
```

### Lab: promote a change through every environment

1. Create the chart and the three values files, and confirm `helm lint` passes for each environment.
2. Show the differences between dev and prod with `helm template` and `diff`.
3. Deploy all three environments and verify `APP_ENV`, `LOG_LEVEL` and the replica counts.
4. Add a new setting `CACHE_TTL` (default `60`, prod `300`). Deploy it and check that the pods restarted on their own.
5. Release image `1.1.0` to dev with `--set`, then to staging by editing its values file, then to prod.
6. Roll prod back to the previous revision and confirm the old version is serving.
7. Package the chart, push it to ECR, and deploy staging from the registry.
8. Bonus: replace the manual commands with the Argo CD ApplicationSet.

### Cheat sheet

| Task | Command |
|---|---|
| Lint for an environment | `helm lint CHART -f CHART/values-prod.yaml` |
| See final YAML | `helm template REL CHART -f CHART/values-prod.yaml` |
| Install or upgrade | `helm upgrade --install REL CHART -n NS --create-namespace -f values-ENV.yaml --wait` |
| One-off override | `--set image.tag=1.1.0` |
| What's deployed | `helm list -A` / `helm get values REL -n NS --all` |
| History / rollback | `helm history REL -n NS` / `helm rollback REL N -n NS` |
| Remove | `helm uninstall REL -n NS` |
| Publish to ECR | `helm package CHART && helm push CHART-x.y.z.tgz oci://REGISTRY/charts` |
