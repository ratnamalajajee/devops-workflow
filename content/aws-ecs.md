# Amazon ECS: Running Containers on AWS

Amazon ECS (Elastic Container Service) is AWS's own container orchestrator. It keeps your containers running, replaces failed ones, rolls out new versions and connects them to load balancers, without the complexity of Kubernetes. With **Fargate** there are no servers to manage at all. This guide deploys the sample app from ECR to ECS on Fargate behind an Application Load Balancer, then covers updates, rollbacks, auto scaling, logs, shell access and secrets.

> **Note:** Do the [ECR guide](#/tool/aws-ecr) first. This guide uses the `hello-app:1.0.0` image pushed there, which listens on port 8000 with a `/health` endpoint. Knowing the [Load Balancers](#/tool/aws-elb) and [IAM](#/tool/aws-iam) guides helps too.

> **Cost:** Fargate charges per vCPU-hour and GB-hour while tasks run. A small task (0.25 vCPU, 0.5 GB) costs roughly **1–2 cents per hour**, plus the ALB at about $0.0225/hour. Run the lab, then **clean up**. See [Fargate pricing](https://aws.amazon.com/fargate/pricing/).

## Start here: ECS in simple words

> **In simple words:** You give ECS a **recipe card** (the *task definition*: which image, how much CPU and memory, which port) and say "always keep 2 of these running" (the *service*). ECS starts them, watches them, replaces any that crash, and plugs them into the load balancer.

### Watch how it works

```svg Watch it work: shipping image 1.1.0 to two Fargate tasks behind a load balancer, a user visiting, and the ECS service replacing a task that stops. The animation loops.
<svg viewBox="0 0 600 476" role="img" data-anim="ecs" aria-label="Animated ECS flow. Ship: docker build makes the image, docker push stores it in ECR, the ECS service starts two Fargate tasks, each task pulls the image from ECR, and the service registers the tasks in the target group. Visit: the browser asks Route 53, connects over HTTPS to the load balancer, the target group picks a healthy task, task A answers and the reply goes back. Self-healing: task B stops, the target group stops sending users to it, and the ECS service starts a new task.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<rect x="136" y="12" width="452" height="318" rx="14" class="dg-region"/>
<text x="148" y="31" font-size="13" font-weight="800" fill="#f97316">VPC</text>
<rect x="148" y="40" width="428" height="72" rx="10" fill="none" stroke="#10b981" stroke-width="1.5" stroke-dasharray="5 4"/>
<text x="568" y="57" text-anchor="end" font-size="11" class="dg-muted">public subnets</text>
<rect x="148" y="124" width="428" height="194" rx="10" fill="none" stroke="#3b82f6" stroke-width="1.5" stroke-dasharray="5 4"/>
<text x="568" y="141" text-anchor="end" font-size="11" class="dg-muted">private subnets</text>
<polyline points="66,98 66,130" fill="none" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="120,76 184,76" fill="none" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="304,76 324,76" fill="none" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="376,98 376,150" fill="none" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="301,150 451,150" fill="none" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="301,150 301,180" fill="none" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="451,150 451,180" fill="none" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="120,369 236,369" fill="none" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".6"/>
<polyline points="301,346 301,250" fill="none" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".6"/>
<polyline points="346,346 346,336 420,336 420,250" fill="none" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".6"/>
<polyline points="461,346 461,250" fill="none" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".7"/>
<polyline points="461,296 272,296 272,250" fill="none" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".7"/>
<g><rect x="8" y="50" width="116" height="52" rx="12" fill="#6366f1" fill-opacity=".18" stroke="#6366f1" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.4595;0.5473;0.7162;0.8041" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/></rect><rect x="12" y="54" width="108" height="44" rx="9" class="dg-box" stroke="#6366f1" stroke-width="2.2"/><text x="66" y="72" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">User</text><text x="66" y="89" text-anchor="middle" font-size="11" class="dg-muted">browser</text></g>
<g><rect x="8" y="126" width="116" height="52" rx="12" fill="#7c3aed" fill-opacity=".18" stroke="#7c3aed" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4595;0.5473" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/></rect><rect x="12" y="130" width="108" height="44" rx="9" class="dg-box" stroke="#7c3aed" stroke-width="2.2"/><text x="66" y="148" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Route 53</text><text x="66" y="165" text-anchor="middle" font-size="11" class="dg-muted">DNS</text></g>
<g><rect x="8" y="342" width="116" height="54" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.0878" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/></rect><rect x="12" y="346" width="108" height="46" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="66" y="365" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Laptop / CI</text><text x="66" y="382" text-anchor="middle" font-size="11" class="dg-muted">your code</text></g>
<g><rect x="232" y="342" width="138" height="54" rx="12" fill="#2563eb" fill-opacity=".18" stroke="#2563eb" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0878;0.1757" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/></rect><rect x="236" y="346" width="130" height="46" rx="9" class="dg-box" stroke="#2563eb" stroke-width="2.2"/><text x="301" y="365" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Amazon ECR</text><text x="301" y="382" text-anchor="middle" font-size="11" class="dg-muted">hello-app:1.1.0</text></g>
<g><rect x="382" y="342" width="158" height="54" rx="12" fill="#ea580c" fill-opacity=".18" stroke="#ea580c" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.1757;0.2703;0.8986" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/></rect><rect x="386" y="346" width="150" height="46" rx="9" class="dg-box" stroke="#ea580c" stroke-width="2.2"/><text x="461" y="365" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">ECS service</text><text x="461" y="382" text-anchor="middle" font-size="11" class="dg-muted">keeps 2 running</text></g>
<g><rect x="180" y="50" width="128" height="52" rx="12" fill="#c026d3" fill-opacity=".18" stroke="#c026d3" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5473;0.6351" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/></rect><rect x="184" y="54" width="120" height="44" rx="9" class="dg-box" stroke="#c026d3" stroke-width="2.2"/><text x="244" y="72" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Load balancer</text><text x="244" y="89" text-anchor="middle" font-size="11" class="dg-muted">HTTPS · ACM</text></g>
<g><rect x="320" y="50" width="112" height="52" rx="12" fill="#0ea5e9" fill-opacity=".18" stroke="#0ea5e9" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0;1;0" keyTimes="0;0.3649;0.4595;0.5473;0.6351;0.8041;0.8986" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/></rect><rect x="324" y="54" width="104" height="44" rx="9" class="dg-box" stroke="#0ea5e9" stroke-width="2.2"/><text x="376" y="72" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Target group</text><text x="376" y="89" text-anchor="middle" font-size="11" class="dg-muted">checks /health</text></g>
<g><rect x="232" y="176" width="138" height="78" rx="12" fill="#10b981" fill-opacity=".18" stroke="#10b981" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0" keyTimes="0;0.2703;0.3649;0.6351;0.7162" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/></rect><rect x="236" y="180" width="130" height="70" rx="9" class="dg-box" stroke="#10b981" stroke-width="2.2"/><text x="301" y="211" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Task A</text><text x="301" y="229" text-anchor="middle" font-size="11" class="dg-muted">Fargate · :8000</text></g>
<g><rect x="382" y="176" width="138" height="78" rx="12" fill="#10b981" fill-opacity=".18" stroke="#10b981" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.2703;0.3649;0.8041" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/></rect><rect x="386" y="180" width="130" height="70" rx="9" class="dg-box" stroke="#10b981" stroke-width="2.2"/><text x="451" y="211" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Task B</text><text x="451" y="229" text-anchor="middle" font-size="11" class="dg-muted">Fargate · :8000</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8041;0.8986" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/><rect x="386" y="180" width="130" height="70" rx="9" fill="#e11d48"/><text x="451" y="220" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">✕ stopped</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8986" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/><rect x="386" y="180" width="130" height="70" rx="9" fill="#059669"/><text x="451" y="220" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">+ new task</text></g></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8041;0.8986" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/><circle cx="451" cy="165" r="9" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M447,161 L455,169 M455,161 L447,169" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/></g>
<g font-size="10.5" class="dg-muted"><circle cx="18" cy="16" r="5" fill="#6366f1"/><text x="27" y="20">request</text><circle cx="70" cy="16" r="5" fill="#10b981"/><text x="79" y="20">reply</text><rect x="13" y="28" width="10" height="9" rx="2" fill="#f97316"/><text x="27" y="37">code</text><circle cx="70" cy="33" r="4.5" fill="#a855f7"/><text x="79" y="37">command</text></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0931;0.1634" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/><animateMotion path="M66,369 L301,369" keyPoints="0;0;1;1" keyTimes="0;0.0931;0.1634;1" calcMode="linear" dur="29.6s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1814;0.257" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/><animateMotion path="M461,369 L461,296 L272,296 L272,215" keyPoints="0;0;1;1" keyTimes="0;0.1814;0.257;1" calcMode="linear" dur="29.6s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1814;0.257" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/><animateMotion path="M461,369 L461,215" keyPoints="0;0;1;1" keyTimes="0;0.1814;0.257;1" calcMode="linear" dur="29.6s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2759;0.3516" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/><animateMotion path="M301,369 L301,215" keyPoints="0;0;1;1" keyTimes="0;0.2759;0.3516;1" calcMode="linear" dur="29.6s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2759;0.3516" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/><animateMotion path="M346,369 L346,336 L420,336 L420,215" keyPoints="0;0;1;1" keyTimes="0;0.2759;0.3516;1" calcMode="linear" dur="29.6s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3705;0.4462" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/><animateMotion path="M301,215 L301,150 L376,150 L376,76" keyPoints="0;0;1;1" keyTimes="0;0.3705;0.4462;1" calcMode="linear" dur="29.6s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3705;0.4462" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/><animateMotion path="M451,215 L451,150 L376,150 L376,76" keyPoints="0;0;1;1" keyTimes="0;0.3705;0.4462;1" calcMode="linear" dur="29.6s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4647;0.535" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/><animateMotion path="M66,76 L66,152 L66,76" keyPoints="0;0;1;1" keyTimes="0;0.4647;0.535;1" calcMode="linear" dur="29.6s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5526;0.6228" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/><animateMotion path="M66,76 L244,76 L376,76" keyPoints="0;0;1;1" keyTimes="0;0.5526;0.6228;1" calcMode="linear" dur="29.6s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.64;0.7049" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/><animateMotion path="M376,76 L376,150 L301,150 L301,215" keyPoints="0;0;1;1" keyTimes="0;0.64;0.7049;1" calcMode="linear" dur="29.6s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7215;0.7918" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/><animateMotion path="M301,215 L301,150 L376,150 L376,76 L244,76 L66,76" keyPoints="0;0;1;1" keyTimes="0;0.7215;0.7918;1" calcMode="linear" dur="29.6s" repeatCount="indefinite"/><circle r="7" fill="#10b981" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.9047;0.9858" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/><animateMotion path="M461,369 L461,215" keyPoints="0;0;1;1" keyTimes="0;0.9047;0.9858;1" calcMode="linear" dur="29.6s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<rect x="12" y="414" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/>
<rect x="12" y="414" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="29.6s" repeatCount="indefinite"/></rect>
<g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.0878" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/><circle cx="36" cy="442" r="14" fill="#f97316"/><text x="36" y="447" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="437" font-size="14" font-weight="800" fill="#f97316">Build the image</text><text x="578" y="437" text-anchor="end" font-size="10.5" class="dg-muted">Ship a new version · 1/11</text><text x="60" y="458" font-size="12.5" class="dg-text">docker build packs your code, Python and libraries into hello-app:1.1.0.</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0878;0.1757" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/><circle cx="36" cy="442" r="14" fill="#f97316"/><text x="36" y="447" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="437" font-size="14" font-weight="800" fill="#f97316">Push it to ECR</text><text x="578" y="437" text-anchor="end" font-size="10.5" class="dg-muted">Ship a new version · 2/11</text><text x="60" y="458" font-size="12.5" class="dg-text">docker push puts the image on AWS&#x27;s private shelf for images.</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1757;0.2703" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/><circle cx="36" cy="442" r="14" fill="#f97316"/><text x="36" y="447" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="437" font-size="14" font-weight="800" fill="#f97316">The ECS service starts new tasks</text><text x="578" y="437" text-anchor="end" font-size="10.5" class="dg-muted">Ship a new version · 3/11</text><text x="60" y="458" font-size="12.5" class="dg-text">update-service with the new task definition: Fargate starts 2 tasks.</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2703;0.3649" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/><circle cx="36" cy="442" r="14" fill="#f97316"/><text x="36" y="447" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="437" font-size="14" font-weight="800" fill="#f97316">Each task pulls the image</text><text x="578" y="437" text-anchor="end" font-size="10.5" class="dg-muted">Ship a new version · 4/11</text><text x="60" y="458" font-size="12.5" class="dg-text">Fargate downloads hello-app:1.1.0 from ECR and starts the container.</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3649;0.4595" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/><circle cx="36" cy="442" r="14" fill="#f97316"/><text x="36" y="447" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="437" font-size="14" font-weight="800" fill="#f97316">Tasks join the target group</text><text x="578" y="437" text-anchor="end" font-size="10.5" class="dg-muted">Ship a new version · 5/11</text><text x="60" y="458" font-size="12.5" class="dg-text">The service adds each task&#x27;s IP; old tasks stop once the new ones are healthy.</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4595;0.5473" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/><circle cx="36" cy="442" r="14" fill="#6366f1"/><text x="36" y="447" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="437" font-size="14" font-weight="800" fill="#6366f1">A user opens ecs.example.com</text><text x="578" y="437" text-anchor="end" font-size="10.5" class="dg-muted">A user visits · 6/11</text><text x="60" y="458" font-size="12.5" class="dg-text">The browser asks Route 53, which answers with the load balancer&#x27;s address.</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5473;0.6351" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/><circle cx="36" cy="442" r="14" fill="#6366f1"/><text x="36" y="447" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="437" font-size="14" font-weight="800" fill="#6366f1">HTTPS to the load balancer</text><text x="578" y="437" text-anchor="end" font-size="10.5" class="dg-muted">A user visits · 7/11</text><text x="60" y="458" font-size="12.5" class="dg-text">The ACM certificate gives the padlock; the target group picks a healthy task.</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6351;0.7162" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/><circle cx="36" cy="442" r="14" fill="#6366f1"/><text x="36" y="447" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="437" font-size="14" font-weight="800" fill="#6366f1">Task A answers</text><text x="578" y="437" text-anchor="end" font-size="10.5" class="dg-muted">A user visits · 8/11</text><text x="60" y="458" font-size="12.5" class="dg-text">Your container replies on port 8000. There is no server for you to manage.</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7162;0.8041" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/><circle cx="36" cy="442" r="14" fill="#6366f1"/><text x="36" y="447" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">9</text><text x="60" y="437" font-size="14" font-weight="800" fill="#6366f1">The reply goes back the same way</text><text x="578" y="437" text-anchor="end" font-size="10.5" class="dg-muted">A user visits · 9/11</text><text x="60" y="458" font-size="12.5" class="dg-text">Load balancer → browser. The next visitor may be sent to task B.</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8041;0.8986" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/><circle cx="36" cy="442" r="14" fill="#e11d48"/><text x="36" y="447" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">10</text><text x="60" y="437" font-size="14" font-weight="800" fill="#e11d48">If task B stops…</text><text x="578" y="437" text-anchor="end" font-size="10.5" class="dg-muted">Self-healing · 10/11</text><text x="60" y="458" font-size="12.5" class="dg-text">Its health check fails, so the target group stops sending users to it.</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8986" calcMode="discrete" dur="29.6s" repeatCount="indefinite"/><circle cx="36" cy="442" r="14" fill="#e11d48"/><text x="36" y="447" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">11</text><text x="60" y="437" font-size="14" font-weight="800" fill="#e11d48">…the ECS service replaces it</text><text x="578" y="437" text-anchor="end" font-size="10.5" class="dg-muted">Self-healing · 11/11</text><text x="60" y="458" font-size="12.5" class="dg-text">Running 1 of 2 → Fargate starts a new task and registers it. Back to 2 of 2.</text></g>
</svg>
```

### A real-life comparison

Think of a **food truck company**:

| Food trucks | ECS |
|---|---|
| The recipe card for a dish | **Task definition**: image, CPU, memory, ports, environment |
| One cook making that dish right now | **Task**: a running copy of the task definition |
| "Always have 2 cooks on the burger stand" | **Service**: keeps N tasks running and replaces failed ones |
| The company running everything | **Cluster**: the logical group your services run in |
| Renting kitchen space by the hour vs owning trucks | **Fargate** (serverless) vs the **EC2** launch type (your own instances) |

### How the pieces fit

```text
 ECR image ──▶ Task definition (hello-app:3)  ──used by──▶  Service "hello" (desired: 2)
                                                              │ runs tasks on Fargate
                                                              ▼
 users ──▶ ALB ──▶ Target group (ip targets) ──▶ [task 10.0.1.12:8000] [task 10.0.2.40:8000]
                                                  logs ─▶ CloudWatch Logs
```

### Key words

| Word | Simple meaning |
|---|---|
| **Cluster** | A named group for your services and tasks |
| **Task definition** | A versioned JSON recipe: containers, image, CPU/memory, ports, env, logging, IAM roles |
| **Task** | A running instance of a task definition (one or more containers) |
| **Service** | Keeps a desired number of tasks running, handles deployments and the load balancer |
| **Fargate** | Serverless compute for containers: no EC2 instances to patch |
| **Task execution role** | The IAM role **ECS** uses to pull the image and write logs |
| **Task role** | The IAM role **your app** uses to call AWS (S3, DynamoDB…) |
| **awsvpc** | Network mode where each task gets its own IP and security group |

### ECS or EKS?

| | ECS | EKS (Kubernetes) |
|---|---|---|
| Learning curve | Gentle, AWS-native | Steeper |
| Portability | AWS only | Any cloud or on-premises |
| Control plane cost | **Free** | About $0.10/hour per cluster |
| Ecosystem | AWS integrations | Huge (Helm, Argo CD, operators…) |
| Good for | Teams all-in on AWS who want simplicity | Multi-cloud, platform teams, Kubernetes skills |

### Check yourself

1. What's the difference between a task definition and a task?
2. Which IAM role pulls the image from ECR: the task role or the task execution role?
3. What does a service do that a single task doesn't?

> **Tip:** Answers: 1) The task definition is the recipe; a task is one running copy of it. 2) The task **execution** role. 3) It keeps the desired number of tasks running, replaces failures, does rolling deployments and registers tasks with the load balancer.

