# AWS KMS: Encryption Keys

AWS KMS (Key Management Service) creates and protects the encryption keys used across AWS: S3, EBS disks, RDS databases, Secrets Manager, EKS secrets and your own applications. The keys never leave KMS unencrypted. You ask KMS to encrypt or decrypt, and KMS checks permissions and logs every use. This guide covers key types, creating keys, encrypting data, envelope encryption, key policies, rotation and safe deletion.

> **Cost:** Each **customer managed key** costs about **$1 per month** (prorated), and the first two rotations add a little more. API requests cost a few cents per 10,000, and many requests are free tier. AWS managed keys (`aws/s3`, `aws/ebs`…) have no monthly fee. See [KMS pricing](https://aws.amazon.com/kms/pricing/).

## Start here: KMS in simple words

> **In simple words:** KMS is a **bank vault for encryption keys**. You never take the master key out of the vault. Instead you hand data to the vault clerk, who encrypts or decrypts it for you, but only if you're on the key's permission list, and every visit is written in a logbook.

### Watch how it works

```svg Watch it work: envelope encryption, with a data key from KMS to encrypt a file locally, and KMS decrypting only that small key later. The animation loops.
<svg viewBox="0 0 600 410" role="img" data-anim="aws-kms" aria-label="Animated envelope encryption. Encrypt and store: the app calls GenerateDataKey on the KMS key alias/app-data. KMS returns the same data key twice: once in plain form and once encrypted under the KMS key. The app encrypts big-file locally with the plaintext key, then wipes the plaintext key from memory. The encrypted file and the encrypted data key are stored together in Amazon S3. Read it back: later the app downloads both and sends only the small encrypted data key to KMS with Decrypt. KMS checks that the key policy and IAM allow kms:Decrypt, and CloudTrail records the call. The plaintext data key comes back, and the app decrypts the file locally. The KMS key itself never leaves KMS.">
<style>@media (prefers-reduced-motion: reduce) { .dfa-move { display: none } }</style>
<polyline points="66,157 238,157" fill="none" stroke-linejoin="round" stroke="#0d9488" stroke-width="1.8" stroke-dasharray="6 3" stroke-opacity=".7"/>
<polyline points="238,157 503,157" fill="none" stroke-linejoin="round" stroke="#94a3b8" stroke-width="2.2"/>
<polyline points="503,157 503,53 238,53" fill="none" stroke-linejoin="round" stroke="#eab308" stroke-width="1.8" stroke-dasharray="3 3" stroke-opacity=".75"/>
<polyline points="238,53 238,157" fill="none" stroke-linejoin="round" stroke="#eab308" stroke-width="1.8" stroke-dasharray="3 3" stroke-opacity=".75"/>
<polyline points="238,157 238,287" fill="none" stroke-linejoin="round" stroke="#f97316" stroke-width="1.8" stroke-dasharray="5 4" stroke-opacity=".65"/>
<polyline points="503,157 503,287" fill="none" stroke-linejoin="round" stroke="#64748b" stroke-width="1.8" stroke-dasharray="4 3" stroke-opacity=".7"/>
<rect x="176" y="30" width="124" height="46" rx="9" class="dg-box"/><g opacity="0.28"><animate attributeName="opacity" values="0.28;1;0.28;1" keyTimes="0;0.1182;0.3727;0.8636" calcMode="discrete" dur="22s" repeatCount="indefinite"/><rect x="172" y="26" width="132" height="54" rx="12" fill="#eab308" fill-opacity=".18" stroke="#eab308" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.1182;0.3727;0.8636" calcMode="discrete" dur="22s" repeatCount="indefinite"/></rect><rect x="176" y="30" width="124" height="46" rx="9" class="dg-box" stroke="#eab308" stroke-width="2.2"/><text x="238" y="49.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Plaintext key</text><text x="238" y="65" text-anchor="middle" font-size="11" class="dg-muted">in memory only</text></g>
<g><rect x="10" y="126" width="112" height="62" rx="12" fill="#0d9488" fill-opacity=".18" stroke="#0d9488" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0;1" keyTimes="0;0.2455;0.3727;0.8636" calcMode="discrete" dur="22s" repeatCount="indefinite"/></rect><rect x="14" y="130" width="104" height="54" rx="9" class="dg-box" stroke="#0d9488" stroke-width="2.2"/><text x="66" y="153.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Your data</text><text x="66" y="169" text-anchor="middle" font-size="11" class="dg-muted">big-file</text></g>
<g><rect x="172" y="126" width="132" height="62" rx="12" fill="#f59e0b" fill-opacity=".18" stroke="#f59e0b" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1" keyTimes="0;0.7364;0.8636" calcMode="discrete" dur="22s" repeatCount="indefinite"/></rect><rect x="176" y="130" width="124" height="54" rx="9" class="dg-box" stroke="#f59e0b" stroke-width="2.2"/><text x="238" y="153.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Your app</text><text x="238" y="169" text-anchor="middle" font-size="11" class="dg-muted">encrypts locally</text></g>
<g><rect x="416" y="115" width="174" height="84" rx="12" fill="#dd344c" fill-opacity=".18" stroke="#dd344c" stroke-width="3" opacity="1"><animate attributeName="opacity" values="1;0;1;0" keyTimes="0;0.2455;0.6182;0.8636" calcMode="discrete" dur="22s" repeatCount="indefinite"/></rect><rect x="420" y="119" width="166" height="76" rx="9" class="dg-box" stroke="#dd344c" stroke-width="2.2"/><text x="503" y="146" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">AWS KMS</text><text x="503" y="161.5" text-anchor="middle" font-size="11" class="dg-muted">KMS key</text><text x="503" y="176.5" text-anchor="middle" font-size="11" class="dg-muted">alias/app-data</text></g>
<g><rect x="172" y="258" width="132" height="58" rx="12" fill="#16a34a" fill-opacity=".18" stroke="#16a34a" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3727;0.6182" calcMode="discrete" dur="22s" repeatCount="indefinite"/></rect><rect x="176" y="262" width="124" height="50" rx="9" class="dg-box" stroke="#16a34a" stroke-width="2.2"/><text x="238" y="283.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">Amazon S3</text><text x="238" y="299" text-anchor="middle" font-size="11" class="dg-muted">stored together</text></g>
<g><rect x="416" y="258" width="174" height="58" rx="12" fill="#64748b" fill-opacity=".18" stroke="#64748b" stroke-width="3" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7364;0.8636" calcMode="discrete" dur="22s" repeatCount="indefinite"/></rect><rect x="420" y="262" width="166" height="50" rx="9" class="dg-box" stroke="#64748b" stroke-width="2.2"/><text x="503" y="283.5" text-anchor="middle" font-size="13" font-weight="800" class="dg-text">CloudTrail</text><text x="503" y="299" text-anchor="middle" font-size="11" class="dg-muted">logs every call</text></g>
<g opacity="1"><circle cx="586" cy="119" r="9.5" fill="#d97706" stroke="#fff" stroke-width="2"/><rect x="581.5" y="118" width="9" height="6.5" rx="1.2" fill="#fff"/><path d="M583.2,118 V116 A2.8,2.8 0 0 1 588.8,116 V118" fill="none" stroke="#fff" stroke-width="1.6"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3727;0.5" calcMode="discrete" dur="22s" repeatCount="indefinite"/><circle cx="300" cy="30" r="9.5" fill="#e11d48" stroke="#fff" stroke-width="2"/><path d="M296,26 L304,34 M304,26 L296,34" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/></g>
<g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7364;0.8636" calcMode="discrete" dur="22s" repeatCount="indefinite"/><circle cx="420" cy="119" r="9.5" fill="#059669" stroke="#fff" stroke-width="2"/><path d="M415.5,119 L419,122.5 L424.5,115.5" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.0071;0.1016" calcMode="discrete" dur="22s" repeatCount="indefinite"/><animateMotion path="M238,157 L503,157" keyPoints="0;0;1;1" keyTimes="0;0.0071;0.1016;1" calcMode="linear" dur="22s" repeatCount="indefinite"/><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1258;0.22" calcMode="discrete" dur="22s" repeatCount="indefinite"/><animateMotion path="M503,157 L503,53 L238,53" keyPoints="0;0;1;1" keyTimes="0;0.1258;0.22;1" calcMode="linear" dur="22s" repeatCount="indefinite"/><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.136;0.2276" calcMode="discrete" dur="22s" repeatCount="indefinite"/><animateMotion path="M503,157 L238,157" keyPoints="0;0;1;1" keyTimes="0;0.136;0.2276;1" calcMode="linear" dur="22s" repeatCount="indefinite"/><g><rect x="-9" y="-6" width="18" height="12" rx="2" fill="#db2777" stroke="#fff" stroke-width="1.6"/><path d="M-8,-5 L0,1 L8,-5" fill="none" stroke="#fff" stroke-width="1.4"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2531;0.3218" calcMode="discrete" dur="22s" repeatCount="indefinite"/><animateMotion path="M66,157 L238,157" keyPoints="0;0;1;1" keyTimes="0;0.2531;0.3218;1" calcMode="linear" dur="22s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2836;0.3218" calcMode="discrete" dur="22s" repeatCount="indefinite"/><animateMotion path="M238,53 L238,157" keyPoints="0;0;1;1" keyTimes="0;0.2836;0.3218;1" calcMode="linear" dur="22s" repeatCount="indefinite"/><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3804;0.4745" calcMode="discrete" dur="22s" repeatCount="indefinite"/><animateMotion path="M238,157 L238,287" keyPoints="0;0;1;1" keyTimes="0;0.3804;0.4745;1" calcMode="linear" dur="22s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3931;0.4873" calcMode="discrete" dur="22s" repeatCount="indefinite"/><animateMotion path="M238,157 L238,287" keyPoints="0;0;1;1" keyTimes="0;0.3931;0.4873;1" calcMode="linear" dur="22s" repeatCount="indefinite"/><g><rect x="-9" y="-6" width="18" height="12" rx="2" fill="#db2777" stroke="#fff" stroke-width="1.6"/><path d="M-8,-5 L0,1 L8,-5" fill="none" stroke="#fff" stroke-width="1.4"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5071;0.5945" calcMode="discrete" dur="22s" repeatCount="indefinite"/><animateMotion path="M238,287 L238,157" keyPoints="0;0;1;1" keyTimes="0;0.5071;0.5945;1" calcMode="linear" dur="22s" repeatCount="indefinite"/><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5189;0.6064" calcMode="discrete" dur="22s" repeatCount="indefinite"/><animateMotion path="M238,287 L238,157" keyPoints="0;0;1;1" keyTimes="0;0.5189;0.6064;1" calcMode="linear" dur="22s" repeatCount="indefinite"/><g><rect x="-9" y="-6" width="18" height="12" rx="2" fill="#db2777" stroke="#fff" stroke-width="1.6"/><path d="M-8,-5 L0,1 L8,-5" fill="none" stroke="#fff" stroke-width="1.4"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6253;0.7198" calcMode="discrete" dur="22s" repeatCount="indefinite"/><animateMotion path="M238,157 L503,157" keyPoints="0;0;1;1" keyTimes="0;0.6253;0.7198;1" calcMode="linear" dur="22s" repeatCount="indefinite"/><g><rect x="-9" y="-6" width="18" height="12" rx="2" fill="#db2777" stroke="#fff" stroke-width="1.6"/><path d="M-8,-5 L0,1 L8,-5" fill="none" stroke="#fff" stroke-width="1.4"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7618;0.8458" calcMode="discrete" dur="22s" repeatCount="indefinite"/><animateMotion path="M503,157 L503,287" keyPoints="0;0;1;1" keyTimes="0;0.7618;0.8458;1" calcMode="linear" dur="22s" repeatCount="indefinite"/><g><rect x="-8" y="-6" width="16" height="12" rx="2" fill="#64748b" stroke="#fff" stroke-width="1.6"/><path d="M-5,-2 H5 M-5,2 H3" stroke="#fff" stroke-width="1.4"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.8691;0.9318" calcMode="discrete" dur="22s" repeatCount="indefinite"/><animateMotion path="M503,157 L503,53 L238,53 L238,157" keyPoints="0;0;1;1" keyTimes="0;0.8691;0.9318;1" calcMode="linear" dur="22s" repeatCount="indefinite"/><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g>
<g class="dfa-move" opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.94;0.9918" calcMode="discrete" dur="22s" repeatCount="indefinite"/><animateMotion path="M238,157 L66,157" keyPoints="0;0;1;1" keyTimes="0;0.94;0.9918;1" calcMode="linear" dur="22s" repeatCount="indefinite"/><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g>
<g font-size="10.5" class="dg-muted"><g transform="translate(20.4,334.5) scale(.8)"><circle r="7" fill="#6366f1" stroke="#fff" stroke-width="2"/></g><text x="31.8" y="338">request</text><g transform="translate(93.4,334.5) scale(.8)"><circle r="6.5" fill="#0d9488" stroke="#fff" stroke-width="2"/></g><text x="104.8" y="338">data</text><g transform="translate(150.4,334.5) scale(.8)"><g><circle cx="-4" r="5" fill="#eab308" stroke="#fff" stroke-width="1.6"/><rect x="0" y="-2" width="10" height="4" rx="1" fill="#eab308" stroke="#fff" stroke-width="1.2"/></g></g><text x="163.4" y="338">data key</text><g transform="translate(232.2,334.5) scale(.8)"><g><rect x="-9" y="-6" width="18" height="12" rx="2" fill="#db2777" stroke="#fff" stroke-width="1.6"/><path d="M-8,-5 L0,1 L8,-5" fill="none" stroke="#fff" stroke-width="1.4"/></g></g><text x="245.2" y="338">encrypted data key</text><g transform="translate(369.2,334.5) scale(.8)"><rect x="-8" y="-7" width="16" height="14" rx="3" fill="#f97316" stroke="#fff" stroke-width="2"/></g><text x="381.4" y="338">encrypted file</text><g transform="translate(483,334.5) scale(.8)"><g><rect x="-8" y="-6" width="16" height="12" rx="2" fill="#64748b" stroke="#fff" stroke-width="1.6"/><path d="M-5,-2 H5 M-5,2 H3" stroke="#fff" stroke-width="1.4"/></g></g><text x="495.2" y="338">log entry</text></g>
<rect x="12" y="350" width="576" height="56" rx="10" class="dg-box" stroke="#94a3b8" stroke-opacity=".45"/><rect x="12" y="350" width="0" height="3" rx="1.5" fill="#94a3b8"><animate attributeName="width" values="0;576" dur="22s" repeatCount="indefinite"/></rect><g opacity="1"><animate attributeName="opacity" values="1;0" keyTimes="0;0.1182" calcMode="discrete" dur="22s" repeatCount="indefinite"/><circle cx="36" cy="378" r="14" fill="#6366f1"/><text x="36" y="383" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">1</text><text x="60" y="373" font-size="14" font-weight="800" fill="#6366f1">The app asks KMS for a data key</text><text x="578" y="373" text-anchor="end" font-size="10.5" class="dg-muted">Encrypt and store · 1/8</text><text x="60" y="394" font-size="12.5" class="dg-text">It calls GenerateDataKey on alias/app-data, asking for an AES_256 key.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.1182;0.2455" calcMode="discrete" dur="22s" repeatCount="indefinite"/><circle cx="36" cy="378" r="14" fill="#6366f1"/><text x="36" y="383" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">2</text><text x="60" y="373" font-size="14" font-weight="800" fill="#6366f1">KMS returns the same key twice</text><text x="578" y="373" text-anchor="end" font-size="10.5" class="dg-muted">Encrypt and store · 2/8</text><text x="60" y="394" font-size="12.5" class="dg-text">Once in plain form, and once encrypted under the KMS key.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.2455;0.3727" calcMode="discrete" dur="22s" repeatCount="indefinite"/><circle cx="36" cy="378" r="14" fill="#6366f1"/><text x="36" y="383" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">3</text><text x="60" y="373" font-size="14" font-weight="800" fill="#6366f1">The app encrypts the data locally</text><text x="578" y="373" text-anchor="end" font-size="10.5" class="dg-muted">Encrypt and store · 3/8</text><text x="60" y="394" font-size="12.5" class="dg-text">It uses the plaintext key, then wipes it from memory.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.3727;0.5" calcMode="discrete" dur="22s" repeatCount="indefinite"/><circle cx="36" cy="378" r="14" fill="#6366f1"/><text x="36" y="383" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">4</text><text x="60" y="373" font-size="14" font-weight="800" fill="#6366f1">Both are stored together in S3</text><text x="578" y="373" text-anchor="end" font-size="10.5" class="dg-muted">Encrypt and store · 4/8</text><text x="60" y="394" font-size="12.5" class="dg-text">big-file.enc sits next to big-file.key.enc. The plaintext key is gone.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.5;0.6182" calcMode="discrete" dur="22s" repeatCount="indefinite"/><circle cx="36" cy="378" r="14" fill="#0891b2"/><text x="36" y="383" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">5</text><text x="60" y="373" font-size="14" font-weight="800" fill="#0891b2">Later, the app reads the file back</text><text x="578" y="373" text-anchor="end" font-size="10.5" class="dg-muted">Read it back · 5/8</text><text x="60" y="394" font-size="12.5" class="dg-text">It can&#x27;t decrypt yet: the data key it needs is still encrypted.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.6182;0.7364" calcMode="discrete" dur="22s" repeatCount="indefinite"/><circle cx="36" cy="378" r="14" fill="#0891b2"/><text x="36" y="383" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">6</text><text x="60" y="373" font-size="14" font-weight="800" fill="#0891b2">It asks KMS to Decrypt the small key</text><text x="578" y="373" text-anchor="end" font-size="10.5" class="dg-muted">Read it back · 6/8</text><text x="60" y="394" font-size="12.5" class="dg-text">Only the encrypted data key goes to KMS, never the big file.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1;0" keyTimes="0;0.7364;0.8636" calcMode="discrete" dur="22s" repeatCount="indefinite"/><circle cx="36" cy="378" r="14" fill="#0891b2"/><text x="36" y="383" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">7</text><text x="60" y="373" font-size="14" font-weight="800" fill="#0891b2">KMS checks permissions and logs it</text><text x="578" y="373" text-anchor="end" font-size="10.5" class="dg-muted">Read it back · 7/8</text><text x="60" y="394" font-size="12.5" class="dg-text">The key policy and IAM must allow kms:Decrypt. CloudTrail records the call.</text></g><g opacity="0"><animate attributeName="opacity" values="0;1" keyTimes="0;0.8636" calcMode="discrete" dur="22s" repeatCount="indefinite"/><circle cx="36" cy="378" r="14" fill="#0891b2"/><text x="36" y="383" text-anchor="middle" font-size="13" font-weight="800" fill="#fff">8</text><text x="60" y="373" font-size="14" font-weight="800" fill="#0891b2">The plaintext key comes back</text><text x="578" y="373" text-anchor="end" font-size="10.5" class="dg-muted">Read it back · 8/8</text><text x="60" y="394" font-size="12.5" class="dg-text">The app decrypts big-file locally. The KMS key itself never left KMS.</text></g>
</svg>
```

### A real-life comparison

| Bank | KMS |
|---|---|
| The master key that never leaves the vault | **KMS key** (stored in hardware security modules) |
| The list of people allowed to use it | **Key policy** plus IAM policies |
| A small lockbox key you're allowed to take home, delivered sealed | A **data key**, returned both in plain form and encrypted by the KMS key |
| The visitor logbook | **CloudTrail**: every Encrypt, Decrypt and GenerateDataKey call |
| Changing the lock every year | **Key rotation** |

### Key words

| Word | Simple meaning |
|---|---|
| **KMS key** | The main key inside KMS. It never leaves KMS unencrypted |
| **Customer managed key** | A key **you** create and control: policy, rotation, deletion |
| **AWS managed key** | A key AWS creates for a service in your account, such as `aws/s3` |
| **Alias** | A friendly name, such as `alias/app-data`, pointing to a key ID |
| **Key policy** | The key's own permission document. **Every key has exactly one** |
| **Data key** | A key KMS generates for you to encrypt large data locally |
| **Envelope encryption** | Encrypt data with a data key, then encrypt the data key with the KMS key |
| **Encryption context** | Extra non-secret labels that must match at decrypt time, like a second password |

### Check yourself

1. Can you download a KMS key to your laptop?
2. Why do services use data keys instead of sending all data to KMS?
3. Where can you see who used a key?

> **Tip:** Answers: 1) No. KMS keys never leave KMS unencrypted. 2) KMS encrypts at most 4 KB per call, and sending gigabytes over the network would be slow, so services encrypt locally with a data key. 3) In CloudTrail.

