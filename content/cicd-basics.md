# CI/CD Basics

CI/CD is how teams turn a code change into a tested, running application automatically, many times a day, without anyone copying files to servers by hand. This guide explains the ideas and the vocabulary, compares the four tools in this section (Jenkins, GitHub Actions, GitLab CI and Argo CD), and sets up the **sample app** that every CI/CD guide uses.

## Start here: CI/CD in simple words

> **In simple words:** CI/CD is an **automatic assembly line for software**. Every time someone saves a change to the code, a robot builds it, tests it and, if everything passes, delivers it to the servers.

### Watch how it works

```svg Watch it work: a push being built, tested and packaged as an image once, delivered to staging and then production after an approval, and a failed test stopping the line. The animation loops.
<svg viewBox="0 0 600 312" role="img" data-anim="cicd-basics" aria-label="Animated CI/CD pipeline for the sample app hello-app. Continuous integration: a developer runs git push, and that push is the trigger that starts the pipeline. A runner gets the code, installs it and runs pytest; both tests pass. The app is packaged once as a Docker image tagged with the commit SHA, hello-app:1a2b3c4, and pushed to a registry. Continuous delivery: the same image is deployed to staging, where a smoke test checks that /health answers. The release is now ready, and a person approves production. Production gets exactly the same image, with no rebuild; with continuous deployment this approval would be automatic. A test fails: on the next push one test fails, so the pipeline stops, nothing is packaged or deployed, and the developer sees the red build and the failing test within minutes.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<rect x="248" y="10" width="344" height="96" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="5 4"/>
<polyline points="64,65 182,65 337,65 503,65" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="503,90 503,130 72,130 72,162" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="72,187 224,187 376,187 528,187" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<rect x="254" y="16" width="167.3" height="16" rx="5" class="dg-box"/><text x="258" y="26" font-size="11" class="dg-muted">pipeline · runs on a runner</text>
<g><rect x="8" y="36" width="112" height="58" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1" keyTimes="0;0.1066;0.8852" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/></rect><rect x="12" y="40" width="104" height="50" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="64" y="61.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Developer</text><text x="64" y="77" text-anchor="middle" font-size="11" class="dg-muted">git push</text></g>
<g><rect x="126" y="36" width="112" height="58" rx="12" fill="#7c3aed" fill-opacity=".18" stroke="#7c3aed" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.2213" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/></rect><rect x="130" y="40" width="104" height="50" rx="9" class="dg-box" stroke="#7c3aed" stroke-width="2.2"/><text x="182" y="61.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Git repo</text><text x="182" y="77" text-anchor="middle" font-size="11" class="dg-muted">hello-app</text></g>
<g><rect x="258" y="36" width="158" height="58" rx="12" fill="#0d9488" fill-opacity=".18" stroke="#0d9488" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.1066;0.2213;0.7705;0.8852" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/></rect><rect x="262" y="40" width="150" height="50" rx="9" class="dg-box" stroke="#0d9488" stroke-width="2.2"/><text x="337" y="61.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Build + test</text><text x="337" y="77" text-anchor="middle" font-size="11" class="dg-muted">pip install, pytest</text><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.7705" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><rect x="262" y="40" width="150" height="50" rx="9" fill="#e11d48"/><text x="337" y="69.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">✕ 1 test failed</text></g></g>
<rect x="428" y="40" width="150" height="50" rx="9" class="dg-box"/><g opacity="1"><animate attributeName="opacity" values="1;0.28" keyTimes="0;0.7705" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><rect x="424" y="36" width="158" height="58" rx="12" fill="#f97316" fill-opacity=".18" stroke="#f97316" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2213;0.3279" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/></rect><rect x="428" y="40" width="150" height="50" rx="9" class="dg-box" stroke="#f97316" stroke-width="2.2"/><text x="503" y="61.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Package image</text><text x="503" y="77" text-anchor="middle" font-size="11" class="dg-muted">hello-app:1a2b3c4</text></g>
<rect x="12" y="162" width="120" height="50" rx="9" class="dg-box"/><g opacity="1"><animate attributeName="opacity" values="1;0.28" keyTimes="0;0.7705" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><rect x="8" y="158" width="128" height="58" rx="12" fill="#0ea5e9" fill-opacity=".18" stroke="#0ea5e9" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3279;0.4344" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/></rect><rect x="12" y="162" width="120" height="50" rx="9" class="dg-box" stroke="#0ea5e9" stroke-width="2.2"/><text x="72" y="183.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Registry</text><text x="72" y="199" text-anchor="middle" font-size="11" class="dg-muted">stores the image</text></g>
<rect x="164" y="162" width="120" height="50" rx="9" class="dg-box"/><g opacity="1"><animate attributeName="opacity" values="1;0.28" keyTimes="0;0.7705" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><rect x="160" y="158" width="128" height="58" rx="12" fill="#10b981" fill-opacity=".18" stroke="#10b981" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4344;0.5492" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/></rect><rect x="164" y="162" width="120" height="50" rx="9" class="dg-box" stroke="#10b981" stroke-width="2.2"/><text x="224" y="183.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Staging</text><text x="224" y="199" text-anchor="middle" font-size="11" class="dg-muted">smoke test /health</text></g>
<rect x="316" y="162" width="120" height="50" rx="9" class="dg-box"/><g opacity="1"><animate attributeName="opacity" values="1;0.28" keyTimes="0;0.7705" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><rect x="312" y="158" width="128" height="58" rx="12" fill="#d97706" fill-opacity=".18" stroke="#d97706" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5492;0.6557" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/></rect><rect x="316" y="162" width="120" height="50" rx="9" class="dg-box" stroke="#d97706" stroke-width="2.2"/><text x="376" y="183.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Approval</text><text x="376" y="199" text-anchor="middle" font-size="11" class="dg-muted">a person clicks</text></g>
<rect x="468" y="162" width="120" height="50" rx="9" class="dg-box"/><g opacity="1"><animate attributeName="opacity" values="1;0.28" keyTimes="0;0.7705" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><rect x="464" y="158" width="128" height="58" rx="12" fill="#2563eb" fill-opacity=".18" stroke="#2563eb" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6557;0.7705" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/></rect><rect x="468" y="162" width="120" height="50" rx="9" class="dg-box" stroke="#2563eb" stroke-width="2.2"/><text x="528" y="183.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Production</text><text x="528" y="199" text-anchor="middle" font-size="11" class="dg-muted">the same image</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1066;0.7705" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><circle cx="412" cy="40" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M407.5,40 L411,43.5 L416.5,36.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4344;0.7705" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><circle cx="284" cy="162" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M279.5,162 L283,165.5 L288.5,158.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5492;0.6557" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><circle cx="436" cy="162" r="9.5" fill="#d97706" stroke="#fff" stroke-width="2"/><rect x="431.5" y="161" width="9" height="6.5" rx="1.2" fill="#fff"/><path d="M433.2,161 V159 A2.8,2.8 0 0 1 438.8,159 V161" fill="none" stroke="#fff" stroke-width="1.6"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6557;0.7705" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><circle cx="436" cy="162" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M431.5,162 L435,165.5 L440.5,158.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6557;0.7705" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><circle cx="588" cy="162" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M583.5,162 L587,165.5 L592.5,158.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.7705" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><circle cx="420" cy="65" r="9.5" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M416,61 L424,69 M424,61 L416,69" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0064;0.0916" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><animateMotion path="M64,65 L182,65" keyPoints="0;0;1;1" keyTimes="0;0.0064;0.0916;1" calcMode="linear" dur="24.4s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1134;0.1754" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><animateMotion path="M182,65 L337,65" keyPoints="0;0;1;1" keyTimes="0;0.1134;0.1754;1" calcMode="linear" dur="24.4s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2277;0.313" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><animateMotion path="M337,65 L503,65" keyPoints="0;0;1;1" keyTimes="0;0.2277;0.313;1" calcMode="linear" dur="24.4s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3343;0.4195" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><animateMotion path="M503,90 L503,130 L72,130 L72,162" keyPoints="0;0;1;1" keyTimes="0;0.3343;0.4195;1" calcMode="linear" dur="24.4s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4413;0.5331" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><animateMotion path="M72,187 L224,187" keyPoints="0;0;1;1" keyTimes="0;0.4413;0.5331;1" calcMode="linear" dur="24.4s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5556;0.6408" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><animateMotion path="M224,187 L376,187" keyPoints="0;0;1;1" keyTimes="0;0.5556;0.6408;1" calcMode="linear" dur="24.4s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6626;0.7544" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><animateMotion path="M376,187 L528,187" keyPoints="0;0;1;1" keyTimes="0;0.6626;0.7544;1" calcMode="linear" dur="24.4s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7751;0.8279" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><animateMotion path="M64,65 L182,65 L337,65" keyPoints="0;0;1;1" keyTimes="0;0.7751;0.8279;1" calcMode="linear" dur="24.4s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8921;0.9839" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><animateMotion path="M337,65 L182,65 L64,65" keyPoints="0;0;1;1" keyTimes="0;0.8921;0.9839;1" calcMode="linear" dur="24.4s" repeatCount="indefinite"/><g><rect x="-9" y="-6" width="18" height="12" rx="2" fill="#db2777" stroke="#fff" stroke-width="1.6"/><path d="M-8,-5 L0,1 L8,-5" fill="none" stroke="#fff" stroke-width="1.4"/></g></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(20.4,236.5) scale(.8)"><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g><text x="31.8" y="240">trigger</text><g transform="translate(93.4,236.5) scale(.8)"><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g><text x="104.8" y="240">job</text><g transform="translate(144.8,236.5) scale(.8)"><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g><text x="157" y="240">image</text><g transform="translate(209,236.5) scale(.8)"><g><rect x="-9" y="-6" width="18" height="12" rx="2" fill="#db2777" stroke="#fff" stroke-width="1.6"/><path d="M-8,-5 L0,1 L8,-5" fill="none" stroke="#fff" stroke-width="1.4"/></g></g><text x="222" y="240">feedback</text></g>
<rect x="12" y="252" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="252" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="24.4s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1066" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><circle cx="36" cy="280" r="14" fill="#6366f1"/><text x="36" y="285" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="275" font-size="14" font-weight="800" fill="#6366f1">You push a change</text><text x="578" y="275" text-anchor="end" font-size="10.5" class="dg-muted">CI: build and test · 1/9</text><text x="60" y="296" font-size="12.5" class="dg-text">git push to hello-app. That push is the trigger that starts the pipeline.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1066;0.2213" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><circle cx="36" cy="280" r="14" fill="#6366f1"/><text x="36" y="285" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="275" font-size="14" font-weight="800" fill="#6366f1">A runner builds and tests it</text><text x="578" y="275" text-anchor="end" font-size="10.5" class="dg-muted">CI: build and test · 2/9</text><text x="60" y="296" font-size="12.5" class="dg-text">The runner gets the code, installs it and runs pytest -v: 2 passed.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2213;0.3279" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><circle cx="36" cy="280" r="14" fill="#6366f1"/><text x="36" y="285" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="275" font-size="14" font-weight="800" fill="#6366f1">Package it once, as an image</text><text x="578" y="275" text-anchor="end" font-size="10.5" class="dg-muted">CI: build and test · 3/9</text><text x="60" y="296" font-size="12.5" class="dg-text">docker build makes hello-app:1a2b3c4, tagged with the commit SHA.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3279;0.4344" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><circle cx="36" cy="280" r="14" fill="#6366f1"/><text x="36" y="285" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="275" font-size="14" font-weight="800" fill="#6366f1">Publish it to a registry</text><text x="578" y="275" text-anchor="end" font-size="10.5" class="dg-muted">CI: build and test · 4/9</text><text x="60" y="296" font-size="12.5" class="dg-text">This image is the artifact. Every later step uses this exact image.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4344;0.5492" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><circle cx="36" cy="280" r="14" fill="#f97316"/><text x="36" y="285" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="275" font-size="14" font-weight="800" fill="#f97316">Deploy to staging</text><text x="578" y="275" text-anchor="end" font-size="10.5" class="dg-muted">CD: deliver · 5/9</text><text x="60" y="296" font-size="12.5" class="dg-text">The same image starts on staging. A smoke test checks /health answers.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5492;0.6557" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><circle cx="36" cy="280" r="14" fill="#f97316"/><text x="36" y="285" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="275" font-size="14" font-weight="800" fill="#f97316">A person approves production</text><text x="578" y="275" text-anchor="end" font-size="10.5" class="dg-muted">CD: deliver · 6/9</text><text x="60" y="296" font-size="12.5" class="dg-text">Continuous delivery: the release is ready, and a human clicks Deploy.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6557;0.7705" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><circle cx="36" cy="280" r="14" fill="#f97316"/><text x="36" y="285" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="275" font-size="14" font-weight="800" fill="#f97316">Production gets the same image</text><text x="578" y="275" text-anchor="end" font-size="10.5" class="dg-muted">CD: deliver · 7/9</text><text x="60" y="296" font-size="12.5" class="dg-text">No rebuild. With continuous deployment, nobody needs to click at all.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7705;0.8852" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><circle cx="36" cy="280" r="14" fill="#e11d48"/><text x="36" y="285" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="275" font-size="14" font-weight="800" fill="#e11d48">Next push: a test fails</text><text x="578" y="275" text-anchor="end" font-size="10.5" class="dg-muted">A test fails · 8/9</text><text x="60" y="296" font-size="12.5" class="dg-text">pytest fails, so the line stops. Nothing is packaged or deployed.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8852" calcMode="discrete" dur="24.4s" repeatCount="indefinite"/><circle cx="36" cy="280" r="14" fill="#e11d48"/><text x="36" y="285" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">9</text><text x="60" y="275" font-size="14" font-weight="800" fill="#e11d48">The developer knows in minutes</text><text x="578" y="275" text-anchor="end" font-size="10.5" class="dg-muted">A test fails · 9/9</text><text x="60" y="296" font-size="12.5" class="dg-text">A red build names the failing test. Fix it, push again, and it&#x27;s checked again.</text></g>
</svg>
```