## Set up: cluster, roles, network and logs

> **In simple words:** Before running anything, create an empty cluster, the IAM role ECS uses to pull images and write logs, security groups, and a log group.

```bash
export AWS_REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IMAGE=$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/hello-app:1.0.0
VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
read SUBNET_A SUBNET_B <<< $(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID Name=default-for-az,Values=true \
  --query 'Subnets[0:2].SubnetId' --output text)

# 1. Cluster (Fargate needs no instances)
aws ecs create-cluster --cluster-name demo

# 2. Task execution role: lets ECS pull from ECR and write logs
cat > ecs-tasks-trust.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{ "Effect": "Allow", "Principal": { "Service": "ecs-tasks.amazonaws.com" }, "Action": "sts:AssumeRole" }]
}
EOF
aws iam create-role --role-name ecsTaskExecutionRole --assume-role-policy-document file://ecs-tasks-trust.json
aws iam attach-role-policy --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# 3. Security groups: ALB open to the world, tasks open only to the ALB on 8000
ALB_SG=$(aws ec2 create-security-group --group-name ecs-alb-sg --description "ECS ALB" --vpc-id $VPC_ID --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $ALB_SG --protocol tcp --port 80 --cidr 0.0.0.0/0
TASK_SG=$(aws ec2 create-security-group --group-name ecs-task-sg --description "ECS tasks" --vpc-id $VPC_ID --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $TASK_SG --protocol tcp --port 8000 --source-group $ALB_SG

# 4. Log group for container output
aws logs create-log-group --log-group-name /ecs/hello-app
aws logs put-retention-policy --log-group-name /ecs/hello-app --retention-in-days 7
```

