# Linux Fundamentals

Almost every server, container, and Kubernetes node you touch runs Linux. You don't need to be a kernel expert. You do need to move around the filesystem, read logs, manage processes and services, understand permissions, and write small scripts without thinking twice. This guide covers exactly that.

> **Tip:** No setup yet? Open the [Practice lab](#/lab) and click **Start Linux** to get a real Linux terminal right in your browser. It runs almost every command in this guide. The exceptions are `apt`, `systemctl` and networking, which need a full machine: WSL Ubuntu or the lab's cloud machine.

## Start here: Linux in simple words

> **In simple words:** Linux is the software that runs most of the world's servers, the computers behind websites and apps. Learning Linux means learning to talk to those servers by typing commands.

### Watch how it works

```svg Watch it work: an SSH login, a command becoming a process that the kernel checks, a denied file, and systemd starting, restarting and logging a service. The animation loops.
<svg viewBox="0 0 600 372" role="img" data-anim="linux" data-dur="42.5" data-starts="0 4.42 9.18 13.6 18.7 23.8 28.56 32.98 37.4" aria-label="Animated Linux server. Log in with SSH: from your laptop, ssh -i ~/.ssh/mykey.pem ubuntu@203.0.113.10 connects to the sshd program on port 22 of the server. sshd checks that your key matches a public key in the user&#x27;s ~/.ssh/authorized_keys file, then starts a bash shell for the user ubuntu. Run a command: you type ls -l /var/www/html, and bash starts a new process with its own PID. The process asks the Linux kernel to read the folder; the kernel checks the permissions, you are allowed, and the list comes back to your screen. Then you try cat /etc/shadow: normal users cannot read the password hashes, so the kernel answers Permission denied; sudo would run it as root. Run a service: sudo systemctl enable --now myapp asks systemd to start the service, which runs python3 on port 9000, now and after every reboot. The app crashes; because of Restart=on-failure, systemd starts it again by itself. Everything the app printed went to journald, so systemctl status myapp and journalctl -u myapp show you what happened.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<rect x="128" y="8" width="464" height="268" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="5 4"/>
<polyline points="62,66 208,66 360,66 512,66" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="512,66 512,151 512,237" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="1.6" stroke-opacity=".8"/>
<polyline points="330,66 330,108 208,108 208,151" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="208,151 208,237" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="1.6" stroke-opacity=".8"/>
<polyline points="208,237 360,237" fill="none" stroke-linejoin="round" stroke="#64748b" stroke-width="1.8" stroke-dasharray="4 3" stroke-opacity=".7"/>
<polyline points="390,237 390,66" fill="none" stroke-linejoin="round" stroke="#64748b" stroke-width="1.8" stroke-dasharray="4 3" stroke-opacity=".7"/>
<rect x="134" y="14" width="173.2" height="16" rx="5" class="dg-box"/><text x="138" y="24" font-size="11" class="dg-muted">Server 203.0.113.10 · Ubuntu</text>
<g><rect x="8" y="36" width="108" height="60" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.104" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/></rect><rect x="12" y="40" width="100" height="52" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="62" y="62.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Your laptop</text><text x="62" y="78" text-anchor="middle" font-size="11" class="dg-muted">ssh ubuntu@…</text></g>
<g><rect x="136" y="36" width="144" height="60" rx="12" fill="#6366f1" fill-opacity=".18" stroke="#6366f1" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.216" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/></rect><rect x="140" y="40" width="136" height="52" rx="9" class="dg-box" stroke="#6366f1" stroke-width="2.2"/><text x="208" y="62.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">sshd</text><text x="208" y="78" text-anchor="middle" font-size="11" class="dg-muted">port 22</text></g>
<g><rect x="288" y="36" width="144" height="60" rx="12" fill="#a855f7" fill-opacity=".18" stroke="#a855f7" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0;1" keyTimes="0;0.104;0.32;0.56;0.672;0.88" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/></rect><rect x="292" y="40" width="136" height="52" rx="9" class="dg-box" stroke="#a855f7" stroke-width="2.2"/><text x="360" y="62.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">bash shell</text><text x="360" y="78" text-anchor="middle" font-size="11" class="dg-muted">user ubuntu</text></g>
<g><rect x="440" y="36" width="144" height="60" rx="12" fill="#0ea5e9" fill-opacity=".18" stroke="#0ea5e9" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.216;0.56" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/></rect><rect x="444" y="40" width="136" height="52" rx="9" class="dg-box" stroke="#0ea5e9" stroke-width="2.2"/><text x="512" y="62.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Process</text><text x="512" y="78" text-anchor="middle" font-size="11" class="dg-muted">a running program</text></g>
<g><rect x="136" y="122" width="144" height="58" rx="12" fill="#059669" fill-opacity=".18" stroke="#059669" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.56;0.88" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/></rect><rect x="140" y="126" width="136" height="50" rx="9" class="dg-box" stroke="#059669" stroke-width="2.2"/><text x="208" y="147.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">systemd</text><text x="208" y="163" text-anchor="middle" font-size="11" class="dg-muted">PID 1, runs services</text></g>
<g><rect x="440" y="122" width="144" height="58" rx="12" fill="#f59e0b" fill-opacity=".18" stroke="#f59e0b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.32;0.56" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/></rect><rect x="444" y="126" width="136" height="50" rx="9" class="dg-box" stroke="#f59e0b" stroke-width="2.2"/><text x="512" y="147.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Linux kernel</text><text x="512" y="163" text-anchor="middle" font-size="11" class="dg-muted">checks permissions</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.44;0.56" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><rect x="444" y="126" width="136" height="50" rx="9" fill="#e11d48"/><text x="512" y="155.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">✕ denied</text></g></g>
<g><rect x="136" y="208" width="144" height="58" rx="12" fill="#10b981" fill-opacity=".18" stroke="#10b981" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.56;0.88" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/></rect><rect x="140" y="212" width="136" height="50" rx="9" class="dg-box" stroke="#10b981" stroke-width="2.2"/><text x="208" y="233.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">myapp.service</text><text x="208" y="249" text-anchor="middle" font-size="11" class="dg-muted">python3 · port 9000</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.672;0.776" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><rect x="140" y="212" width="136" height="50" rx="9" fill="#e11d48"/><text x="208" y="241.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">✕ crashed</text></g></g>
<g><rect x="288" y="208" width="144" height="58" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.88" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/></rect><rect x="292" y="212" width="136" height="50" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="360" y="233.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">journald</text><text x="360" y="249" text-anchor="middle" font-size="11" class="dg-muted">keeps the logs</text></g>
<g><rect x="440" y="208" width="144" height="58" rx="12" fill="#0d9488" fill-opacity=".18" stroke="#0d9488" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.32;0.44" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/></rect><rect x="444" y="212" width="136" height="50" rx="9" class="dg-box" stroke="#0d9488" stroke-width="2.2"/><text x="512" y="233.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Files</text><text x="512" y="249" text-anchor="middle" font-size="11" class="dg-muted">/var/www · /etc</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.104;0.216" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><circle cx="276" cy="40" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M271.5,40 L275,43.5 L280.5,36.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.32;0.44" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><circle cx="580" cy="126" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M575.5,126 L579,129.5 L584.5,122.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.56;0.672;0.776;0.88" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><circle cx="276" cy="212" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M271.5,212 L275,215.5 L280.5,208.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0062;0.0894" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><animateMotion path="M62,66 L208,66" keyPoints="0;0;1;1" keyTimes="0;0.0062;0.0894;1" calcMode="linear" dur="42.5s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1096;0.151" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><animateMotion path="M62,66 L208,66" keyPoints="0;0;1;1" keyTimes="0;0.1096;0.151;1" calcMode="linear" dur="42.5s" repeatCount="indefinite"/><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.16;0.2048" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><animateMotion path="M208,66 L360,66" keyPoints="0;0;1;1" keyTimes="0;0.16;0.2048;1" calcMode="linear" dur="42.5s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2212;0.2628" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><animateMotion path="M62,66 L208,66 L360,66" keyPoints="0;0;1;1" keyTimes="0;0.2212;0.2628;1" calcMode="linear" dur="42.5s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.268;0.3096" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><animateMotion path="M360,66 L512,66" keyPoints="0;0;1;1" keyTimes="0;0.268;0.3096;1" calcMode="linear" dur="42.5s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.326;0.3704" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><animateMotion path="M512,66 L512,151 L512,237" keyPoints="0;0;1;1" keyTimes="0;0.326;0.3704;1" calcMode="linear" dur="42.5s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3776;0.434" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><animateMotion path="M512,237 L512,151 L512,66 L360,66 L208,66 L62,66" keyPoints="0;0;1;1" keyTimes="0;0.3776;0.434;1" calcMode="linear" dur="42.5s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4448;0.4736" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><animateMotion path="M360,66 L512,66" keyPoints="0;0;1;1" keyTimes="0;0.4448;0.4736;1" calcMode="linear" dur="42.5s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.476;0.5" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><animateMotion path="M512,66 L512,151" keyPoints="0;0;1;1" keyTimes="0;0.476;0.5;1" calcMode="linear" dur="42.5s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.506;0.554" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><animateMotion path="M512,151 L512,66 L360,66 L208,66 L62,66" keyPoints="0;0;1;1" keyTimes="0;0.506;0.554;1" calcMode="linear" dur="42.5s" repeatCount="indefinite"/><g><circle r="7" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M0,-3.5 V1 M0,3.2 V3.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5667;0.6563" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><animateMotion path="M330,66 L330,108 L208,108 L208,151 L208,237" keyPoints="0;0;1;1" keyTimes="0;0.5667;0.6563;1" calcMode="linear" dur="42.5s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6772;0.724" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><animateMotion path="M208,237 L208,151" keyPoints="0;0;1;1" keyTimes="0;0.6772;0.724;1" calcMode="linear" dur="42.5s" repeatCount="indefinite"/><g><circle r="7" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M0,-3.5 V1 M0,3.2 V3.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7032;0.7552" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><animateMotion path="M208,237 L360,237" keyPoints="0;0;1;1" keyTimes="0;0.7032;0.7552;1" calcMode="linear" dur="42.5s" repeatCount="indefinite"/><g><rect x="-8" y="-6" width="16" height="12" rx="2" fill="#64748b" stroke="#fff" stroke-width="1.6"/><path d="M-5,-2 H5 M-5,2 H3" stroke="#fff" stroke-width="1.4"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7822;0.8654" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><animateMotion path="M208,151 L208,237" keyPoints="0;0;1;1" keyTimes="0;0.7822;0.8654;1" calcMode="linear" dur="42.5s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8848;0.9184" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><animateMotion path="M208,237 L360,237" keyPoints="0;0;1;1" keyTimes="0;0.8848;0.9184;1" calcMode="linear" dur="42.5s" repeatCount="indefinite"/><g><rect x="-8" y="-6" width="16" height="12" rx="2" fill="#64748b" stroke="#fff" stroke-width="1.6"/><path d="M-5,-2 H5 M-5,2 H3" stroke="#fff" stroke-width="1.4"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.9256;0.994" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><animateMotion path="M390,237 L390,66 L208,66 L62,66" keyPoints="0;0;1;1" keyTimes="0;0.9256;0.994;1" calcMode="linear" dur="42.5s" repeatCount="indefinite"/><g><rect x="-8" y="-6" width="16" height="12" rx="2" fill="#64748b" stroke="#fff" stroke-width="1.6"/><path d="M-5,-2 H5 M-5,2 H3" stroke="#fff" stroke-width="1.4"/></g></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(20.4,296.5) scale(.8)"><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g><text x="31.8" y="300">connection</text><g transform="translate(111,296.5) scale(.8)"><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g><text x="124" y="300">SSH key</text><g transform="translate(185.6,296.5) scale(.8)"><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g><text x="197" y="300">command</text><g transform="translate(258.6,296.5) scale(.8)"><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g><text x="270" y="300">file data</text><g transform="translate(342.8,296.5) scale(.8)"><g><circle r="7" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M0,-3.5 V1 M0,3.2 V3.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/></g></g><text x="354.2" y="300">error</text><g transform="translate(405.4,296.5) scale(.8)"><g><rect x="-8" y="-6" width="16" height="12" rx="2" fill="#64748b" stroke="#fff" stroke-width="1.6"/><path d="M-5,-2 H5 M-5,2 H3" stroke="#fff" stroke-width="1.4"/></g></g><text x="417.6" y="300">log line</text></g>
<rect x="12" y="312" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="312" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="42.5s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.104" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><circle cx="36" cy="340" r="14" fill="#6366f1"/><text x="36" y="345" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="335" font-size="14" font-weight="800" fill="#6366f1">ssh to the server</text><text x="578" y="335" text-anchor="end" font-size="10.5" class="dg-muted">Log in with SSH · 1/9</text><text x="60" y="356" font-size="12.5" class="dg-text">ssh -i ~/.ssh/mykey.pem ubuntu@203.0.113.10 connects to port 22.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.104;0.216" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><circle cx="36" cy="340" r="14" fill="#6366f1"/><text x="36" y="345" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="335" font-size="14" font-weight="800" fill="#6366f1">sshd checks your key</text><text x="578" y="335" text-anchor="end" font-size="10.5" class="dg-muted">Log in with SSH · 2/9</text><text x="60" y="356" font-size="12.5" class="dg-text">It matches a public key in ~/.ssh/authorized_keys, so you get a shell.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.216;0.32" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><circle cx="36" cy="340" r="14" fill="#a855f7"/><text x="36" y="345" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="335" font-size="14" font-weight="800" fill="#a855f7">You type ls -l /var/www/html</text><text x="578" y="335" text-anchor="end" font-size="10.5" class="dg-muted">Run a command · 3/9</text><text x="60" y="356" font-size="12.5" class="dg-text">bash starts a new process to run it. Each process gets its own PID.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.32;0.44" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><circle cx="36" cy="340" r="14" fill="#a855f7"/><text x="36" y="345" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="335" font-size="14" font-weight="800" fill="#a855f7">The kernel checks permissions</text><text x="578" y="335" text-anchor="end" font-size="10.5" class="dg-muted">Run a command · 4/9</text><text x="60" y="356" font-size="12.5" class="dg-text">You may read this folder, so the list comes back to your screen.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.44;0.56" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><circle cx="36" cy="340" r="14" fill="#a855f7"/><text x="36" y="345" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="335" font-size="14" font-weight="800" fill="#a855f7">cat /etc/shadow: Permission denied</text><text x="578" y="335" text-anchor="end" font-size="10.5" class="dg-muted">Run a command · 5/9</text><text x="60" y="356" font-size="12.5" class="dg-text">Normal users can&#x27;t read the password hashes. sudo runs it as root.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.56;0.672" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><circle cx="36" cy="340" r="14" fill="#059669"/><text x="36" y="345" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="335" font-size="14" font-weight="800" fill="#059669">systemd starts your service</text><text x="578" y="335" text-anchor="end" font-size="10.5" class="dg-muted">Run a service · 6/9</text><text x="60" y="356" font-size="12.5" class="dg-text">sudo systemctl enable --now myapp: it runs now and after every reboot.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.672;0.776" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><circle cx="36" cy="340" r="14" fill="#059669"/><text x="36" y="345" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="335" font-size="14" font-weight="800" fill="#059669">The app crashes</text><text x="578" y="335" text-anchor="end" font-size="10.5" class="dg-muted">Run a service · 7/9</text><text x="60" y="356" font-size="12.5" class="dg-text">The process exits with an error. systemd notices at once.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.776;0.88" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><circle cx="36" cy="340" r="14" fill="#059669"/><text x="36" y="345" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="335" font-size="14" font-weight="800" fill="#059669">systemd restarts it</text><text x="578" y="335" text-anchor="end" font-size="10.5" class="dg-muted">Run a service · 8/9</text><text x="60" y="356" font-size="12.5" class="dg-text">Restart=on-failure starts it again. Nobody had to log in.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.88" calcMode="discrete" dur="42.5s" repeatCount="indefinite"/><circle cx="36" cy="340" r="14" fill="#059669"/><text x="36" y="345" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">9</text><text x="60" y="335" font-size="14" font-weight="800" fill="#059669">Read what happened</text><text x="578" y="335" text-anchor="end" font-size="10.5" class="dg-muted">Run a service · 9/9</text><text x="60" y="356" font-size="12.5" class="dg-text">systemctl status myapp and journalctl -u myapp show the crash.</text></g>
</svg>
```

```steps
#6366f1 | Log in with SSH | ssh to the server | ssh -i ~/.ssh/mykey.pem ubuntu@203.0.113.10 connects to port 22.
#6366f1 | Log in with SSH | sshd checks your key | It matches a public key in ~/.ssh/authorized_keys, so you get a shell.
#a855f7 | Run a command | You type ls -l /var/www/html | bash starts a new process to run it. Each process gets its own PID.
#a855f7 | Run a command | The kernel checks permissions | You may read this folder, so the list comes back to your screen.
#a855f7 | Run a command | cat /etc/shadow: Permission denied | Normal users can't read the password hashes. sudo runs it as root.
#059669 | Run a service | systemd starts your service | sudo systemctl enable --now myapp: it runs now and after every reboot.
#059669 | Run a service | The app crashes | The process exits with an error. systemd notices at once.
#059669 | Run a service | systemd restarts it | Restart=on-failure starts it again. Nobody had to log in.
#059669 | Run a service | Read what happened | systemctl status myapp and journalctl -u myapp show the crash.
```

### What is Linux?

An **operating system** is the main software that runs a computer and lets other programs use the screen, disk and network. Windows and macOS are operating systems. **Linux** is another one: free, very stable, and used on almost every server, cloud machine and container.

**Think of it like this:** a computer is a big office building. The **operating system** is the building manager who controls the rooms (files), the staff (programs) and the doors (network). In Linux you talk to the manager by typing short instructions in a **terminal**.

### How a command is built

```text
ls   -l   /etc
│    │    └── argument: WHAT to act on (the /etc folder)
│    └─────── option:   HOW to do it (-l = long, detailed list)
└──────────── command:  WHAT to do  (ls = list files)
```

Almost every Linux command follows this pattern: **command → options → what to act on**.

### Key words

| Word | Simple meaning |
|---|---|
| **Terminal / shell / bash** | The window where you type commands, and the program that reads them |
| **Command** | One instruction, like `ls` (list) or `cd` (change folder) |
| **Directory** | A folder |
| **Path** | The address of a file, like `/home/alice/notes.txt` |
| **Root (`/`)** | The very top folder that contains everything |
| **root (user)** | The administrator account that can do anything |
| **sudo** | "Do this as administrator" |
| **Process** | A program that is currently running |
| **Service** | A program that runs in the background all the time, like a web server |
| **Package** | An installable piece of software |

### Survival tips

- Press **Tab** to auto-complete file and command names. It saves typing and spelling mistakes.
- Press **↑ (up arrow)** to bring back your previous command.
- **Ctrl+C** stops a running command. **Ctrl+L** or `clear` clears the screen.
- Stuck on a command? Try `man ls` (the full manual; press `q` to quit) or `ls --help`.
- Linux is **case-sensitive**: `File.txt` and `file.txt` are two different files.
- Want to practise right now? Use the in-browser Linux terminal in the [Practice lab](#/lab).

### Check yourself

1. In `cp -r photos backup`, which part is the command, the option and the arguments?
2. What's the difference between `/` and `root`?
3. How do you stop a command that won't finish?

> **Tip:** Answers: 1) `cp` is the command, `-r` the option ("recursive", meaning include folders), and `photos backup` the arguments. 2) `/` is the top folder; `root` is the admin user. 3) Press `Ctrl+C`.