### The problem it solves

Without CI/CD, releasing software looks like this: a developer finishes a feature, someone builds it on their laptop, runs a few tests if there's time, copies the files to the server late on a Friday, and hopes nothing breaks. Bugs are found by users, and nobody is sure exactly what is running.

With CI/CD, **every change goes through the same automatic checks, every time**. Problems are caught within minutes, while the developer still remembers the change, and releases become boring, which is exactly what you want.

### A real-life comparison

Think of a **car factory assembly line**. Each car moves through fixed stations: frame, engine, paint, quality check. If a car fails the quality check, it never leaves the factory. Every car is built the same way, no matter who is working that day.

A CI/CD **pipeline** is that assembly line. The stations are steps like *build*, *test*, *security scan* and *deploy*, and a failed check stops the line.

### Key words

| Word | Simple meaning |
|---|---|
| **CI (Continuous Integration)** | Automatically build and test every change as soon as it's pushed |
| **CD (Continuous Delivery)** | Every change that passes is *ready* to release; a human clicks "deploy" |
| **CD (Continuous Deployment)** | Every change that passes is released *automatically*, with no human click |
| **Pipeline** | The full list of automatic steps from code change to release |
| **Stage** | A group of steps in the pipeline, such as *test* or *deploy* |
| **Job** | One task inside a stage, such as "run unit tests" |
| **Trigger** | What starts the pipeline: a push, a pull request, a schedule, or a button |
| **Runner / agent** | The machine that actually runs the jobs |
| **Artifact** | A file the pipeline produces and keeps, such as a test report or a built image |
| **Secret** | A password or token the pipeline needs, stored safely and hidden in logs |
| **Environment** | A place the app runs: *dev*, *staging* or *production* |