## Key types

> **In simple words:** There are three owners of keys (AWS owns it, AWS manages it in your account, or you manage it) and a few kinds of key (symmetric for encryption, asymmetric for signing, HMAC for message checks).

### Who owns and manages the key

| Type | Example | You can see it? | You control policy, rotation, deletion? | Monthly fee |
|---|---|---|---|---|
| **AWS owned** | Default S3 (SSE-S3) or DynamoDB encryption | No | No | Free |
| **AWS managed** | `aws/s3`, `aws/ebs`, `aws/secretsmanager` | Yes | No (rotated yearly by AWS) | Free |
| **Customer managed** | `alias/app-data` | Yes | **Yes** | ~$1 |

Use a **customer managed key** when you need your own access rules (for example, "only the payments role may decrypt"), cross-account access, your own rotation schedule, or the ability to disable a key in an emergency.

### What kind of key

| Spec | Used for |
|---|---|
| `SYMMETRIC_DEFAULT` (AES-256) | Encrypting data. **What you'll use 95% of the time**; AWS services require it |
| RSA / ECC (asymmetric) | Signing and verifying, or encryption where the public key is shared outside AWS |
| HMAC | Creating and verifying message authentication codes (tamper checks) |

AWS docs: [AWS KMS keys](https://docs.aws.amazon.com/kms/latest/developerguide/concepts.html) · [What is AWS KMS?](https://docs.aws.amazon.com/kms/latest/developerguide/overview.html)

## Create a key and an alias

> **In simple words:** Create one customer managed key, give it a readable name (alias), and say who may administer it and who may use it.

### Console

1. **KMS → Customer managed keys → Create key**.
2. **Symmetric**, **Encrypt and decrypt**, then **Next**.
3. **Alias:** `app-data`. Add a description and tags (`team`, `env`).
4. **Key administrators:** your admin role. Admins manage the key but can't use it to decrypt.
5. **Key users:** the roles that may encrypt and decrypt with it.
6. Review the generated **key policy**, then **Finish**.

### CLI

```bash
KEY_ID=$(aws kms create-key \
  --description "App data encryption key" \
  --tags TagKey=team,TagValue=platform TagKey=env,TagValue=lab \
  --query KeyMetadata.KeyId --output text)

aws kms create-alias --alias-name alias/app-data --target-key-id $KEY_ID

aws kms describe-key --key-id alias/app-data \
  --query 'KeyMetadata.[KeyId,KeyState,KeySpec,KeyManager,Arn]' --output table
aws kms list-aliases --query "Aliases[?starts_with(AliasName,'alias/app')]"
```

Without `--policy`, the key gets the **default key policy**: the account (root) has full access, which means **IAM policies** in this account decide who can use the key.

## Encrypt and decrypt small secrets

> **In simple words:** For small data (up to 4 KB), such as a password or token, send it to KMS and get back an encrypted blob. Only someone allowed to use the key can turn it back into plaintext.

```bash
echo -n "db-password-123" > secret.txt

# Encrypt → binary ciphertext file
aws kms encrypt --key-id alias/app-data \
  --plaintext fileb://secret.txt \
  --encryption-context app=billing \
  --query CiphertextBlob --output text | base64 --decode > secret.enc

xxd secret.enc | head -3        # unreadable bytes; it also records which key was used

# Decrypt → original text (no key ID needed for symmetric keys)
aws kms decrypt --ciphertext-blob fileb://secret.enc \
  --encryption-context app=billing \
  --query Plaintext --output text | base64 --decode; echo
```

Try decrypting **without** `--encryption-context`: it fails with `InvalidCiphertextException`. The context must match exactly, and it appears in CloudTrail, which makes logs much more useful.

> **Tip:** For storing application secrets, use **AWS Secrets Manager** or **SSM Parameter Store (SecureString)**. Both use KMS underneath and add versioning, rotation and an easy API.

## Envelope encryption with data keys

> **In simple words:** To encrypt a big file, KMS gives you a fresh **data key** twice: once in plain form (use it, then throw it away) and once encrypted (store it next to the data). To read the file later, ask KMS to decrypt the small encrypted key. This is how S3, EBS and most AWS services encrypt your data.

```text
            GenerateDataKey
 KMS key ─────────────────────▶  plaintext data key  ──encrypt──▶  big-file.enc
 (never leaves KMS)              encrypted data key  ──store────▶  big-file.key.enc
                                 (forget the plaintext key after use)

 To read:  Decrypt(big-file.key.enc) → plaintext data key → decrypt big-file.enc
```

Try the KMS part:

```bash
aws kms generate-data-key --key-id alias/app-data --key-spec AES_256 \
  --query '{PlaintextKey:Plaintext,EncryptedKey:CiphertextBlob}' > datakey.json
jq -r .EncryptedKey datakey.json | base64 --decode > datakey.enc

# Later: recover the plaintext data key from the stored encrypted copy
aws kms decrypt --ciphertext-blob fileb://datakey.enc --query Plaintext --output text
jq -r .PlaintextKey datakey.json        # same value

rm datakey.json                          # never keep the plaintext data key on disk
```

Why this design matters:
- Large data is encrypted **locally and quickly**. Only a tiny key goes over the network to KMS.
- **Revoking access to the KMS key** makes every encrypted data key, and so all the data, unreadable.
- Real apps use the **AWS Encryption SDK**, which does all of this correctly for you.

## Key policies, IAM policies and grants

> **In simple words:** A KMS key checks **its own key policy first**. The default policy says "trust IAM in this account", so IAM policies then decide. For stricter control, name the allowed roles directly in the key policy.

View the current key policy:

```bash
aws kms get-key-policy --key-id $KEY_ID --policy-name default --output text | jq .
```

A tighter key policy: admins manage it, only the `billing-app` role uses it, and AWS services may use it on that role's behalf. Save as `key-policy.json`, replacing `111122223333`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EnableRootAccountAccess",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::111122223333:root" },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "AllowKeyAdministration",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::111122223333:role/platform-admin" },
      "Action": ["kms:Describe*", "kms:List*", "kms:Get*", "kms:Put*", "kms:Update*", "kms:Enable*",
                 "kms:Disable*", "kms:TagResource", "kms:UntagResource", "kms:ScheduleKeyDeletion",
                 "kms:CancelKeyDeletion", "kms:RotateKeyOnDemand"],
      "Resource": "*"
    },
    {
      "Sid": "AllowUseByBillingApp",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::111122223333:role/billing-app" },
      "Action": ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"],
      "Resource": "*"
    },
    {
      "Sid": "AllowAwsServicesForBillingApp",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::111122223333:role/billing-app" },
      "Action": ["kms:CreateGrant", "kms:ListGrants", "kms:RevokeGrant"],
      "Resource": "*",
      "Condition": { "Bool": { "kms:GrantIsForAWSResource": "true" } }
    }
  ]
}
```

```bash
aws kms put-key-policy --key-id $KEY_ID --policy-name default --policy file://key-policy.json
```

> **Warning:** Keep the first statement (account root access) unless you really know what you're doing. A key policy that locks out every admin makes the key unmanageable, and only AWS Support can help.

In a key policy, `"Resource": "*"` means "this key".

| Mechanism | Use |
|---|---|
| **Key policy** | The primary control, and required. Needed for cross-account access |
| **IAM policy** | Works only if the key policy trusts the account (as the default policy does) |
| **Grant** | Temporary, narrow permissions. AWS services such as EBS and RDS create them automatically |

AWS docs: [Key policies](https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html) · [Grants](https://docs.aws.amazon.com/kms/latest/developerguide/grants.html)

## Use KMS with AWS services

> **In simple words:** You rarely call KMS directly. Instead you tell S3, EBS, Secrets Manager or EKS "use this key", and they handle the encryption.

### S3: default encryption with your key

```bash
aws s3api put-bucket-encryption --bucket my-bucket --server-side-encryption-configuration '{
  "Rules": [{ "ApplyServerSideEncryptionByDefault": { "SSEAlgorithm": "aws:kms", "KMSMasterKeyID": "alias/app-data" },
              "BucketKeyEnabled": true }]
}'
```

A **Bucket Key** makes S3 call KMS far less often, which cuts cost. More detail is in the [S3 guide](#/tool/aws-s3).

### EBS: encrypt every new disk in the Region

```bash
aws ec2 enable-ebs-encryption-by-default
aws ec2 modify-ebs-default-kms-key-id --kms-key-id alias/app-data
aws ec2 get-ebs-encryption-by-default
```

### Secrets Manager: store a secret with your key

```bash
aws secretsmanager create-secret --name billing/db-password \
  --secret-string 'db-password-123' --kms-key-id alias/app-data