## Why Linux matters in DevOps

> **In simple words:** Servers, containers and cloud machines almost all run Linux, so this is the one skill every other guide builds on.

- **Servers:** EC2 instances, on-prem VMs, and Kubernetes nodes are almost all Linux.
- **Containers:** every Docker image is a small Linux userspace. Debugging containers means debugging Linux.
- **Automation:** CI pipelines run shell commands on Linux runners.
- **Troubleshooting:** when production breaks, you SSH in and use `top`, `journalctl`, `df`, `ss`, and `curl`.

Key idea: **everything is a file**. Configuration, devices, process information (`/proc`), and logs all appear in the filesystem.

## The filesystem hierarchy

> **In simple words:** Linux stores everything in one big tree of folders starting at `/`. Each top-level folder has a job: settings live in `/etc`, logs in `/var/log`, your files in `/home`.

| Path | What lives there |
|---|---|
| `/` | Root of everything |
| `/home/<user>` | Your files (`~` is shorthand) |
| `/root` | Home of the root user |
| `/etc` | System-wide configuration (`/etc/ssh/sshd_config`, `/etc/hosts`) |
| `/var` | Variable data. `/var/log` holds logs |
| `/usr/bin`, `/usr/local/bin` | Installed programs |
| `/tmp` | Temporary files, cleared on reboot |
| `/opt` | Optional, third-party software |
| `/proc`, `/sys` | Virtual files exposing kernel and process info |
| `/dev` | Devices (disks, `/dev/null`) |
| `/mnt`, `/media` | Mount points (WSL mounts Windows drives at `/mnt/c`) |