### Check yourself

1. What's the difference between Continuous Delivery and Continuous Deployment?
2. What happens on the assembly line if a test fails?
3. What is a runner?

> **Tip:** Answers: 1) Delivery means every change is *ready* to release and a person clicks deploy; Deployment means it's released *automatically*. 2) The pipeline stops, and the change never reaches users. 3) The machine that runs the pipeline's jobs.

## CI, continuous delivery and continuous deployment

> **In simple words:** CI checks every change. Continuous delivery gets every good change ready to ship. Continuous deployment ships it automatically.

```text
  Continuous Integration          Continuous Delivery            Continuous Deployment
 ┌──────────────────────┐      ┌───────────────────────┐      ┌──────────────────────┐
 │ push → build → test  │ ───▶ │ package → deploy to   │ ───▶ │ deploy to production │
 │ (every commit)       │      │ staging → READY       │      │ AUTOMATICALLY        │
 └──────────────────────┘      │ (human approves prod) │      └──────────────────────┘
                               └───────────────────────┘
```

| | What's automated | Who decides to release |
|---|---|---|
| **Continuous Integration** | Build and test on every push | Not a release step yet |
| **Continuous Delivery** | Everything up to a release-ready package, often deployed to staging | A person approves production |
| **Continuous Deployment** | Everything, including production | The pipeline: if all checks pass, it ships |

