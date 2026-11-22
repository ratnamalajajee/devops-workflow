# Create Your AWS Account

Never used AWS before? This guide walks you through **opening your own AWS account**, screen by screen: choosing the right sign-up, the **Free or Paid plan**, card and phone checks (including the extra step for **India**), then the four things to do in your first 15 minutes: **lock the root user with MFA, set a budget alert, create an admin user, and connect the AWS CLI**.

> **Cost:** Creating an account is **free**. New accounts get **USD $100 in credits** at sign-up and can earn **up to $100 more**. On the **Free plan** you are never charged; on the **Paid plan** you pay only for usage beyond your credits. Either way, set the budget alert in Step 9. See [AWS Free Tier](https://aws.amazon.com/free/).

## Start here: an AWS account in simple words

> **In simple words:** An AWS account is like **opening a bank account for cloud resources**. You prove who you are (email, phone, card), you get a **master key** (the **root user**), and from then on everything you create (servers, buckets, clusters) lives inside that account and is billed to it. The first thing you do with a master key is lock it away and make yourself a normal key for everyday use.

### Watch how it works

```svg Watch it work: signing up with email, plan, card and phone, then root MFA, a budget alert, an admin user for daily work and aws login, with root locked away. The animation loops.
<svg viewBox="0 0 600 426" role="img" data-anim="aws-account" aria-label="Animated account set-up. Sign up: you choose Sign up for AWS (advanced), enter the root user email and an account name, type the code AWS emails you, and set a strong root password. You choose a plan: the Free plan never charges you and ends after 6 months or when credits run out, the Paid plan bills usage beyond your credits, and both get 100 US dollars in credits. AWS checks a card that allows online payments, then your phone with a PIN by SMS or voice call; in India there is also a refunded 2 rupee card check and an ID check. You pick Basic support, which is free, the account is activated, and you sign in as the root user for the first time. First 15 minutes: you add MFA to the root user with a passkey or an authenticator app. You create a Zero spend budget, which emails you as soon as spending goes over one cent. As root, you create an IAM user called admin in the group admins with the AdministratorAccess policy, and give it its own MFA. Daily use: you sign in as admin, and aws login in the AWS CLI opens the browser, you sign in as admin, and the CLI gets temporary credentials, so there are no access keys to leak. The root user stays locked away, used only to close the account, change its email or change the support plan.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<rect x="150" y="92" width="442" height="240" rx="12" fill="none" stroke="#ff9900" stroke-width="2" stroke-dasharray="7 4"/>
<polyline points="72,44 202,44 314,44 426,44 538,44" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="72,44 72,152 235,152" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="72,44 72,206 511,206 511,152" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="235,152 511,152" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="235,152 235,290" fill="none" stroke-linejoin="round" stroke="#a855f7" stroke-width="1.8" stroke-dasharray="2 4" stroke-opacity=".75"/>
<polyline points="235,290 72,290" fill="none" stroke-linejoin="round" stroke="#db2777" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<rect x="156" y="99" width="129.6" height="18" rx="5" class="dg-box"/><text x="160" y="111" font-size="13" font-weight="800" fill="#ff9900">Your AWS account</text>
<g><rect x="8" y="12" width="128" height="64" rx="28" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1;0;1;0" keyTimes="0;0.1111;0.3254;0.5476;0.7778;0.8968" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/></rect><rect x="12" y="16" width="120" height="56" rx="25" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="72" y="40.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">You</text><text x="72" y="56" text-anchor="middle" font-size="11" class="dg-muted">laptop + phone</text></g>
<rect x="152" y="16" width="100" height="56" rx="9" class="dg-box"/><g opacity="1"><animate attributeName="opacity" values="1;0.28" keyTimes="0;0.4365" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><rect x="148" y="12" width="108" height="64" rx="12" fill="#6366f1" fill-opacity=".18" stroke="#6366f1" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1111" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/></rect><rect x="152" y="16" width="100" height="56" rx="9" class="dg-box" stroke="#6366f1" stroke-width="2.2"/><text x="202" y="40.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Email</text><text x="202" y="56" text-anchor="middle" font-size="11" class="dg-muted">code + password</text></g>
<rect x="264" y="16" width="100" height="56" rx="9" class="dg-box"/><g opacity="1"><animate attributeName="opacity" values="1;0.28" keyTimes="0;0.4365" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><rect x="260" y="12" width="108" height="64" rx="12" fill="#6366f1" fill-opacity=".18" stroke="#6366f1" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1111;0.2143" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/></rect><rect x="264" y="16" width="100" height="56" rx="9" class="dg-box" stroke="#6366f1" stroke-width="2.2"/><text x="314" y="40.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Plan</text><text x="314" y="56" text-anchor="middle" font-size="11" class="dg-muted">Free or Paid</text></g>
<rect x="376" y="16" width="100" height="56" rx="9" class="dg-box"/><g opacity="1"><animate attributeName="opacity" values="1;0.28" keyTimes="0;0.4365" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><rect x="372" y="12" width="108" height="64" rx="12" fill="#6366f1" fill-opacity=".18" stroke="#6366f1" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2143;0.3254" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/></rect><rect x="376" y="16" width="100" height="56" rx="9" class="dg-box" stroke="#6366f1" stroke-width="2.2"/><text x="426" y="40.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Card check</text><text x="426" y="56" text-anchor="middle" font-size="11" class="dg-muted">online payments</text></g>
<rect x="488" y="16" width="100" height="56" rx="9" class="dg-box"/><g opacity="1"><animate attributeName="opacity" values="1;0.28" keyTimes="0;0.4365" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><rect x="484" y="12" width="108" height="64" rx="12" fill="#6366f1" fill-opacity=".18" stroke="#6366f1" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2143;0.3254" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/></rect><rect x="488" y="16" width="100" height="56" rx="9" class="dg-box" stroke="#6366f1" stroke-width="2.2"/><text x="538" y="40.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Phone PIN</text><text x="538" y="56" text-anchor="middle" font-size="11" class="dg-muted">SMS or call</text></g>
<rect x="170" y="124" width="130" height="56" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.3254" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><rect x="166" y="120" width="138" height="64" rx="12" fill="#dd344c" fill-opacity=".18" stroke="#dd344c" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.3254;0.7778;0.8968" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/></rect><rect x="170" y="124" width="130" height="56" rx="9" class="dg-box" stroke="#dd344c" stroke-width="2.2"/><text x="235" y="148.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Root user</text><text x="235" y="164" text-anchor="middle" font-size="11" class="dg-muted">can do everything</text><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8968" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><rect x="170" y="124" width="130" height="56" rx="9" fill="#475569"/><text x="235" y="156.5" text-anchor="middle" font-size="12.5" font-weight="800" fill="#fff">locked away</text></g></g>
<rect x="446" y="124" width="130" height="56" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.6667" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><rect x="442" y="120" width="138" height="64" rx="12" fill="#d97706" fill-opacity=".18" stroke="#d97706" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6667;0.8968" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/></rect><rect x="446" y="124" width="130" height="56" rx="9" class="dg-box" stroke="#d97706" stroke-width="2.2"/><text x="511" y="148.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">IAM user admin</text><text x="511" y="164" text-anchor="middle" font-size="11" class="dg-muted">AdministratorAccess</text></g>
<rect x="170" y="262" width="130" height="56" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1" keyTimes="0;0.5476" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><rect x="166" y="258" width="138" height="64" rx="12" fill="#059669" fill-opacity=".18" stroke="#059669" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5476;0.6667" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/></rect><rect x="170" y="262" width="130" height="56" rx="9" class="dg-box" stroke="#059669" stroke-width="2.2"/><text x="235" y="286.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">AWS Budgets</text><text x="235" y="302" text-anchor="middle" font-size="11" class="dg-muted">Zero spend budget</text></g>
<g><rect x="8" y="258" width="128" height="64" rx="12" fill="#db2777" fill-opacity=".18" stroke="#db2777" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5476;0.6667" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/></rect><rect x="12" y="262" width="120" height="56" rx="9" class="dg-box" stroke="#db2777" stroke-width="2.2"/><text x="72" y="286.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Your inbox</text><text x="72" y="302" text-anchor="middle" font-size="11" class="dg-muted">budget alerts</text></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1111;0.4365" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="252" cy="16" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M247.5,16 L251,19.5 L256.5,12.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2143;0.4365" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="364" cy="16" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M359.5,16 L363,19.5 L368.5,12.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3254;0.4365" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="476" cy="16" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M471.5,16 L475,19.5 L480.5,12.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3254;0.4365" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="588" cy="16" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M583.5,16 L587,19.5 L592.5,12.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.4365" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="300" cy="124" r="9.5" fill="#d97706" stroke="#fff" stroke-width="2"/><rect x="295.5" y="123" width="9" height="6.5" rx="1.2" fill="#fff"/><path d="M297.2,123 V121 A2.8,2.8 0 0 1 302.8,121 V123" fill="none" stroke="#fff" stroke-width="1.6"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.6667" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="576" cy="124" r="9.5" fill="#d97706" stroke="#fff" stroke-width="2"/><rect x="571.5" y="123" width="9" height="6.5" rx="1.2" fill="#fff"/><path d="M573.2,123 V121 A2.8,2.8 0 0 1 578.8,121 V123" fill="none" stroke="#fff" stroke-width="1.6"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0056;0.0467" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M72,44 L202,44" keyPoints="0;0;1;1" keyTimes="0;0.0056;0.0467;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0578;0.1" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M202,44 L72,44" keyPoints="0;0;1;1" keyTimes="0;0.0578;0.1;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><g><rect x="-9" y="-6" width="18" height="12" rx="2" fill="#db2777" stroke="#fff" stroke-width="1.6"/><path d="M-8,-5 L0,1 L8,-5" fill="none" stroke="#fff" stroke-width="1.4"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1173;0.1998" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M202,44 L314,44" keyPoints="0;0;1;1" keyTimes="0;0.1173;0.1998;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2198;0.261" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M314,44 L426,44" keyPoints="0;0;1;1" keyTimes="0;0.2198;0.261;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2698;0.3121" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M426,44 L538,44" keyPoints="0;0;1;1" keyTimes="0;0.2698;0.3121;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3321;0.421" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M72,44 L72,152 L235,152" keyPoints="0;0;1;1" keyTimes="0;0.3321;0.421;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4432;0.5321" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M72,44 L72,152 L235,152" keyPoints="0;0;1;1" keyTimes="0;0.4432;0.5321;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5536;0.5952" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M235,152 L235,290" keyPoints="0;0;1;1" keyTimes="0;0.5536;0.5952;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6071;0.6548" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M235,290 L72,290" keyPoints="0;0;1;1" keyTimes="0;0.6071;0.6548;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><g><rect x="-9" y="-6" width="18" height="12" rx="2" fill="#db2777" stroke="#fff" stroke-width="1.6"/><path d="M-8,-5 L0,1 L8,-5" fill="none" stroke="#fff" stroke-width="1.4"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6733;0.7622" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M235,152 L511,152" keyPoints="0;0;1;1" keyTimes="0;0.6733;0.7622;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7825;0.8325" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M72,44 L72,206 L511,206 L511,152" keyPoints="0;0;1;1" keyTimes="0;0.7825;0.8325;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8397;0.8897" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><animateMotion path="M511,152 L511,206 L72,206 L72,44" keyPoints="0;0;1;1" keyTimes="0;0.8397;0.8897;1" calcMode="linear" dur="25.2s" repeatCount="indefinite"/><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(20.4,350.5) scale(.8)"><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g><text x="31.8" y="354">you</text><g transform="translate(72.6,350.5) scale(.8)"><g><rect x="-9" y="-6" width="18" height="12" rx="2" fill="#db2777" stroke="#fff" stroke-width="1.6"/><path d="M-8,-5 L0,1 L8,-5" fill="none" stroke="#fff" stroke-width="1.4"/></g></g><text x="85.6" y="354">email</text><g transform="translate(136.8,350.5) scale(.8)"><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g><text x="149.8" y="354">MFA / temporary keys</text><g transform="translate(284.2,350.5) scale(.8)"><circle r="6" fill="#a855f7" stroke="#fff" stroke-width="2"/></g><text x="295.6" y="354">set up</text></g>
<rect x="12" y="366" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="366" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="25.2s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1111" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="36" cy="394" r="14" fill="#6366f1"/><text x="36" y="399" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="389" font-size="14" font-weight="800" fill="#6366f1">Sign up with your email</text><text x="578" y="389" text-anchor="end" font-size="10.5" class="dg-muted">Sign up · 1/9</text><text x="60" y="410" font-size="12.5" class="dg-text">Root email and account name, a code from your inbox, then a strong password.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1111;0.2143" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="36" cy="394" r="14" fill="#6366f1"/><text x="36" y="399" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="389" font-size="14" font-weight="800" fill="#6366f1">Choose a plan</text><text x="578" y="389" text-anchor="end" font-size="10.5" class="dg-muted">Sign up · 2/9</text><text x="60" y="410" font-size="12.5" class="dg-text">Free plan: never charged, ends after 6 months. Both get $100 in credits.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2143;0.3254" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="36" cy="394" r="14" fill="#6366f1"/><text x="36" y="399" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="389" font-size="14" font-weight="800" fill="#6366f1">Card and phone checks</text><text x="578" y="389" text-anchor="end" font-size="10.5" class="dg-muted">Sign up · 3/9</text><text x="60" y="410" font-size="12.5" class="dg-text">A card for online payments, then a PIN by SMS or call. India: an ID check too.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3254;0.4365" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="36" cy="394" r="14" fill="#6366f1"/><text x="36" y="399" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="389" font-size="14" font-weight="800" fill="#6366f1">Active: first sign-in as root</text><text x="578" y="389" text-anchor="end" font-size="10.5" class="dg-muted">Sign up · 4/9</text><text x="60" y="410" font-size="12.5" class="dg-text">Pick Basic support (free). Once active, sign in with the root email.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.4365;0.5476" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="36" cy="394" r="14" fill="#059669"/><text x="36" y="399" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="389" font-size="14" font-weight="800" fill="#059669">Protect root with MFA</text><text x="578" y="389" text-anchor="end" font-size="10.5" class="dg-muted">First 15 minutes · 5/9</text><text x="60" y="410" font-size="12.5" class="dg-text">Add a passkey or authenticator app. A stolen password alone is now useless.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5476;0.6667" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="36" cy="394" r="14" fill="#059669"/><text x="36" y="399" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="389" font-size="14" font-weight="800" fill="#059669">Set a budget alert</text><text x="578" y="389" text-anchor="end" font-size="10.5" class="dg-muted">First 15 minutes · 6/9</text><text x="60" y="410" font-size="12.5" class="dg-text">A Zero spend budget emails you as soon as spending goes over $0.01.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6667;0.7778" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="36" cy="394" r="14" fill="#059669"/><text x="36" y="399" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="389" font-size="14" font-weight="800" fill="#059669">Create your admin user</text><text x="578" y="389" text-anchor="end" font-size="10.5" class="dg-muted">First 15 minutes · 7/9</text><text x="60" y="410" font-size="12.5" class="dg-text">IAM user admin in group admins with AdministratorAccess, plus its own MFA.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7778;0.8968" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="36" cy="394" r="14" fill="#d97706"/><text x="36" y="399" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="389" font-size="14" font-weight="800" fill="#d97706">Daily work: admin and aws login</text><text x="578" y="389" text-anchor="end" font-size="10.5" class="dg-muted">Daily use · 8/9</text><text x="60" y="410" font-size="12.5" class="dg-text">Sign in as admin. aws login gives the CLI temporary keys: no access keys.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8968" calcMode="discrete" dur="25.2s" repeatCount="indefinite"/><circle cx="36" cy="394" r="14" fill="#d97706"/><text x="36" y="399" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">9</text><text x="60" y="389" font-size="14" font-weight="800" fill="#d97706">Root stays locked away</text><text x="578" y="389" text-anchor="end" font-size="10.5" class="dg-muted">Daily use · 9/9</text><text x="60" y="410" font-size="12.5" class="dg-text">Use it only to close the account, change its email or the support plan.</text></g>
</svg>
```

### The whole journey at a glance

```flow
📧 | Email and password | Your root user email, an account name and a strong password.
🎁 | Choose a plan | **Free plan** (never charged, up to 6 months) or **Paid plan** (full access, pay beyond credits).
🏠 | Contact details | Personal or business, address and phone. An Indian address means your account is with **AWS India**.
💳 | Card | A credit or debit card that allows online payments, used to verify you (AWS India: a refunded ₹2 check).
🪪 | Identity (India only) | PAN card, voter ID or driving licence, as required by CERT-In rules.
📱 | Phone check | A PIN by SMS or voice call.
✅ | Support plan and activation | Choose **Basic (free)**. The account is usually active within minutes.
🔐 | First 15 minutes | Root MFA, budget alert, an admin user for daily work, AWS CLI with `aws login`.
```

### Key words

| Word | Meaning |
|---|---|
| **Root user** | The email and password you sign up with. It can do **everything**, including closing the account. Use it only for a few account-level tasks |
| **Account ID** | A 12-digit number that identifies your account, e.g. `123456789012` |
| **IAM user** | A normal login you create inside the account, with only the permissions you give it |
| **MFA** | Multi-factor authentication: a second proof (phone app or passkey) on top of the password |
| **Region** | Where your resources run, e.g. Mumbai (`ap-south-1`) or N. Virginia (`us-east-1`) |
| **Credits** | Free money from AWS that is used up before anything is charged |
| **Budget** | An email alert when your spending passes an amount you choose |

### Check yourself

1. Why shouldn't you use the root user every day?
2. What happens to your Free plan account after 6 months?

> **Tip:** Answers: 1) It has unlimited power; if it leaks, someone can delete everything or run up a huge bill, and you can't limit it. 2) It closes, unless you upgrade to the Paid plan within 90 days.