```bash
pwd                 # where am I?
ls /                # list the root
cat /etc/os-release # which distro?
uname -a            # kernel info
```

## Navigation and file operations

> **In simple words:** The everyday commands to move between folders and create, copy, move, find and delete files, just like in File Explorer but by typing.

```bash
cd ~/code           # change directory (cd alone goes home, cd - goes back)
ls -lah             # long listing, hidden files, human sizes
tree -L 2           # directory tree, 2 levels
mkdir -p app/src/utils     # create nested dirs
touch app/README.md        # create empty file
cp file.txt backup.txt     # copy
cp -r app app-copy         # copy directory
mv old.txt new.txt         # move / rename
rm file.txt                # delete file
rm -r app-copy             # delete directory
ln -s /opt/tool/bin/tool /usr/local/bin/tool   # symbolic link
```

### Finding things

```bash
find . -name "*.log" -mtime -1        # .log files modified in last day
find / -type f -size +100M 2>/dev/null # files bigger than 100MB
grep -rn "ERROR" /var/log/            # search text recursively
grep -i "timeout" app.log | wc -l     # count case-insensitive matches
which python3                         # path of a command
```

> **Warning:** `rm -rf` has no undo and no recycle bin. Double-check the path, especially when it contains a variable.

## Viewing and editing files