aws secretsmanager get-secret-value --secret-id billing/db-password --query SecretString --output text
```

### EKS

EKS encrypts Kubernetes API data, including Secrets, with KMS envelope encryption by default. You can supply your **own** customer managed key when creating the cluster if you need to control it.

AWS docs: [EKS default envelope encryption](https://docs.aws.amazon.com/eks/latest/userguide/envelope-encryption.html)

## Key rotation

> **In simple words:** Rotation gives the key new cryptographic material on a schedule. Old data still decrypts (KMS keeps every old version), new data uses the new material, and your apps change nothing.

```bash
aws kms enable-key-rotation --key-id $KEY_ID --rotation-period-in-days 365   # 90 to 2560 days
aws kms get-key-rotation-status --key-id $KEY_ID
aws kms rotate-key-on-demand --key-id $KEY_ID           # rotate right now (limited number per key)
aws kms list-key-rotations --key-id $KEY_ID
```

- The key ID, ARN and alias stay the same, so nothing in your apps changes.
- Rotation does **not** re-encrypt existing data. It doesn't need to.
- Automatic rotation is for **symmetric** keys. AWS managed keys rotate every year automatically.

AWS docs: [Rotate KMS keys](https://docs.aws.amazon.com/kms/latest/developerguide/rotate-keys.html)

## Disable and delete keys safely

> **In simple words:** Deleting a KMS key is **permanent**, and everything encrypted with it becomes unreadable forever. So KMS forces a waiting period, and you should disable the key first to see whether anything breaks.

```bash
# 1. Disable (reversible): any use now fails
aws kms disable-key --key-id $KEY_ID
aws kms enable-key --key-id $KEY_ID          # undo