AWS docs: [What is Amazon ECS?](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/Welcome.html) · [Task execution IAM role](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html)

## Write and register a task definition

> **In simple words:** The task definition is the recipe card: image, CPU and memory, port, environment variables and where logs go. Every time you register it, you get a new numbered **revision**.

`taskdef.json`. Replace `ACCOUNT_ID` and the Region if needed:

```json
{
  "family": "hello-app",
  "requiresCompatibilities": ["FARGATE"],
  "networkMode": "awsvpc",
  "cpu": "256",
  "memory": "512",
  "runtimePlatform": { "operatingSystemFamily": "LINUX", "cpuArchitecture": "X86_64" },
  "executionRoleArn": "arn:aws:iam::ACCOUNT_ID:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "web",
      "image": "ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/hello-app:1.0.0",
      "essential": true,
      "portMappings": [{ "containerPort": 8000, "protocol": "tcp" }],
      "environment": [{ "name": "APP_VERSION", "value": "1.0.0" }],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/hello-app",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "web"
        }
      }
    }
  ]
}
```

```bash
sed -i "s/ACCOUNT_ID/$ACCOUNT_ID/g" taskdef.json
aws ecs register-task-definition --cli-input-json file://taskdef.json \
  --query 'taskDefinition.[family,revision,status]' --output text      # hello-app 1 ACTIVE
aws ecs list-task-definitions --family-prefix hello-app
```

