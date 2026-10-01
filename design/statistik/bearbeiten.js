// Runde 2: Klickbarer Bearbeiten-Prototyp für das Kachelraster.
// Ziehen zum Sortieren, Ecke ziehen für feste Größen, − entfernt, ＋ öffnet
// den Katalog (mit "Eigene Kachel erstellen").
(function () {
  const K = window.KACHELN;
  const B = window.BAUSTEINE;
  const { esc } = B;

  const BESCHREIBUNG = {
    personen: 'Gesamtzahl mit Kindern & Jugendlichen, Leitenden und Sonstigen.',
    stufen: 'Anteile der Stufen als Band mit Anzahl je Stufe.',
    gruppen: '2×1: Summe je Stufe. 2×2: alle Gruppen mit Leitenden und Zielmarke.',
    alter: 'Alter je Stufe als Balken, Altersgrenzen als Fläche.',
    alterZahlen: 'Median, jüngste und älteste Person je Stufe, Anzahl über der Grenze.',
    wechsel: '1×1: Anzahl zum Stichtag. 2×1: je Stufe heute → danach. 2×2: Übersicht mit Zielwerten.',
    bindung: '1×1: Neue in 12 Monaten mit Ziel. 2×1: zusätzlich Mitgliedsdauer.',
    verlauf: 'Monatliche Summen ab jetzt, nur auf diesem Gerät.',
    geschlecht: 'Anteile der Kinder & Jugendlichen.',
    konfession: 'Anteile der Kinder & Jugendlichen.',
    standorte: 'Wohnorte und Stammesheim auf der Karte.',
  };

  const groessenText = (w) => w.groessen.map((g) => g.replace('x', '×')).join(' · ');

  function naechsteGroesse(w, spalten, zeilen) {
    const wunsch = `${spalten}x${zeilen}`;
    if (w.groessen.includes(wunsch)) return wunsch;
    return w.groessen
      .map((g) => {
        const [c, r] = g.split('x').map(Number);
        return { g, d: Math.abs(c - spalten) * 1.1 + Math.abs(r - zeilen) };
      })
      .sort((a, b) => a.d - b.d)[0].g;
  }

  const R3 = (window.RUNDE || 2) >= 3;

  function editor(root, ctxFn, preset = {}) {
    const state = {
      tabs: preset.tabs || [true, true, true],
      modus: preset.modus || 'ansicht',
      tiles: K.tabKacheln('H1', 0).filter(Boolean).map(([ref, g]) => ({ ref, g })),
      overlay: preset.overlay || null,
      katalogRef: preset.katalogRef || 'standorte',
      katalogGroesse: preset.katalogGroesse || '2x2',
      drag: null,
      undo: null,
      resizeDemo: preset.resizeDemo || null,
    };
    const screen = root.querySelector('.screen');
    const body = root.querySelector('.body');

    function katalogHtml(ctx) {
      const bereiche = [...new Set(K.KATALOG.map((w) => w.bereich))];
      const eintrag = (w) => {
        const g = w.groessen[w.groessen.length > 1 && w.groessen[0] === '1x1' ? 1 : 0];
        return `<div class="kat-item" data-aktion="waehle" data-ref="${w.id}">
          <div class="thumb"><div class="thumb-in"><div class="kgrid">${K.kachel(ctx, w.id, g)}</div></div></div>
          <div class="kat-text"><b>${esc(w.titel2 || w.titel)}</b><span>${groessenText(w)}</span></div><span class="chev">›</span></div>`;
      };
      return `<div class="dim" data-aktion="schliessen"></div><div class="sheet kat">
        <div class="grabber"></div><div class="sheet-title">Kachel hinzufügen</div>
        ${R3 ? '<div class="foot muted center kat-hint">Auch die Kacheln aus „Stufen“ und „Entwicklung“ stehen für den Überblick bereit.</div>' : ''}
        <div class="kat-own" data-aktion="eigen"><span>＋</span><div><b>Eigene Kachel erstellen</b><br><small>Zählt Personen nach Filtern der Mitgliederliste</small></div><span class="chev">›</span></div>
        ${bereiche.map((b) => `<h4 class="sec">${esc(b)}</h4><div class="card nopad">${K.KATALOG.filter((w) => w.bereich === b).map(eintrag).join('')}</div>`).join('')}
      </div>`;
    }

    function detailHtml(ctx) {
      const w = K.katalogById[state.katalogRef];
      const g = w.groessen.includes(state.katalogGroesse) ? state.katalogGroesse : w.groessen[0];
      return `<div class="dim" data-aktion="schliessen"></div><div class="sheet kat">
        <div class="grabber"></div>
        <div class="sheet-nav"><span class="lnk" data-aktion="katalog">‹ Katalog</span><b>${esc(w.titel2 || w.titel)}</b><span></span></div>
        <div class="seg wide">${w.groessen.map((x) => `<i class="${x === g ? 'on' : ''}" data-aktion="groesse-waehlen" data-g="${x}">${x.replace('x', '×')}</i>`).join('')}</div>
        <div class="preview-box"><div class="kgrid">${K.kachel(ctx, w.id, g)}</div></div>
        <div class="foot muted center">${esc(BESCHREIBUNG[w.id] || '')}</div>
        <div class="btn" data-aktion="hinzufuegen">Hinzufügen</div>
      </div>`;
    }

    function eigenHtml(ctx) {
      const kachel = ctx.k.eigeneKacheln[0];
      return `<div class="dim" data-aktion="schliessen"></div><div class="sheet kat">
        <div class="grabber"></div>
        <div class="sheet-nav"><span class="lnk" data-aktion="katalog">‹ Katalog</span><b>Eigene Kachel</b><span></span></div>
        <label class="fld"><span>Name</span><div class="input">${esc(kachel.titel)}</div></label>
        <div class="fld"><span>Wer wird gezählt?</span>
          <div class="rule"><span>hat Rolle in Gruppe <b>Stammesvorstand</b> · beliebige Rolle</span><i>×</i></div>
          <div class="rule-add">＋ Bedingung</div>
          <div class="seg wide"><i class="on">alle Bedingungen</i><i>eine reicht</i></div></div>
        ${R3 ? '<div class="fld"><span>Darstellung</span><div class="seg wide"><i class="on">Zahl</i><i>nach Stufe</i></div></div>' : ''}
        <div class="fld row"><span>Zielwert</span><div class="stepper"><i>−</i><b>${kachel.ziel}</b><i>＋</i></div><em class="toggle on"></em></div>
        <div class="fld"><span>Vorschau · so erscheint die Kachel</span>
          <div class="preview-box"><div class="kgrid">${K.kachel(ctx, 'eigen:0', '1x1')}</div></div></div>
        <div class="btn" data-aktion="eigen-speichern">Kachel hinzufügen</div>
      </div>`;
    }

    function render() {
      const ctx = ctxFn();
      const bearbeiten = state.modus === 'bearbeiten';
      // Runde 3: Stufen und Entwicklung sind fest, lassen sich aber ausblenden.
      const tabZeile = R3
        ? `<div class="tab-edit"><span class="fix">Überblick</span>${[1, 2].map((t) => `<span class="${state.tabs[t] ? 'an' : 'aus'}" data-aktion="tab" data-tab="${t}">${['', 'Stufen', 'Entwicklung'][t]}<i>${state.tabs[t] ? '−' : '＋'}</i></span>`).join('')}</div>
          <div class="foot muted tab-hint">„Stufen“ und „Entwicklung“ sind fest zusammengestellt. Ausgeblendet verschwindet ihr Tab.</div>`
        : '';
      const leiste = bearbeiten
        ? `<div class="editbar"><span class="eb-add" data-aktion="katalog" title="Kachel hinzufügen">＋</span><b>Überblick bearbeiten</b><span class="eb-done" data-aktion="fertig">Fertig</span></div>${tabZeile}`
        : K.themenLeiste(0, state.tabs);
      const kacheln = state.tiles.map((t, i) => K.kachel(ctx, t.ref, t.g, { bearbeiten, index: i, klasse: state.drag === i ? 'dragging' : '' })).join('');
      const hinweis = bearbeiten
        ? '<div class="foot muted center">Kachel ziehen zum Sortieren · Ecke ziehen für die Größe · − entfernt</div>'
        : '<div class="adjust"><span data-aktion="bearbeiten">✎ Bearbeiten</span></div>';
      const toast = state.undo ? '<div class="toast">Kachel entfernt <span data-aktion="rueckgaengig">Rückgängig</span></div>' : '';
      body.innerHTML = `${leiste}<div class="kgrid${bearbeiten ? ' edit' : ''}">${kacheln}</div>${hinweis}`;
      screen.querySelectorAll('.overlay, .toast').forEach((el) => el.remove());
      if (toast) screen.insertAdjacentHTML('beforeend', toast);
      const ov = state.overlay === 'katalog' ? katalogHtml(ctx) : state.overlay === 'detail' ? detailHtml(ctx) : state.overlay === 'eigen' ? eigenHtml(ctx) : '';
      if (ov) screen.insertAdjacentHTML('beforeend', `<div class="overlay">${ov}</div>`);
      if (state.resizeDemo) {
        const el = body.querySelector(`.tile[data-ref="${state.resizeDemo.ref}"]`);
        if (el) zeigeGeist(el, state.resizeDemo.g);
      }
    }

    function zeigeGeist(tileEl, g) {
      const grid = tileEl.parentElement;
      let geist = grid.querySelector('.resize-ghost');
      if (!geist) {
        geist = document.createElement('div');
        geist.className = 'resize-ghost';
        grid.appendChild(geist);
      }
      const [c, r] = g.split('x').map(Number);
      const links = c === 2 ? 0 : tileEl.offsetLeft;
      geist.style.left = `${links}px`;
      geist.style.top = `${tileEl.offsetTop}px`;
      geist.style.width = `${c * K.SPALTE + (c - 1) * K.LUECKE}px`;
      geist.style.height = `${r * K.ZEILE + (r - 1) * K.LUECKE}px`;
      geist.dataset.g = g.replace('x', '×');
      return geist;
    }

    root.addEventListener('click', (e) => {
      const el = e.target.closest('[data-aktion]');
      if (!el || !root.contains(el)) return;
      const aktion = el.dataset.aktion;
      const tileEl = el.closest('.tile');
      state.resizeDemo = null;
      if (aktion === 'bearbeiten') state.modus = 'bearbeiten';
      else if (aktion === 'tab') state.tabs[Number(el.dataset.tab)] = !state.tabs[Number(el.dataset.tab)];
      else if (aktion === 'fertig') { state.modus = 'ansicht'; state.overlay = null; state.undo = null; }
      else if (aktion === 'entfernen' && tileEl) {
        const i = Number(tileEl.dataset.i);
        state.undo = { t: state.tiles[i], i };
        state.tiles.splice(i, 1);
      } else if (aktion === 'rueckgaengig' && state.undo) {
        state.tiles.splice(state.undo.i, 0, state.undo.t);
        state.undo = null;
      } else if (aktion === 'katalog') state.overlay = 'katalog';
      else if (aktion === 'schliessen') state.overlay = null;
      else if (aktion === 'waehle') {
        state.katalogRef = el.dataset.ref;
        const w = K.katalogById[state.katalogRef];
        state.katalogGroesse = w.groessen[w.groessen.length > 1 && w.groessen[0] === '1x1' ? 1 : 0];
        state.overlay = 'detail';
      } else if (aktion === 'groesse-waehlen') state.katalogGroesse = el.dataset.g;
      else if (aktion === 'hinzufuegen') {
        state.tiles.push({ ref: state.katalogRef, g: state.katalogGroesse });
        state.overlay = null;
        state.modus = 'bearbeiten';
      } else if (aktion === 'eigen') state.overlay = 'eigen';
      else if (aktion === 'eigen-speichern') {
        state.tiles.push({ ref: 'eigen:0', g: '1x1' });
        state.overlay = null;
        state.modus = 'bearbeiten';
      } else return;
      render();
      if (aktion === 'hinzufuegen' || aktion === 'eigen-speichern') body.scrollTop = body.scrollHeight;
    });

    root.addEventListener('pointerdown', (e) => {
      if (state.modus !== 'bearbeiten' || state.overlay) return;
      const tileEl = e.target.closest('.kgrid .tile');
      if (!tileEl || e.target.closest('.k-minus')) return;
      state.resizeDemo = null;
      if (e.target.closest('.k-resize')) groesseZiehen(e, tileEl);
      else sortieren(e, tileEl);
    });

    function sortieren(e, tileEl) {
      const sr = screen.getBoundingClientRect();
      const tr = tileEl.getBoundingClientRect();
      const offX = e.clientX - tr.left;
      const offY = e.clientY - tr.top;
      const sx = e.clientX;
      const sy = e.clientY;
      let klon = null;
      function move(ev) {
        if (!klon) {
          if (Math.hypot(ev.clientX - sx, ev.clientY - sy) < 5) return;
          state.drag = Number(tileEl.dataset.i);
          klon = tileEl.cloneNode(true);
          klon.classList.add('klon');
          klon.style.width = `${tr.width}px`;
          klon.style.height = `${tr.height}px`;
          screen.appendChild(klon);
          render();
        }
        klon.style.left = `${ev.clientX - sr.left - offX}px`;
        klon.style.top = `${ev.clientY - sr.top - offY}px`;
        const unter = document.elementFromPoint(ev.clientX, ev.clientY);
        const ziel = unter && unter.closest('.kgrid .tile');
        if (!ziel || ziel.dataset.i === undefined) return;
        const j = Number(ziel.dataset.i);
        if (j === state.drag) return;
        // Nur im inneren Bereich tauschen, sonst springt es hin und her.
        const zr = ziel.getBoundingClientRect();
        const fx = (ev.clientX - zr.left) / zr.width;
        const fy = (ev.clientY - zr.top) / zr.height;
        if (fx < 0.2 || fx > 0.8 || fy < 0.2 || fy > 0.8) return;
        const [t] = state.tiles.splice(state.drag, 1);
        state.tiles.splice(j, 0, t);
        state.drag = j;
        render();
      }
      function up() {
        window.removeEventListener('pointermove', move);
        window.removeEventListener('pointerup', up);
        if (klon) klon.remove();
        state.drag = null;
        render();
      }
      window.addEventListener('pointermove', move);
      window.addEventListener('pointerup', up);
    }

    function groesseZiehen(e, tileEl) {
      e.preventDefault();
      const i = Number(tileEl.dataset.i);
      const t = state.tiles[i];
      const w = K.widgetFuer(ctxFn(), t.ref);
      const tr = tileEl.getBoundingClientRect();
      let ziel = t.g;
      zeigeGeist(tileEl, ziel);
      function move(ev) {
        const breite = tr.width + (ev.clientX - e.clientX);
        const hoehe = tr.height + (ev.clientY - e.clientY);
        ziel = naechsteGroesse(w, breite > K.SPALTE * 1.4 ? 2 : 1, hoehe > K.ZEILE * 1.4 ? 2 : 1);
        zeigeGeist(tileEl, ziel);
      }
      function up() {
        window.removeEventListener('pointermove', move);
        window.removeEventListener('pointerup', up);
        t.g = ziel;
        render();
      }
      window.addEventListener('pointermove', move);
      window.addEventListener('pointerup', up);
    }

    render();
    return state;
  }

  window.BEARBEITEN = { editor, BESCHREIBUNG };
})();
