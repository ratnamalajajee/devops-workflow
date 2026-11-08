# Create Your AWS Account

Never used AWS before? This guide walks you through **opening your own AWS account**, screen by screen: choosing the right sign-up, the **Free or Paid plan**, card and phone checks (including the extra step for **India**), then the four things to do in your first 15 minutes: **lock the root user with MFA, set a budget alert, create an admin user, and connect the AWS CLI**.

> **Cost:** Creating an account is **free**. New accounts get **USD $100 in credits** at sign-up and can earn **up to $100 more**. On the **Free plan** you are never charged; on the **Paid plan** you pay only for usage beyond your credits. Either way, set the budget alert in Step 9. See [AWS Free Tier](https://aws.amazon.com/free/).

## Start here: an AWS account in simple words

> **In simple words:** An AWS account is like **opening a bank account for cloud resources**. You prove who you are (email, phone, card), you get a **master key** (the **root user**), and from then on everything you create (servers, buckets, clusters) lives inside that account and is billed to it. The first thing you do with a master key is lock it away and make yourself a normal key for everyday use.

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