Valid Fargate sizes pair CPU with memory, for example 256 (0.25 vCPU) with 512–2048 MB, or 512 with 1–4 GB. `cpuArchitecture` must match how the image was built (`X86_64` or `ARM64`).

AWS docs: [Task definitions](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definitions.html) · [Fargate](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html)

## Run a one-off task

> **In simple words:** Before building a full service, start a single task by hand to check that the image, roles and network are right. It's like a test cook before opening the stand.

```bash
# temporary rule: allow your IP straight to the task on 8000 for this test
MYIP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress --group-id $TASK_SG --protocol tcp --port 8000 --cidr $MYIP/32

TASK_ARN=$(aws ecs run-task --cluster demo --launch-type FARGATE --task-definition hello-app \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_A],securityGroups=[$TASK_SG],assignPublicIp=ENABLED}" \
  --query 'tasks[0].taskArn' --output text)
aws ecs wait tasks-running --cluster demo --tasks $TASK_ARN

ENI=$(aws ecs describe-tasks --cluster demo --tasks $TASK_ARN \
  --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" --output text)
TASK_IP=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI --query 'NetworkInterfaces[0].Association.PublicIp' --output text)
curl -s http://$TASK_IP:8000/ ; echo

aws ecs stop-task --cluster demo --task $TASK_ARN
aws ec2 revoke-security-group-ingress --group-id $TASK_SG --protocol tcp --port 8000 --cidr $MYIP/32
```