# 2. Schedule deletion: waiting period of 7–30 days (default 30)
aws kms schedule-key-deletion --key-id $KEY_ID --pending-window-in-days 7
aws kms describe-key --key-id $KEY_ID --query 'KeyMetadata.[KeyState,DeletionDate]'

# Changed your mind?
aws kms cancel-key-deletion --key-id $KEY_ID && aws kms enable-key --key-id $KEY_ID
```

> **Tip:** During the waiting period, watch CloudTrail for failed `Decrypt` calls using the key, and set a CloudWatch alarm on them. Any hit means something still needs the key, so cancel the deletion.

**Multi-Region keys** are copies of one key in several Regions, so data encrypted in one Region can be decrypted in another (useful for disaster recovery and global apps).

AWS docs: [Delete a KMS key](https://docs.aws.amazon.com/kms/latest/developerguide/deleting-keys.html) · [Multi-Region keys](https://docs.aws.amazon.com/kms/latest/developerguide/multi-region-keys-overview.html)

## Troubleshooting

> **In simple words:** Most KMS errors mean "you're not on this key's list", "the key is disabled", or "the extra labels (encryption context) don't match".

| Error | Likely cause / fix |
|---|---|
| `AccessDeniedException … kms:Decrypt` | The caller's role isn't allowed by the key policy or IAM. Reading SSE-KMS S3 objects needs `kms:Decrypt` too |
| `KMSInvalidStateException` / `DisabledException` | The key is disabled or pending deletion |
| `InvalidCiphertextException` | Wrong or missing encryption context, a corrupted blob, or the ciphertext isn't binary (decode the base64 first) |
| `NotFoundException` for an alias | Wrong Region: keys and aliases are Regional |
| Cross-account access denied | Needs **both** the key policy in the key's account **and** an IAM policy in the caller's account |
| Throttling (`ThrottlingException`) | Too many requests. Enable S3 Bucket Keys, or cache data keys |

Check who used the key, in **CloudTrail → Event history → Event source `kms.amazonaws.com`**.

## Lab: protect application data with your own key

> **In simple words:** Practice time: create a key, use it to protect a file, a bucket and a secret, then prove that removing access makes the data unreadable.

1. Create a customer managed key `alias/lab-data` with rotation every **180 days**.
2. Encrypt and decrypt a short text with encryption context `env=lab`. Show that decrypting without the context fails.
3. Set it as the default encryption key for a test S3 bucket, with a Bucket Key. Upload a file and confirm with `head-object`.
4. Store a secret in Secrets Manager using the key.
5. **Disable** the key: downloading the S3 object and reading the secret now fail. Re-enable it, and both work again.
6. Find your Encrypt and Decrypt calls in CloudTrail.
7. Clean up: delete the secret (`--force-delete-without-recovery`), empty and delete the bucket, then schedule the key for deletion with a 7-day window.

### Cheat sheet

| Task | Command |
|---|---|
| Create key + alias | `aws kms create-key` / `aws kms create-alias --alias-name alias/x --target-key-id ID` |
| Encrypt file | `aws kms encrypt --key-id alias/x --plaintext fileb://f --query CiphertextBlob --output text \| base64 -d > f.enc` |
| Decrypt file | `aws kms decrypt --ciphertext-blob fileb://f.enc --query Plaintext --output text \| base64 -d` |
| Data key | `aws kms generate-data-key --key-id alias/x --key-spec AES_256` |
| Rotation | `aws kms enable-key-rotation --key-id ID --rotation-period-in-days 365` |
| See policy | `aws kms get-key-policy --key-id ID --policy-name default` |
| Delete (7-day wait) | `aws kms schedule-key-deletion --key-id ID --pending-window-in-days 7` |