> **In simple words:** How to read files (all at once, page by page, or live as they grow) and how to edit them in the terminal. The `|` pipe passes one command's output into the next.

```bash
cat file.txt            # print whole file
less /var/log/syslog    # scroll (q to quit, / to search)
head -n 20 file.txt     # first 20 lines
tail -n 50 app.log      # last 50 lines
tail -f app.log         # follow live (Ctrl+C to stop)
wc -l file.txt          # count lines
diff a.conf b.conf      # compare files
```

### Pipes and redirection

The `|` pipe sends one command's output into the next. This is the core of Linux power-use.

```bash
echo "hello" > out.txt        # overwrite file
echo "world" >> out.txt       # append
command 2> errors.txt         # redirect stderr
command > all.txt 2>&1        # stdout + stderr
cat access.log | awk '{print $1}' | sort | uniq -c | sort -rn | head
# -> top client IPs in a web access log
```

### Vim survival kit

You will meet `vim` on servers with no other editor.

| Key | Action |
|---|---|
| `i` | Insert mode (start typing) |
| `Esc` | Back to normal mode |
| `:w` | Save |
| `:q` / `:q!` | Quit / quit without saving |
| `:wq` | Save and quit |
| `/text` | Search, `n` for next |
| `dd` / `u` | Delete line / undo |