Most teams start with CI, then add continuous delivery with a manual approval for production. They move to full continuous deployment once their tests are trusted.

## Anatomy of a pipeline

> **In simple words:** A pipeline is a list of steps in order. Each step must pass before the next one starts.

A typical pipeline for a web app:

```text
 git push
    │
    ▼
 1. Checkout   get the code
 2. Build      install dependencies / compile
 3. Test       unit tests, lint (style checks)
 4. Scan       security checks on code and dependencies
 5. Package    build a Docker image, tag it with the version
 6. Publish    push the image to a registry (Docker Hub, GHCR, ECR, GitLab)
 7. Deploy     update staging ── approve ──▶ update production
 8. Verify     smoke test: does the live app answer?
```

Rules that make pipelines trustworthy:

- **Fail fast.** Put quick checks (lint, unit tests) first so mistakes are found in seconds, not minutes.
- **Build once, deploy many times.** Build the image once, then promote **the same image** to staging and production. Don't rebuild for each environment.
- **Version everything.** Tag images with the Git commit SHA or a version number, never just `latest`, so you always know what's running and can roll back.
- **Keep secrets out of code.** Use the tool's secret store, and give the pipeline the least access it needs.
- **The pipeline is code.** Store it in the repo (`Jenkinsfile`, `.github/workflows/*.yml`, `.gitlab-ci.yml`) so changes to it are reviewed too.