## Before you start: what you need

> **In simple words:** Keep these ready before you open the sign-up page. The whole process takes about **15 minutes**, plus up to a day for activation in rare cases.

| You need | Details |
|---|---|
| **An email address you'll keep for years** | For a personal learning account use your **personal** email, not your work email (you might change jobs). For a company account use a shared list such as `aws-root@yourcompany.com` |
| **A phone that can receive SMS or calls** | Used to confirm your identity now, and to recover the account later |
| **A credit or debit card** | It must allow **online** (and, outside India, **international**) payments. Some debit and prepaid cards are refused |
| **India only: an ID document** | Personal accounts: **PAN card**, **voter ID (EPIC)** or **driving licence**. Business accounts: **PAN card** or **Certificate of Incorporation** |
| **A password manager** (recommended) | To create and store a long, unique root password |
| **An authenticator app or passkey** | Google Authenticator, Microsoft Authenticator, a phone passkey or a security key, for MFA in Step 8 |

> **Tip:** Every AWS account needs its own email address. With Gmail you can reuse one inbox: `yourname+aws-learning@gmail.com` arrives in `yourname@gmail.com`, but AWS sees it as a different address.

## Which sign-up to choose: new or advanced

> **In simple words:** AWS now offers **two ways to sign up**. The **new** one lets you log in with Google, GitHub, Apple or Amazon and sets everything up for you, but hides some controls. The **advanced** one is the classic AWS account with full control. **To follow the guides on this site, choose "Sign up for AWS (advanced)".**