Prefer something simpler? `nano file.txt` works too. Save with Ctrl+O and exit with Ctrl+X.

## Users, groups and permissions

> **In simple words:** Every file has an owner and a set of rules saying who can **r**ead, **w**rite or e**x**ecute (run) it, like locks with different keys for different people.

```bash
whoami && id                 # current user, UID, groups
sudo adduser deploy          # create user
sudo usermod -aG sudo deploy # give sudo rights
sudo su - deploy             # switch to user
```

### Reading permissions

```text
-rwxr-xr--  1 alice devs  1024 Jan 1 10:00 deploy.sh
 │└┬┘└┬┘└┬┘     │     │
 │ │  │  └ others: r--  (read)
 │ │  └─── group:  r-x  (read, execute)
 │ └────── owner:  rwx  (read, write, execute)
 └──────── type: - file, d directory, l link
```

Numeric form: r=4, w=2, x=1. So `rwxr-xr--` = 7,5,4 = **754**.

```bash
chmod 755 deploy.sh          # rwx r-x r-x
chmod +x script.sh           # add execute
chmod 600 ~/.ssh/id_ed25519  # private key: owner read/write only
sudo chown alice:devs file   # change owner and group
sudo chown -R www-data /var/www
```

> **Tip:** SSH refuses keys that other users can read. If you see `UNPROTECTED PRIVATE KEY FILE`, run `chmod 600` on the key.

