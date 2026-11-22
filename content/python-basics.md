# Python Basics & Module Cheat Sheet

A quick-reference page: the Python syntax you'll use every day, then a short "how to use it" card for each module DevOps engineers rely on (`os`, `subprocess`, `json`, `re`, `logging`, `socket`, `requests`, `psutil`, `boto3`, `kubernetes` and more). Every card links to the **official documentation**, the place to go for the full details.

> **Note:** Want explanations and bigger examples? See [Python for DevOps](#/tool/python-devops). Want interview-style programs to practise? See [Python Interview Programs](#/tool/python-programs).

## Start here: running Python

> **In simple words:** Python runs your `.py` file line by line, from top to bottom. Try small things in the **interactive shell** (REPL), keep real work in **script files**, and give each project its own **virtual environment** for packages.

### Watch how it works

```svg Watch it work: one script using json, subprocess, requests, boto3 and logging, returning exit code 0, then a timed-out API call logged as an error with exit code 1. The animation loops.
<svg viewBox="0 0 600 428" role="img" data-anim="python-basics" data-dur="43.18" data-starts="0 4.42 8.84 13.94 19.04 24.14 28.56 32.98 38.08" aria-label="Animated Python script, check.py. Start up: you or cron run python3 check.py; Python runs the file from top to bottom, the imports load each module, and main() starts. json.load(f) turns config.json into a Python dict. Do the work: subprocess.run([&quot;df&quot;, &quot;-h&quot;, &quot;/&quot;]) runs a Linux command and gives back its return code 0 and its output. requests.get(url, timeout=5) calls an HTTP API at api.example.com, gets status 200, and r.json() gives the data. boto3 asks AWS EC2 to describe the instances, using the same credentials in ~/.aws that the AWS CLI uses. log.info writes a timestamped INFO line to the terminal or a log file, instead of a bare print. main() returns 0, and sys.exit(main()) hands exit code 0 to cron or CI: everything worked. When a call fails: on a later run the API does not answer, and after the 5-second timeout requests raises an exception instead of hanging forever. The except block uses log.error to record it, and the script exits with code 1, which tells cron or CI that it failed.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<rect x="142" y="8" width="256" height="326" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="5 4"/>
<polyline points="71,60 199,60" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="199,300 71,300" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="1.6" stroke-opacity=".8"/>
<polyline points="199,60 324,60 504,60" fill="none" stroke-linejoin="round" stroke="#0d9488" stroke-width="1.8" stroke-dasharray="6 3" stroke-opacity=".7"/>
<polyline points="199,120 324,120 504,120" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="199,180 324,180 504,180" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="199,240 324,240 504,240" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="199,300 324,300 504,300" fill="none" stroke-linejoin="round" stroke="#64748b" stroke-width="1.8" stroke-dasharray="4 3" stroke-opacity=".7"/>
<rect x="148" y="14" width="55.2" height="16" rx="5" class="dg-box"/><text x="152" y="24" font-size="11" class="dg-muted">check.py</text>
<g><rect x="8" y="31" width="126" height="58" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1024" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/></rect><rect x="12" y="35" width="118" height="50" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="71" y="56.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">You or cron</text><text x="71" y="72" text-anchor="middle" font-size="11" class="dg-muted">python3 check.py</text></g>
<g><rect x="8" y="272" width="126" height="56" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.6614;0.7638;0.8819" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/></rect><rect x="12" y="276" width="118" height="48" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="71" y="296.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Exit code</text><text x="71" y="312" text-anchor="middle" font-size="11" class="dg-muted">0 OK · 1 failed</text></g>
<g><rect x="150" y="32" width="98" height="296" rx="12" fill="#6366f1" fill-opacity=".18" stroke="#6366f1" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1;0" keyTimes="0;0.1024;0.6614;0.7638" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/></rect><rect x="154" y="36" width="90" height="288" rx="9" class="dg-box" stroke="#6366f1" stroke-width="2.2"/><text x="199" y="169" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">main()</text><text x="199" y="184.5" text-anchor="middle" font-size="11" class="dg-muted">runs each</text><text x="199" y="199.5" text-anchor="middle" font-size="11" class="dg-muted">step in turn</text></g>
<g><rect x="258" y="32" width="132" height="56" rx="12" fill="#0d9488" fill-opacity=".18" stroke="#0d9488" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1024;0.2047" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/></rect><rect x="262" y="36" width="124" height="48" rx="9" class="dg-box" stroke="#0d9488" stroke-width="2.2"/><text x="324" y="56.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">json</text><text x="324" y="72" text-anchor="middle" font-size="11" class="dg-muted">json.load(f)</text></g>
<g><rect x="258" y="92" width="132" height="56" rx="12" fill="#a855f7" fill-opacity=".18" stroke="#a855f7" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2047;0.3228" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/></rect><rect x="262" y="96" width="124" height="48" rx="9" class="dg-box" stroke="#a855f7" stroke-width="2.2"/><text x="324" y="116.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">subprocess</text><text x="324" y="132" text-anchor="middle" font-size="11" class="dg-muted">subprocess.run</text></g>
<g><rect x="258" y="152" width="132" height="56" rx="12" fill="#2563eb" fill-opacity=".18" stroke="#2563eb" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.3228;0.4409;0.7638;0.8819" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/></rect><rect x="262" y="156" width="124" height="48" rx="9" class="dg-box" stroke="#2563eb" stroke-width="2.2"/><text x="324" y="176.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">requests</text><text x="324" y="192" text-anchor="middle" font-size="11" class="dg-muted">requests.get</text></g>
<g><rect x="258" y="212" width="132" height="56" rx="12" fill="#f97316" fill-opacity=".18" stroke="#f97316" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4409;0.5591" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/></rect><rect x="262" y="216" width="124" height="48" rx="9" class="dg-box" stroke="#f97316" stroke-width="2.2"/><text x="324" y="236.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">boto3</text><text x="324" y="252" text-anchor="middle" font-size="11" class="dg-muted">ec2 client</text></g>
<g><rect x="258" y="272" width="132" height="56" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.5591;0.6614;0.8819" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/></rect><rect x="262" y="276" width="124" height="48" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="324" y="296.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">logging</text><text x="324" y="312" text-anchor="middle" font-size="11" class="dg-muted">log.info / error</text></g>
<g><rect x="416" y="32" width="176" height="56" rx="12" fill="#0d9488" fill-opacity=".18" stroke="#0d9488" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1024;0.2047" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/></rect><rect x="420" y="36" width="168" height="48" rx="9" class="dg-box" stroke="#0d9488" stroke-width="2.2"/><text x="504" y="56.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">config.json</text><text x="504" y="72" text-anchor="middle" font-size="11" class="dg-muted">{&quot;url&quot;: …}</text></g>
<g><rect x="416" y="92" width="176" height="56" rx="12" fill="#a855f7" fill-opacity=".18" stroke="#a855f7" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2047;0.3228" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/></rect><rect x="420" y="96" width="168" height="48" rx="9" class="dg-box" stroke="#a855f7" stroke-width="2.2"/><text x="504" y="116.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">df -h /</text><text x="504" y="132" text-anchor="middle" font-size="11" class="dg-muted">a Linux command</text></g>
<g><rect x="416" y="152" width="176" height="56" rx="12" fill="#2563eb" fill-opacity=".18" stroke="#2563eb" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.3228;0.4409;0.7638;0.8819" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/></rect><rect x="420" y="156" width="168" height="48" rx="9" class="dg-box" stroke="#2563eb" stroke-width="2.2"/><text x="504" y="176.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">HTTP API</text><text x="504" y="192" text-anchor="middle" font-size="11" class="dg-muted">api.example.com</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7638;0.8819" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><rect x="420" y="156" width="168" height="48" rx="9" fill="#e11d48"/><text x="504" y="184.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">✕ no answer</text></g></g>
<g><rect x="416" y="212" width="176" height="56" rx="12" fill="#ff9900" fill-opacity=".18" stroke="#ff9900" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4409;0.5591" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/></rect><rect x="420" y="216" width="168" height="48" rx="9" class="dg-box" stroke="#ff9900" stroke-width="2.2"/><text x="504" y="236.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">AWS EC2</text><text x="504" y="252" text-anchor="middle" font-size="11" class="dg-muted">uses ~/.aws credentials</text></g>
<g><rect x="416" y="272" width="176" height="56" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.5591;0.6614;0.8819" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/></rect><rect x="420" y="276" width="168" height="48" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="504" y="296.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Terminal / log</text><text x="504" y="312" text-anchor="middle" font-size="11" class="dg-muted">timestamped lines</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2047;0.3228" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><circle cx="588" cy="96" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M583.5,96 L587,99.5 L592.5,92.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3228;0.4409" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><circle cx="588" cy="156" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M583.5,156 L587,159.5 L592.5,152.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4409;0.5591" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><circle cx="588" cy="216" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M583.5,216 L587,219.5 L592.5,212.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6614;0.7638" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><circle cx="130" cy="276" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M125.5,276 L129,279.5 L134.5,272.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0061;0.088" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><animateMotion path="M71,60 L199,60" keyPoints="0;0;1;1" keyTimes="0;0.0061;0.088;1" calcMode="linear" dur="43.18s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1085;0.1904" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><animateMotion path="M504,60 L324,60 L199,60" keyPoints="0;0;1;1" keyTimes="0;0.1085;0.1904;1" calcMode="linear" dur="43.18s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2106;0.2579" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><animateMotion path="M199,120 L324,120 L504,120" keyPoints="0;0;1;1" keyTimes="0;0.2106;0.2579;1" calcMode="linear" dur="43.18s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2661;0.3134" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><animateMotion path="M504,120 L324,120 L199,120" keyPoints="0;0;1;1" keyTimes="0;0.2661;0.3134;1" calcMode="linear" dur="43.18s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3287;0.376" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><animateMotion path="M199,180 L324,180 L504,180" keyPoints="0;0;1;1" keyTimes="0;0.3287;0.376;1" calcMode="linear" dur="43.18s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3843;0.4315" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><animateMotion path="M504,180 L324,180 L199,180" keyPoints="0;0;1;1" keyTimes="0;0.3843;0.4315;1" calcMode="linear" dur="43.18s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4469;0.4941" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><animateMotion path="M199,240 L324,240 L504,240" keyPoints="0;0;1;1" keyTimes="0;0.4469;0.4941;1" calcMode="linear" dur="43.18s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5024;0.5496" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><animateMotion path="M504,240 L324,240 L199,240" keyPoints="0;0;1;1" keyTimes="0;0.5024;0.5496;1" calcMode="linear" dur="43.18s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5652;0.6471" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><animateMotion path="M199,300 L324,300 L504,300" keyPoints="0;0;1;1" keyTimes="0;0.5652;0.6471;1" calcMode="linear" dur="43.18s" repeatCount="indefinite"/><g><rect x="-8" y="-6" width="16" height="12" rx="2" fill="#64748b" stroke="#fff" stroke-width="1.6"/><path d="M-5,-2 H5 M-5,2 H3" stroke="#fff" stroke-width="1.4"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6676;0.7494" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><animateMotion path="M199,300 L71,300" keyPoints="0;0;1;1" keyTimes="0;0.6676;0.7494;1" calcMode="linear" dur="43.18s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7697;0.811" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><animateMotion path="M199,180 L324,180 L504,180" keyPoints="0;0;1;1" keyTimes="0;0.7697;0.811;1" calcMode="linear" dur="43.18s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8287;0.876" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><animateMotion path="M504,180 L324,180 L199,180" keyPoints="0;0;1;1" keyTimes="0;0.8287;0.876;1" calcMode="linear" dur="43.18s" repeatCount="indefinite"/><g><circle r="7" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M0,-3.5 V1 M0,3.2 V3.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8878;0.9386" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><animateMotion path="M199,300 L324,300 L504,300" keyPoints="0;0;1;1" keyTimes="0;0.8878;0.9386;1" calcMode="linear" dur="43.18s" repeatCount="indefinite"/><g><rect x="-8" y="-6" width="16" height="12" rx="2" fill="#64748b" stroke="#fff" stroke-width="1.6"/><path d="M-5,-2 H5 M-5,2 H3" stroke="#fff" stroke-width="1.4"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.9433;0.9906" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><animateMotion path="M199,300 L71,300" keyPoints="0;0;1;1" keyTimes="0;0.9433;0.9906;1" calcMode="linear" dur="43.18s" repeatCount="indefinite"/><g><circle r="7" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M0,-3.5 V1 M0,3.2 V3.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/></g></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(20.4,352.5) scale(.8)"><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g><text x="31.8" y="356">command</text><g transform="translate(93.4,352.5) scale(.8)"><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g><text x="104.8" y="356">data</text><g transform="translate(149.6,352.5) scale(.8)"><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g><text x="161" y="356">request</text><g transform="translate(222.6,352.5) scale(.8)"><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g><text x="234" y="356">reply</text><g transform="translate(285.2,352.5) scale(.8)"><g><rect x="-8" y="-6" width="16" height="12" rx="2" fill="#64748b" stroke="#fff" stroke-width="1.6"/><path d="M-5,-2 H5 M-5,2 H3" stroke="#fff" stroke-width="1.4"/></g></g><text x="297.4" y="356">log line</text><g transform="translate(364.6,352.5) scale(.8)"><g><circle r="7" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M0,-3.5 V1 M0,3.2 V3.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/></g></g><text x="376" y="356">error</text></g>
<rect x="12" y="368" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="368" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="43.18s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1024" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><circle cx="36" cy="396" r="14" fill="#6366f1"/><text x="36" y="401" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="391" font-size="14" font-weight="800" fill="#6366f1">python3 check.py starts main()</text><text x="578" y="391" text-anchor="end" font-size="10.5" class="dg-muted">Start up · 1/9</text><text x="60" y="412" font-size="12.5" class="dg-text">Python runs the file top to bottom; the imports load each module first.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1024;0.2047" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><circle cx="36" cy="396" r="14" fill="#6366f1"/><text x="36" y="401" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="391" font-size="14" font-weight="800" fill="#6366f1">json reads the config</text><text x="578" y="391" text-anchor="end" font-size="10.5" class="dg-muted">Start up · 2/9</text><text x="60" y="412" font-size="12.5" class="dg-text">json.load(f) turns config.json into a Python dict you can read.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2047;0.3228" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><circle cx="36" cy="396" r="14" fill="#0d9488"/><text x="36" y="401" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="391" font-size="14" font-weight="800" fill="#0d9488">subprocess runs a command</text><text x="578" y="391" text-anchor="end" font-size="10.5" class="dg-muted">Do the work · 3/9</text><text x="60" y="412" font-size="12.5" class="dg-text">subprocess.run([&quot;df&quot;, &quot;-h&quot;, &quot;/&quot;]) returns returncode 0 and stdout.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3228;0.4409" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><circle cx="36" cy="396" r="14" fill="#0d9488"/><text x="36" y="401" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="391" font-size="14" font-weight="800" fill="#0d9488">requests calls an API</text><text x="578" y="391" text-anchor="end" font-size="10.5" class="dg-muted">Do the work · 4/9</text><text x="60" y="412" font-size="12.5" class="dg-text">requests.get(url, timeout=5): status 200, and r.json() gives the data.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4409;0.5591" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><circle cx="36" cy="396" r="14" fill="#0d9488"/><text x="36" y="401" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="391" font-size="14" font-weight="800" fill="#0d9488">boto3 asks AWS</text><text x="578" y="391" text-anchor="end" font-size="10.5" class="dg-muted">Do the work · 5/9</text><text x="60" y="412" font-size="12.5" class="dg-text">describe_instances, with the same ~/.aws credentials the AWS CLI uses.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5591;0.6614" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><circle cx="36" cy="396" r="14" fill="#0d9488"/><text x="36" y="401" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="391" font-size="14" font-weight="800" fill="#0d9488">logging records what happened</text><text x="578" y="391" text-anchor="end" font-size="10.5" class="dg-muted">Do the work · 6/9</text><text x="60" y="412" font-size="12.5" class="dg-text">log.info writes a timestamped INFO line instead of a bare print.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6614;0.7638" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><circle cx="36" cy="396" r="14" fill="#0d9488"/><text x="36" y="401" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="391" font-size="14" font-weight="800" fill="#0d9488">main() returns 0</text><text x="578" y="391" text-anchor="end" font-size="10.5" class="dg-muted">Do the work · 7/9</text><text x="60" y="412" font-size="12.5" class="dg-text">sys.exit(main()) hands 0 to cron or CI: everything worked.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7638;0.8819" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><circle cx="36" cy="396" r="14" fill="#e11d48"/><text x="36" y="401" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="391" font-size="14" font-weight="800" fill="#e11d48">Next run: the API does not answer</text><text x="578" y="391" text-anchor="end" font-size="10.5" class="dg-muted">When a call fails · 8/9</text><text x="60" y="412" font-size="12.5" class="dg-text">requests raises Timeout after 5 s instead of hanging forever.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8819" calcMode="discrete" dur="43.18s" repeatCount="indefinite"/><circle cx="36" cy="396" r="14" fill="#e11d48"/><text x="36" y="401" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">9</text><text x="60" y="391" font-size="14" font-weight="800" fill="#e11d48">Log the error, exit with 1</text><text x="578" y="391" text-anchor="end" font-size="10.5" class="dg-muted">When a call fails · 9/9</text><text x="60" y="412" font-size="12.5" class="dg-text">log.error records it, and exit code 1 tells cron or CI it failed.</text></g>
</svg>
```

```steps
#6366f1 | Start up | python3 check.py starts main() | Python runs the file top to bottom; the imports load each module first.
#6366f1 | Start up | json reads the config | json.load(f) turns config.json into a Python dict you can read.
#0d9488 | Do the work | subprocess runs a command | subprocess.run(["df", "-h", "/"]) returns returncode 0 and stdout.
#0d9488 | Do the work | requests calls an API | requests.get(url, timeout=5): status 200, and r.json() gives the data.
#0d9488 | Do the work | boto3 asks AWS | describe_instances, with the same ~/.aws credentials the AWS CLI uses.
#0d9488 | Do the work | logging records what happened | log.info writes a timestamped INFO line instead of a bare print.
#0d9488 | Do the work | main() returns 0 | sys.exit(main()) hands 0 to cron or CI: everything worked.
#e11d48 | When a call fails | Next run: the API does not answer | requests raises Timeout after 5 s instead of hanging forever.
#e11d48 | When a call fails | Log the error, exit with 1 | log.error records it, and exit code 1 tells cron or CI it failed.
```

```bash
python3 --version                      # Python 3.10+ recommended
python3                                # interactive shell (REPL); exit with exit() or Ctrl+D
python3 script.py arg1 arg2            # run a script with arguments
python3 -c 'print(2 ** 10)'            # one-liner
python3 -m venv .venv && source .venv/bin/activate   # per-project environment
pip install requests                   # install a package into the active venv
pip install -r requirements.txt        # install a project's dependencies
```

Script template, a good starting point for every script:

```python
#!/usr/bin/env python3
"""What this script does, in one line."""
import sys


def main() -> int:
    print("hello")
    return 0           # 0 = success, anything else = failure (used by cron, CI and monitoring)


if __name__ == "__main__":
    sys.exit(main())
```

Docs: [The Python Tutorial](https://docs.python.org/3/tutorial/) · [Standard library index](https://docs.python.org/3/library/index.html) · [Virtual environments](https://docs.python.org/3/tutorial/venv.html) · [PEP 8 style guide](https://peps.python.org/pep-0008/)

## Syntax essentials

> **In simple words:** The core language on one page: values, collections, decisions, loops, functions and errors. Indentation (4 spaces) is part of the syntax: it marks which lines belong to a block.

### Values and strings

```python
name = "web-01"                  # str
port = 8080                      # int
load = 0.75                      # float
healthy = True                   # bool
owner = None                     # "no value"

msg = f"{name}:{port} load={load:.0%}"    # f-string → "web-01:8080 load=75%"
"ERROR" in "ERROR db down"       # True: substring check
"  text \n".strip()              # "text"
"a,b,c".split(",")               # ["a", "b", "c"]
"-".join(["a", "b"])             # "a-b"
"Web-01".lower(), "api".upper(), "app.log".endswith(".log")
int("42"), str(42), float("0.5")         # conversions
```

### Collections

```python
servers = ["web-1", "web-2"]          # list: ordered, changeable
servers.append("db-1"); servers[0]; servers[-1]; servers[1:3]; len(servers)

point = ("10.0.0.1", 22)              # tuple: ordered, fixed
host, port = point                    # unpacking

envs = {"dev", "prod", "dev"}         # set: unique values → {"dev", "prod"}
"dev" in envs                         # fast membership test
{"a", "b"} & {"b", "c"}               # intersection → {"b"};  | union, - difference

svc = {"name": "api", "port": 8080}   # dict: key → value
svc["port"]; svc.get("owner", "n/a"); svc["replicas"] = 3
for key, value in svc.items(): print(key, value)

names = [s.upper() for s in servers if s.startswith("web")]   # list comprehension
ports = {s: 80 for s in servers}                               # dict comprehension
```

### Conditions and loops

```python
if load > 0.9:
    level = "critical"
elif load > 0.7:
    level = "warning"
else:
    level = "ok"

status = "up" if healthy else "down"          # one-line if

for i, server in enumerate(servers, start=1):  # index + item
    print(i, server)
for name, port in zip(["web", "db"], [80, 5432]):  # walk two lists together
    print(name, port)
for n in range(3):                             # 0, 1, 2
    print(n)

attempt = 0
while attempt < 3:
    attempt += 1
    if attempt == 2:
        continue          # skip to the next loop round
    if attempt > 5:
        break             # leave the loop
```

### Functions

```python
def check(host: str, port: int = 80, *, timeout: float = 5.0) -> bool:
    """Return True if host:port answers. Arguments after * must be passed by name."""
    ...
    return True


check("web-1")
check("db-1", 5432, timeout=2)


def tag(*args, **kwargs):          # any number of positional / keyword arguments
    print(args, kwargs)            # tag("a", "b", env="dev") → ('a', 'b') {'env': 'dev'}


square = lambda x: x * x           # small anonymous function
sorted(servers, key=len)           # functions passed as arguments
```

### Errors and exceptions

```python
try:
    value = int("8o80")
except ValueError as err:              # catch a SPECIFIC error
    print(f"bad number: {err}")
else:
    print("parsed fine")               # runs only if no error
finally:
    print("always runs")               # clean-up

if port < 1:
    raise ValueError(f"invalid port {port}")   # signal your own error
```

### Files and context managers

```python
with open("app.log") as f:             # 'with' closes the file automatically
    for line in f:                     # line by line: memory-friendly
        if "ERROR" in line:
            print(line.rstrip())

with open("report.txt", "w") as f:     # "w" overwrite, "a" append
    f.write("all good\n")
```

### Classes (just enough)

```python
from dataclasses import dataclass


@dataclass
class Server:
    name: str
    ip: str
    port: int = 22

    def address(self) -> str:
        return f"{self.ip}:{self.port}"


web = Server("web-1", "10.0.0.5")
print(web, web.address())     # Server(name='web-1', ip='10.0.0.5', port=22) 10.0.0.5:22
```

Docs: [Data structures](https://docs.python.org/3/tutorial/datastructures.html) · [Control flow](https://docs.python.org/3/tutorial/controlflow.html) · [Errors and exceptions](https://docs.python.org/3/tutorial/errors.html) · [dataclasses](https://docs.python.org/3/library/dataclasses.html)

## Files and the operating system: os, sys, pathlib, shutil, glob

> **In simple words:** These modules talk to the machine: environment variables, command-line arguments, folders and files, copying and deleting, and disk space.

```python
import os
import sys
import shutil
from pathlib import Path

# os: environment and the process
os.environ.get("ENV", "dev")              # read an env var with a default
os.getcwd(); os.getpid(); os.cpu_count()
os.makedirs("/tmp/app/logs", exist_ok=True)

# sys: arguments, exit, Python info
sys.argv            # ['script.py', 'arg1', ...]
sys.exit(1)         # stop with an exit code
print("error", file=sys.stderr)

# pathlib: the modern way to handle paths
log_dir = Path("/var/log/myapp")
for p in log_dir.glob("*.log"):           # rglob("*.log") searches subfolders too
    print(p.name, p.stat().st_size, p.suffix)
Path("config.json").exists(); Path("out.txt").write_text("hi"); Path("out.txt").read_text()
Path.home() / ".aws" / "config"           # build paths with /

# shutil: copy, move, delete trees, disk usage
shutil.copy("app.conf", "app.conf.bak")
shutil.rmtree("/tmp/app", ignore_errors=True)
total, used, free = shutil.disk_usage("/")
shutil.which("kubectl")                   # path to a command, or None
```

| Need | Use |
|---|---|
| Env vars | `os.environ.get("NAME", default)` |
| Script arguments | `sys.argv` (simple) or `argparse` (proper options) |
| Paths and files | `pathlib.Path` |
| Copy, move, delete, disk usage | `shutil` |
| Wildcard search | `Path.glob` / `glob.glob("*.log")` |

Docs: [os](https://docs.python.org/3/library/os.html) · [sys](https://docs.python.org/3/library/sys.html) · [pathlib](https://docs.python.org/3/library/pathlib.html) · [shutil](https://docs.python.org/3/library/shutil.html) · [glob](https://docs.python.org/3/library/glob.html)

## Running commands: subprocess

> **In simple words:** `subprocess.run` starts another program (`kubectl`, `git`, `df`), waits for it, and gives you its output and exit code.

```python
import subprocess

result = subprocess.run(["df", "-h", "/"], capture_output=True, text=True, timeout=30)
print(result.returncode)      # 0 = success
print(result.stdout)          # what it printed
print(result.stderr)          # its errors

# raise an exception automatically if the command fails
subprocess.run(["git", "pull", "--ff-only"], check=True)

# output as a string in one line
branch = subprocess.check_output(["git", "rev-parse", "--abbrev-ref", "HEAD"], text=True).strip()
```

| Option | Meaning |
|---|---|
| `["cmd", "arg"]` (a list) | Safe: no shell, no injection. Prefer this |
| `capture_output=True, text=True` | Collect stdout and stderr as strings |
| `check=True` | Raise `CalledProcessError` on a non-zero exit code |
| `timeout=30` | Kill it if it takes longer (raises `TimeoutExpired`) |
| `shell=True` | Run through the shell (pipes, `*`). **Never with untrusted input** |

Docs: [subprocess](https://docs.python.org/3/library/subprocess.html)

## Time and dates: time, datetime

> **In simple words:** `time` is for pauses and measuring durations; `datetime` is for real dates: timestamps in logs, "older than 7 days", time zones.

```python
import time
from datetime import datetime, timedelta, timezone

time.sleep(2)                          # wait 2 seconds
start = time.monotonic()               # for measuring durations
elapsed = time.monotonic() - start
time.time()                            # seconds since 1970 (epoch), used by file mtimes

now = datetime.now(timezone.utc)                       # always prefer timezone-aware UTC
week_ago = now - timedelta(days=7)
now.isoformat()                                        # '2026-11-08T11:30:00.123456+00:00'
now.strftime("%Y-%m-%d %H:%M")                          # format → '2026-11-08 11:30'
datetime.strptime("08/Nov/2026:10:00:00", "%d/%b/%Y:%H:%M:%S")   # parse a log timestamp
datetime.fromtimestamp(1762600000, tz=timezone.utc)     # epoch → datetime
```

Docs: [time](https://docs.python.org/3/library/time.html) · [datetime](https://docs.python.org/3/library/datetime.html)

## Data formats: json, csv, yaml

> **In simple words:** APIs speak JSON, spreadsheets and reports use CSV, and Kubernetes and CI configs use YAML. Each has a `load`/`read` side and a `dump`/`write` side.

```python
import csv
import json

import yaml      # pip install pyyaml

# JSON
data = json.loads('{"replicas": 3}')           # string → dict
text = json.dumps(data, indent=2)              # dict → string
with open("config.json") as f:
    cfg = json.load(f)                         # file → dict
with open("out.json", "w") as f:
    json.dump(cfg, f, indent=2)                # dict → file

# CSV
with open("servers.csv", newline="") as f:
    for row in csv.DictReader(f):              # each row is a dict keyed by the header
        print(row["hostname"], row["ip"])
with open("report.csv", "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["host", "status"])
    writer.writerow(["web-1", "up"])

# YAML
with open("deployment.yaml") as f:
    manifest = yaml.safe_load(f)               # safe_load: never plain load() on untrusted files
docs = list(yaml.safe_load_all(open("multi.yaml")))   # files with several --- documents
print(yaml.safe_dump({"env": "dev", "replicas": 2}))
```

Docs: [json](https://docs.python.org/3/library/json.html) · [csv](https://docs.python.org/3/library/csv.html) · [PyYAML](https://pyyaml.org/wiki/PyYAMLDocumentation)

## Text and logs: re, collections

> **In simple words:** `re` (regular expressions) finds patterns in text, such as IPs, status codes and error IDs. `collections` gives you counters and dictionaries that make log analysis short.

```python
import re
from collections import Counter, defaultdict

line = '10.0.0.7 - - [08/Nov/2026:10:00:00 +0000] "GET /api HTTP/1.1" 500 12'

m = re.search(r'^(\S+) .* "(\w+) (\S+) [^"]*" (\d{3})', line)
if m:
    ip, method, path, status = m.groups()       # ('10.0.0.7', 'GET', '/api', '500')

re.findall(r"\b\d{1,3}(?:\.\d{1,3}){3}\b", "from 10.0.0.1 to 10.0.0.2")   # all IPs
re.sub(r"password=\S+", "password=***", "user=a password=secret")         # mask secrets
pattern = re.compile(r"ERROR|CRITICAL")                                   # reuse a compiled pattern

counts = Counter(["200", "500", "200", "404"])
counts.most_common(2)                           # [('200', 2), ('500', 1)]

by_status = defaultdict(list)                   # missing keys start as an empty list
by_status["500"].append("/api")
```

Docs: [re](https://docs.python.org/3/library/re.html) · [Regular expression HOWTO](https://docs.python.org/3/howto/regex.html) · [collections](https://docs.python.org/3/library/collections.html)

## Scripts that behave: argparse, logging

> **In simple words:** `argparse` gives your script real options and a `--help` page. `logging` replaces `print` with timestamped messages and levels (DEBUG, INFO, WARNING, ERROR).

```python
import argparse
import logging

parser = argparse.ArgumentParser(description="Check disk usage")
parser.add_argument("path", nargs="?", default="/")
parser.add_argument("--threshold", type=int, default=80, help="alert above this %%")
parser.add_argument("-v", "--verbose", action="store_true")
args = parser.parse_args()

logging.basicConfig(
    level=logging.DEBUG if args.verbose else logging.INFO,
    format="%(asctime)s %(levelname)-7s %(message)s",
)
log = logging.getLogger(__name__)
log.info("checking %s (threshold %d%%)", args.path, args.threshold)
log.warning("disk above threshold")
log.error("could not read %s", args.path)
# log.exception("...") inside an except block also prints the traceback
```

Docs: [argparse](https://docs.python.org/3/library/argparse.html) · [logging](https://docs.python.org/3/library/logging.html) · [Logging HOWTO](https://docs.python.org/3/howto/logging.html)

## Network and HTTP: socket, requests

> **In simple words:** `socket` answers "can I reach this host and port at all?" (TCP). `requests` makes HTTP calls: health checks, REST APIs, webhooks.

```python
import socket

import requests     # pip install requests

# Is a TCP port open?
try:
    with socket.create_connection(("10.0.1.50", 5432), timeout=5):
        print("port open")
except OSError as err:
    print("port closed or unreachable:", err)

socket.gethostbyname("example.com")              # DNS lookup → IP

# HTTP
r = requests.get("https://api.github.com/repos/python/cpython", timeout=5)
r.status_code, r.ok, r.elapsed.total_seconds()
data = r.json()                                  # parse a JSON response
r.raise_for_status()                             # raise on 4xx / 5xx

requests.post("https://hooks.example.com/alert", json={"text": "disk 91%"}, timeout=5)
requests.get(url, headers={"Authorization": f"Bearer {token}"}, params={"page": 2}, timeout=5)
```

Always set a **`timeout`** on network calls. Without one, a script can hang forever.

Docs: [socket](https://docs.python.org/3/library/socket.html) · [Requests quickstart](https://requests.readthedocs.io/en/latest/user/quickstart/)

## System monitoring: psutil

> **In simple words:** `psutil` reads what `top`, `free` and `df` show: CPU, memory, disk, network and processes, on Linux, macOS and Windows alike.

```python
import psutil      # pip install psutil

psutil.cpu_percent(interval=1)           # % over 1 second
psutil.cpu_count()
mem = psutil.virtual_memory()
mem.percent, mem.available // 2**20      # % used, MiB available
psutil.disk_usage("/").percent
psutil.boot_time()

for p in psutil.process_iter(["pid", "name", "memory_percent"]):
    if p.info["name"] == "nginx":
        print(p.info)

top = sorted(psutil.process_iter(["name", "memory_percent"]),
             key=lambda p: p.info["memory_percent"] or 0, reverse=True)[:5]
```

Docs: [psutil](https://psutil.readthedocs.io/)

## Parallel work: concurrent.futures

> **In simple words:** Checking 100 URLs one after another is slow. A thread pool runs them side by side, which is ideal for anything that waits on the network (HTTP, AWS calls, SSH).

```python
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests

urls = ["https://example.com", "https://python.org"]


def check(url):
    return url, requests.get(url, timeout=5).status_code


with ThreadPoolExecutor(max_workers=10) as pool:
    futures = [pool.submit(check, u) for u in urls]
    for fut in as_completed(futures):           # results as they finish
        print(*fut.result())
```

Use `ProcessPoolExecutor` instead for CPU-heavy work, such as compressing or parsing huge files.

Docs: [concurrent.futures](https://docs.python.org/3/library/concurrent.futures.html)

## Cloud and Kubernetes: boto3, kubernetes

> **In simple words:** `boto3` controls AWS, and the `kubernetes` client controls clusters. Both reuse the credentials you already have (`~/.aws`, `~/.kube/config`), so if the CLIs work, these work.

```python
import boto3                                       # pip install boto3

ec2 = boto3.client("ec2", region_name="us-east-1")
for page in ec2.get_paginator("describe_instances").paginate():   # all pages, not just the first
    for r in page["Reservations"]:
        for i in r["Instances"]:
            print(i["InstanceId"], i["State"]["Name"])

s3 = boto3.client("s3")
s3.upload_file("backup.tgz", "my-bucket", "backups/backup.tgz")
boto3.Session(profile_name="dev").client("sts").get_caller_identity()
```

```python
from kubernetes import client, config               # pip install kubernetes

config.load_kube_config()                           # inside a pod: config.load_incluster_config()
v1 = client.CoreV1Api()
for pod in v1.list_namespaced_pod("default").items:
    print(pod.metadata.name, pod.status.phase)

apps = client.AppsV1Api()
apps.patch_namespaced_deployment_scale("api", "default", {"spec": {"replicas": 3}})
```

Docs: [boto3 quickstart](https://boto3.amazonaws.com/v1/documentation/api/latest/guide/quickstart.html) · [boto3 reference](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html) · [Kubernetes Python client](https://github.com/kubernetes-client/python)

## Module quick reference

> **In simple words:** One table to answer "which module do I need for this?", with a link to its official docs.

| Task | Module | Install | Docs |
|---|---|---|---|
| Environment variables, folders | `os` | built in | [os](https://docs.python.org/3/library/os.html) |
| Arguments, exit codes | `sys`, `argparse` | built in | [sys](https://docs.python.org/3/library/sys.html) · [argparse](https://docs.python.org/3/library/argparse.html) |
| Paths and files | `pathlib`, `shutil`, `glob` | built in | [pathlib](https://docs.python.org/3/library/pathlib.html) · [shutil](https://docs.python.org/3/library/shutil.html) |
| Run Linux commands | `subprocess` | built in | [subprocess](https://docs.python.org/3/library/subprocess.html) |
| Sleep, durations, timestamps | `time`, `datetime` | built in | [time](https://docs.python.org/3/library/time.html) · [datetime](https://docs.python.org/3/library/datetime.html) |
| JSON and CSV | `json`, `csv` | built in | [json](https://docs.python.org/3/library/json.html) · [csv](https://docs.python.org/3/library/csv.html) |
| YAML | `yaml` | `pip install pyyaml` | [PyYAML](https://pyyaml.org/wiki/PyYAMLDocumentation) |
| Log parsing, patterns | `re`, `collections` | built in | [re](https://docs.python.org/3/library/re.html) · [collections](https://docs.python.org/3/library/collections.html) |
| Logs from your script | `logging` | built in | [logging](https://docs.python.org/3/library/logging.html) |
| TCP connectivity, DNS | `socket` | built in | [socket](https://docs.python.org/3/library/socket.html) |
| HTTP and APIs | `requests` | `pip install requests` | [Requests](https://requests.readthedocs.io/) |
| CPU, memory, processes | `psutil` | `pip install psutil` | [psutil](https://psutil.readthedocs.io/) |
| Parallel checks | `concurrent.futures` | built in | [concurrent.futures](https://docs.python.org/3/library/concurrent.futures.html) |
| AWS | `boto3` | `pip install boto3` | [boto3](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html) |
| Kubernetes | `kubernetes` | `pip install kubernetes` | [Python client](https://github.com/kubernetes-client/python) |
| Type hints, simple classes | `typing`, `dataclasses` | built in | [typing](https://docs.python.org/3/library/typing.html) · [dataclasses](https://docs.python.org/3/library/dataclasses.html) |
