// Feedbackrunde: Laufzeit fuer Entwurfsseiten. Siehe ../SKILL.md.
//
//   Runde.start({
//     nr: 2, thema: 'Supporter-Icons',
//     geraete: ['iphone'],                 // Auswahl in der Kopfzeile: iphone | ipad | web
//     theme: 'hell',                       // Startwert: hell | dunkel | beide
//     farben: { hell: {...}, dunkel: {...} },  // optional, Standard = App-Palette "standard"
//     steuerung: [{ id: 'kopf', titel: 'Kopf', optionen: [['k1', 'K1'], ['k2', 'K2']], frage: 'kopf' }],
//     fragen: [{ id: 'kopf', titel: 'Kopfbereich', mehrfach: false }],
//     festgelegt: ['Tabs: B, Breite nach Text'],
//     render(z) { document.querySelector('[data-slot=x]').innerHTML = Runde.geraet(z, '<div>…</div>'); },
//   });
//
// Varianten stehen im HTML als <div class="variante" data-variante="k1" data-titel="K1: Kompakt">
// innerhalb von <section class="frage" data-frage="kopf">. Die Laufzeit ergaenzt an jeder
// Variante "Wählen" und ein Kommentarfeld, je Frage "Keine passt" und einen Fragekommentar.
// Eine Steuerung mit `frage` folgt der Auswahl dieser Frage (Folgescreens).
(function () {
  const STANDARD = {
    hell: { bg: '#f5f5f7', surface: '#ffffff', surface2: '#ececf0', fg: '#1c1c1e', fg2: '#5f5f66', muted: '#8e8e93', border: '#e5e5ea', primary: '#003056', 'on-primary': '#ffffff', 'primary-lite': '#e8edf5', secondary: '#810a1a', error: '#cc1f2f', success: '#00823c' },
    dunkel: { bg: '#0e0e12', surface: '#1a1a22', surface2: '#24242e', fg: '#f0f0f5', fg2: '#a8a8b6', muted: '#8a8a9a', border: '#2e2e3a', primary: '#5a9ad8', 'on-primary': '#0e0e12', 'primary-lite': '#1a253a', secondary: '#810a1a', error: '#ff5050', success: '#22c65a' },
  };
  // iOS-Textstile in px; mit --ts skaliert (Bedienungshilfen bis 1,4).
  const TEXT = { caption: 12, footnote: 13, subhead: 15, body: 17, title3: 20, title2: 22, title1: 28, large: 34 };
  const GERAETE = { iphone: 'iPhone', ipad: 'iPad', web: 'Web' };
  const SKALEN = [['1', '1,0'], ['1.3', '1,3'], ['1.4', '1,4']];

  let cfg;
  let z;
  let wahl;
  let speicherKey;

  const esc = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;');

  function laden() {
    try {
      return JSON.parse(localStorage.getItem(speicherKey)) || {};
    } catch {
      return {};
    }
  }
  function speichern() {
    try {
      localStorage.setItem(speicherKey, JSON.stringify(wahl));
    } catch {}
  }

  function zustandAusUrl() {
    const q = new URLSearchParams(location.search);
    const s = { theme: q.get('theme') || cfg.theme || 'hell', ts: q.get('ts') || '1', geraet: q.get('geraet') || cfg.geraete[0] };
    for (const st of cfg.steuerung) s[st.id] = q.get(st.id) || st.start || st.optionen[0][0];
    return s;
  }
  function zustandInUrl() {
    const q = new URLSearchParams(z);
    history.replaceState(null, '', `${location.pathname}?${q}`);
  }

  function stile() {
    const farben = { hell: { ...STANDARD.hell, ...(cfg.farben?.hell || {}) }, dunkel: { ...STANDARD.dunkel, ...(cfg.farben?.dunkel || {}) } };
    let css = '';
    for (const [modus, f] of Object.entries(farben)) {
      css += `.geraet.${modus}{${Object.entries(f).map(([k, v]) => `--${k}:${v}`).join(';')}}\n`;
    }
    css += `.geraet{${Object.entries(TEXT).map(([k, v]) => `--t-${k}:calc(${v}px * var(--ts, 1))`).join(';')}}\n`;
    const el = document.createElement('style');
    el.textContent = css;
    document.head.append(el);
  }

  // Ein Inhalt in allen gewaehlten Themes auf dem gewaehlten Geraet. Der Rahmen
  // ist mindestens einen Bildschirm hoch; ist der Inhalt laenger, markiert eine
  // Linie das Ende des ersten Bildschirms. Ein Element mit class="unten" (z. B.
  // Tabbar) sitzt am unteren Rand.
  // opts: { titel, shot, fest (genau ein Bildschirm, Rest abgeschnitten), url (Web-Adresszeile) }
  function geraet(zz, inhalt, opts = {}) {
    const modi = zz.theme === 'beide' ? ['hell', 'dunkel'] : [zz.theme];
    const art = zz.geraet;
    return modi
      .map((modus) => {
        const kopf =
          art === 'web'
            ? `<div class="browser"><i></i><i></i><i></i><span>${esc(opts.url || 'namiapp.de')}</span></div>`
            : `<div class="status"><span>9:41</span>${art === 'iphone' ? '<i class="island"></i>' : ''}<span class="sys"></span></div>`;
        const inhaltHtml = typeof inhalt === 'function' ? inhalt(modus) : inhalt;
        const shot = opts.shot ? ` data-shot="${esc(opts.shot)}-${art}-${modus}"` : '';
        const titel = [opts.titel, zz.theme === 'beide' ? (modus === 'hell' ? 'hell' : 'dunkel') : ''].filter(Boolean).join(', ');
        return `<figure class="geraet ${art} ${modus}" style="--ts:${zz.ts}"${shot}><div class="rahmen${opts.fest ? ' fest' : ''}">${kopf}${inhaltHtml}<i class="falz"><span>Ende 1. Bildschirm</span></i></div>${titel ? `<figcaption>${esc(titel)}</figcaption>` : ''}</figure>`;
      })
      .join('');
  }

  function tgl(id, optionen, aktiv) {
    return `<span class="tgl" data-tgl="${id}">${optionen.map(([v, l]) => `<button data-v="${esc(v)}" class="${v === aktiv ? 'on' : ''}">${esc(l)}</button>`).join('')}</span>`;
  }

  function kopfzeile() {
    const teile = [`<span class="titel">#${cfg.nr} ${esc(cfg.thema)}</span>`];
    if (cfg.geraete.length > 1) teile.push(`<span class="gruppe"><label>Gerät</label>${tgl('geraet', cfg.geraete.map((g) => [g, GERAETE[g]]), z.geraet)}</span>`);
    teile.push(`<span class="gruppe"><label>Theme</label>${tgl('theme', [['hell', 'Hell'], ['dunkel', 'Dunkel'], ['beide', 'Beide']], z.theme)}</span>`);
    teile.push(`<span class="gruppe"><label>Schrift</label>${tgl('ts', SKALEN, z.ts)}</span>`);
    for (const st of cfg.steuerung) teile.push(`<span class="gruppe"><label>${esc(st.titel)}</label>${tgl(st.id, st.optionen, z[st.id])}</span>`);
    const links = cfg.fragen.map((f) => `<a href="#frage-${f.id}">${esc(f.titel)}</a>`).join('');
    teile.push(`<span class="rechts"><nav>${links}</nav><span class="stand" id="rk-stand"></span><button class="kopieren" id="rk-kopieren">Entscheidungen kopieren</button></span>`);
    const kopf = document.createElement('header');
    kopf.className = 'rk';
    kopf.innerHTML = teile.join('');
    document.body.prepend(kopf);
    kopf.addEventListener('click', (e) => {
      const b = e.target.closest('[data-tgl] button');
      if (!b) return;
      z[b.parentElement.dataset.tgl] = b.dataset.v;
      aktualisieren();
    });
    document.getElementById('rk-kopieren').addEventListener('click', kopieren);
  }

  function kopfAktualisieren() {
    for (const t of document.querySelectorAll('.rk [data-tgl]')) {
      for (const b of t.children) b.classList.toggle('on', b.dataset.v === z[t.dataset.tgl]);
    }
    const offen = cfg.fragen.filter((f) => !(wahl.picks[f.id]?.length || wahl.keine[f.id]));
    document.getElementById('rk-stand').textContent = offen.length ? `${cfg.fragen.length - offen.length}/${cfg.fragen.length} entschieden` : 'alles entschieden';
  }

  function festgelegt() {
    if (!cfg.festgelegt?.length) return;
    const box = document.createElement('div');
    box.className = 'fest';
    box.innerHTML = `<b>Festgelegt</b><ul>${cfg.festgelegt.map((f) => `<li>${esc(f)}</li>`).join('')}</ul>`;
    const h1 = document.querySelector('main h1');
    (h1?.nextElementSibling?.tagName === 'P' ? h1.nextElementSibling : h1)?.after(box);
  }

  // Auswahl und Kommentare direkt an den Varianten.
  function variantenAusstatten() {
    for (const sec of document.querySelectorAll('section.frage[data-frage]')) {
      const fid = sec.dataset.frage;
      sec.id = `frage-${fid}`;
      for (const v of sec.querySelectorAll('.variante[data-variante]')) {
        const vid = v.dataset.variante;
        const leiste = document.createElement('div');
        leiste.className = 'wahl';
        leiste.innerHTML = `<span class="titel">${esc(v.dataset.titel || vid)}</span><button type="button">Wählen</button><input placeholder="Kommentar zu ${esc((v.dataset.titel || vid).split(':')[0])}" value="${esc(wahl.kommentare[fid]?.[vid])}">`;
        v.prepend(leiste);
        leiste.querySelector('button').addEventListener('click', () => waehlen(fid, vid));
        leiste.querySelector('input').addEventListener('input', (e) => {
          (wahl.kommentare[fid] ??= {})[vid] = e.target.value;
          speichern();
        });
      }
      const fuss = document.createElement('div');
      fuss.className = 'fragefuss';
      fuss.innerHTML = `<button type="button" class="keine">Keine passt</button><input placeholder="Kommentar zur Frage" value="${esc(wahl.kommentare[fid]?._frage)}">`;
      sec.append(fuss);
      fuss.querySelector('.keine').addEventListener('click', () => {
        wahl.keine[fid] = !wahl.keine[fid];
        if (wahl.keine[fid]) wahl.picks[fid] = [];
        speichern();
        aktualisieren();
      });
      fuss.querySelector('input').addEventListener('input', (e) => {
        (wahl.kommentare[fid] ??= {})._frage = e.target.value;
        speichern();
      });
    }
    const allgemein = document.createElement('section');
    allgemein.className = 'frage allgemein';
    allgemein.innerHTML = `<h2>Sonst noch</h2><textarea placeholder="Allgemeiner Kommentar">${esc(wahl.allgemein)}</textarea>`;
    document.querySelector('main').append(allgemein);
    allgemein.querySelector('textarea').addEventListener('input', (e) => {
      wahl.allgemein = e.target.value;
      speichern();
    });
  }

  function waehlen(fid, vid) {
    const frage = cfg.fragen.find((f) => f.id === fid) || {};
    const liste = wahl.picks[fid] || [];
    if (liste.includes(vid)) wahl.picks[fid] = liste.filter((x) => x !== vid);
    else wahl.picks[fid] = frage.mehrfach ? [...liste, vid] : [vid];
    wahl.keine[fid] = false;
    // Folgescreens: Steuerungen, die an diese Frage gekoppelt sind, uebernehmen die Wahl.
    for (const st of cfg.steuerung.filter((s) => s.frage === fid)) {
      if (wahl.picks[fid].length && st.optionen.some(([v]) => v === wahl.picks[fid][0])) z[st.id] = wahl.picks[fid][0];
    }
    speichern();
    aktualisieren();
  }

  function variantenAktualisieren() {
    for (const sec of document.querySelectorAll('section.frage[data-frage]')) {
      const fid = sec.dataset.frage;
      for (const v of sec.querySelectorAll('.variante[data-variante]')) {
        const an = (wahl.picks[fid] || []).includes(v.dataset.variante);
        v.classList.toggle('gewaehlt', an);
        v.querySelector('.wahl button').textContent = an ? 'Gewählt ✓' : 'Wählen';
      }
      sec.querySelector('.fragefuss .keine')?.classList.toggle('on', !!wahl.keine[fid]);
    }
  }

  function markdown() {
    const titel = (fid, vid) => document.querySelector(`[data-frage="${fid}"] [data-variante="${vid}"]`)?.dataset.titel || vid;
    const zeilen = [`## Rückmeldung #${cfg.nr} ${cfg.thema}`, ''];
    for (const f of cfg.fragen) {
      const picks = wahl.picks[f.id] || [];
      const k = wahl.kommentare[f.id] || {};
      const ergebnis = wahl.keine[f.id] ? 'keine passt' : picks.length ? picks.map((v) => titel(f.id, v)).join(', ') : 'offen';
      zeilen.push(`- **${f.titel}:** ${ergebnis}${k._frage ? ` – ${k._frage}` : ''}`);
      for (const [vid, text] of Object.entries(k)) {
        if (vid !== '_frage' && text) zeilen.push(`  - zu ${titel(f.id, vid)}: ${text}`);
      }
    }
    if (wahl.allgemein) zeilen.push(`- **Sonst noch:** ${wahl.allgemein}`);
    const ansicht = [GERAETE[z.geraet], `Theme ${z.theme}`, `Schrift ${SKALEN.find(([v]) => v === z.ts)?.[1] ?? z.ts}`, ...cfg.steuerung.map((s) => `${s.titel} ${s.optionen.find(([v]) => v === z[s.id])?.[1]}`)];
    zeilen.push('', `_Ansicht: ${ansicht.join(', ')}_`);
    return zeilen.join('\n');
  }

  async function kopieren() {
    const text = markdown();
    const knopf = document.getElementById('rk-kopieren');
    try {
      await navigator.clipboard.writeText(text);
      knopf.textContent = 'Kopiert ✓';
      knopf.classList.add('ok');
      setTimeout(() => {
        knopf.textContent = 'Entscheidungen kopieren';
        knopf.classList.remove('ok');
      }, 2000);
    } catch {
      prompt('Kopieren mit Cmd+C:', text);
    }
  }

  function aktualisieren() {
    zustandInUrl();
    kopfAktualisieren();
    variantenAktualisieren();
    cfg.render(z);
    falzMarkieren();
  }

  // Linie nur zeigen, wenn der Inhalt ueber den ersten Bildschirm hinausgeht.
  function falzMarkieren() {
    for (const r of document.querySelectorAll('.rahmen:not(.fest)')) {
      const falz = r.querySelector(':scope > .falz');
      if (falz) r.classList.toggle('lang', r.clientHeight - falz.offsetTop > 2);
    }
  }

  function start(config) {
    cfg = { geraete: ['iphone'], steuerung: [], fragen: [], ...config };
    document.title = `#${cfg.nr} ${cfg.thema}`;
    speicherKey = `feedbackrunde:${cfg.thema}:${cfg.nr}`;
    wahl = { picks: {}, keine: {}, kommentare: {}, allgemein: '', ...laden() };
    z = zustandAusUrl();
    stile();
    kopfzeile();
    festgelegt();
    variantenAusstatten();
    aktualisieren();
    document.body.dataset.fertig = '1';
  }

  window.Runde = { start, geraet, markdown, zustand: () => z };
})();