## Package management

> **In simple words:** A package manager is an app store for the command line. One command downloads and installs software and everything it needs.

| Distro family | Tool | Install example |
|---|---|---|
| Ubuntu / Debian | `apt` | `sudo apt install nginx` |
| RHEL / Amazon Linux / Fedora | `dnf` (older: `yum`) | `sudo dnf install nginx` |
| Alpine (common in containers) | `apk` | `apk add curl` |

```bash
sudo apt update              # refresh package index
sudo apt upgrade -y          # upgrade everything
apt search nginx             # search
sudo apt install -y nginx    # install
sudo apt remove nginx        # remove
dpkg -l | grep nginx         # is it installed?
```

## Processes and systemd services

> **In simple words:** A process is a running program. A service is a program that runs in the background all the time, and systemd is the manager that starts, stops and restarts services.

```bash
ps aux | grep nginx       # find a process
top                       # live view (q to quit); try htop
pgrep -a python           # PIDs by name
kill 1234                 # graceful stop (SIGTERM)
kill -9 1234              # force kill (SIGKILL), last resort
nohup ./long-job.sh &     # run in background, survive logout
jobs; fg; bg              # job control
free -h                   # memory
uptime                    # load average
```

### systemd

Most distros use **systemd** to manage long-running services.

```bash
sudo systemctl status nginx     # is it running? recent logs
sudo systemctl start nginx
sudo systemctl stop nginx
sudo systemctl restart nginx
sudo systemctl enable nginx     # start on boot
systemctl list-units --type=service --state=running
```

