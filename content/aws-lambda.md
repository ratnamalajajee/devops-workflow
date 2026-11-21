# AWS Lambda and EventBridge: Serverless Automation

Run small pieces of code **without managing any server**: AWS Lambda starts your code only when something happens, and Amazon EventBridge decides **when** (a timetable) or **on what** (an event from another AWS service). This guide creates and tests a Python function, then builds a real money saver: a Lambda that **stops tagged EC2 instances every Friday evening and starts them on Monday morning**. Every step shows the **console clicks** and the matching **AWS CLI** commands.

> **Cost:** Lambda costs about **$0.20 per million requests** plus **$0.0000166667 per GB-second** of run time (x86, us-east-1), and the monthly free tier includes **1 million requests and 400,000 GB-seconds**. **EventBridge Scheduler** gives **14 million invocations per month free**, then $1.00 per million. Events from AWS services on the default event bus are free. Everything in this lab fits in the free tiers; only the small test EC2 instance costs a few cents per hour. See [Lambda pricing](https://aws.amazon.com/lambda/pricing/) and [EventBridge pricing](https://aws.amazon.com/eventbridge/pricing/).

## Start here: Lambda and EventBridge in simple words

> **In simple words:** **Lambda** is code that **sleeps until something happens**, wakes up, does one job, and goes back to sleep. You never see or patch a server, and you pay only for the milliseconds it runs. **EventBridge** is what wakes it up: an **alarm clock** (Scheduler) or a **doorbell** (rules that react to events).

### Watch how it works

```svg Watch it work: a Friday schedule wakes the Lambda function, which finds and stops the tagged servers, and a Monday schedule starts them again. The animation loops.
<svg viewBox="0 0 600 386" role="img" data-anim="aws-lambda" aria-label="Animated weekend shutdown with Lambda and EventBridge Scheduler. Friday evening: at 20:00 India time the schedule weekend-stop fires and invokes the Lambda function weekend-scheduler with the event {&quot;action&quot;: &quot;stop&quot;}. There is no server to manage: Lambda starts the code only for this run. Using its execution role, the function calls DescribeInstances to find running instances tagged Schedule=office-hours, and gets back the dev server and the test server. It then calls StopInstances on those two. The role only allows stopping and starting instances with that tag, so the prod database, which has no tag, is never touched. The function writes a summary line to the log group /aws/lambda/weekend-scheduler in CloudWatch Logs. The weekend: the two servers stay stopped and the function sleeps, which costs nothing. Monday morning: at 08:00 the schedule weekend-start invokes the same function with {&quot;action&quot;: &quot;start&quot;}. It finds the stopped tagged instances and calls StartInstances, and logs the result. You pay per request and per millisecond of run time, which for two short runs a week fits in the free tier.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<rect x="6" y="8" width="160" height="244" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="5 4"/>
<rect x="420" y="8" width="172" height="244" rx="12" fill="none" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="5 4"/>
<polyline points="86,67 184,67 184,140 290,140" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="86,213 184,213 184,140" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="290,40 290,140" fill="none" stroke-linejoin="round" stroke="#eab308" stroke-width="1.8" stroke-dasharray="3 3" stroke-opacity=".75"/>
<polyline points="290,140 290,250" fill="none" stroke-linejoin="round" stroke="#64748b" stroke-width="1.8" stroke-dasharray="4 3" stroke-opacity=".7"/>
<polyline points="290,140 507,140" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="400,140 400,66 507,66" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="400,140 400,214 507,214" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<rect x="12" y="14" width="149.6" height="16" rx="5" class="dg-box"/><text x="16" y="24" font-size="11" class="dg-muted">Scheduler · Asia/Kolkata</text>
<rect x="426" y="14" width="84.7" height="16" rx="5" class="dg-box"/><text x="430" y="24" font-size="11" class="dg-muted">EC2 instances</text>
<g><rect x="12" y="36" width="148" height="62" rx="12" fill="#6366f1" fill-opacity=".18" stroke="#6366f1" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1239" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/></rect><rect x="16" y="40" width="140" height="54" rx="9" class="dg-box" stroke="#6366f1" stroke-width="2.2"/><text x="86" y="63.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">weekend-stop</text><text x="86" y="79" text-anchor="middle" font-size="11" class="dg-muted">cron(0 20 ? * FRI *)</text></g>
<g><rect x="12" y="182" width="148" height="62" rx="12" fill="#059669" fill-opacity=".18" stroke="#059669" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6195;0.7434" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/></rect><rect x="16" y="186" width="140" height="54" rx="9" class="dg-box" stroke="#059669" stroke-width="2.2"/><text x="86" y="209.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">weekend-start</text><text x="86" y="225" text-anchor="middle" font-size="11" class="dg-muted">cron(0 8 ? * MON *)</text></g>
<g><rect x="208" y="12" width="164" height="56" rx="12" fill="#ca8a04" fill-opacity=".18" stroke="#ca8a04" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1239;0.2566" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/></rect><rect x="212" y="16" width="156" height="48" rx="9" class="dg-box" stroke="#ca8a04" stroke-width="2.2"/><text x="290" y="36.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Execution role</text><text x="290" y="52" text-anchor="middle" font-size="11" class="dg-muted">only tagged servers</text></g>
<g><rect x="208" y="108" width="164" height="64" rx="12" fill="#f97316" fill-opacity=".18" stroke="#f97316" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1" keyTimes="0;0.4956;0.6195" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/></rect><rect x="212" y="112" width="156" height="56" rx="9" class="dg-box" stroke="#f97316" stroke-width="2.2"/><text x="290" y="136.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">weekend-scheduler</text><text x="290" y="152" text-anchor="middle" font-size="11" class="dg-muted">Lambda · Python 3.14</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4956;0.6195" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/><rect x="212" y="112" width="156" height="56" rx="9" fill="#64748b"/><text x="290" y="144.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">asleep · $0</text></g></g>
<g><rect x="208" y="216" width="164" height="68" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.3805;0.4956;0.8761" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/></rect><rect x="212" y="220" width="156" height="60" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="290" y="239" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">CloudWatch Logs</text><text x="290" y="254.5" text-anchor="middle" font-size="11" class="dg-muted">/aws/lambda/</text><text x="290" y="269.5" text-anchor="middle" font-size="11" class="dg-muted">weekend-scheduler</text></g>
<g><rect x="430" y="36" width="154" height="60" rx="12" fill="#0891b2" fill-opacity=".18" stroke="#0891b2" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0;1" keyTimes="0;0.1239;0.3805;0.4956;0.6195;0.7434" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/></rect><rect x="434" y="40" width="146" height="52" rx="9" class="dg-box" stroke="#0891b2" stroke-width="2.2"/><text x="507" y="62.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">dev server</text><text x="507" y="78" text-anchor="middle" font-size="11" class="dg-muted">Schedule=office-hours</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3805;0.8761" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/><rect x="434" y="40" width="146" height="52" rx="9" fill="#64748b"/><text x="507" y="70.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">dev: stopped</text></g></g>
<g><rect x="430" y="110" width="154" height="60" rx="12" fill="#0891b2" fill-opacity=".18" stroke="#0891b2" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1;0;1" keyTimes="0;0.1239;0.3805;0.4956;0.6195;0.7434" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/></rect><rect x="434" y="114" width="146" height="52" rx="9" class="dg-box" stroke="#0891b2" stroke-width="2.2"/><text x="507" y="136.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">test server</text><text x="507" y="152" text-anchor="middle" font-size="11" class="dg-muted">Schedule=office-hours</text><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3805;0.8761" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/><rect x="434" y="114" width="146" height="52" rx="9" fill="#64748b"/><text x="507" y="144.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">test: stopped</text></g></g>
<g><rect x="430" y="184" width="154" height="60" rx="12" fill="#2563eb" fill-opacity=".18" stroke="#2563eb" stroke-width="3" opacity="0"></rect><rect x="434" y="188" width="146" height="52" rx="9" class="dg-box" stroke="#2563eb" stroke-width="2.2"/><text x="507" y="210.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">prod database</text><text x="507" y="226" text-anchor="middle" font-size="11" class="dg-muted">no Schedule tag</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.1239;0.2566;0.7434" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/><circle cx="580" cy="40" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M575.5,40 L579,43.5 L584.5,36.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.1239;0.2566;0.7434" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/><circle cx="580" cy="114" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M575.5,114 L579,117.5 L584.5,110.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2566;0.3805" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/><circle cx="580" cy="188" r="9.5" fill="#d97706" stroke="#fff" stroke-width="2"/><rect x="575.5" y="187" width="9" height="6.5" rx="1.2" fill="#fff"/><path d="M577.2,187 V185 A2.8,2.8 0 0 1 582.8,185 V187" fill="none" stroke="#fff" stroke-width="1.6"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0074;0.1065" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/><animateMotion path="M86,67 L184,67 L184,140 L290,140" keyPoints="0;0;1;1" keyTimes="0;0.0074;0.1065;1" calcMode="linear" dur="22.6s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1292;0.1637" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/><animateMotion path="M290,40 L290,140" keyPoints="0;0;1;1" keyTimes="0;0.1292;0.1637;1" calcMode="linear" dur="22.6s" repeatCount="indefinite"/><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1717;0.2434" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/><animateMotion path="M290,140 L507,140" keyPoints="0;0;1;1" keyTimes="0;0.1717;0.2434;1" calcMode="linear" dur="22.6s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1717;0.2434" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/><animateMotion path="M290,140 L400,140 L400,66 L507,66" keyPoints="0;0;1;1" keyTimes="0;0.1717;0.2434;1" calcMode="linear" dur="22.6s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2641;0.3632" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/><animateMotion path="M290,140 L507,140" keyPoints="0;0;1;1" keyTimes="0;0.2641;0.3632;1" calcMode="linear" dur="22.6s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2641;0.3632" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/><animateMotion path="M290,140 L400,140 L400,66 L507,66" keyPoints="0;0;1;1" keyTimes="0;0.2641;0.3632;1" calcMode="linear" dur="22.6s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3874;0.4795" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/><animateMotion path="M290,140 L290,250" keyPoints="0;0;1;1" keyTimes="0;0.3874;0.4795;1" calcMode="linear" dur="22.6s" repeatCount="indefinite"/><g><rect x="-8" y="-6" width="16" height="12" rx="2" fill="#64748b" stroke="#fff" stroke-width="1.6"/><path d="M-5,-2 H5 M-5,2 H3" stroke="#fff" stroke-width="1.4"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6269;0.726" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/><animateMotion path="M86,213 L184,213 L184,140 L290,140" keyPoints="0;0;1;1" keyTimes="0;0.6269;0.726;1" calcMode="linear" dur="22.6s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7487;0.7991" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/><animateMotion path="M290,140 L507,140" keyPoints="0;0;1;1" keyTimes="0;0.7487;0.7991;1" calcMode="linear" dur="22.6s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7487;0.7991" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/><animateMotion path="M290,140 L400,140 L400,66 L507,66" keyPoints="0;0;1;1" keyTimes="0;0.7487;0.7991;1" calcMode="linear" dur="22.6s" repeatCount="indefinite"/><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8097;0.8655" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/><animateMotion path="M290,140 L507,140" keyPoints="0;0;1;1" keyTimes="0;0.8097;0.8655;1" calcMode="linear" dur="22.6s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8097;0.8655" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/><animateMotion path="M290,140 L400,140 L400,66 L507,66" keyPoints="0;0;1;1" keyTimes="0;0.8097;0.8655;1" calcMode="linear" dur="22.6s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8835;0.9827" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/><animateMotion path="M290,140 L290,250" keyPoints="0;0;1;1" keyTimes="0;0.8835;0.9827;1" calcMode="linear" dur="22.6s" repeatCount="indefinite"/><g><rect x="-8" y="-6" width="16" height="12" rx="2" fill="#64748b" stroke="#fff" stroke-width="1.6"/><path d="M-5,-2 H5 M-5,2 H3" stroke="#fff" stroke-width="1.4"/></g></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(20.4,310.5) scale(.8)"><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g><text x="31.8" y="314">invoke / API call</text><g transform="translate(150.2,310.5) scale(.8)"><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g><text x="163.2" y="314">role</text><g transform="translate(208,310.5) scale(.8)"><circle r="5" fill="#0ea5e9" stroke="#fff" stroke-width="2"/></g><text x="219.4" y="314">look up</text><g transform="translate(281.8,310.5) scale(.8)"><g><rect x="-8" y="-6" width="16" height="12" rx="2" fill="#64748b" stroke="#fff" stroke-width="1.6"/><path d="M-5,-2 H5 M-5,2 H3" stroke="#fff" stroke-width="1.4"/></g></g><text x="294" y="314">log line</text></g>
<rect x="12" y="326" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="326" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="22.6s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1239" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#6366f1"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="349" font-size="14" font-weight="800" fill="#6366f1">Friday 20:00: the schedule fires</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">Friday evening · 1/8</text><text x="60" y="370" font-size="12.5" class="dg-text">weekend-stop invokes the function with {&quot;action&quot;: &quot;stop&quot;}. No server to run.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1239;0.2566" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#6366f1"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="349" font-size="14" font-weight="800" fill="#6366f1">It finds the tagged, running servers</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">Friday evening · 2/8</text><text x="60" y="370" font-size="12.5" class="dg-text">Using its role, it calls DescribeInstances with the tag Schedule=office-hours.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2566;0.3805" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#6366f1"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="349" font-size="14" font-weight="800" fill="#6366f1">StopInstances stops just those two</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">Friday evening · 3/8</text><text x="60" y="370" font-size="12.5" class="dg-text">The role may stop only tagged instances, so the prod database is never touched.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3805;0.4956" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#6366f1"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="349" font-size="14" font-weight="800" fill="#6366f1">It writes what it did to CloudWatch Logs</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">Friday evening · 4/8</text><text x="60" y="370" font-size="12.5" class="dg-text">A JSON summary such as &quot;count&quot;: 2 lands in /aws/lambda/weekend-scheduler.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4956;0.6195" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#d97706"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="349" font-size="14" font-weight="800" fill="#d97706">All weekend: servers off, Lambda asleep</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">The weekend · 5/8</text><text x="60" y="370" font-size="12.5" class="dg-text">60 of 168 hours stopped: about 36% less compute. An idle function costs nothing.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6195;0.7434" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#059669"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="349" font-size="14" font-weight="800" fill="#059669">Monday 08:00: the second schedule fires</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">Monday morning · 6/8</text><text x="60" y="370" font-size="12.5" class="dg-text">weekend-start invokes the same function with {&quot;action&quot;: &quot;start&quot;}.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7434;0.8761" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#059669"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="349" font-size="14" font-weight="800" fill="#059669">It finds the stopped servers and starts them</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">Monday morning · 7/8</text><text x="60" y="370" font-size="12.5" class="dg-text">DescribeInstances finds them, then StartInstances brings them back.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8761" calcMode="discrete" dur="22.6s" repeatCount="indefinite"/><circle cx="36" cy="354" r="14" fill="#059669"/><text x="36" y="359" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="349" font-size="14" font-weight="800" fill="#059669">You pay only while the code runs</text><text x="578" y="349" text-anchor="end" font-size="10.5" class="dg-muted">Monday morning · 8/8</text><text x="60" y="370" font-size="12.5" class="dg-text">Billed per request and per millisecond: two short runs a week fit the free tier.</text></g>
</svg>
```

### The motion-sensor light comparison

| Everyday life | Lambda and EventBridge |
|---|---|
| A motion-sensor light: it switches on only when someone walks by | A **Lambda function** runs only when an **event** arrives |
| You pay for electricity only while the light is on | You pay per **request** and per **millisecond** of run time |
| The light's instructions: "turn on, wait, turn off" | Your **code**, starting at the **handler** (the function Lambda calls) |
| The building manager decides what the light may control | The **execution role**: what your code is allowed to do in AWS |
| An alarm clock that rings at 8 AM every Monday | **EventBridge Scheduler** |
| A doorbell that rings when a visitor arrives | An **EventBridge rule**: reacts to events, such as "a server stopped" |
| A notebook where the light writes down what it did | **CloudWatch Logs** |

### What happens when a function runs

```flow
⚡ | Something happens | A file lands in S3, a message arrives in a queue, an HTTP call comes in, or the clock says "Friday 8 PM".
🚀 | Lambda starts your code | AWS reuses or creates a small, isolated environment and calls your handler with the event (JSON).
🐍 | Your code does one job | For example, it finds servers with a tag and stops them, then returns a result.
📜 | Logs go to CloudWatch | Everything you print lands in the log group /aws/lambda/my-function.
💤 | Lambda goes idle | No events, no cost. You paid only for the time your code ran.
```

### Key words

| Word | Simple meaning |
|---|---|
| **Serverless** | You run code, AWS runs the servers. No OS to patch, no capacity to plan |
| **Function** | Your code plus its settings (runtime, memory, timeout, role) |
| **Handler** | The entry point Lambda calls, written as `file.function`, e.g. `lambda_function.lambda_handler` |
| **Runtime** | The language version that runs your code, e.g. `python3.14` |
| **Event** | The JSON input your function receives, e.g. `{"action": "stop"}` |
| **Context** | A second argument with run details: request ID, remaining time, log group |
| **Execution role** | The IAM role your code uses to call AWS (see the [IAM guide](#/tool/aws-iam)) |
| **Trigger** | The thing that invokes the function: S3, SQS, API Gateway, EventBridge... |
| **Timeout** | How long one run may take. **Default 3 seconds**, maximum 900 seconds (15 minutes) |
| **Memory** | 128 MB to 10,240 MB. CPU power grows with memory |
| **Environment variables** | Settings passed to your code without changing it (4 KB in total) |
| **Concurrency** | How many copies run at the same time. The default quota is 1,000 per Region (new accounts start lower) |
| **Cold start** | The extra time to create a new environment the first time (shown as `Init Duration`) |
| **EventBridge Scheduler** | Runs a target on a timetable: cron, rate or one time, in any time zone |
| **EventBridge rule** | Watches an **event bus** and sends matching events to targets |

### Check yourself

1. Your new function fails with "Task timed out after 3.00 seconds". Why 3?
2. Who gives your Python code permission to stop EC2 instances?
3. You need "every Friday at 8 PM India time". Scheduler or a rule?

> **Tip:** Answers: 1) 3 seconds is the **default timeout**; raise it in the function's configuration. 2) The function's **execution role** (an IAM role). 3) **EventBridge Scheduler**: it supports cron with a time zone such as `Asia/Kolkata`.

## When to use Lambda (and when not)

> **In simple words:** Lambda is perfect for **short jobs that react to something**: glue code, automation, small APIs, file processing. For apps that run all day, need more than 15 minutes, or need special software, a server or container is usually better.

```compare
⚡ AWS Lambda | 🖥️ Amazon EC2
Runs only when an event arrives | Runs all the time until you stop it
Pay per request and per millisecond | Pay while it runs, even when idle
AWS patches the OS and the runtime | You patch and manage the operating system
Maximum 15 minutes per run | Runs as long as you want
Scales by itself: one environment per concurrent request | You add servers (by hand or with Auto Scaling)
Best for automation, glue code, small APIs | Best for long-running apps and special software
```

Good first uses for a DevOps team: stop dev servers at night, clean old snapshots, resize uploaded images, send a chat message when a deployment fails, rotate or check secrets, react to "an EC2 instance stopped" events.

AWS docs: [Create your first Lambda function](https://docs.aws.amazon.com/lambda/latest/dg/getting-started.html) · [Lambda quotas](https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html)

## Step 1: Create the execution role

> **In simple words:** Before the function exists, give it an **ID badge**: an IAM role that Lambda is allowed to wear (the **trust policy**) and that lets the code write its logs (the **AWSLambdaBasicExecutionRole** managed policy).

**Console:** IAM console → **Roles** → **Create role** → Trusted entity type **AWS service**, Use case **Lambda** → **Next** → tick **AWSLambdaBasicExecutionRole** → **Next** → Role name `hello-lambda-role` → **Create role**. (Shortcut: the Lambda console can create a role like this for you when you create the function.)

**CLI:**

```bash
export AWS_REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
mkdir -p ~/lambda-lab && cd ~/lambda-lab

# trust policy: "the Lambda service may use this role"
cat > lambda-trust.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "lambda.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role --role-name hello-lambda-role \
  --assume-role-policy-document file://lambda-trust.json

# permission to create log streams and write logs to CloudWatch
aws iam attach-role-policy --role-name hello-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

HELLO_ROLE_ARN=$(aws iam get-role --role-name hello-lambda-role --query Role.Arn --output text)
echo "$HELLO_ROLE_ARN"
```

| Part | What it says |
|---|---|
| **Trust policy** | **Who** may use the role: only the Lambda service (`lambda.amazonaws.com`) |
| **AWSLambdaBasicExecutionRole** | **What** the code may do: create log groups and streams, and write log events |
| Anything else (EC2, S3...) | Add it later, only what the function really needs |

## Step 2: Write and create your first function

> **In simple words:** Write a tiny Python file, zip it, and upload it as a function. Lambda needs four things: a **name**, a **runtime**, a **handler** and a **role**.

Save this as `lambda_function.py` in `~/lambda-lab`:

```python
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# read settings once, outside the handler
GREETING = os.environ.get("GREETING", "Hello")


def lambda_handler(event, context):
    """Lambda calls this function. event = the JSON input as a dict."""
    name = event.get("name", "world")
    message = f"{GREETING}, {name}!"
    logger.info("request %s says: %s", context.aws_request_id, message)
    return {
        "message": message,
        "function": context.function_name,
        "memory_mb": context.memory_limit_in_mb,
        "time_left_ms": context.get_remaining_time_in_millis(),
    }
```

**Console:**

1. Open the **Lambda console** → **Create function** → **Author from scratch**.
2. **Function name:** `hello-lambda`. **Runtime:** **Python 3.14**. **Architecture:** `x86_64`.
3. Expand **Change default execution role** → **Use an existing role** → `hello-lambda-role`.
4. Click **Create function**. In the **Code** tab, paste the code into `lambda_function.py` → **Deploy**.
5. **Configuration** → **Environment variables** → **Edit** → **Add environment variable**: `GREETING` = `Namaste` → **Save**.

> **Note:** The newest Lambda console and docs call these **Event Functions** (for example a **Create Event Function** button), to tell them apart from newer Lambda options. It's the same thing, and the CLI commands stay `aws lambda create-function` and friends.

**CLI:**

```bash
cd ~/lambda-lab
zip function.zip lambda_function.py
# no zip command (for example in Git Bash on Windows)? use Python instead:
# python -m zipfile -c function.zip lambda_function.py

aws lambda create-function --function-name hello-lambda \
  --runtime python3.14 --architectures x86_64 \
  --handler lambda_function.lambda_handler \
  --role "$HELLO_ROLE_ARN" \
  --zip-file fileb://function.zip \
  --timeout 10 --memory-size 128 \
  --environment 'Variables={GREETING=Namaste}'

aws lambda wait function-active-v2 --function-name hello-lambda
aws lambda get-function-configuration --function-name hello-lambda \
  --query '{State:State,Runtime:Runtime,Handler:Handler,Timeout:Timeout,Memory:MemorySize}'
```

| Flag | Meaning |
|---|---|
| `--runtime python3.14` | The language version. Check the [supported runtimes](https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html) and upgrade before a runtime is deprecated |
| `--handler lambda_function.lambda_handler` | File `lambda_function.py`, function `lambda_handler` |
| `--zip-file fileb://function.zip` | The code package (`fileb://` = send the file as binary) |
| `--timeout 10` | Stop the run after 10 seconds (default 3) |
| `--memory-size 128` | 128 MB, the smallest (and default) size |
| `--environment` | Environment variables your code reads with `os.environ` |

The Python runtimes already include **boto3** (the AWS SDK for Python), so you don't need to package it for simple functions.

## Step 3: Invoke the function and read the logs

> **In simple words:** **Invoke** means "run it now with this input". Then read what it printed in **CloudWatch Logs**: every run writes a `START`, your own lines, an `END` and a `REPORT` line with the time and memory used.

**Console:** In the **Code** tab, under **TEST EVENTS**, choose **Create test event** → Event name `asha` → Event JSON `{"name": "Asha"}` → **Save**, then run it. The result and the logs appear in the **OUTPUT** panel. For older runs: **Monitor** tab → **View CloudWatch logs**.

**CLI:**

```bash
cd ~/lambda-lab

# synchronous call: wait for the answer
aws lambda invoke --function-name hello-lambda \
  --cli-binary-format raw-in-base64-out \
  --payload '{"name": "Asha"}' \
  response.json
cat response.json; echo

# the same, plus the last 4 KB of this run's log
aws lambda invoke --function-name hello-lambda \
  --cli-binary-format raw-in-base64-out --payload '{"name": "Ravi"}' \
  --log-type Tail --query LogResult --output text response.json | base64 --decode

# asynchronous call: Lambda queues the event and answers 202 at once
aws lambda invoke --function-name hello-lambda --invocation-type Event \
  --cli-binary-format raw-in-base64-out --payload '{"name": "later"}' response.json

# read the log group (created on the first run)
aws logs tail /aws/lambda/hello-lambda --since 15m
aws logs tail /aws/lambda/hello-lambda --follow     # Ctrl+C to stop
```

`--cli-binary-format raw-in-base64-out` tells AWS CLI v2 that the payload is plain JSON (without it, the CLI expects base64).

How to read the `REPORT` line:

| Field | Meaning |
|---|---|
| `Duration` | How long your handler ran |
| `Billed Duration` | What you pay for (rounded up to the next millisecond) |
| `Memory Size` / `Max Memory Used` | Configured memory / what the run really used |
| `Init Duration` | Only on a **cold start**: time to create the environment and load your code |

| Invocation type | Who uses it | What happens on an error |
|---|---|---|
| **Synchronous** (`RequestResponse`) | You, API Gateway, function URLs | The caller gets the error and decides what to do |
| **Asynchronous** (`Event`) | S3, SNS, EventBridge Scheduler and rules | Lambda retries **up to 2 more times**, keeping the event for up to 6 hours |

## Step 4: Update the code and the configuration

> **In simple words:** Changing a function means two separate things: **new code** (upload a new zip) and **new settings** (timeout, memory, variables). Wait for each update to finish before the next one.

**Console:** edit the code in the **Code** tab → **Deploy**. Settings: **Configuration** → **General configuration** → **Edit** → **Memory** and **Timeout** → **Save**.

**CLI:**

```bash
cd ~/lambda-lab
# after editing lambda_function.py (e.g. change the default name to "team"):
zip function.zip lambda_function.py
aws lambda update-function-code --function-name hello-lambda --zip-file fileb://function.zip
aws lambda wait function-updated-v2 --function-name hello-lambda

aws lambda update-function-configuration --function-name hello-lambda \
  --timeout 15 --memory-size 256 \
  --environment 'Variables={GREETING=Hello,TEAM=platform}'
aws lambda wait function-updated-v2 --function-name hello-lambda
```

> **Warning:** `--environment` **replaces all** environment variables. Always pass the full list, or you'll lose the ones you left out.

| Setting | Default | Allowed range | Tip |
|---|---|---|---|
| Timeout | 3 seconds | 1 to 900 seconds | Set a bit above the normal run time, not always 900 |
| Memory | 128 MB | 128 to 10,240 MB | More memory also means more CPU (one full vCPU at 1,769 MB) |
| `/tmp` storage | 512 MB | 512 to 10,240 MB | Scratch space, wiped when the environment goes away |
| Environment variables | none | 4 KB in total | Never put passwords here; use [Secrets Manager](#/tool/aws-secrets) |
| Architecture | `x86_64` | `x86_64` or `arm64` | `arm64` (Graviton) costs less per GB-second |
| Zip package | | 50 MB zipped upload, 250 MB unzipped | Bigger? Upload through S3 or use a container image |

AWS docs: [Configure timeout](https://docs.aws.amazon.com/lambda/latest/dg/configuration-timeout.html) · [Configure memory](https://docs.aws.amazon.com/lambda/latest/dg/configuration-memory.html) · [Building with Python](https://docs.aws.amazon.com/lambda/latest/dg/lambda-python.html)

## Triggers: what can start a function

> **In simple words:** A **trigger** is whatever calls your function. Each one needs **permission** to do so: most services get a line in the function's **resource-based policy** ("S3 may invoke me"), while EventBridge Scheduler and SQS polling work through **IAM roles**.

| Trigger | How it calls Lambda | Typical use | Permission |
|---|---|---|---|
| **Amazon S3** | Async, when an object is created or deleted | Resize images, scan uploads | Resource-based policy for `s3.amazonaws.com` (the console adds it) |
| **Amazon SQS** | Lambda **polls** the queue and sends **batches** (an *event source mapping*) | Background jobs | Execution role needs `sqs:ReceiveMessage`, `sqs:DeleteMessage`, `sqs:GetQueueAttributes` (managed policy `AWSLambdaSQSQueueExecutionRole`) |
| **API Gateway** / **function URL** | Sync: HTTP request in, HTTP response out | Small APIs, webhooks | API Gateway: resource-based policy. Function URL: auth type `AWS_IAM` or `NONE` (public) |
| **Amazon SNS** | Async, one call per message | Fan-out alerts | Resource-based policy for `sns.amazonaws.com` |
| **EventBridge Scheduler** | Async, on a timetable | Cron jobs | The **schedule's own role** needs `lambda:InvokeFunction` |
| **EventBridge rule** | Async, when an event matches a pattern | React to AWS changes | Resource-based policy for `events.amazonaws.com` |

What a resource-based permission looks like (an example for an S3 bucket called `my-app-uploads`; you don't need to run it for this lab):

```bash
aws lambda add-permission --function-name hello-lambda \
  --statement-id allow-s3-my-app-uploads \
  --action lambda:InvokeFunction --principal s3.amazonaws.com \
  --source-arn arn:aws:s3:::my-app-uploads --source-account "$ACCOUNT_ID"

aws lambda get-policy --function-name hello-lambda --query Policy --output text
```

AWS docs: [Asynchronous invocation](https://docs.aws.amazon.com/lambda/latest/dg/invocation-async.html) · [Event source mappings](https://docs.aws.amazon.com/lambda/latest/dg/invocation-eventsourcemapping.html) · [Function URLs](https://docs.aws.amazon.com/lambda/latest/dg/urls-configuration.html)

## EventBridge: Scheduler or rules?

> **In simple words:** EventBridge has two tools that both start Lambda. **Scheduler** is the **alarm clock**: "every Friday at 8 PM". **Rules** are the **doorbell**: "when an EC2 instance stops, tell me". Use Scheduler for time, rules for events.

```compare
⏰ EventBridge Scheduler | 🔔 EventBridge rules
Answers "when?": cron, rate or one-time schedules | Answers "what happened?": matches events by a pattern
Any time zone, adjusts for daylight saving time | Sees events from AWS services, your apps and partners
Optional flexible time window (spread runs out) | AWS service events on the default bus are free
Uses its own IAM role to call the target | Lambda and SNS targets get a resource-based permission
Retry policy and optional SQS dead-letter queue | Retry policy and optional dead-letter queue per target
Example: stop dev servers every Friday at 8 PM | Example: email the team when a server stops
```

> **Note:** Rules can also run on a schedule ("scheduled rules"), but AWS now calls that a **legacy** feature and it only uses UTC. For anything time-based, use **EventBridge Scheduler**.

### Schedule expressions

Scheduler cron has **six fields**: `cron(minutes hours day-of-month month day-of-week year)`. One of day-of-month or day-of-week must be `?`.

| Expression | Runs |
|---|---|
| `cron(0 20 ? * FRI *)` | Every Friday at 20:00 |
| `cron(0 8 ? * MON *)` | Every Monday at 08:00 |
| `cron(30 9 ? * MON-FRI *)` | Weekdays at 09:30 |
| `cron(0 2 1 * ? *)` | 02:00 on the 1st of every month |
| `rate(15 minutes)` | Every 15 minutes |
| `at(2026-12-31T18:00:00)` | Once, at that date and time |

| Setting | What it does |
|---|---|
| **Time zone** | Cron and one-time schedules run in the zone you pick (e.g. `Asia/Kolkata`). If you set none, it's **UTC** |
| **Daylight saving time** | Handled for you. A time that doesn't exist (clocks jump forward) is skipped; a repeated hour runs once |
| **Flexible time window** | `OFF` = run on time. `FLEXIBLE` with 1 to 1,440 minutes = run any time in that window (spreads load) |
| **Retry policy** | By default Scheduler keeps trying for up to 24 hours and 185 retries if it can't deliver the event |
| **Dead-letter queue** | An SQS queue that receives events Scheduler finally couldn't deliver |
| **Execution role** | The role Scheduler assumes to call the target, trusted for `scheduler.amazonaws.com` |

Scheduler hands the event to Lambda **asynchronously**. Its retries cover problems **delivering** the event (for example throttling); errors **inside your code** are retried by Lambda's own async retries.

AWS docs: [Schedule types](https://docs.aws.amazon.com/scheduler/latest/UserGuide/schedule-types.html) · [Setting up Scheduler](https://docs.aws.amazon.com/scheduler/latest/UserGuide/setting-up.html) · [Invoke Lambda on a schedule](https://docs.aws.amazon.com/lambda/latest/dg/with-eventbridge-scheduler.html) · [What is EventBridge?](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-what-is.html)

## Project: weekend shutdown to save money

> **In simple words:** Dev and test servers usually sit idle from Friday night to Monday morning. A small Lambda, woken by two schedules, **stops every instance tagged `Schedule=office-hours` on Friday at 20:00 and starts them again on Monday at 08:00**. Instances without the tag are never touched.

### What we'll build

```text
 Friday 20:00 IST                 Monday 08:00 IST
 ┌──────────────────┐            ┌──────────────────┐
 │ Scheduler:       │            │ Scheduler:       │
 │ weekend-stop     │            │ weekend-start    │
 └────────┬─────────┘            └────────┬─────────┘
          │ {"action":"stop"}             │ {"action":"start"}
          └──────────────┬────────────────┘
                         ▼
              ┌─────────────────────┐
              │ Lambda              │──▶ CloudWatch Logs
              │ weekend-scheduler   │
              └──────────┬──────────┘
                         │ only instances tagged
                         │ Schedule=office-hours
                         ▼
              ┌─────────────────────┐
              │ EC2 dev/test servers│
              └─────────────────────┘
```

### How much does it save?

Friday 20:00 to Monday 08:00 is **60 hours** out of 168 in a week: about **36% less compute time**. An instance that costs about $0.04 per hour saves roughly $2.40 a week, around $10 a month, and a team with 30 such servers saves around $300 a month. Extend it to week nights (stop at 20:00, start at 08:00 every weekday) and the saving passes 60%.

> **Warning:** A stopped instance still pays for its **EBS volumes** and any **Elastic IP**. Don't tag instances that belong to an **Auto Scaling group** (or EKS node groups): the group sees a stopped instance as unhealthy and launches a replacement. Scale those groups down with scheduled actions instead.

### Tag the instances (and launch a test one)

**Console:** EC2 console → select the instance → **Actions** → **Instance settings** → **Manage tags** → **Add new tag**: Key `Schedule`, Value `office-hours` → **Save**.

**CLI:** for the lab, launch one small instance that already carries the tag (it uses your default VPC):

```bash
AMI_ID=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query Parameter.Value --output text)

INSTANCE_ID=$(aws ec2 run-instances --image-id "$AMI_ID" --instance-type t3.micro \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=weekend-test},{Key=Schedule,Value=office-hours}]' \
  --query 'Instances[0].InstanceId' --output text)
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
echo "Test instance: $INSTANCE_ID"

# tagging an existing instance instead:
# aws ec2 create-tags --resources i-0123456789abcdef0 --tags Key=Schedule,Value=office-hours
```

## Step 5: The weekend scheduler code

> **In simple words:** The function reads `{"action": "stop"}` or `{"action": "start"}`, finds tagged instances in the **opposite** state, and changes them in small batches. A **dry run** checks the permissions without changing anything.

Save this as `~/lambda-lab/weekend_scheduler.py`:

```python
"""Stop or start EC2 instances that carry a schedule tag.

Event examples:
    {"action": "stop"}
    {"action": "start", "dry_run": true}
"""
import json
import logging
import os

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client("ec2")  # created once, reused while the environment stays warm

TAG_KEY = os.environ.get("TAG_KEY", "Schedule")
TAG_VALUE = os.environ.get("TAG_VALUE", "office-hours")
DEFAULT_DRY_RUN = os.environ.get("DRY_RUN", "false").lower() == "true"
BATCH_SIZE = 50

# "stop" looks for running instances, "start" looks for stopped ones
WANTED_STATE = {"stop": "running", "start": "stopped"}


def to_bool(value):
    if isinstance(value, bool):
        return value
    return str(value).lower() == "true"


def find_instances(state):
    """Return the IDs of tagged instances that are in the given state."""
    paginator = ec2.get_paginator("describe_instances")
    pages = paginator.paginate(
        Filters=[
            {"Name": f"tag:{TAG_KEY}", "Values": [TAG_VALUE]},
            {"Name": "instance-state-name", "Values": [state]},
        ]
    )
    ids = []
    for page in pages:
        for reservation in page["Reservations"]:
            for instance in reservation["Instances"]:
                ids.append(instance["InstanceId"])
    return ids


def change_state(action, ids, dry_run):
    """Stop or start instances in batches. Returns (done, failed)."""
    call = ec2.stop_instances if action == "stop" else ec2.start_instances
    done, failed = [], []
    for i in range(0, len(ids), BATCH_SIZE):
        batch = ids[i:i + BATCH_SIZE]
        try:
            call(InstanceIds=batch, DryRun=dry_run)
            done.extend(batch)
        except ClientError as err:
            code = err.response["Error"]["Code"]
            if dry_run and code == "DryRunOperation":
                done.extend(batch)  # allowed, but nothing was changed
            else:
                logger.error("%s failed for %s: %s", action, batch, code)
                failed.extend(batch)
    return done, failed


def lambda_handler(event, context):
    action = str(event.get("action", "")).lower()
    if action not in WANTED_STATE:
        raise ValueError(f"action must be 'stop' or 'start', got {action!r}")
    dry_run = to_bool(event.get("dry_run", DEFAULT_DRY_RUN))

    ids = find_instances(WANTED_STATE[action])
    done, failed = change_state(action, ids, dry_run) if ids else ([], [])

    result = {
        "action": action,
        "dry_run": dry_run,
        "tag": f"{TAG_KEY}={TAG_VALUE}",
        "count": len(done),
        "instances": done,
        "failed": failed,
    }
    logger.info(json.dumps(result))
    if failed:
        # make the run fail, so it shows in the Errors metric and can be retried
        raise RuntimeError(f"{len(failed)} instance(s) failed: {failed}")
    return result
```

| Design choice | Why it matters |
|---|---|
| **Paginator** for `describe_instances` | Gets every page of results, even with hundreds of instances |
| **Tag + state filters** | AWS does the filtering; the code only sees instances it should change |
| Only acts on the **opposite state** | **Idempotent**: running it twice, or a retry, does no harm |
| **`DryRun=True`** | EC2 checks permissions and answers `DryRunOperation` (allowed) or `UnauthorizedOperation` |
| Settings in **environment variables** | Change the tag without changing the code |
| **Raise on failure** | A failed run is visible (Errors metric) instead of silently "succeeding" |

## Step 6: A least-privilege role and the function

> **In simple words:** This role can **look at** all instances, but can **stop and start only instances tagged `Schedule=office-hours`**. Even a bug in the code can't stop your production database.

**Console:** IAM → **Roles** → **Create role** → **AWS service** → **Lambda** → tick **AWSLambdaBasicExecutionRole** → name `weekend-scheduler-lambda-role` → **Create role**. Open the role → **Add permissions** → **Create inline policy** → **JSON** → paste the policy below (with your Region and account ID) → name `ec2-stop-start-tagged` → **Create policy**. Then create the function as in Step 2 with runtime **Python 3.14**, handler `weekend_scheduler.lambda_handler`, timeout **2 min**, memory **256 MB** and the three environment variables.

**CLI:**

```bash
cd ~/lambda-lab

cat > weekend-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "FindInstances",
      "Effect": "Allow",
      "Action": "ec2:DescribeInstances",
      "Resource": "*"
    },
    {
      "Sid": "StopStartOnlyTaggedInstances",
      "Effect": "Allow",
      "Action": ["ec2:StopInstances", "ec2:StartInstances"],
      "Resource": "arn:aws:ec2:${AWS_REGION}:${ACCOUNT_ID}:instance/*",
      "Condition": {
        "StringEquals": { "aws:ResourceTag/Schedule": "office-hours" }
      }
    }
  ]
}
EOF

aws iam create-role --role-name weekend-scheduler-lambda-role \
  --assume-role-policy-document file://lambda-trust.json
aws iam attach-role-policy --role-name weekend-scheduler-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam put-role-policy --role-name weekend-scheduler-lambda-role \
  --policy-name ec2-stop-start-tagged --policy-document file://weekend-policy.json
WEEKEND_ROLE_ARN=$(aws iam get-role --role-name weekend-scheduler-lambda-role --query Role.Arn --output text)
sleep 10   # a new role takes a few seconds to be usable

zip weekend.zip weekend_scheduler.py
aws lambda create-function --function-name weekend-scheduler \
  --runtime python3.14 --handler weekend_scheduler.lambda_handler \
  --role "$WEEKEND_ROLE_ARN" --zip-file fileb://weekend.zip \
  --timeout 120 --memory-size 256 \
  --environment 'Variables={TAG_KEY=Schedule,TAG_VALUE=office-hours,DRY_RUN=false}' \
  --description "Stops tagged EC2 instances on Friday evening, starts them on Monday"
aws lambda wait function-active-v2 --function-name weekend-scheduler

FUNCTION_ARN=$(aws lambda get-function --function-name weekend-scheduler \
  --query Configuration.FunctionArn --output text)
echo "$FUNCTION_ARN"
```

| Policy part | Why |
|---|---|
| `ec2:DescribeInstances` on `*` | Describe calls can't be limited to single instances, so `*` is required |
| Stop/Start on `instance/*` **with a tag condition** | Only instances whose tag `Schedule` equals `office-hours` (the value is case-sensitive) |
| No `ec2:TerminateInstances` | The function can never delete a server |

> **Note:** If your instances use EBS volumes encrypted with a **customer managed KMS key**, starting them also needs permission to use that key (for example `kms:CreateGrant` with the `kms:GrantIsForAWSResource` condition, plus `kms:Decrypt`). Without it the instance goes from *pending* straight back to *stopped*. See [EBS encryption requirements](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-encryption-requirements.html) and the [KMS guide](#/tool/aws-kms).

AWS docs: [IAM example: start or stop instances by tag](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_examples_ec2-start-stop-match-tags.html)

## Step 7: Dry-run test, then a real test

> **In simple words:** Never let a new automation loose on real servers first. Run it in **dry-run** mode, read what it **would** do, then test for real on the one test instance.

**Console:** open `weekend-scheduler` → create test events `stop-dry` = `{"action": "stop", "dry_run": true}`, `stop` = `{"action": "stop"}` and `start` = `{"action": "start"}` → run them one by one and read the **OUTPUT** panel.

**CLI:**

```bash
cd ~/lambda-lab
run() {   # run '<json payload>'
  aws lambda invoke --function-name weekend-scheduler \
    --cli-binary-format raw-in-base64-out --payload "$1" out.json \
    --query '{Status:StatusCode,Error:FunctionError}' --output text
  cat out.json; echo
}

# 1) dry run: checks permissions, changes nothing
run '{"action": "stop", "dry_run": true}'
#    expect "dry_run": true, "count": 1 and your test instance ID

# 2) real stop
run '{"action": "stop"}'
aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID"

# 3) stop again: nothing left to stop, "count": 0 (idempotent)
run '{"action": "stop"}'

# 4) start it again
run '{"action": "start"}'
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

# 5) a bad input fails loudly: FunctionError "Unhandled" and a ValueError
run '{"action": "reboot"}'

aws logs tail /aws/lambda/weekend-scheduler --since 15m --format short
```

| Result | Meaning |
|---|---|
| `"count": 1` in the dry run | The tag filter found the instance **and** the role is allowed to stop it |
| `"failed": [...]` with `UnauthorizedOperation` in the logs | The instance is found but the IAM tag condition doesn't match (check the tag spelling and case) |
| `"count": 0` | No tagged instance in the right state: check the tag and the Region |

## Step 8: Create the Friday and Monday schedules

> **In simple words:** Create two alarm clocks in the **India time zone**: one sends `{"action": "stop"}` on Friday at 20:00, the other sends `{"action": "start"}` on Monday at 08:00. Scheduler uses **its own IAM role** to invoke the function.

**Console:**

1. Open **Amazon EventBridge** → **Scheduler** → **Schedules** → **Create schedule**.
2. **Schedule name:** `weekend-stop`. **Schedule group:** `default`.
3. **Schedule pattern:** **Occurrence** **Recurring schedule**, **Time zone** `Asia/Kolkata`, **Schedule type** **Cron-based schedule**, cron `0 20 ? * FRI *`, **Flexible time window** **Off** → **Next**.
4. **Target:** **AWS Lambda Invoke** → function `weekend-scheduler` → **Payload** `{"action": "stop"}` → **Next**.
5. **Settings:** keep the retry policy (or lower it), optionally pick a dead-letter queue. **Permissions:** **Create new role for this schedule** → **Next** → **Create schedule**.
6. Repeat for `weekend-start` with cron `0 8 ? * MON *` and payload `{"action": "start"}`.

**CLI:** first the scheduler role (trusted only for `scheduler.amazonaws.com` from your account), then the two schedules:

```bash
cd ~/lambda-lab

cat > scheduler-trust.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "scheduler.amazonaws.com" },
      "Action": "sts:AssumeRole",
      "Condition": { "StringEquals": { "aws:SourceAccount": "${ACCOUNT_ID}" } }
    }
  ]
}
EOF

cat > scheduler-invoke.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "lambda:InvokeFunction",
      "Resource": ["${FUNCTION_ARN}", "${FUNCTION_ARN}:*"]
    }
  ]
}
EOF

aws iam create-role --role-name weekend-scheduler-invoke-role \
  --assume-role-policy-document file://scheduler-trust.json
aws iam put-role-policy --role-name weekend-scheduler-invoke-role \
  --policy-name invoke-weekend-lambda --policy-document file://scheduler-invoke.json
SCHEDULER_ROLE_ARN=$(aws iam get-role --role-name weekend-scheduler-invoke-role --query Role.Arn --output text)
sleep 10

mk_target() {   # mk_target stop|start
  cat <<EOF
{
  "Arn": "${FUNCTION_ARN}",
  "RoleArn": "${SCHEDULER_ROLE_ARN}",
  "Input": "{\"action\": \"$1\"}",
  "RetryPolicy": { "MaximumRetryAttempts": 3, "MaximumEventAgeInSeconds": 3600 }
}
EOF
}
mk_target stop  > stop-target.json
mk_target start > start-target.json

aws scheduler create-schedule --name weekend-stop \
  --description "Stop office-hours EC2 instances every Friday 20:00 IST" \
  --schedule-expression 'cron(0 20 ? * FRI *)' \
  --schedule-expression-timezone Asia/Kolkata \
  --flexible-time-window '{"Mode": "OFF"}' \
  --target file://stop-target.json

aws scheduler create-schedule --name weekend-start \
  --description "Start office-hours EC2 instances every Monday 08:00 IST" \
  --schedule-expression 'cron(0 8 ? * MON *)' \
  --schedule-expression-timezone Asia/Kolkata \
  --flexible-time-window '{"Mode": "OFF"}' \
  --target file://start-target.json

aws scheduler list-schedules --query 'Schedules[].[Name,State]' --output table
aws scheduler get-schedule --name weekend-stop \
  --query '{Expr:ScheduleExpression,TZ:ScheduleExpressionTimezone,State:State,Input:Target.Input}'
```

**Don't want to wait until Friday?** Create a one-time schedule that fires in 3 minutes, in dry-run mode, and deletes itself afterwards:

```bash
RUN_AT=$(date -u -d '+3 minutes' +%Y-%m-%dT%H:%M:%S)   # macOS: date -u -v+3M +%Y-%m-%dT%H:%M:%S

cat > test-target.json <<EOF
{
  "Arn": "${FUNCTION_ARN}",
  "RoleArn": "${SCHEDULER_ROLE_ARN}",
  "Input": "{\"action\": \"stop\", \"dry_run\": true}"
}
EOF

aws scheduler create-schedule --name weekend-test-once \
  --schedule-expression "at(${RUN_AT})" --schedule-expression-timezone UTC \
  --flexible-time-window '{"Mode": "OFF"}' \
  --action-after-completion DELETE \
  --target file://test-target.json
# about 3 minutes later:
aws logs tail /aws/lambda/weekend-scheduler --since 10m --format short
```

> **Tip:** To pause the shutdown for a week (a release weekend, say), open the schedule in the console and choose **Disable**; **Enable** it again on Monday.

## Step 9: Check that it worked

> **In simple words:** After the first weekend, check three places: the **function's logs** (what it did), the **instances** (their state now), and the **metrics** (did the schedule fire, did the function fail).

```bash
# what the function did (the JSON summary line of each run)
aws logs filter-log-events --log-group-name /aws/lambda/weekend-scheduler \
  --start-time $(( ($(date +%s) - 3*24*3600) * 1000 )) \
  --filter-pattern '"count"' --query 'events[].message' --output text

# the current state of every tagged instance
aws ec2 describe-instances --filters Name=tag:Schedule,Values=office-hours \
  --query 'Reservations[].Instances[].[InstanceId,State.Name,Tags[?Key==`Name`]|[0].Value]' \
  --output table

# keep logs for 30 days instead of forever
aws logs put-retention-policy --log-group-name /aws/lambda/weekend-scheduler --retention-in-days 30
```

| Where | What to look at |
|---|---|
| **CloudWatch** → **Metrics** → `AWS/Scheduler` | `InvocationAttemptCount` (the schedule fired), `TargetErrorCount` and `InvocationDroppedCount` (it couldn't call Lambda) |
| **CloudWatch** → **Metrics** → `AWS/Lambda` | `Invocations`, `Errors`, `Duration`, `Throttles` for `weekend-scheduler` |
| **Lambda** → **Monitor** tab | The same Lambda graphs, plus a link to the logs |
| **EC2** → **Instances** | Filter by tag `Schedule: office-hours` and check the state |

Put a CloudWatch alarm on the function's `Errors` metric so a failed Monday start pages someone before the team arrives. See the [CloudWatch guide](#/tool/aws-cloudwatch).

## Example 2: email me when an instance stops (EventBridge rule)

> **In simple words:** A **rule** watches the default event bus. EC2 sends an event each time an instance changes state; our rule matches `"state": "stopped"` and sends it to an **SNS topic**, which emails you.

Every EC2 state change produces an event like this (the pattern below matches its `source`, `detail-type` and `detail.state`):

```json
{
  "source": ["aws.ec2"],
  "detail-type": ["EC2 Instance State-change Notification"],
  "detail": {
    "state": ["stopped"]
  }
}
```

**Console:**

1. **SNS** console → **Topics** → **Create topic** → **Standard**, name `ec2-state-alerts` → **Create topic** → **Create subscription** → Protocol **Email**, your address → confirm the email you receive.
2. **EventBridge** console → **Rules** → **Create rule** → Name `ec2-stopped-alert`, Event bus **default**, Rule type **Rule with an event pattern** → **Next**.
3. Event source **AWS events or EventBridge partner events**, Creation method **Use pattern form**, Event source **AWS services**, AWS service **EC2**, Event type **EC2 Instance State-change Notification**, **Specific state(s)** `stopped` → **Next**.
4. Target types **AWS service** → **SNS topic** → `ec2-state-alerts` → **Next** → **Create rule**.

**CLI:**

```bash
cd ~/lambda-lab
ALERT_EMAIL=ops@example.com     # use your own address

TOPIC_ARN=$(aws sns create-topic --name ec2-state-alerts --query TopicArn --output text)
aws sns subscribe --topic-arn "$TOPIC_ARN" --protocol email --notification-endpoint "$ALERT_EMAIL"
# open the email and click "Confirm subscription"

cat > ec2-stopped-pattern.json <<'EOF'
{
  "source": ["aws.ec2"],
  "detail-type": ["EC2 Instance State-change Notification"],
  "detail": { "state": ["stopped"] }
}
EOF

RULE_ARN=$(aws events put-rule --name ec2-stopped-alert \
  --event-pattern file://ec2-stopped-pattern.json --query RuleArn --output text)

# allow EventBridge (only this rule) to publish to the topic
cat > topic-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowEventBridgeRule",
      "Effect": "Allow",
      "Principal": { "Service": "events.amazonaws.com" },
      "Action": "sns:Publish",
      "Resource": "${TOPIC_ARN}",
      "Condition": { "ArnEquals": { "aws:SourceArn": "${RULE_ARN}" } }
    }
  ]
}
EOF
aws sns set-topic-attributes --topic-arn "$TOPIC_ARN" \
  --attribute-name Policy --attribute-value file://topic-policy.json

aws events put-targets --rule ec2-stopped-alert --targets "Id=email-ops,Arn=${TOPIC_ARN}"

# test it: stop the test instance and wait for the email
aws ec2 stop-instances --instance-ids "$INSTANCE_ID"
```

| Want to... | How |
|---|---|
| Call a Lambda instead of SNS | Target = the function ARN, plus `aws lambda add-permission --principal events.amazonaws.com --source-arn "$RULE_ARN"` |
| A readable email instead of raw JSON | Add an **input transformer** to the target. See the [SNS and SES guide](#/tool/aws-sns-ses) |
| Only some instances | State-change events don't include tags, so filter by `"instance-id"` or check tags inside a Lambda |

AWS docs: [EC2 state change events](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/monitoring-instance-state-changes.html) · [Resource-based policies for EventBridge](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-use-resource-based.html)

## Good practices

> **In simple words:** Give the function only the permissions it needs, make it safe to run twice, set honest timeouts, decide what happens to failed events, and release changes through **versions** so you can roll back.

| Practice | How |
|---|---|
| **Least privilege** | One role per function; limit actions, resources and tags (like Step 6) |
| **Idempotency** | Running twice gives the same result. Async events can arrive more than once |
| **Timeouts** | Slightly above the normal run time. Set timeouts on your own HTTP calls too |
| **Retries and failed events** | Tune async retries; send failures to an **on-failure destination** (SQS, SNS, Lambda, EventBridge bus or S3) or a **dead-letter queue** |
| **Layers** (briefly) | A zip of shared libraries or tools attached to many functions (up to 5 layers per function) |
| **Versions and aliases** (briefly) | `publish-version` freezes the code; an **alias** like `live` points to a version, so triggers call the alias and you roll back by moving it |
| **Secrets** | Read them from [Secrets Manager](#/tool/aws-secrets) or [Parameter Store](#/tool/aws-ssm), not environment variables |
| **VPC only when needed** | Attach a function to a VPC only to reach private resources (a database). It then needs a NAT gateway or [VPC endpoints](#/tool/aws-privatelink) to call AWS APIs |
| **Logs** | Log one JSON summary line per run; set a log retention period |
| **Infrastructure as code** | Keep it all in Terraform (`aws_lambda_function`, `aws_scheduler_schedule`, `aws_iam_role`). See the [Terraform guide](#/tool/terraform) |

```bash
# failed async events: retry once, keep them 1 hour, then publish to SNS
# (the function's execution role also needs sns:Publish on that topic)
aws lambda put-function-event-invoke-config --function-name weekend-scheduler \
  --maximum-retry-attempts 1 --maximum-event-age-in-seconds 3600 \
  --destination-config "{\"OnFailure\":{\"Destination\":\"${TOPIC_ARN}\"}}"

# versions and an alias
VERSION=$(aws lambda publish-version --function-name weekend-scheduler --query Version --output text)
aws lambda create-alias --function-name weekend-scheduler --name live --function-version "$VERSION"
# point the schedules at "${FUNCTION_ARN}:live" (the scheduler role already allows "${FUNCTION_ARN}:*")
```

AWS docs: [Versions](https://docs.aws.amazon.com/lambda/latest/dg/configuration-versions.html) · [Aliases](https://docs.aws.amazon.com/lambda/latest/dg/configuration-aliases.html) · [Layers](https://docs.aws.amazon.com/lambda/latest/dg/chapter-layers.html)

## Cost and free tier

> **In simple words:** For automation jobs like this one, Lambda and Scheduler are practically free: a few runs a week use a tiny part of the monthly free tier. The real money is in what the function **saves**.

| Item | Price (us-east-1) | Monthly free tier |
|---|---|---|
| Lambda requests | $0.20 per million | 1 million requests |
| Lambda compute, x86 | $0.0000166667 per GB-second | 400,000 GB-seconds |
| Lambda compute, Arm (`arm64`) | $0.0000133334 per GB-second | Shared with the above |
| EventBridge Scheduler | $1.00 per million invocations | 14 million invocations |
| EventBridge: AWS service events to the default bus | Free | |
| EventBridge: custom events you publish | $1.00 per million | |
| CloudWatch Logs | Billed by CloudWatch (ingestion and storage) | See the [CloudWatch guide](#/tool/aws-cloudwatch) |

**GB-seconds** = memory in GB × seconds of run time. The weekend function at 256 MB (0.25 GB) running 5 seconds uses 1.25 GB-seconds per run; about 9 runs a month use around 11 GB-seconds, far below 400,000.

> **Cost:** Prices change; always check [Lambda pricing](https://aws.amazon.com/lambda/pricing/) and [EventBridge pricing](https://aws.amazon.com/eventbridge/pricing/). Provisioned Concurrency (pre-warmed environments) costs extra and isn't covered by the free tier.

## Troubleshooting

> **In simple words:** Start with the **logs** of the run (`aws logs tail`). Most problems are a timeout, a missing permission, a wrong handler name, or a schedule in the wrong time zone.

| Problem | Likely cause | Fix |
|---|---|---|
| `Task timed out after 3.00 seconds` | Default 3-second timeout, or a slow call (often a network call that never answers) | Raise the timeout; check VPC networking (row below); add timeouts to your own calls |
| Function in a VPC hangs calling AWS or the internet | VPC-attached functions get **no public IP**, even in a public subnet | Put it in private subnets with a route to a **NAT gateway**, or add [VPC endpoints](#/tool/aws-privatelink); or remove the VPC config if it isn't needed. See the [VPC guide](#/tool/aws-vpc) |
| `AccessDenied` / `UnauthorizedOperation` in the logs | The execution role lacks the action, or the tag condition doesn't match | Fix the policy; tag values are case-sensitive; test with `"dry_run": true` |
| `The role defined for the function cannot be assumed by Lambda` | The role was created seconds ago, or the trust policy isn't for `lambda.amazonaws.com` | Wait 10 seconds and retry; check the trust policy |
| `Runtime.ImportModuleError` / `Handler ... missing` | Handler doesn't match `file.function`, or the file is inside a folder in the zip | Zip the file at the top level; set the handler to `weekend_scheduler.lambda_handler` |
| `Invalid base64` when invoking from the CLI | AWS CLI v2 expects base64 payloads by default | Add `--cli-binary-format raw-in-base64-out` |
| `ResourceConflictException` on an update | The previous update is still in progress | `aws lambda wait function-updated-v2` between updates |
| Schedule never fires | Schedule **disabled**; the scheduler role can't be assumed or lacks `lambda:InvokeFunction` | `aws scheduler get-schedule`; check `State`, the role's trust and policy; watch `TargetErrorCount` |
| Schedule fires at the wrong hour | No time zone set (so **UTC**), or cron fields swapped | Set `--schedule-expression-timezone Asia/Kolkata`; check `cron(minutes hours ...)` |
| Instance starts, then goes back to *stopped* | Encrypted EBS with a customer managed KMS key the role can't use | Allow the role to use the key (see the note in Step 6) |
| Stopped instances come back by themselves | They belong to an Auto Scaling group, which replaces them | Remove the tag; use Auto Scaling scheduled actions instead |
| No email from the rule | Subscription not confirmed, or the topic policy doesn't allow `events.amazonaws.com` | Confirm the email; check the topic's access policy |
| `TooManyRequestsException` / throttles | The account or function hit its concurrency limit | Check the `Throttles` metric; request a quota increase |

AWS docs: [Internet access for VPC functions](https://repost.aws/knowledge-center/internet-access-lambda-function)

## Clean up

> **In simple words:** Delete in reverse order: the schedules and the rule first (so nothing calls the function), then the functions and their log groups, the IAM roles, the SNS topic, and finally the test instance.

```bash
export AWS_REGION=us-east-1

# schedules (the one-time test schedule deleted itself)
aws scheduler delete-schedule --name weekend-stop
aws scheduler delete-schedule --name weekend-start

# EventBridge rule and SNS topic
aws events remove-targets --rule ec2-stopped-alert --ids email-ops
aws events delete-rule --name ec2-stopped-alert
TOPIC_ARN=$(aws sns list-topics --query "Topics[?ends_with(TopicArn, ':ec2-state-alerts')].TopicArn | [0]" --output text)
aws sns delete-topic --topic-arn "$TOPIC_ARN"

# functions and their log groups
for FN in hello-lambda weekend-scheduler; do
  aws lambda delete-function --function-name "$FN"
  aws logs delete-log-group --log-group-name "/aws/lambda/$FN"
done

# IAM roles (policies first, then the role)
aws iam delete-role-policy --role-name weekend-scheduler-invoke-role --policy-name invoke-weekend-lambda
aws iam delete-role --role-name weekend-scheduler-invoke-role
aws iam delete-role-policy --role-name weekend-scheduler-lambda-role --policy-name ec2-stop-start-tagged
for ROLE in weekend-scheduler-lambda-role hello-lambda-role; do
  aws iam detach-role-policy --role-name "$ROLE" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
  aws iam delete-role --role-name "$ROLE"
done

# the test instance
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters Name=tag:Name,Values=weekend-test Name=instance-state-name,Values=running,stopped \
  --query 'Reservations[].Instances[].InstanceId' --output text)
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
```

If you created the schedules in the console with **Create new role for this schedule**, also delete those roles (their names start with `Amazon_EventBridge_Scheduler_`) in IAM → **Roles**.

## Lab and cheat sheet

> **In simple words:** Practice time: build the weekend shutdown yourself, break it on purpose, and extend it.

1. Create `hello-lambda` with the CLI, invoke it, and find the `Init Duration` of the cold start in the `REPORT` line.
2. Change the timeout to 1 second and add `time.sleep(2)` to the code. Read the `Task timed out` error, then fix it.
3. Build the weekend scheduler and run all five tests from Step 7.
4. **Break it:** change the policy's tag value to `Office-Hours` (capital letters) and run the dry run. You get `UnauthorizedOperation`. Put it back.
5. Launch a second instance **without** the tag, run `{"action": "stop"}`, and prove it is never touched.
6. Create the two schedules in `Asia/Kolkata`, then a one-time dry-run schedule 3 minutes ahead, and find its run in the logs.
7. Extend it to week nights: a third schedule `cron(0 20 ? * MON-THU *)` (stop) and a fourth `cron(0 8 ? * TUE-FRI *)` (start).
8. Create the EventBridge rule and get an email when the test instance stops.
9. Clean up everything and check that no schedule, rule, function or instance is left.

### Cheat sheet

| Task | Command |
|---|---|
| Create a function | `aws lambda create-function --function-name F --runtime python3.14 --handler file.func --role ROLE_ARN --zip-file fileb://f.zip` |
| Invoke with JSON | `aws lambda invoke --function-name F --cli-binary-format raw-in-base64-out --payload '{"k":"v"}' out.json` |
| Invoke asynchronously | `aws lambda invoke --function-name F --invocation-type Event ... out.json` |
| Follow the logs | `aws logs tail /aws/lambda/F --follow` |
| Upload new code | `aws lambda update-function-code --function-name F --zip-file fileb://f.zip` |
| Change settings | `aws lambda update-function-configuration --function-name F --timeout 60 --memory-size 256` |
| Wait for an update | `aws lambda wait function-updated-v2 --function-name F` |
| Allow a service to invoke | `aws lambda add-permission --function-name F --statement-id ID --action lambda:InvokeFunction --principal events.amazonaws.com --source-arn RULE_ARN` |
| Weekly schedule | `aws scheduler create-schedule --name N --schedule-expression 'cron(0 20 ? * FRI *)' --schedule-expression-timezone Asia/Kolkata --flexible-time-window '{"Mode":"OFF"}' --target file://t.json` |
| One-time schedule | `--schedule-expression 'at(2026-12-31T18:00:00)' --action-after-completion DELETE` |
| List schedules | `aws scheduler list-schedules --query 'Schedules[].[Name,State]' --output table` |
| Event rule | `aws events put-rule --name R --event-pattern file://p.json` + `aws events put-targets --rule R --targets Id=1,Arn=TARGET_ARN` |
| Publish a version and alias | `aws lambda publish-version --function-name F` + `aws lambda create-alias --function-name F --name live --function-version 1` |