`assignPublicIp=ENABLED` lets the task reach ECR over the internet in the default VPC's public subnets. In private subnets you'd use a **NAT gateway** or **VPC endpoints** instead.

## Create a service behind a load balancer

> **In simple words:** Now the real thing: a **service** that keeps 2 tasks running across two AZs and registers them with an ALB, so users get one stable address and failed tasks are replaced automatically.

```bash
# Target group: target type "ip" (required for Fargate / awsvpc)
TG_ARN=$(aws elbv2 create-target-group --name ecs-hello-tg --protocol HTTP --port 8000 --vpc-id $VPC_ID \
  --target-type ip --health-check-path /health --health-check-interval-seconds 15 \
  --healthy-threshold-count 2 --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 modify-target-group-attributes --target-group-arn $TG_ARN \
  --attributes Key=deregistration_delay.timeout_seconds,Value=30

read ALB_ARN ALB_DNS <<< $(aws elbv2 create-load-balancer --name ecs-hello-alb --type application \
  --subnets $SUBNET_A $SUBNET_B --security-groups $ALB_SG \
  --query 'LoadBalancers[0].[LoadBalancerArn,DNSName]' --output text)
aws elbv2 create-listener --load-balancer-arn $ALB_ARN --protocol HTTP --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN

# The service
aws ecs create-service --cluster demo --service-name hello \
  --task-definition hello-app --desired-count 2 --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_A,$SUBNET_B],securityGroups=[$TASK_SG],assignPublicIp=ENABLED}" \
  --load-balancers "targetGroupArn=$TG_ARN,containerName=web,containerPort=8000" \
  --health-check-grace-period-seconds 30 \
  --deployment-configuration "deploymentCircuitBreaker={enable=true,rollback=true},maximumPercent=200,minimumHealthyPercent=100"

aws ecs wait services-stable --cluster demo --services hello     # a few minutes
for i in $(seq 6); do curl -s http://$ALB_DNS/; echo; done          # "host" alternates between tasks
```