Write your own service in `/etc/systemd/system/myapp.service`:

```ini
[Unit]
Description=My demo app
After=network.target

[Service]
User=deploy
WorkingDirectory=/opt/myapp
ExecStart=/usr/bin/python3 -m http.server 9000
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now myapp
curl localhost:9000
```

> **Note:** WSL2 on recent Windows versions supports systemd. If `systemctl` fails, add `[boot]` and `systemd=true` to `/etc/wsl.conf`, then run `wsl --shutdown` from PowerShell.

## Networking basics

> **In simple words:** Commands to see your computer's address, which "doors" (ports) are open, and whether another computer or website is reachable.

```bash
ip a                          # interfaces and IPs
ip route                      # routing table / default gateway
ss -tulpn                     # listening ports and owning process
ping -c 3 google.com          # reachability
curl -I https://example.com   # HTTP headers only
curl -v http://localhost:8080/health
dig example.com +short        # DNS lookup (apt install dnsutils)
nslookup example.com
traceroute example.com        # path to host
cat /etc/hosts /etc/resolv.conf
```

Concepts to know cold:

- **IP and CIDR:** `10.0.1.0/24` = 256 addresses (`10.0.1.0`–`10.0.1.255`). The smaller the suffix, the bigger the network.
- **Ports:** 22 SSH, 80 HTTP, 443 HTTPS, 5432 Postgres, 3306 MySQL, 6443 Kubernetes API.
- **DNS:** turns names into IPs. Many outages are DNS.
- **Firewall:** `sudo ufw status` (Ubuntu), security groups in AWS.

## Disks and storage

> **In simple words:** How to see how full the disk is and which folders take up the most space. "Disk full" is one of the most common server problems.

```bash
df -h                     # free space per filesystem
du -sh /var/log/*         # size of each item
du -h --max-depth=1 / 2>/dev/null | sort -h | tail
lsblk                     # block devices
sudo mount /dev/xvdf /data
tar -czvf backup.tar.gz /etc/nginx   # compress
tar -xzvf backup.tar.gz -C /tmp      # extract
```

> **Tip:** "Disk full" is a top-5 production incident. `df -h` then `du -sh` is the first move. The usual culprit is logs in `/var/log` or Docker data in `/var/lib/docker`.

## SSH: remote access

> **In simple words:** SSH lets you open a terminal on a computer far away, safely, as if you were sitting in front of it.

```bash
ssh -i ~/.ssh/mykey.pem ubuntu@203.0.113.10       # connect
scp -i ~/.ssh/mykey.pem app.tar.gz ubuntu@203.0.113.10:/tmp/   # copy file
ssh-copy-id user@host                              # install your key on a server
```

