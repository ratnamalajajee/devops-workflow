# DevOps Launchpad

A self-paced learning site for new joiners and learners. It takes you from a blank laptop to GitOps on Kubernetes:

**Workstation Setup → Linux → Docker → AWS → Terraform → Kubernetes → Argo CD → Capstone**

Features:
- Step-by-step guides with copy buttons on every command
- Progress tracking per step, saved in the browser
- Full-text search (press `/`)
- Light and dark themes, works on mobile
- No build step and no dependencies: plain HTML, CSS and JavaScript, with guides written in Markdown

## Run locally

The guides are fetched as Markdown files, so serve the folder over HTTP. Opening `index.html` directly won't work.

```bash
python -m http.server 8080
# or: npx serve -l 8080 .
```

Open http://localhost:8080.

## Run with Docker

```bash
docker build -t devops-launchpad .
docker run -d -p 8080:80 --name launchpad devops-launchpad
```

## Deploy to Cloudflare Pages (HTTPS)

The site is connected to Cloudflare Pages through Git, so every push to `main` redeploys it automatically.

1. Cloudflare dashboard → **Workers & Pages** → **Create** → **Pages** → **Connect to Git**, then pick this repo.
2. Build settings: **Framework preset** `None`, **Build command** empty, **Build output directory** `/`.
3. **Save and Deploy**. The site goes live at `https://<project>.pages.dev` with HTTPS included.
4. Optional: **Custom domains** → add `devops.yourdomain.com`.

Response headers (caching and security) are set in `_headers`.

## Login and logout (Cloudflare Access)

Sign-in is handled by Cloudflare Access in front of the site, so nobody can reach the pages or guides without logging in. The site itself does three things:

- When someone is signed in, it shows their email and a **Log out** button (`/cdn-cgi/access/logout`).
- It saves progress separately for each user (`dl-progress:<email>`).
- With no Access in front of it (for example on `localhost`), it hides the user chip and works as before.

To turn it on:

1. Cloudflare dashboard → **Zero Trust**. The first time, pick a team name and the **Free** plan (up to 50 users).
2. **Settings → Authentication → Login methods**: keep **One-time PIN** (a code sent by email). Optionally add Google, GitHub or Microsoft Entra ID.
3. Protect the site:
   - **Pages:** project → **Settings → General → Access policy → Enable**, then edit the policy.
   - **Worker:** worker → **Settings → Domains & Routes** → enable **Cloudflare Access** on the `workers.dev` route.
4. In the policy, choose who can log in. Use a rule **Emails ending in** `@yourcompany.com`, or **Emails** to list specific people.

Logged-out visitors now see the Cloudflare login page before the site loads.

## Practice lab

The **Practice lab** page (`#/lab`) gives learners two places to run commands:

1. **Linux in the browser.** The [v86](https://github.com/copy/v86) x86 emulator (WebAssembly) boots a small Buildroot Linux 6.8 + BusyBox system inside the tab, shown through [xterm.js](https://xtermjs.org). Nothing runs on a server, and each learner's machine is private and resets on reload. All files are self-hosted in `assets/vm/` (about 13 MB, cached for a week by `_headers`). The pinned versions are v86 0.5.465, xterm.js 5.3.0 and SeaBIOS from v86 commit `b8a39b1`. The licenses are next to the files.
2. **Full lab machine (GitHub Codespaces).** The **Open lab machine** button opens this repo in Codespaces using `.devcontainer/`: Ubuntu 24.04 with Docker, kind, kubectl, Helm, Terraform, AWS CLI, eksctl and the Argo CD CLI. Each learner gets their own machine, which uses their personal GitHub free quota. The button reads the repo from `repo` in `assets/js/config.js`.

## Project structure

```text
index.html              # app shell
assets/css/style.css    # styles (light/dark tokens at the top)
assets/js/config.js     # learning path: order, titles, colors, estimates
assets/js/markdown.js   # tiny Markdown renderer
assets/js/app.js        # routing, progress, search, copy buttons
assets/vm/              # in-browser Linux: v86 emulator, BIOS, kernel image, xterm.js
content/*.md            # one guide per tool  <-- edit these
.devcontainer/          # GitHub Codespaces lab machine
Dockerfile, nginx.conf  # container hosting
```

## Editing and adding guides

Each guide is a Markdown file in `content/`:

- `# Title` on the first line, followed by an intro paragraph.
- Every `## Heading` becomes a numbered **step** with its own "Done" checkbox. Don't start lines inside code blocks with `## `.
- Supported: `###` subheadings, lists, tables, fenced code blocks (with a language such as `bash` or `yaml`), `inline code`, **bold**, links.
- Callouts: start a blockquote with `> **Tip:**`, `> **Note:**`, `> **Warning:**`, `> **Cost:**` or `> **Why:**`.
- Write a literal `|` inside a table cell as `\|`.

To add a new tool (for example Jenkins), create `content/jenkins.md` and add an entry to `assets/js/config.js`:

```js
{ id: 'jenkins', title: 'Jenkins', badge: 'JK', color: '#d33833', level: 'Intermediate', hours: 6, desc: 'CI pipelines…' }
```

Its position in the array sets its place on the roadmap.

> Renaming a `##` heading resets that step's saved progress for learners, because progress is keyed by heading.
