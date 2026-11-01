// Minimal, dependency-free Markdown renderer covering what the guides use:
// headings (###+), paragraphs, ul/ol lists, fenced code, tables, callouts
// (> **Tip:** / **Note:** / **Warning:** / **Cost:** / **Why:** / **In simple words:**),
// `code`, **bold**, *italic*, [links](url).
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

  function codeBlock(lang, code) {
    let html = esc(code);
    if (COMMENT_LANGS.test(lang)) html = html.replace(/^(\s*#.*)$/gm, '<span class="c">$1</span>');
    return `<div class="code" data-lang="${esc(lang || 'text')}"><div class="code-head">` +
      `<span class="dots" aria-hidden="true"><i></i><i></i><i></i></span><span class="lang">${esc(lang || 'text')}</span>` +
      `<button class="copy" type="button">Copy</button></div><pre><code>${html}</code></pre></div>`;
  }

  // Table cells split on unescaped pipes; write \| for a literal pipe inside a cell.
  const splitRow = (r) => r.trim().replace(/^\||\|$/g, '').split(/(?<!\\)\|/).map((c) => c.trim().replace(/\\\|/g, '|'));
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
        const lang = l.slice(3).trim().toLowerCase();
        const buf = [];
        i++;
        while (i < L.length && !L[i].startsWith('```')) buf.push(L[i++]);
        i++;
        out.push(codeBlock(lang, buf.join('\n')));
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