Test self-healing: stop one task and watch the service start a replacement.

```bash
aws ecs stop-task --cluster demo --task $(aws ecs list-tasks --cluster demo --service-name hello --query 'taskArns[0]' --output text)
watch -n5 "aws ecs describe-services --cluster demo --services hello --query 'services[0].[runningCount,desiredCount]' --output text"
```

The console's **ECS → Clusters → demo → Services → Create** walks through the same fields.

AWS docs: [ECS services](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs_services.html)

## Deploy a new version and roll back

> **In simple words:** Register a new task definition revision with the new image, then point the service at it. ECS starts new tasks, waits until they're healthy behind the ALB, then stops the old ones. If the new version keeps failing, the **circuit breaker** rolls back automatically.

```bash
# Build and push 1.1.0 (see ECR guide), then:
sed -i 's/hello-app:1.0.0/hello-app:1.1.0/; s/"value": "1.0.0"/"value": "1.1.0"/' taskdef.json
aws ecs register-task-definition --cli-input-json file://taskdef.json --query 'taskDefinition.revision'

aws ecs update-service --cluster demo --service hello --task-definition hello-app     # latest revision
aws ecs describe-services --cluster demo --services hello \
  --query 'services[0].deployments[].[status,taskDefinition,runningCount,rolloutState]' --output table
aws ecs wait services-stable --cluster demo --services hello
```

**Manual rollback:** point the service back at the previous revision:

```bash
aws ecs update-service --cluster demo --service hello --task-definition hello-app:1
```

Restart all tasks with the same definition (for example to pick up a changed secret) with `aws ecs update-service --cluster demo --service hello --force-new-deployment`.

| Deployment strategy | How it works |
|---|---|
| **Rolling update** (default) | Replaces tasks gradually, controlled by `minimumHealthyPercent` and `maximumPercent` |
| **Blue/green** (built into ECS) | Starts the full new version next to the old one, shifts load balancer traffic (all at once, canary or linear), keeps both during a bake time, and rolls back on alarms |
| **Circuit breaker** | Detects deployments whose tasks never become healthy and rolls back automatically |

AWS docs: [Rolling deployments](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-ecs.html) · [Blue/green deployments](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-blue-green.html)

## Auto scaling