Save hosts in `~/.ssh/config` so you can type `ssh web1`:

```text
Host web1
    HostName 203.0.113.10
    User ubuntu
    IdentityFile ~/.ssh/mykey.pem

Host bastion-*
    User ec2-user
    ForwardAgent no
```

Harden the server in `/etc/ssh/sshd_config`: `PasswordAuthentication no`, `PermitRootLogin no`, then `sudo systemctl restart ssh`.

## Bash scripting

> **In simple words:** A script is a text file of commands that run one after another, so you can automate a task instead of typing it every time.

> **Tip:** Go deeper in the **Scripting** section: [Bash Scripting for DevOps](#/tool/bash-scripting) (8 ready-to-use scripts and interview questions) and [Python for DevOps](#/tool/python-devops) (boto3 and automation).

A script is a file of commands with a shebang line. This one has the patterns you will reuse everywhere:

```bash
#!/usr/bin/env bash
set -euo pipefail   # exit on error, undefined vars, failed pipes

APP_NAME="${1:-myapp}"          # first argument, default "myapp"
LOG_DIR="/var/log/${APP_NAME}"
THRESHOLD=80

log() { echo "[$(date +'%F %T')] $*"; }

if [[ ! -d "$LOG_DIR" ]]; then
  log "Log dir $LOG_DIR missing, creating"
  mkdir -p "$LOG_DIR"
fi

usage=$(df / --output=pcent | tail -1 | tr -dc '0-9')
if (( usage > THRESHOLD )); then
  log "WARNING: root disk at ${usage}%"
fi

for svc in nginx ssh cron; do
  if systemctl is-active --quiet "$svc"; then
    log "$svc: running"
  else
    log "$svc: NOT running"
  fi
done
```

```bash
chmod +x healthcheck.sh
./healthcheck.sh myapp
```

### Scheduling with cron

```bash
crontab -e
# m  h  dom mon dow  command
*/5 *  *   *   *     /home/deploy/healthcheck.sh >> /tmp/health.log 2>&1
0   2  *   *   *     /home/deploy/backup.sh
```

Use [crontab.guru](https://crontab.guru) to check expressions.

## Logs and troubleshooting

> **In simple words:** Logs are a program's diary. When something breaks, you read the logs and follow a checklist to find out why.

```bash
journalctl -u nginx -f            # follow a service's logs
journalctl -p err --since "1 hour ago"
journalctl --disk-usage
sudo tail -f /var/log/syslog      # Ubuntu system log
dmesg -T | tail                   # kernel messages (OOM kills show here)
```

A troubleshooting checklist when "the app is down":

1. **Is the process running?** `systemctl status app` or `ps aux | grep app`
2. **Is it listening?** `ss -tulpn | grep 8080`
3. **Can I reach it locally?** `curl -v localhost:8080`
4. **What do the logs say?** `journalctl -u app -n 100`
5. **Are resources exhausted?** `df -h`, `free -h`, `top`
6. **Is the network or firewall blocking it?** security groups, `ufw`, DNS

## Lab: build a monitored web server

> **In simple words:** Practice time: use everything above to set up a small website and a script that checks it's healthy.

Do this without looking back at the earlier steps.

1. Install `nginx`, enable it, and confirm `curl localhost` returns the welcome page.
2. Replace `/var/www/html/index.html` with a page showing your name.
3. Create a user `deploy` and make it the owner of `/var/www/html`.
4. Write `healthcheck.sh` that checks nginx is active, port 80 is listening, and disk usage is below 80%. Log the result with a timestamp.
5. Schedule it every 5 minutes with cron, then check the log file fills up.
6. Stop nginx and confirm your script reports the failure.
7. Find the top 5 largest directories under `/var`.

### Cheat sheet

| Task | Command |
|---|---|
| What's using port 80? | `sudo ss -tulpn \| grep :80` |
| Follow service logs | `journalctl -u svc -f` |
| Disk usage | `df -h` / `du -sh *` |
| Memory | `free -h` |
| Find text in files | `grep -rn "text" dir/` |
| Make executable | `chmod +x file` |
| Service on boot | `systemctl enable --now svc` |
