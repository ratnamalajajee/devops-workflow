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

## Project structure

```text
index.html              # app shell
assets/css/style.css    # styles (light/dark tokens at the top)
assets/js/config.js     # learning path: order, titles, colors, estimates
assets/js/markdown.js   # tiny Markdown renderer
assets/js/app.js        # routing, progress, search, copy buttons
content/*.md            # one guide per tool  <-- edit these
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