> **In simple words:** Let ECS add tasks when they get busy and remove them when it's quiet, for example "keep average CPU around 60%, with between 2 and 6 tasks".

```bash
aws application-autoscaling register-scalable-target --service-namespace ecs \
  --scalable-dimension ecs:service:DesiredCount --resource-id service/demo/hello \
  --min-capacity 2 --max-capacity 6

aws application-autoscaling put-scaling-policy --service-namespace ecs \
  --scalable-dimension ecs:service:DesiredCount --resource-id service/demo/hello \
  --policy-name cpu-60 --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{
    "TargetValue": 60.0,
    "PredefinedMetricSpecification": { "PredefinedMetricType": "ECSServiceAverageCPUUtilization" },
    "ScaleInCooldown": 120, "ScaleOutCooldown": 60
  }'

aws application-autoscaling describe-scaling-activities --service-namespace ecs --resource-id service/demo/hello
```

Other useful metrics: `ECSServiceAverageMemoryUtilization`, and `ALBRequestCountPerTarget` (scale by requests per task).

AWS docs: [Service auto scaling](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-auto-scaling.html)

## Logs, metrics and a shell inside a task (ECS Exec)

> **In simple words:** Container output goes to CloudWatch Logs. **ECS Exec** lets you open a shell inside a running container, like `docker exec`, without SSH or open ports.

### Logs and metrics

```bash
aws logs tail /ecs/hello-app --follow --since 10m
aws ecs describe-services --cluster demo --services hello --query 'services[0].events[0:5].[createdAt,message]' --output table
```

Turn on **Container Insights** for per-task CPU, memory and network dashboards:

```bash
aws ecs update-cluster-settings --cluster demo --settings name=containerInsights,value=enabled
```

### ECS Exec

