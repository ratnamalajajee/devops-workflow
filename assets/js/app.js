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
      return { title: t, slug: slugify(t), body: nl === -1 ? '' : p.slice(nl + 1) };
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

  // ---------- sidebar ----------
  function renderSidebar(activeId) {
    sidebar.innerHTML =
      `<a href="#/" class="nav-home ${!activeId ? 'active' : ''}">🏠 Home &amp; roadmap</a>` +
      '<div class="nav-label">Learning path</div>' +
      TOOLS.map((t, i) => `
        <a href="#/tool/${t.id}" class="nav-item ${t.id === activeId ? 'active' : ''}">
          <span class="badge" style="--c:${t.color}">${esc(t.badge)}</span>
          <span class="nav-text"><span class="nav-title">${i}. ${esc(t.title)}</span>
          <span class="mini-bar"><span style="width:${pct(t.id)}%"></span></span></span>
          <span class="nav-pct">${pct(t.id)}%</span>
        </a>`).join('');
  }

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
        <div class="hero-actions">
          <a class="btn primary" href="#/tool/${next.id}">${overall ? 'Continue' : 'Start'}: ${esc(next.title)} →</a>
          <a class="btn" href="#/tool/capstone">See the final project</a>
        </div>
        <div class="stats">
          <div><strong>${TOOLS.length}</strong><span>guides</span></div>
          <div><strong>${total}</strong><span>steps</span></div>
          <div><strong>~${hours}h</strong><span>total effort</span></div>
          <div><strong>${overall}%</strong><span>your progress</span></div>
        </div>
      </section>

      <h2 class="section-title">Your roadmap</h2>
      <ol class="roadmap">
        ${TOOLS.map((t, i) => `
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

      <h2 class="section-title">How to use this site</h2>
      <div class="howto">
        <div><h3>1 · Set up once</h3><p>Do <a href="#/tool/setup">Workstation Setup</a> first. Every later guide assumes a Linux shell (WSL2 on Windows) with the CLIs installed.</p></div>
        <div><h3>2 · Type, don't just read</h3><p>Run every command yourself. Break things on purpose, then use the troubleshooting sections to fix them.</p></div>
        <div><h3>3 · Finish each lab</h3><p>Each guide ends with a hands-on lab. Do it without looking back at the steps before moving on.</p></div>
        <div><h3>4 · Watch the bill</h3><p>AWS steps that cost money are marked <span class="pill cost">Cost</span>. Always run the cleanup steps.</p></div>
      </div>`;
    toc.innerHTML = '';
    document.title = 'DevOps Launchpad';
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
            <p class="eyebrow">Step ${idx} · ${esc(t.level)} · ~${t.hours}h</p>
            <h1>${esc(g.title)}</h1>
          </div>
        </header>
        <div class="progress-row">
          <div class="bar"><span id="docBar" style="width:${pct(id)}%"></span></div>
          <span id="docPct">${pct(id)}% complete</span>
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
      </article>`;

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
        <div class="code"><div class="code-head"><span>bash</span><button class="copy" type="button">Copy</button></div><pre><code>python -m http.server 8080
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
  function watchActive() {
    if (observer) observer.disconnect();
    if (!('IntersectionObserver' in window)) return;
    observer = new IntersectionObserver((entries) => {
      entries.forEach((e) => {
        if (!e.isIntersecting) return;
        toc.querySelectorAll('a').forEach((a) => a.classList.toggle('active', a.dataset.slug === e.target.dataset.slug));
      });
    }, { rootMargin: '-80px 0px -70% 0px' });
    main.querySelectorAll('.step').forEach((s) => observer.observe(s));
  }

  // ---------- router ----------
  function route() {
    closeMenu();
    hideResults();
    if (loadError && !Object.keys(guides).length) { renderSidebar(); return renderLoadError(); }
    const parts = location.hash.replace(/^#\/?/, '').split('/');
    if (parts[0] === 'tool' && parts[1]) {
      renderSidebar(parts[1]);
      renderTool(parts[1], parts[2]);
    } else {
      renderSidebar();
      renderHome();
      window.scrollTo(0, 0);
    }
    main.focus({ preventScroll: true });
  }

  // ---------- search ----------
  const searchInput = $('#search'), results = $('#results');
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
        const pos = s.body.toLowerCase().indexOf(q);
        if (!inTitle && pos === -1) return;
        let snippet = '';
        if (pos !== -1) {
          const start = Math.max(0, pos - 40);
          snippet = (start ? '…' : '') + s.body.slice(start, pos + q.length + 60).replace(/[`#*>|]/g, '').replace(/\s+/g, ' ') + '…';
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
