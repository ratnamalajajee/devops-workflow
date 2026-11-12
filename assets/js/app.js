(function () {
  const TOOLS = window.DEVOPS_CONFIG.tools;
  const { render, esc } = window.Markdown;
  const $ = (s, el = document) => el.querySelector(s);
  const main = $('#main'), sidebar = $('#sidebar'), toc = $('#toc');
  const guides = {};          // id -> parsed guide
  let loadError = null;

  // ---------- storage (progress + theme), safe if storage is blocked ----------
  const store = {
    get(k, d) { try { const v = localStorage.getItem(k); return v ? JSON.parse(v) : d; } catch (e) { return d; } },
    set(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (e) { /* ignore */ } }
  };
  let progress = store.get('dl-progress', {});
  const doneSet = (id) => new Set(progress[id] || []);
  function setDone(id, slug, on) {
    const s = doneSet(id);
    on ? s.add(slug) : s.delete(slug);
    progress[id] = [...s];
    store.set('dl-progress', progress);
  }
  function pct(id) {
    const g = guides[id];
    if (!g || !g.sections.length) return 0;
    const s = doneSet(id);
    return Math.round(100 * g.sections.filter((x) => s.has(x.slug)).length / g.sections.length);
  }

  // ---------- theme ----------
  const theme = store.get('dl-theme', null);
  if (theme) document.documentElement.dataset.theme = theme;
  $('#themeBtn').addEventListener('click', () => {
    const dark = document.documentElement.dataset.theme
      ? document.documentElement.dataset.theme === 'dark'
      : matchMedia('(prefers-color-scheme: dark)').matches;
    document.documentElement.dataset.theme = dark ? 'light' : 'dark';
    store.set('dl-theme', document.documentElement.dataset.theme);
  });

  // ---------- content loading ----------
  const slugify = (s) => s.toLowerCase().replace(/`/g, '').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

  function parse(id, text) {
    const parts = text.replace(/\r/g, '').split(/^## /m);
    const head = parts.shift();
    const title = (head.match(/^# (.+)$/m) || [])[1] || id;
    const intro = head.replace(/^# .+$/m, '').trim();
    const sections = parts.map((p) => {
      const nl = p.indexOf('\n');
      const t = (nl === -1 ? p : p.slice(0, nl)).trim();
      const body = nl === -1 ? '' : p.slice(nl + 1);
      // search text: body without inline SVG drawings
      return { title: t, slug: slugify(t), body, text: body.replace(/^```svg[^\n]*\n[\s\S]*?^```/gm, '') };
    });
    return { id, title, intro, sections };
  }

  async function loadAll() {
    await Promise.all(TOOLS.map(async (t) => {
      try {
        const res = await fetch('content/' + t.id + '.md', { cache: 'no-cache' });
        if (!res.ok) throw new Error('HTTP ' + res.status);
        guides[t.id] = parse(t.id, await res.text());
      } catch (e) {
        loadError = e;
      }
    }));
  }

  // ---------- author ----------
  const AUTHOR = window.DEVOPS_CONFIG.author || {};
  const authorLink = () => AUTHOR.url
    ? `<a href="${esc(AUTHOR.url)}" target="_blank" rel="noopener author">${esc(AUTHOR.name)}</a>`
    : esc(AUTHOR.name || '');
  const byline = (cls) => AUTHOR.name ? `<p class="byline ${cls || ''}">✍️ Created by ${authorLink()}</p>` : '';
  function footerHtml() {
    return `
      <footer class="site-footer">
        ${AUTHOR.name ? `<p>Created and maintained by <strong>${authorLink()}</strong></p>` : ''}
        <p>© ${new Date().getFullYear()} DevOps Launchpad</p>
      </footer>`;
  }

  // ---------- sections ----------
  const SECTIONS = window.DEVOPS_CONFIG.sections || {};
  const sectionOf = (name) => SECTIONS[name] || { color: 'var(--accent)', icon: '📘' };

  // Consecutive tools with the same `section` form one group, keeping their path index.
  function groupTools() {
    const groups = [];
    TOOLS.forEach((t, i) => {
      const last = groups[groups.length - 1];
      if (!last || last.name !== t.section) groups.push({ name: t.section || 'Learning path', items: [] });
      groups[groups.length - 1].items.push({ t, i });
    });
    return groups;
  }

  // ---------- sidebar ----------
  // Sections are collapsible and start collapsed. navOpen remembers only sections the
  // reader opened by clicking. The section of the guide being read is shown open for that
  // page only (not saved), unless the reader collapses it (activeCollapsed, reset per route).
  const navOpen = store.get('dl-nav-open-v2', {});
  const saveNavOpen = () => store.set('dl-nav-open-v2', navOpen);
  let activeCollapsed = false;

  function renderSidebar(activeId) {
    sidebar.innerHTML =
      `<a href="#/" class="nav-home ${!activeId ? 'active' : ''}">🏠 Home</a>` +
      `<a href="#/roadmap" class="nav-home ${activeId === 'roadmap' ? 'active' : ''}">🧭 How to start: roadmap</a>` +
      `<a href="#/lab" class="nav-home ${activeId === 'lab' ? 'active' : ''}">🖥️ Practice lab</a>` +
      `<a href="multicloud/" class="nav-home" title="Every NextGen service on AWS, Azure and GCP: console steps, CLI and docs">🌐 AWS · Azure · GCP runbook</a>` +
      groupTools().map((g) => {
        const sec = sectionOf(g.name);
        const hasActive = g.items.some(({ t }) => t.id === activeId);
        const open = hasActive ? !activeCollapsed : !!navOpen[g.name];
        return `
        <div class="nav-group ${open ? 'open' : ''} ${hasActive ? 'has-active' : ''}" data-section="${esc(g.name)}" style="--s:${sec.color}">
          <button type="button" class="nav-label" aria-expanded="${open}">
            <span class="nav-label-text" title="${esc(g.name)}">${sec.icon} ${esc(sec.short || g.name)}</span>
            <span class="nav-line" aria-hidden="true"></span>
            <span class="nav-count" title="${g.items.length} guides">${g.items.length}</span>
            <span class="nav-chevron" aria-hidden="true">›</span>
          </button>
          <div class="nav-group-items"><div>
            ${g.items.map(({ t, i }) => `
            <a href="#/tool/${t.id}" class="nav-item ${t.id === activeId ? 'active' : ''}" style="--c:${t.color}">
              <span class="badge" style="--c:${t.color}">${esc(t.badge)}</span>
              <span class="nav-text"><span class="nav-title">${i}. ${esc(t.title)}</span>
              <span class="mini-bar"><span style="width:${pct(t.id)}%"></span></span></span>
              <span class="nav-pct">${pct(t.id)}%</span>
            </a>`).join('')}
          </div></div>
        </div>`;
      }).join('');
  }

  sidebar.addEventListener('click', (e) => {
    const btn = e.target.closest('.nav-label');
    if (!btn) return;
    const group = btn.closest('.nav-group');
    const open = !group.classList.contains('open');
    group.classList.toggle('open', open);
    btn.setAttribute('aria-expanded', String(open));
    if (group.classList.contains('has-active')) {
      activeCollapsed = !open;                 // current guide's section: this page only
    } else {
      navOpen[group.dataset.section] = open;   // other sections: remembered
      saveNavOpen();
    }
  });

  // ---------- pages ----------
  function renderHome() {
    const total = TOOLS.reduce((a, t) => a + (guides[t.id] ? guides[t.id].sections.length : 0), 0);
    const done = TOOLS.reduce((a, t) => a + (guides[t.id] ? guides[t.id].sections.filter((s) => doneSet(t.id).has(s.slug)).length : 0), 0);
    const overall = total ? Math.round(100 * done / total) : 0;
    const next = TOOLS.find((t) => guides[t.id] && pct(t.id) < 100) || TOOLS[0];
    const hours = TOOLS.reduce((a, t) => a + t.hours, 0);

    main.innerHTML = `
      <section class="hero">
        <p class="eyebrow">Onboarding · Self-paced · Hands-on</p>
        <h1>Learn DevOps from a blank laptop to GitOps on Kubernetes.</h1>
        <p class="lead">Follow the path in order. Every guide starts from scratch, explains <em>why</em> before <em>how</em>,
          and every command has a copy button. Tick off steps as you go — your progress is saved in this browser.</p>
        ${byline('hero-byline')}
        <div class="hero-actions">
          <a class="btn primary" href="#/tool/${next.id}">${overall ? 'Continue' : 'Start'}: ${esc(next.title)} →</a>
          <a class="btn" href="#/tool/capstone">See the final project</a>
        </div>
        <div class="stats">
          <div style="--c:#6366f1"><strong>${TOOLS.length}</strong><span>📚 guides</span></div>
          <div style="--c:#ec4899"><strong>${total}</strong><span>🪜 steps</span></div>
          <div style="--c:#f59e0b"><strong>~${hours}h</strong><span>⏱️ total effort</span></div>
          <div style="--c:#10b981"><strong>${overall}%</strong><span>🎯 your progress</span></div>
        </div>
      </section>

      ${ROADMAP.length ? `
      <h2 class="section-title">🧭 How to start DevOps</h2>
      ${flowStrip()}
      <p class="rm-more"><a href="#/roadmap">See the full roadmap: what to learn at each stage and when you're ready to move on →</a></p>` : ''}

      <h2 class="section-title">📚 All guides, in order</h2>
      ${groupTools().map((g) => `
        <div class="road-group" style="--s:${sectionOf(g.name).color}">
          <h3 class="road-group-title"><span class="road-group-icon">${sectionOf(g.name).icon}</span>${esc(g.name)}</h3>
          <ol class="roadmap">
            ${g.items.map(({ t, i }) => `
              <li class="road-card" style="--c:${t.color}">
                <a href="#/tool/${t.id}">
                  <div class="road-top">
                    <span class="badge big" style="--c:${t.color}">${esc(t.badge)}</span>
                    <span class="step-chip">Step ${i}</span>
                  </div>
                  <h3>${esc(t.title)}</h3>
                  <p>${esc(t.desc)}</p>
                  <div class="road-meta"><span>${esc(t.level)}</span><span>~${t.hours}h</span>
                    <span>${guides[t.id] ? guides[t.id].sections.length + ' steps' : ''}</span></div>
                  <div class="bar"><span style="width:${pct(t.id)}%"></span></div>
                </a>
              </li>`).join('')}
          </ol>
        </div>`).join('')}

      <h2 class="section-title">🧭 How to use this site</h2>
      <div class="howto">
        <div style="--c:#6366f1"><span class="howto-icon">🛠️</span><h3>1 · Set up once</h3><p>Do <a href="#/tool/setup">Workstation Setup</a> first. Every later guide assumes a Linux shell (WSL2 on Windows) with the CLIs installed.</p></div>
        <div style="--c:#ec4899"><span class="howto-icon">⌨️</span><h3>2 · Type, don't just read</h3><p>Run every command yourself, on your machine or in the <a href="#/lab">Practice lab</a>. Break things on purpose, then use the troubleshooting sections to fix them.</p></div>
        <div style="--c:#10b981"><span class="howto-icon">🧪</span><h3>3 · Finish each lab</h3><p>Each guide ends with a hands-on lab. Do it without looking back at the steps before moving on.</p></div>
        <div style="--c:#f59e0b"><span class="howto-icon">💰</span><h3>4 · Watch the bill</h3><p>AWS steps that cost money are marked <span class="pill cost">Cost</span>. Always run the cleanup steps.</p></div>
      </div>
      ${footerHtml()}`;
    toc.innerHTML = '';
    document.title = 'DevOps Launchpad';
  }

  // ---------- roadmap: "how to start DevOps" ----------
  const ROADMAP = window.DEVOPS_CONFIG.roadmap || [];
  const toolById = (id) => TOOLS.find((t) => t.id === id);
  const rowItems = (r) => r.then || r.pick || r.links || [];

  // Average of the stage's guides; a "pick one" row counts once, as its best-progressed choice.
  function stagePct(st) {
    const parts = [];
    st.rows.forEach((r) => {
      const ids = rowItems(r).filter((x) => typeof x === 'string' && guides[x]);
      if (!ids.length) return;
      if (r.pick) parts.push(Math.max(...ids.map(pct)));
      else ids.forEach((x) => parts.push(pct(x)));
    });
    return parts.length ? Math.round(parts.reduce((a, b) => a + b, 0) / parts.length) : 0;
  }

  function rmGuide(x) {
    if (typeof x === 'string') {
      const t = toolById(x);
      if (!t) return '';
      return `<a class="rm-guide" href="#/tool/${t.id}" style="--c:${t.color}">
        <span class="badge" style="--c:${t.color}">${esc(t.badge)}</span>
        <span class="rm-guide-title">${esc(t.title)}</span>
        <span class="rm-guide-pct">${pct(t.id)}%</span></a>`;
    }
    const local = x.url.startsWith('#');   // a page or section on this site
    return `<a class="rm-guide" href="${esc(x.url)}" ${local ? '' : 'target="_blank" rel="noopener"'} style="--c:${x.color}">
      <span class="badge" style="--c:${x.color}">${esc(x.badge)}</span>
      <span class="rm-guide-title">${esc(x.title)}${x.note ? `<small>${esc(x.note)}</small>` : ''}</span>
      ${local ? '' : '<span class="rm-guide-pct" aria-label="opens in a new tab">↗</span>'}</a>`;
  }

  function flowStrip() {
    return `<ol class="rm-flow">${ROADMAP.map((st, i) => `
      <li style="--c:${st.color}"><a href="#/roadmap/${st.id}">
        <span class="rm-flow-num">${i + 1}</span><span aria-hidden="true">${st.icon}</span>${esc(st.short || st.title)}</a></li>`).join('')}
    </ol>`;
  }

  function renderRoadmap(stageId) {
    // total time from "2–3 weeks" style strings
    const range = ROADMAP.reduce((a, st) => {
      const n = (st.time.match(/\d+/g) || []).map(Number);
      return [a[0] + (n[0] || 0), a[1] + (n[1] || n[0] || 0)];
    }, [0, 0]);
    const line = ROADMAP.map((st) => st.color).join(', ');

    main.innerHTML = `
      <section class="hero">
        <p class="eyebrow">Roadmap · Where to start</p>
        <h1>How to start DevOps: the roadmap</h1>
        <p class="lead">${ROADMAP.length} stages, in order. Each stage tells you <em>why</em> it matters, what to learn,
          which guides to follow and how to know you're ready for the next one. Plan about
          <strong>${range[0]}–${range[1]} weeks</strong> at 1–2 hours a day.</p>
        ${byline('hero-byline')}
      </section>

      <h2 class="section-title">🗺️ The flow at a glance</h2>
      ${flowStrip()}

      <ol class="rm-stages" style="--rm-line:linear-gradient(180deg, ${line})">
        ${ROADMAP.map((st, i) => `
        <li class="rm-stage" id="rm-${st.id}" data-slug="${st.id}" style="--c:${st.color}">
          <div class="rm-marker" aria-hidden="true">${i + 1}</div>
          <div class="rm-card">
            <header class="rm-head">
              <span class="rm-icon" aria-hidden="true">${st.icon}</span>
              <div class="rm-head-text">
                <p class="rm-kicker">Stage ${i + 1} · ${esc(st.time)}</p>
                <h2><a href="#/roadmap/${st.id}">${esc(st.title)}</a></h2>
              </div>
              <span class="rm-pct" title="Your progress in this stage's guides">${stagePct(st)}%</span>
            </header>
            <p class="rm-why">${esc(st.why)}</p>
            <div class="rm-cols">
              <div>
                <h3 class="rm-sub">📌 What to learn</h3>
                <ul class="rm-learn">${st.learn.map((l) => `<li>${esc(l)}</li>`).join('')}</ul>
              </div>
              <div>
                <h3 class="rm-sub">📘 Follow these guides</h3>
                ${st.rows.map((r) => `
                <div class="rm-row">
                  <p class="rm-row-label">${esc(r.label)}${r.pick ? '<span class="rm-pick">choose one</span>' : ''}</p>
                  <div class="rm-path">${rowItems(r).map(rmGuide).filter(Boolean)
                    .map((html, n) => n === 0 || r.links ? html : `<span class="rm-step">${r.pick
                      ? '<span class="rm-join or">or</span>' : '<span class="rm-join" aria-hidden="true">→</span>'}${html}</span>`)
                    .join('')}</div>
                </div>`).join('')}
              </div>
            </div>
            ${st.tools ? `
            <h3 class="rm-sub rm-tools-title">🧰 Tools you'll use</h3>
            <div class="rm-tools">${st.tools.map(([n, w]) => `<span class="rm-tool"><strong>${esc(n)}</strong> <small>${esc(w)}</small></span>`).join('')}</div>` : ''}
            <p class="rm-ready"><strong>✅ Ready for the next stage when:</strong> ${esc(st.ready)}</p>
          </div>
        </li>`).join('')}
      </ol>
      ${footerHtml()}`;

    toc.style.setProperty('--c', 'var(--accent)');
    toc.innerHTML = '<div class="toc-label">Stages</div>' + ROADMAP.map((st, i) =>
      `<a href="#/roadmap/${st.id}" data-slug="${st.id}">${i + 1}. ${esc(st.short || st.title)}</a>`).join('');
    document.title = 'DevOps Roadmap · DevOps Launchpad';
    watchActive('.rm-stage');

    const target = stageId && document.getElementById('rm-' + stageId);
    if (target) {
      requestAnimationFrame(() => target.scrollIntoView({ block: 'start' }));
      target.classList.add('rm-target');
    } else {
      window.scrollTo(0, 0);
    }
  }

  function renderTool(id, sectionSlug) {
    const t = TOOLS.find((x) => x.id === id);
    const g = guides[id];
    if (!t || !g) return renderNotFound();
    const done = doneSet(id);
    const idx = TOOLS.indexOf(t);
    const prev = TOOLS[idx - 1], next = TOOLS[idx + 1];

    main.innerHTML = `
      <article class="doc" style="--c:${t.color}">
        <header class="doc-head">
          <span class="badge big" style="--c:${t.color}">${esc(t.badge)}</span>
          <div>
            <p class="eyebrow">${sectionOf(t.section).icon} ${esc(t.section || '')} · Step ${idx} · ${esc(t.level)} · ~${t.hours}h</p>
            <h1>${esc(g.title)}</h1>
            ${AUTHOR.name ? `<p class="doc-author">by ${authorLink()}</p>` : ''}
          </div>
        </header>
        <div class="progress-row">
          <div class="bar"><span id="docBar" style="width:${pct(id)}%"></span></div>
          <span id="docPct">${pct(id)}% complete</span>
          <button class="link-btn code-all" id="codeAllBtn" type="button" hidden>Show all code</button>
          <button class="link-btn" id="resetBtn" type="button">Reset</button>
        </div>
        <div class="intro">${render(g.intro)}</div>
        ${g.sections.map((s, i) => `
          <section class="step ${done.has(s.slug) ? 'is-done' : ''}" id="s-${s.slug}" data-slug="${s.slug}">
            <div class="step-head">
              <span class="step-num">${i + 1}</span>
              <h2><a href="#/tool/${id}/${s.slug}">${esc(s.title)}</a></h2>
              <label class="done-toggle"><input type="checkbox" data-slug="${s.slug}" ${done.has(s.slug) ? 'checked' : ''}> Done</label>
            </div>
            <div class="step-body">${render(s.body)}</div>
          </section>`).join('')}
        <nav class="pager">
          ${prev ? `<a href="#/tool/${prev.id}" class="btn">← ${esc(prev.title)}</a>` : '<span></span>'}
          ${next ? `<a href="#/tool/${next.id}" class="btn primary">Next: ${esc(next.title)} →</a>` : '<a href="#/" class="btn primary">Back to roadmap</a>'}
        </nav>
      </article>
      ${footerHtml()}`;

    toc.style.setProperty('--c', t.color);
    toc.innerHTML = '<div class="toc-label">On this page</div>' + g.sections.map((s) =>
      `<a href="#/tool/${id}/${s.slug}" data-slug="${s.slug}" class="${done.has(s.slug) ? 'done' : ''}">${esc(s.title)}</a>`).join('');

    main.querySelectorAll('.done-toggle input').forEach((cb) => cb.addEventListener('change', () => {
      setDone(id, cb.dataset.slug, cb.checked);
      cb.closest('.step').classList.toggle('is-done', cb.checked);
      toc.querySelector(`[data-slug="${cb.dataset.slug}"]`).classList.toggle('done', cb.checked);
      refreshProgress(id);
    }));
    $('#resetBtn').addEventListener('click', () => {
      if (!confirm('Reset progress for ' + t.title + '?')) return;
      progress[id] = [];
      store.set('dl-progress', progress);
      renderTool(id);
      renderSidebar(id);
    });

    document.title = g.title + ' · DevOps Launchpad';
    syncCodeAll();
    watchActive();
    if (sectionSlug) {
      const el = document.getElementById('s-' + sectionSlug);
      if (el) requestAnimationFrame(() => el.scrollIntoView({ block: 'start' }));
    } else {
      window.scrollTo(0, 0);
    }
  }

  function refreshProgress(id) {
    $('#docBar').style.width = pct(id) + '%';
    $('#docPct').textContent = pct(id) + '% complete';
    renderSidebar(id);
  }

  function renderNotFound() {
    main.innerHTML = '<div class="empty"><h1>Page not found</h1><p><a href="#/">Back to the roadmap</a></p></div>';
    toc.innerHTML = '';
  }

  function renderLoadError() {
    main.innerHTML = `
      <div class="empty">
        <h1>Couldn't load the guides</h1>
        <p>The guides are Markdown files fetched by the browser, so the site must be served over HTTP
           (opening <code>index.html</code> directly from disk blocks this).</p>
        <p>From the project folder, run one of:</p>
        <div class="code is-open"><div class="code-head"><span>bash</span><button class="copy" type="button">Copy</button></div><pre><code>python -m http.server 8080
# or
npx serve -l 8080 .
# or
docker build -t devops-launchpad . &amp;&amp; docker run -p 8080:80 devops-launchpad</code></pre></div>
        <p>Then open <a href="http://localhost:8080">http://localhost:8080</a>.</p>
      </div>`;
    toc.innerHTML = '';
  }

  // Highlight the section currently in view in the right-hand TOC.
  let observer;
  function watchActive(selector = '.step') {
    if (observer) observer.disconnect();
    if (!('IntersectionObserver' in window)) return;
    observer = new IntersectionObserver((entries) => {
      entries.forEach((e) => {
        if (!e.isIntersecting) return;
        toc.querySelectorAll('a').forEach((a) => a.classList.toggle('active', a.dataset.slug === e.target.dataset.slug));
      });
    }, { rootMargin: '-80px 0px -70% 0px' });
    main.querySelectorAll(selector).forEach((s) => observer.observe(s));
  }

  // ---------- practice lab ----------
  // In-browser Linux: v86 (x86 emulator in WebAssembly) booting a Buildroot/BusyBox kernel,
  // all self-hosted under assets/vm/. The VM element is built once and re-attached on each
  // visit, so the session survives moving between guides (until the page is reloaded).
  const VM_TRY = [
    ['Where am I?', 'pwd; ls -la'],
    ['System info', 'uname -a; free -m; df -h'],
    ['Create files', 'mkdir -p ~/lab && cd ~/lab && echo "hello linux" > notes.txt && cat notes.txt && ls -l'],
    ['Permissions', 'touch run.sh && chmod 750 run.sh && ls -l run.sh'],
    ['Processes', 'ps | head -15'],
    ['Pipes', 'cut -d: -f1 /etc/passwd | sort | head'],
    ['Loop', 'for i in 1 2 3; do echo "Run $i"; done'],
    ['Clear', 'clear']
  ];
  const vm = { el: null, emulator: null, ready: false, tail: '' };

  function loadAsset(tag, attrs) {
    return new Promise((resolve, reject) => {
      const el = Object.assign(document.createElement(tag), attrs);
      el.onload = resolve;
      el.onerror = () => reject(new Error('Could not load ' + (attrs.src || attrs.href)));
      document.head.appendChild(el);
    });
  }

  function setVmStatus(state, text) {
    vm.el.dataset.state = state;
    vm.el.querySelector('.vm-status').textContent = text;
  }

  const focusVm = () => { const t = vm.el.querySelector('.xterm-helper-textarea'); if (t) t.focus(); };

  function buildVm() {
    const el = document.createElement('div');
    el.className = 'vm';
    el.dataset.state = 'idle';
    el.innerHTML = `
      <div class="vm-bar">
        <span class="vm-dot"></span><span class="vm-status">Not started</span>
        <span class="vm-actions">
          <button class="btn primary vm-start" type="button">▶ Start Linux</button>
          <button class="btn vm-restart" type="button" hidden>↻ Restart</button>
        </span>
      </div>
      <div class="vm-screen"><div class="vm-placeholder"><p>Click <strong>Start Linux</strong> to boot a real Linux kernel in this tab.<br>About 12&nbsp;MB to download the first time, then it boots in a few seconds.</p></div></div>
      <div class="vm-try"><span>Try:</span>${VM_TRY.map(([label, cmd], i) =>
        `<button type="button" class="chip" data-i="${i}" title="${esc(cmd)}">${esc(label)}</button>`).join('')}</div>`;

    el.querySelector('.vm-start').addEventListener('click', startVm);
    el.querySelector('.vm-restart').addEventListener('click', () => {
      if (!vm.emulator) return;
      vm.ready = false;
      vm.tail = '';
      setVmStatus('busy', 'Restarting…');
      vm.emulator.restart();
    });
    el.querySelector('.vm-try').addEventListener('click', (e) => {
      const chip = e.target.closest('.chip');
      if (!chip) return;
      if (!vm.ready) return setVmStatus(vm.emulator ? 'busy' : 'idle', vm.emulator ? 'Still booting… try again in a moment' : 'Click Start Linux first');
      vm.emulator.serial0_send(VM_TRY[chip.dataset.i][1] + '\n');
      focusVm();
    });
    return el;
  }

  async function startVm() {
    const startBtn = vm.el.querySelector('.vm-start');
    startBtn.disabled = true;
    setVmStatus('busy', 'Loading emulator…');
    try {
      await Promise.all([
        loadAsset('link', { rel: 'stylesheet', href: 'assets/vm/xterm.min.css' }),
        loadAsset('script', { src: 'assets/vm/xterm.min.js' })
      ]);
      await loadAsset('script', { src: 'assets/vm/libv86.js' });
    } catch (e) {
      startBtn.disabled = false;
      return setVmStatus('error', e.message);
    }

    const screen = vm.el.querySelector('.vm-screen');
    screen.innerHTML = '';
    vm.emulator = new window.V86({
      wasm_path: 'assets/vm/v86.wasm',
      memory_size: 128 * 1024 * 1024,
      vga_memory_size: 2 * 1024 * 1024,
      bios: { url: 'assets/vm/seabios.bin' },
      vga_bios: { url: 'assets/vm/vgabios.bin' },
      bzimage: { url: 'assets/vm/linux.bin' },
      filesystem: {},
      cmdline: 'tsc=reliable mitigations=off random.trust_cpu=on',
      serial_console: { type: 'xtermjs', container: screen },
      autostart: true
    });
    vm.emulator.add_listener('download-progress', (e) => {
      if (e.lengthComputable && e.total) setVmStatus('busy', `Downloading Linux… ${Math.round(100 * e.loaded / e.total)}%`);
    });
    vm.emulator.add_listener('download-error', () => setVmStatus('error', 'Download failed. Check your connection and reload the page.'));
    vm.emulator.add_listener('emulator-started', () => setVmStatus('busy', 'Booting Linux…'));
    vm.emulator.add_listener('serial0-output-byte', (b) => {
      if (vm.ready) return;
      vm.tail = (vm.tail + String.fromCharCode(b)).slice(-8);
      if (/[#$%] $/.test(vm.tail)) {
        vm.ready = true;
        setVmStatus('ready', 'Running · you are root in a BusyBox shell');
        focusVm();
      }
    });
    startBtn.hidden = true;
    vm.el.querySelector('.vm-restart').hidden = false;
  }

  function renderLab() {
    const repo = window.DEVOPS_CONFIG.repo;
    const codespaceUrl = `https://codespaces.new/${repo}?quickstart=1`;
    main.innerHTML = `
      <article class="doc lab" style="--c:#0f766e">
        <header class="doc-head">
          <span class="badge big" style="--c:#0f766e">&gt;_</span>
          <div><p class="eyebrow">Hands-on · nothing to install</p><h1>Practice lab</h1></div>
        </header>
        <div class="intro"><p>Two ways to run real commands while you follow the guides: a Linux terminal right here in the page,
          and a full cloud machine with every DevOps tool already installed.</p></div>

        <section class="step">
          <div class="step-head"><span class="step-num">1</span><h2>Linux terminal in your browser</h2></div>
          <div class="step-body">
            <p>A real Linux 6.8 kernel with BusyBox runs <strong>entirely inside this browser tab</strong>. Nothing is sent to a server,
              it can't affect your computer, and it resets when you reload. Use it with the <a href="#/tool/linux">Linux guide</a>
              for files, permissions, pipes, processes, <code>vi</code> and shell scripts.</p>
            <div id="vmSlot"></div>
            <div class="callout note"><p><strong>Note:</strong> This is a minimal system: no internet, no <code>apt</code>, no
              <code>systemd</code>, and no Docker or Kubernetes. Use the full lab machine below for those.</p></div>
          </div>
        </section>

        <section class="step">
          <div class="step-head"><span class="step-num">2</span><h2>Full lab machine (GitHub Codespaces)</h2></div>
          <div class="step-body">
            <p>Get your own Ubuntu machine in the cloud, with VS Code in the browser and everything from
              <a href="#/tool/setup">Workstation Setup</a> already installed. Use it for the Docker, Kubernetes, Terraform and Argo CD guides.</p>
            <p><a class="btn primary" href="${codespaceUrl}" target="_blank" rel="noopener">🚀 Open lab machine</a></p>
            <div class="table-wrap"><table><thead><tr><th>Included</th><th>Notes</th></tr></thead><tbody>
              <tr><td>Ubuntu 24.04, Git, VS Code</td><td>Runs in a browser tab, or open it in desktop VS Code</td></tr>
              <tr><td>Docker</td><td><code>docker run hello-world</code> works straight away</td></tr>
              <tr><td>kind, kubectl, Helm</td><td><code>kind create cluster</code> gives you Kubernetes in about a minute</td></tr>
              <tr><td>Terraform, AWS CLI, eksctl</td><td>Sign in with <code>aws configure sso</code></td></tr>
              <tr><td>Argo CD CLI</td><td>For the Argo CD guide, on top of your kind cluster</td></tr>
            </tbody></table></div>
            <ol>
              <li>Sign in to GitHub (a free account works), then click <strong>Open lab machine</strong>.</li>
              <li>The first start takes 2–3 minutes while the tools install. After that it opens in seconds.</li>
              <li>Open the terminal (<code>Ctrl + \`</code>) and check it with <code>docker version &amp;&amp; kind version</code>.</li>
            </ol>
            <div class="callout cost"><p><strong>Cost:</strong> Personal GitHub accounts get <strong>120 core-hours free per month</strong>,
              about 60 hours on the default 2-core machine. A machine stops itself after 30 minutes idle. Stop or delete old ones at
              <a href="https://github.com/codespaces" target="_blank" rel="noopener">github.com/codespaces</a>.</p></div>
          </div>
        </section>
      </article>
      ${footerHtml()}`;
    toc.innerHTML = '';
    document.title = 'Practice lab · DevOps Launchpad';
    if (!vm.el) vm.el = buildVm();
    $('#vmSlot').appendChild(vm.el);
  }

  // ---------- router ----------
  function route() {
    closeMenu();
    hideResults();
    if (loadError && !Object.keys(guides).length) { renderSidebar(); return renderLoadError(); }
    const parts = location.hash.replace(/^#\/?/, '').split('/');
    activeCollapsed = false;
    if (parts[0] === 'tool' && parts[1]) {
      renderSidebar(parts[1]);
      renderTool(parts[1], parts[2]);
    } else if (parts[0] === 'roadmap') {
      renderSidebar('roadmap');
      renderRoadmap(parts[1]);
    } else if (parts[0] === 'lab') {
      renderSidebar('lab');
      renderLab();
      window.scrollTo(0, 0);
    } else {
      renderSidebar();
      renderHome();
      window.scrollTo(0, 0);
    }
    main.focus({ preventScroll: true });
  }

  // ---------- search ----------
  const searchInput = $('#search'), results = $('#results');
  // The "/" shortcut hint is meaningless on touch screens and crowds small search boxes.
  if (matchMedia('(hover: none), (max-width: 860px)').matches) searchInput.placeholder = 'Search guides…';
  function hideResults() { results.hidden = true; }
  function search(q) {
    q = q.trim().toLowerCase();
    if (q.length < 2) return hideResults();
    const hits = [];
    TOOLS.forEach((t) => {
      const g = guides[t.id];
      if (!g) return;
      g.sections.forEach((s) => {
        const inTitle = s.title.toLowerCase().includes(q);
        const pos = s.text.toLowerCase().indexOf(q);
        if (!inTitle && pos === -1) return;
        let snippet = '';
        if (pos !== -1) {
          const start = Math.max(0, pos - 40);
          snippet = (start ? '…' : '') + s.text.slice(start, pos + q.length + 60).replace(/[`#*>|]/g, '').replace(/\s+/g, ' ') + '…';
        }
        hits.push({ t, s, snippet, score: inTitle ? 0 : 1 });
      });
    });
    hits.sort((a, b) => a.score - b.score);
    const mark = (str) => esc(str).replace(new RegExp(q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'gi'), (m) => `<mark>${m}</mark>`);
    results.innerHTML = hits.length
      ? hits.slice(0, 12).map((h) => `
          <a href="#/tool/${h.t.id}/${h.s.slug}">
            <span class="badge" style="--c:${h.t.color}">${esc(h.t.badge)}</span>
            <span><strong>${mark(h.s.title)}</strong><small>${esc(h.t.title)}${h.snippet ? ' — ' + mark(h.snippet) : ''}</small></span>
          </a>`).join('')
      : '<div class="no-results">No matches</div>';
    results.hidden = false;
  }
  searchInput.addEventListener('input', () => search(searchInput.value));
  searchInput.addEventListener('focus', () => search(searchInput.value));
  searchInput.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') { searchInput.blur(); hideResults(); }
    if (e.key === 'Enter') { const first = results.querySelector('a'); if (first) { location.hash = first.getAttribute('href'); searchInput.blur(); } }
  });
  document.addEventListener('click', (e) => { if (!e.target.closest('.search')) hideResults(); });
  document.addEventListener('keydown', (e) => {
    if (e.key === '/' && !/INPUT|TEXTAREA/.test(document.activeElement.tagName)) { e.preventDefault(); searchInput.focus(); }
  });

  // ---------- show / hide code ----------
  function setCodeOpen(block, open) {
    block.classList.toggle('is-open', open);
    const t = block.querySelector('.code-toggle');
    if (t) t.setAttribute('aria-expanded', String(open));
  }
  // "Show all code" covers code blocks only; diagrams keep their own state.
  const codeBlocks = () => [...main.querySelectorAll('.code:not(.is-diagram)')].filter((b) => b.querySelector('.code-toggle'));
  function syncCodeAll() {
    const btn = $('#codeAllBtn');
    if (!btn) return;
    const blocks = codeBlocks();
    btn.hidden = !blocks.length;
    const allOpen = blocks.length && blocks.every((b) => b.classList.contains('is-open'));
    btn.textContent = allOpen ? 'Hide all code' : 'Show all code';
    btn.setAttribute('aria-pressed', String(!!allOpen));
  }
  main.addEventListener('click', (e) => {
    const t = e.target.closest('.code-toggle');
    if (t) {
      const block = t.closest('.code');
      setCodeOpen(block, !block.classList.contains('is-open'));
      syncCodeAll();
      return;
    }
    if (e.target.closest('#codeAllBtn')) {
      const open = !codeBlocks().every((b) => b.classList.contains('is-open'));
      codeBlocks().forEach((b) => setCodeOpen(b, open));
      syncCodeAll();
    }
  });

  // ---------- copy buttons ----------
  main.addEventListener('click', async (e) => {
    const btn = e.target.closest('.copy');
    if (!btn) return;
    const text = btn.closest('.code').querySelector('code').innerText;
    try {
      await navigator.clipboard.writeText(text);
    } catch (err) {
      const ta = document.createElement('textarea');
      ta.value = text; document.body.appendChild(ta); ta.select();
      try { document.execCommand('copy'); } catch (e2) { /* ignore */ }
      ta.remove();
    }
    btn.textContent = 'Copied ✓';
    btn.classList.add('ok');
    setTimeout(() => { btn.textContent = 'Copy'; btn.classList.remove('ok'); }, 1500);
  });

  // ---------- mobile menu ----------
  const scrim = $('#scrim');
  function closeMenu() { document.body.classList.remove('menu-open'); scrim.hidden = true; }
  $('#menuBtn').addEventListener('click', () => {
    const open = document.body.classList.toggle('menu-open');
    scrim.hidden = !open;
  });
  scrim.addEventListener('click', closeMenu);

  // ---------- boot ----------
  main.innerHTML = '<div class="empty"><p>Loading guides…</p></div>';
  window.addEventListener('hashchange', route);
  loadAll().then(route);
})();