1. Give the **task role** (your app's role) permission to open SSM channels:

```bash
aws iam create-role --role-name hello-app-task-role --assume-role-policy-document file://ecs-tasks-trust.json
aws iam put-role-policy --role-name hello-app-task-role --policy-name ecs-exec --policy-document '{
  "Version": "2012-10-17",
  "Statement": [{ "Effect": "Allow", "Resource": "*", "Action": [
    "ssmmessages:CreateControlChannel", "ssmmessages:CreateDataChannel",
    "ssmmessages:OpenControlChannel", "ssmmessages:OpenDataChannel" ] }]
}'
```

2. Add `"taskRoleArn": "arn:aws:iam::<ACCOUNT_ID>:role/hello-app-task-role"` to `taskdef.json`, register it, and enable exec on the service:

```bash
aws ecs register-task-definition --cli-input-json file://taskdef.json
aws ecs update-service --cluster demo --service hello --task-definition hello-app \
  --enable-execute-command --force-new-deployment
aws ecs wait services-stable --cluster demo --services hello
```

3. Install the **Session Manager plugin** for the AWS CLI on your machine, then:

```bash
TASK=$(aws ecs list-tasks --cluster demo --service-name hello --query 'taskArns[0]' --output text)
aws ecs execute-command --cluster demo --task $TASK --container web --interactive --command "/bin/sh"
# inside: env | grep APP_VERSION ; python -c "import urllib.request;print(urllib.request.urlopen('http://localhost:8000/health').read())"
```

AWS docs: [ECS Exec](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html) · [Task IAM role](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html)

## Configuration and secrets

> **In simple words:** Keep settings in `environment`, and passwords in **Secrets Manager** or **SSM Parameter Store**. ECS fetches secrets when a task starts and injects them as environment variables, so they never appear in the task definition.

```bash
aws secretsmanager create-secret --name hello-app/db-password --secret-string 'S3cr3t!'
SECRET_ARN=$(aws secretsmanager describe-secret --secret-id hello-app/db-password --query ARN --output text)

# the EXECUTION role fetches secrets at start-up
aws iam put-role-policy --role-name ecsTaskExecutionRole --policy-name read-app-secrets --policy-document "{
  \"Version\": \"2012-10-17\",
  \"Statement\": [{ \"Effect\": \"Allow\", \"Action\": \"secretsmanager:GetSecretValue\", \"Resource\": \"$SECRET_ARN\" }]
}"
```

Add to the container definition in `taskdef.json`, then register and update the service:

```json
"secrets": [
  { "name": "DB_PASSWORD", "valueFrom": "arn:aws:secretsmanager:us-east-1:111122223333:secret:hello-app/db-password-AbCdEf" }
]
```

If the secret is encrypted with your own KMS key, the execution role also needs `kms:Decrypt` on it (see the [KMS guide](#/tool/aws-kms)).

## Troubleshooting

> **In simple words:** When tasks won't stay up, ask ECS **why it stopped them**. The `stoppedReason` and the service **events** almost always name the problem.

```bash
aws ecs describe-services --cluster demo --services hello --query 'services[0].events[0:8].message'
aws ecs list-tasks --cluster demo --desired-status STOPPED --query 'taskArns[0:3]'
aws ecs describe-tasks --cluster demo --tasks <STOPPED_TASK_ARN> \
  --query 'tasks[0].[stoppedReason,containers[0].reason,containers[0].exitCode]'
aws logs tail /ecs/hello-app --since 30m
```

| Symptom | Likely cause / fix |
|---|---|
| `CannotPullContainerError` | Wrong image URI or tag; execution role missing ECR permissions; no route to ECR (enable a public IP, NAT or VPC endpoints) |
| `ResourceInitializationError: unable to retrieve secret` / logs | The execution role can't read the secret or KMS key, or the log group doesn't exist |
| Tasks start, then stop: `Task failed ELB health checks` | Wrong health check path or port, the app is slow to start (raise the grace period), or the task security group doesn't allow the ALB on 8000 |
| `exec format error` | Image architecture ≠ `cpuArchitecture` (ARM vs x86) |
| Exit code 137 | Out of memory. Raise the task's `memory` |
| `execute-command` fails | Exec not enabled on the service, missing task role permissions, or no Session Manager plugin locally |
| Deployment stuck "IN_PROGRESS" | New tasks never become healthy. The circuit breaker will roll back, so check the events |

## Clean up

> **In simple words:** Scale the service to zero, delete it, then remove the load balancer, cluster, roles, logs and security groups. Running tasks and the ALB bill every hour.

```bash
aws application-autoscaling deregister-scalable-target --service-namespace ecs \
  --scalable-dimension ecs:service:DesiredCount --resource-id service/demo/hello 2>/dev/null
aws ecs update-service --cluster demo --service hello --desired-count 0
aws ecs delete-service --cluster demo --service hello --force
aws ecs wait services-inactive --cluster demo --services hello

aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN
aws elbv2 wait load-balancers-deleted --load-balancer-arns $ALB_ARN
aws elbv2 delete-target-group --target-group-arn $TG_ARN

for rev in $(aws ecs list-task-definitions --family-prefix hello-app --query 'taskDefinitionArns[]' --output text); do
  aws ecs deregister-task-definition --task-definition $rev > /dev/null; done
aws ecs delete-cluster --cluster demo
aws logs delete-log-group --log-group-name /ecs/hello-app
aws secretsmanager delete-secret --secret-id hello-app/db-password --force-delete-without-recovery

sleep 30   # wait for task network interfaces to be released
aws ec2 delete-security-group --group-id $TASK_SG
aws ec2 delete-security-group --group-id $ALB_SG
```

Delete the IAM roles `ecsTaskExecutionRole` and `hello-app-task-role` too, if you don't need them for other labs (detach or delete their policies first).

## Lab: ship the sample app on Fargate

> **In simple words:** Practice time: run the sample app on ECS the way a team would, including a bad release that rolls itself back.

1. Push `hello-app:1.0.0` to ECR (ECR guide).
2. Create the cluster, execution role, security groups and log group.
3. Register the task definition and test with a one-off task.
4. Create the `hello` service with 2 tasks behind an ALB. `curl` the ALB and watch the hosts alternate.
5. Deploy `1.1.0` with a new message and verify the rolling update.
6. Deploy a **broken** image (for example one whose `/health` returns 500). Watch the circuit breaker roll back on its own.
7. Add CPU target-tracking auto scaling between 2 and 6 tasks.
8. Open a shell in a running task with **ECS Exec**.
9. Inject a secret from Secrets Manager and confirm it's visible inside the container (then delete it).
10. Clean up everything.

### Cheat sheet

| Task | Command |
|---|---|
| Create cluster | `aws ecs create-cluster --cluster-name demo` |
| Register task def | `aws ecs register-task-definition --cli-input-json file://taskdef.json` |
| Create service | `aws ecs create-service --cluster demo --service-name s --task-definition td --desired-count 2 --launch-type FARGATE …` |
| Deploy new revision | `aws ecs update-service --cluster demo --service s --task-definition td` |
| Restart tasks | `aws ecs update-service --cluster demo --service s --force-new-deployment` |
| Why did it stop? | `aws ecs describe-tasks --cluster demo --tasks T --query 'tasks[0].stoppedReason'` |
| Logs | `aws logs tail /ecs/hello-app --follow` |
| Shell in task | `aws ecs execute-command --cluster demo --task T --container web --interactive --command /bin/sh` |