```compare
✨ Sign up for AWS (new) | 🛠️ Sign up for AWS (advanced)
Log in with Google, GitHub, Apple or Amazon (creates an AWS Builder ID) | Sign in with a root user email and password
Resources are grouped into projects, with optional spend limits on the Paid plan | A classic AWS account, set up and organised by you
No root user | Root user, which you protect with MFA
IAM users can't sign in to the console (programmatic access only) | IAM users with console sign-in, as in the IAM guide
AWS picks the Region from your contact details | You choose any Region
A selected set of AWS services | All AWS services (on the Paid plan)
```

**Why advanced for this site:** the [IAM guide](#/tool/aws-iam) creates IAM users who sign in to the console, and the [VPC](#/tool/aws-vpc), [EC2](#/tool/ec2-website) and [EKS](#/tool/eks-cluster) guides let you pick Regions. Those work as written only in an advanced account. If you already signed up the new way, you can **activate advanced features** later from AWS Settings.

**How to tell which sign-up page you're on:**
- The page asks for a **root user email address** and an **AWS account name** → **advanced**. ✅
- The page asks you to choose **Google, GitHub, Apple or Amazon** → **new**. Go back and choose **Sign up for AWS (advanced)** on the banner.

AWS docs: [Compare sign-up options](https://docs.aws.amazon.com/accounts/latest/reference/sign-up-for-aws.html)

## Free plan or Paid plan

> **In simple words:** During sign-up you choose a plan. The **Free plan** can never charge you, but it ends after **6 months or when your credits run out**, and some services aren't available. The **Paid plan** gives you everything, and you pay only for what goes beyond your credits. Both get the same credits.

```compare
🎁 Free plan | 💳 Paid plan
USD $100 credits at sign-up, plus up to $100 more for activities | The same credits
You are never charged | You pay for usage beyond your credits
Selected services only (no Savings Plans, Reserved Instances, some Marketplace items) | All AWS services and features
Ends after 6 months or when credits are used up, whichever comes first | Doesn't end when credits run out
Then the account closes; you have 90 days to upgrade or it's deleted | Keeps running for as long as you want
Upgrade any time with one click | Short-term free trials of some services
```

**Our recommendation for learners:** start on the **Free plan**. You can't get a surprise bill while you learn. Upgrade to the Paid plan when a guide needs a service the Free plan doesn't include, or before the 6 months end if you want to keep the account. Set the budget alert in Step 9 **before** you upgrade.

> **Warning:** On the Free plan, anything you forget to delete keeps eating your credits. An EKS cluster, a NAT gateway or a load balancer left running for a few weeks can use up the whole $100, and when the credits hit zero **the plan ends and the account closes**. Always run each guide's clean-up step.

> **Note:** A Free plan account is **upgraded to Paid automatically** if you join **AWS Organizations** or set up AWS Control Tower. Don't turn those on in a learning account unless you mean to.

### Earn the extra $100

On **Console Home**, the **Explore AWS** widget lists five activities. Each one gives **USD $20** in credits (the small cost of doing it comes out of your credits):

| Activity | Related guide |
|---|---|
| Launch an EC2 instance (and terminate it) | [Website on EC2](#/tool/ec2-website) |
| Create a budget | Step 9 below |
| Create a web app with Lambda | |
| Create an Amazon RDS database | |
| Use a model in the Amazon Bedrock playground | |

Credits expire **12 months** after you open the account.

AWS docs: [Choosing a plan](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/free-tier-plans.html) · [Earn additional credits](https://docs.aws.amazon.com/accounts/latest/reference/bcm-lite-free-tier-credits.html)

## Step 1: Email, account name and password

> **In simple words:** Tell AWS which email owns the account, give the account a name, prove the email is yours with a code, and set the root password.

1. Go to **[aws.amazon.com](https://aws.amazon.com/)** and choose **Create account**. On the banner, choose **Sign up for AWS (advanced)**. You can also open the [sign-up page](https://signin.aws.amazon.com/signup?request_type=register) directly.
2. Enter your **Root user email address** and an **AWS account name**, then choose **Verify email address**.
   - A good account name: `firstname-lastname-learning` (personal) or `company-team-dev` (business). It appears on invoices and in the console, and you can change it later.
3. Open your email, copy the **verification code**, paste it and choose **Verify**. (No email? Check spam, then wait a few minutes.)
4. Create the **root user password**, type it again and choose **Continue**. AWS requires:
   - 8 to 128 characters,
   - at least three of: uppercase, lowercase, numbers, symbols,
   - not the same as your account name or email.

> **Tip:** Let your password manager generate a 20+ character password. You will rarely type it: after today you'll sign in as your admin user instead.

## Step 2: Choose your plan

> **In simple words:** Pick the **Free plan** or the **Paid plan** (see the comparison above). You can move from Free to Paid at any time, so if in doubt, start Free.

1. Read the two plan cards on the screen.
2. Select **Free plan** (recommended for learning) or **Paid plan**.
3. Choose **Continue**.

## Step 3: Contact information

> **In simple words:** Tell AWS who owns the account and how to reach you. The **address** matters: if it's in India, your agreement is with **AWS India** and you'll do an extra identity check in Step 5.

1. Choose **Personal** (for yourself) or **Business** (for a company). Both have exactly the same features.
2. Enter your **full name**, **phone number** (with country code) and **address**.
   - **India:** type your name **exactly** as it appears on the ID document you'll use in Step 5. A different spelling makes verification fail.
   - **Business:** use a company phone number and a shared email, so the company keeps access when people change jobs.
3. Read the **AWS Customer Agreement**, tick the box and choose **Continue**.

| If your contact and billing address is… | Your account is with | You pay in |
|---|---|---|
| In India | **Amazon Web Services India Private Limited (AWS India)** | Indian rupees (INR) |
| Anywhere else | Amazon Web Services | US dollars (USD), or a supported local currency |

## Step 4: Billing information

> **In simple words:** Add a card so AWS knows who you are and can bill any paid usage. On the Free plan it is used only for verification.

1. Enter the **card number**, **expiry date**, **cardholder name** and **billing address**. To use a different billing address, choose **Use a new address**.
2. **India (AWS India):**
   - Enter the **CVV**. Your bank may ask for a **one-time password (OTP)**.
   - AWS India charges **₹2** to check the card and **refunds** it after verification.
   - **Do you have a PAN?** Choose **Yes** to show your PAN on tax invoices, or **No** to add it later.
3. Choose **Verify and continue**.

> **Note:** If the card is declined, ask your bank to allow **online** and **international** transactions for it, or try another card. That fixes most cases.

## Step 5 (India only): Customer verification

> **In simple words:** Indian rules (CERT-In) require AWS India to check your identity before you can use AWS. You choose a document, type its number, and AWS checks that the **name matches** your contact or billing name.

1. On **Confirm your identity**, choose the **primary purpose** of the account (for example, learning or personal projects).
2. Choose the **ownership type**: an individual, or a company or partnership. For a company, enter the name of a **key managerial person**, such as a director.
3. Choose a **document type** and type its details:

| Document | Accepted for | You also provide |
|---|---|---|
| **PAN card** (format `AAAAA1111A`) | Personal and business | Date of birth or incorporation; upload the front side |
| **Voter ID (EPIC)** | Personal | Upload front and back |
| **Driving licence** (issued by the Union of India) | Personal | Date of birth; upload front and back |
| **Certificate of Incorporation** (CIN) | Business | Upload the certificate |

4. Select the **name** that exactly matches the document, give your consent and choose **Continue**.

You get the verification result **by email**. You can also check it later under **Account → Customer verification**. You must **pass verification before you can use AWS services**.

AWS docs: [Manage accounts in India](https://docs.aws.amazon.com/accounts/latest/reference/managing-accounts-india.html)

## Step 6: Confirm your phone number

> **In simple words:** AWS sends a short PIN to your phone to prove that the phone is really yours. This phone is also how you recover the account if you ever lose your password or MFA device.

1. Choose **Text message (SMS)** or **Voice call**.
2. Select your **country code** and enter your **mobile number**.
3. Complete the **security check** (type the characters you see).
4. Choose **Send SMS** (or **Call me now**).
5. Enter the **PIN** you receive and choose **Continue**.

> **Tip:** No SMS after a couple of minutes? Go back and choose **Voice call**. It works better with some mobile networks.

## Step 7: Choose a support plan and finish

> **In simple words:** Pick **Basic support**: it's free and includes billing and account help. Paid support plans are for companies running production systems.

1. Select **Basic support – Free**.
2. Choose **Complete sign up**.
3. You'll see "your account is being activated". Watch your inbox (and spam) for the **activation email**. It usually arrives within minutes, but can take **up to 24 hours**. India accounts are activated once the card and customer verification pass.

AWS docs: [Sign up for AWS (advanced)](https://docs.aws.amazon.com/accounts/latest/reference/getting-started.html)

## Step 8: First sign-in: protect the root user with MFA

> **In simple words:** Your account now exists, and the root password is the only thing protecting it. Add **MFA** right away so a stolen password alone is useless. AWS **requires** root MFA: you must register it within **14 days** of your first sign-in.

1. Open the **[AWS console](https://console.aws.amazon.com/)**, choose **Root user**, enter your email, choose **Next**, then enter your password.
2. Top-right, choose your **account name → Security credentials**.
3. Under **Multi-factor authentication (MFA)**, choose **Assign MFA device**.
4. Name the device (for example `root-phone`) and choose a type:

| MFA type | How it works | Recommendation |
|---|---|---|
| **Passkey or security key** | Your phone, laptop fingerprint or a USB key confirms the sign-in | ✅ Best: resists phishing |
| **Authenticator app** | An app shows a 6-digit code that changes every 30 seconds | ✅ Good and free |
| **Hardware TOTP token** | A small device that shows codes | For companies |

5. Follow the screen. For an authenticator app: scan the **QR code**, then type **two codes in a row** and choose **Add MFA**.
6. Sign out and sign in again as root to check that MFA is asked for.
7. Write down your **12-digit account ID** (account menu, top-right). You'll need it to sign in as your admin user.

> **Tip:** You can register up to **8 MFA devices** on the root user. Add a second one (for example a passkey on your laptop plus an app on your phone) so losing one device doesn't lock you out.

**Things only the root user should do:** change the account email, close the account, and change the support plan. For **everything else**, use the admin user from Step 10.

AWS docs: [Root user best practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/root-user-best-practices.html) · [MFA for the root user](https://docs.aws.amazon.com/IAM/latest/UserGuide/enable-mfa-for-root.html)

## Step 9: Set a budget alert

> **In simple words:** A budget is a **smoke alarm for money**. Ask AWS to email you as soon as you spend even one cent, so a forgotten server is noticed within hours, not at the end of the month.

1. In the search bar at the top, type **Budgets** and open **AWS Budgets** (under Billing and Cost Management).
2. Choose **Create budget**.
3. Choose **Use a template (simplified)**, then **Zero spend budget**. It alerts you as soon as spending goes over $0.01.
   - Prefer a limit? Choose **Monthly cost budget** and enter an amount such as **$5**.
4. Enter your **email address** and choose **Create budget**.
5. While you're in Billing, open **Billing and Cost Management home** and find your **credit balance** and (Free plan) **days remaining**. Check it once a week.

> **Note:** Creating a budget is one of the five activities that earn **$20 in credits**.

AWS docs: [Managing your costs with AWS Budgets](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html)

## Step 10: Create an admin user for daily work

> **In simple words:** Make yourself a **normal key**: an IAM user called `admin` with full permissions and its own MFA. You sign in with it every day, and the root user stays locked away.

**First, let IAM users see billing.** As root: account menu → **Account** → **IAM user and role access to Billing information** → **Edit** → tick **Activate IAM Access** → **Update**. (Without this, even an admin user gets "access denied" on billing pages.)

**Then create the admin user:**

1. Open **IAM** → **User groups** → **Create group**. Name it `admins`, tick the **AdministratorAccess** policy and choose **Create user group**.
2. **IAM → Users → Create user**. User name `admin`.
3. Tick **Provide user access to the AWS Management Console**, choose **I want to create an IAM user**, choose **Custom password** and set a strong one. You can untick "must create a new password", since this user is you.
4. **Add user to group** → `admins` → **Next** → **Create user**.
5. Copy the **Console sign-in URL**. It looks like `https://123456789012.signin.aws.amazon.com/console`.
6. **Optional, but easier to remember:** IAM **Dashboard** → **Account Alias** → **Create**, for example `yourname-learning`. Your sign-in URL becomes `https://yourname-learning.signin.aws.amazon.com/console`.
7. **Sign out** of root. Open the sign-in URL and sign in as `admin`.
8. As `admin`: account menu → **Security credentials** → **Assign MFA device**, the same way as Step 8.

| Use the root user to | Use the admin user to |
|---|---|
| Close the account, change the root email | Everything else: create servers, users, VPCs, clusters |
| Change the support plan | View bills and budgets (after "Activate IAM Access") |
| Recover if every admin is locked out | Daily work, and signing in to the AWS CLI |

> **Note:** In a company with several people, the better way is **IAM Identity Center** (single sign-on). The [IAM guide](#/tool/aws-iam) explains both, and how to give other people less than full admin.

## Step 11: Choose a Region and connect the AWS CLI

> **In simple words:** Choose the AWS city your resources will live in, then connect the `aws` command on your laptop to your account. With **`aws login`** you sign in through the browser, just like the console, so there are **no access keys to leak**.

**Choose your Region:** use the **Region selector** at the top-right of the console.

| If you… | Use |
|---|---|
| want to copy this site's commands exactly | **US East (N. Virginia)** `us-east-1` |
| are in India and want low latency | **Asia Pacific (Mumbai)** `ap-south-1` |
| are elsewhere | The Region closest to you |

Most resources belong to one Region. If something you created "disappears", check the Region selector first.

**Connect the AWS CLI** (install it first with [Workstation setup](#/tool/setup)). `aws login` needs **AWS CLI 2.32.0 or later**:

```bash
aws --version                         # must show aws-cli/2.32.0 or newer

aws login                             # asks for a Region the first time, then opens your browser
# In the browser: "Continue with Root or IAM user" -> sign in as your admin user (not root)

aws sts get-caller-identity           # shows your account ID and arn:aws:iam::<id>:user/admin
aws ec2 describe-regions --query 'Regions[].RegionName' --output table
```

No browser on the machine (for example a remote server)? Run `aws login --remote` and open the link it prints on your laptop. The CLI renews its temporary credentials automatically, and a session lasts up to 12 hours; then run `aws login` again.

> **Warning:** Don't create **access keys for the root user**, ever. Avoid access keys for IAM users too, unless a tool can't use anything else. Leaked keys are found by bots within minutes.

AWS docs: [Sign in to the AWS CLI with console credentials](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sign-in.html)

## Troubleshooting

> **In simple words:** Most sign-up problems come from the email, the card or the phone check. Here are the usual fixes.

| Problem | Fix |
|---|---|
| No verification email | Check spam and promotions folders, wait 5 minutes, then choose resend. Make sure the address is typed correctly |
| **Create account** button is missing | You're signed in already. Choose **Sign in to the Console → Sign in to a different account → Create a new AWS account** |
| Card declined | Allow online and international transactions with your bank, check the billing address matches the card, or try another card |
| No SMS PIN | Choose **Voice call** instead, check the country code, and don't request many codes in a row |
| India: verification failed | The name on the document must **exactly** match your contact or billing name. Fix it under **Account → Customer verification** and submit again |
| Account still "pending activation" | Activation can take up to 24 hours. If it's longer, open the **AWS Support Center** and create a case under **Account and billing** |
| "Access denied" on billing pages as admin | Turn on **Activate IAM Access** as root (Step 10) |
| Lost the MFA device | On the root sign-in page, choose **Trouble signing in?** and verify with your email and phone |
| Forgot the root password | On the root sign-in page, choose **Forgot password?**. A reset link goes to the root email |
| Resources "disappeared" | You're looking in a different **Region**. Switch it at the top-right |
| Free plan: "upgrade to use this service" | That service isn't in the Free plan. Upgrade if you need it, and set a budget first |

AWS re:Post: [Create and activate an AWS account](https://repost.aws/knowledge-center/create-and-activate-aws-account)

## Close the account when you're done

> **In simple words:** If you only needed the account for a course, clean up and close it so nothing can ever be charged. Closing is reversible for a while, in case you change your mind.

1. Delete what you created: run the clean-up step of every guide you followed (EC2 instances, EKS clusters, NAT gateways, load balancers, Elastic IPs, S3 buckets).
2. Check **Billing and Cost Management → Bills** for anything still charging.
3. Sign in as **root** → account menu → **Account** → scroll to **Close account** → follow the steps.
4. AWS keeps a closed account for **90 days**, during which you can reopen it by contacting AWS Support. After that, it's deleted permanently.

On the **Free plan** you don't have to do anything: the account closes by itself when the plan ends, and is deleted 90 days later unless you upgrade.

AWS docs: [Close an AWS account](https://docs.aws.amazon.com/accounts/latest/reference/manage-acct-closing.html)

## Checklist

> **In simple words:** Tick every line before you start the other AWS guides. If all are done, your account is safe, cheap to run, and ready for hands-on work.

| ✔ | Task | Where |
|---|---|---|
| ☐ | Signed up with **Sign up for AWS (advanced)** | Step 1 |
| ☐ | Chose a plan (Free recommended for learning) | Step 2 |
| ☐ | Account activated (email received) | Step 7 |
| ☐ | **MFA on the root user** (ideally two devices) | Step 8 |
| ☐ | Root password and account ID saved in a password manager | Step 8 |
| ☐ | **Zero spend** (or small monthly) **budget** with your email | Step 9 |
| ☐ | IAM access to billing **activated** | Step 10 |
| ☐ | `admin` IAM user in the `admins` group, **with its own MFA** | Step 10 |
| ☐ | Signed out of root; daily work as `admin` | Step 10 |
| ☐ | Region chosen; `aws login` and `aws sts get-caller-identity` work | Step 11 |
| ☐ | Earned extra credits from the Explore AWS activities (optional) | Free or Paid plan |

**Next:** the [AWS overview](#/tool/aws) for the core services, then the [IAM guide](#/tool/aws-iam) and [Website on EC2](#/tool/ec2-website) to build something real.
