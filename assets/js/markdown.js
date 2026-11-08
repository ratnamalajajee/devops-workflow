// Minimal, dependency-free Markdown renderer covering what the guides use:
// headings (###+), paragraphs, ul/ol lists, fenced code, tables, callouts
// (> **Tip:** / **Note:** / **Warning:** / **Cost:** / **Why:** / **In simple words:**),
// `code`, **bold**, *italic*, [links](url), and diagram fences: ```flow, ```compare, ```svg.
(function () {
  const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

  function inline(s) {
    const codes = [];
    s = s.replace(/`([^`]+)`/g, (_, c) => { codes.push(c); return '\u0000' + (codes.length - 1) + '\u0000'; });
    s = esc(s)
      .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
      .replace(/(^|[\s(])\*(?=\S)([^*]+?)\*(?=[\s.,;:!?)]|$)/g, '$1<em>$2</em>')
      .replace(/\[([^\]]+)\]\(((?:https?:\/\/|#)[^)\s]+)\)/g, (_, t, u) =>
        u.startsWith('#') ? `<a href="${u}">${t}</a>` : `<a href="${u}" target="_blank" rel="noopener">${t}</a>`);
    return s.replace(/\u0000(\d+)\u0000/g, (_, i) => '<code>' + esc(codes[i]) + '</code>');
  }

  const COMMENT_LANGS = /^(bash|sh|shell|yaml|yml|hcl|terraform|dockerfile|python|text|ini|conf)$/;

  // Code starts collapsed behind a "Show code" bar (Copy still works while collapsed).
  // Text diagrams (box/arrow characters, folder trees) and blocks marked ```lang open start expanded.
  const DIAGRAM = /[│┌└├─▶▼→↓┐┘╱╲]|-->|==>|\+--/;
  function codeBlock(lang, code, flags = []) {
    let html = esc(code);
    if (COMMENT_LANGS.test(lang)) html = html.replace(/^(\s*#.*)$/gm, '<span class="c">$1</span>');
    const l = esc(lang || 'text');
    const diagram = (!lang || lang === 'text') && DIAGRAM.test(code);
    const open = diagram || flags.includes('open');
    const noun = diagram ? 'diagram' : (!lang || lang === 'text') ? 'text' : 'code';
    const n = code.split('\n').length;
    return `<div class="code${open ? ' is-open' : ''}${diagram ? ' is-diagram' : ''}" data-lang="${l}"><div class="code-head">` +
      `<button class="code-toggle" type="button" aria-expanded="${open}">` +
      `<span class="dots" aria-hidden="true"><i></i><i></i><i></i></span><span class="lang">${l}</span>` +
      `<span class="code-hint"><span class="chev" aria-hidden="true">▸</span>` +
      `<span class="when-closed">Show ${noun}</span><span class="when-open">Hide ${noun}</span>` +
      `<span class="n">· ${n} line${n === 1 ? '' : 's'}</span></span></button>` +
      `<button class="copy" type="button">Copy</button></div><pre><code>${html}</code></pre></div>`;
  }

  // Table cells split on unescaped pipes; write \| for a literal pipe inside a cell.
  const splitRow = (r) => r.trim().replace(/^\||\|$/g, '').split(/(?<!\\)\|/).map((c) => c.trim().replace(/\\\|/g, '|'));

  // ---------- diagram blocks ----------
  const PALETTE = ['#6366f1', '#8b5cf6', '#ec4899', '#f97316', '#f59e0b', '#10b981', '#06b6d4', '#3b82f6', '#e11d48'];
  const lines = (code) => code.split('\n').filter((l) => l.trim());

  // ```flow — one step per line: "icon | Title | description". A last line starting with ↻ marks a cycle.
  function flowBlock(code) {
    const all = lines(code);
    const back = all.filter((l) => l.trim().startsWith('↻')).map((l) => l.trim().slice(1).trim())[0];
    const steps = all.filter((l) => !l.trim().startsWith('↻')).map(splitRow);
    return `<figure class="flow${back ? ' is-loop' : ''}"><ol>` + steps.map(([icon, title, desc], n) =>
      `<li style="--fc:${PALETTE[n % PALETTE.length]}"><span class="flow-num">${n + 1}</span><span class="flow-card">` +
      `<span class="flow-icon" aria-hidden="true">${esc(icon || '')}</span>` +
      `<span class="flow-body"><strong>${inline(title || '')}</strong>${desc ? `<span>${inline(desc)}</span>` : ''}</span></span></li>`).join('') +
      `</ol>${back ? `<figcaption class="flow-back">↻ ${inline(back)}</figcaption>` : ''}</figure>`;
  }

  // ```compare — first line "Left title | Right title", then one "left point | right point" per line.
  function compareBlock(code) {
    const [head, ...rows] = lines(code).map(splitRow);
    const col = (k, cls) => `<div class="cmp-col ${cls}"><h4>${inline(head[k] || '')}</h4><ul>` +
      rows.filter((r) => r[k]).map((r) => `<li>${inline(r[k])}</li>`).join('') + '</ul></div>';
    return `<figure class="compare">${col(0, 'cmp-a')}<div class="cmp-vs" aria-hidden="true">VS</div>${col(1, 'cmp-b')}</figure>`;
  }
  const isBlockStart = (l) => /^(```|#{1,6} |>|\s*[-*] |\s*\d+\. )/.test(l) || /^\|/.test(l);

  function render(src) {
    const L = src.replace(/\r/g, '').split('\n');
    const out = [];
    let i = 0;
    while (i < L.length) {
      const l = L[i];
      let m;
      if (!l.trim()) { i++; continue; }

      if (l.startsWith('```')) {
        const info = l.slice(3).trim();
        const lang = info.split(/\s+/)[0].toLowerCase();
        const buf = [];
        i++;
        while (i < L.length && !L[i].startsWith('```')) buf.push(L[i++]);
        i++;
        const code = buf.join('\n');
        if (lang === 'flow') out.push(flowBlock(code));
        else if (lang === 'compare') out.push(compareBlock(code));
        // inline SVG drawn by the guide authors (trusted repo content); text after "svg" is the caption
        else if (lang === 'svg') out.push(`<figure class="diagram">${code}${info.length > 4 ? `<figcaption>${inline(info.slice(4))}</figcaption>` : ''}</figure>`);
        else out.push(codeBlock(lang, code, info.split(/\s+/).slice(1).map((f) => f.toLowerCase())));
      } else if ((m = l.match(/^(#{3,6}) (.*)/))) {
        const n = m[1].length;
        out.push(`<h${n}>${inline(m[2])}</h${n}>`);
        i++;
      } else if (l.startsWith('>')) {
        const buf = [];
        while (i < L.length && L[i].startsWith('>')) buf.push(L[i++].replace(/^>\s?/, ''));
        const text = buf.join('\n');
        const km = text.match(/^\*\*(Tip|Note|Warning|Cost|Why|In simple words)\b/i);
        const kind = km ? km[1].toLowerCase().replace(/\s+/g, '-') : 'note';
        out.push(`<div class="callout ${kind}">${render(text)}</div>`);
      } else if (l.startsWith('|') && L[i + 1] && /^\|[\s:|-]+$/.test(L[i + 1].trim())) {
        const head = splitRow(l);
        i += 2;
        const rows = [];
        while (i < L.length && L[i].startsWith('|')) rows.push(splitRow(L[i++]));
        out.push('<div class="table-wrap"><table><thead><tr>' + head.map((h) => `<th>${inline(h)}</th>`).join('') +
          '</tr></thead><tbody>' + rows.map((r) => '<tr>' + r.map((c) => `<td>${inline(c)}</td>`).join('') + '</tr>').join('') +
          '</tbody></table></div>');
      } else if (/^\s*([-*]|\d+\.) /.test(l)) {
        const ordered = /^\s*\d+\. /.test(l);
        const items = [];
        while (i < L.length && (/^\s*([-*]|\d+\.) /.test(L[i]) || (L[i].startsWith('  ') && L[i].trim() && items.length))) {
          if (/^\s*([-*]|\d+\.) /.test(L[i])) items.push(L[i].replace(/^\s*([-*]|\d+\.) /, ''));
          else items[items.length - 1] += ' ' + L[i].trim();
          i++;
        }
        const tag = ordered ? 'ol' : 'ul';
        out.push(`<${tag}>` + items.map((t) => `<li>${inline(t)}</li>`).join('') + `</${tag}>`);
      } else {
        const buf = [];
        while (i < L.length && L[i].trim() && !isBlockStart(L[i])) buf.push(L[i++]);
        if (!buf.length) buf.push(L[i++]);
        out.push(`<p>${inline(buf.join(' '))}</p>`);
      }
    }
    return out.join('\n');
  }

  window.Markdown = { render, inline, esc };
})();