## The four tools compared

> **In simple words:** Jenkins, GitHub Actions and GitLab CI are all assembly lines that **build and test** code. Argo CD is different: it **deploys** to Kubernetes by watching Git.

| | Jenkins | GitHub Actions | GitLab CI/CD | Argo CD |
|---|---|---|---|---|
| **What it is** | Self-hosted automation server | CI/CD built into GitHub | CI/CD built into GitLab | GitOps deployment tool for Kubernetes |
| **Pipeline file** | `Jenkinsfile` (Groovy) | `.github/workflows/*.yml` | `.gitlab-ci.yml` | Kubernetes YAML plus an `Application` resource |
| **Where it runs** | Your own servers | GitHub's runners, or your own | GitLab's runners, or your own | Inside your Kubernetes cluster |
| **Strengths** | Extremely flexible, 1,800+ plugins, works with any Git host | Zero setup for GitHub repos, huge marketplace | All-in-one: Git, CI, registry, environments | Drift detection, easy rollback, cluster pulls changes |
| **You maintain** | The server, plugins, upgrades and backups | Almost nothing | Almost nothing on gitlab.com | Argo CD itself (it's small) |
| **Typical use** | Enterprises with existing Jenkins | Projects hosted on GitHub | Projects hosted on GitLab | The *deploy* half of a Kubernetes pipeline |

### Push vs pull deployment

```text
 PUSH (Jenkins / GitHub Actions / GitLab deploy job)
   CI pipeline ──kubectl apply──▶ cluster        CI needs cluster credentials

 PULL (GitOps with Argo CD)
   CI pipeline ──commit new tag──▶ Git ◀──watches── Argo CD (in cluster) ──▶ applies
                                                   credentials never leave the cluster
```

A very common setup combines them: **Jenkins, GitHub Actions or GitLab CI** builds, tests and pushes the image, then updates the image tag in a GitOps repo. **Argo CD** deploys it. You'll build exactly that flow in the Argo CD guide.

## The sample app used in every CI/CD guide

> **In simple words:** One tiny web app with two tests. Every CI/CD guide builds, tests and ships this same app, so you can compare the tools fairly.

Create the project once:

```bash
mkdir -p ~/code/hello-app && cd ~/code/hello-app
```

`app.py`, a tiny web API:

```python
from flask import Flask
import os, socket

app = Flask(__name__)

@app.get("/")
def index():
    return {"message": "Hello from CI/CD!", "host": socket.gethostname(),
            "version": os.getenv("APP_VERSION", "dev")}

@app.get("/health")
def health():
    return {"status": "ok"}
```

`test_app.py`, the automatic tests the pipelines will run:

```python
from app import app

def test_index_returns_message():
    response = app.test_client().get("/")
    assert response.status_code == 200
    assert response.get_json()["message"] == "Hello from CI/CD!"

def test_health_is_ok():
    response = app.test_client().get("/health")
    assert response.get_json() == {"status": "ok"}
```

`requirements.txt` lists what the app needs to run, and `requirements-dev.txt` adds what's only needed for testing:

```text
flask==3.0.3
gunicorn==23.0.0
```

```text
-r requirements.txt
pytest==8.3.3
```

`Dockerfile`:

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
RUN useradd --create-home appuser
USER appuser
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}
EXPOSE 8000
CMD ["gunicorn", "-b", "0.0.0.0:8000", "app:app"]
```

`.dockerignore` and `.gitignore`:

```text
.git
.venv
__pycache__
.pytest_cache
reports
```

Check it all works **on your machine first**. A pipeline only automates what already works by hand:

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements-dev.txt
pytest -v                                   # 2 passed

docker build -t hello-app:local .
docker run -d --rm --name hello -p 8000:8000 hello-app:local
curl -s localhost:8000/health               # {"status":"ok"}
docker stop hello
```

Put it in Git, then push it to GitHub (and/or GitLab) as a new repository called `hello-app`:

```bash
git init -b main && git add . && git commit -m "Sample app for CI/CD guides"
git remote add origin git@github.com:<you>/hello-app.git
git push -u origin main
```

> **Tip:** No Python or Docker on your laptop? Open the **cloud lab machine** in the [Practice lab](#/lab). It has both.

## Which guide next?

> **In simple words:** Pick the tool your team uses first. The ideas carry over to the others.

| If your team uses… | Start with |
|---|---|
| GitHub to host code | [GitHub Actions](#/tool/github-actions) |
| GitLab to host code | [GitLab CI/CD](#/tool/gitlab-ci) |
| Jenkins (common in large companies) | [Jenkins](#/tool/jenkins) |
| Kubernetes, and wants GitOps deployments | [Argo CD](#/tool/argocd), after one of the CI tools |

Whichever you choose, finish with the Argo CD guide's **Sample application flow** step. It connects your CI tool to Argo CD for a full commit-to-production pipeline.
