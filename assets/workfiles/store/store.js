// Bausteine für screenshot.html und feature-graphic.html.
window.StoreRender = (() => {
  // Verhindert, dass der Browser nach neuen Rohscreens alte Bilder zeigt.
  const bust = `?t=${Date.now()}`;
  const RAW_RATIO = { iphone: 2868 / 1320, ipad: 2752 / 2064 };

  // Maße in Pixeln des jeweiligen Zielformats.
  const LAYOUT = {
    iphone: { screenW: 900, bezel: 22, radius: 150, bottom: 80, pt: 440 },
    ipad: { screenW: 1440, bezel: 32, radius: 66, bottom: 80, pt: 1032 },
    play: { cardW: 660, radius: 44, bottom: 70, cropTop: 62 / 956 },
  };

  const signal = (h) => `<svg height="${h}" viewBox="0 0 18 12"><rect x="0" y="8" width="3" height="4" rx="1"/><rect x="5" y="5.5" width="3" height="6.5" rx="1"/><rect x="10" y="3" width="3" height="9" rx="1"/><rect x="15" y="0" width="3" height="12" rx="1"/></svg>`;
  const wifi = (h) => `<svg height="${h}" viewBox="0 0 16 12"><path d="M8 11.6 5.6 9.2a3.4 3.4 0 0 1 4.8 0L8 11.6Zm-4.2-4.2L2.1 5.7a8.4 8.4 0 0 1 11.8 0l-1.7 1.7a6 6 0 0 0-8.4 0ZM0.4 4 -1 2.6a11.4 11.4 0 0 1 18 0L15.6 4A9.4 9.4 0 0 0 .4 4Z" transform="translate(0 .2)"/></svg>`;
  const battery = (h) => `<svg height="${h}" viewBox="0 0 27 12"><rect x=".5" y=".5" width="23" height="11" rx="3.2" fill="none" stroke="#000" stroke-opacity=".4"/><rect x="2" y="2" width="20" height="8" rx="2"/><path d="M25 4v4a2 2 0 0 0 0-4Z" fill-opacity=".45"/></svg>`;

  function statusbar(target, screenW) {
    const s = screenW / LAYOUT[target].pt;
    if (target === 'iphone') {
      return `<div class="statusbar" style="height:${62 * s}px;padding:${6 * s}px ${34 * s}px 0 ${50 * s}px;font-size:${17 * s}px">
          <span style="width:${54 * s}px;text-align:center">9:41</span>
          <span class="icons" style="gap:${6 * s}px">${signal(12 * s)}${wifi(12 * s)}${battery(12.5 * s)}</span>
        </div>`;
    }
    return `<div class="statusbar" style="height:${24 * s}px;padding:0 ${22 * s}px;font-size:${12 * s}px">
        <span>9:41&nbsp;&nbsp;Di. 29. Sep.</span>
        <span class="icons" style="gap:${6 * s}px">${wifi(10 * s)}<span style="font-size:${12 * s}px">100 %</span>${battery(11 * s)}</span>
      </div>`;
  }

  // slide.split = [oben, unten] in Prozent: Lage der Trennlinie.
  function splitStyle(slide) {
    const [top, bottom] = slide.split || [62, 38];
    return `clip-path:polygon(${top}% 0,100% 0,100% 100%,${bottom}% 100%)`;
  }

  function screenLayer(target, scene, screenW, dark, slide) {
    return `<div class="screen-layer ${dark ? 'dark' : ''}" style="${dark ? splitStyle(slide) : ''}">
        <img class="raw" src="raw/${target}/${scene}.png${bust}" alt="">
        ${statusbar(target, screenW)}
      </div>`;
  }

  // slide.sceneDark: Bildschirm diagonal geteilt, rechts die Dunkel-Variante.
  function device(target, slide) {
    if (target === 'play') {
      const l = LAYOUT.play;
      const imgH = l.cardW * RAW_RATIO.iphone;
      const crop = imgH * l.cropTop;
      const img = (scene, dark) => `<div class="screen-layer ${dark ? 'dark' : ''}" style="${dark ? splitStyle(slide) : ''}">
          <img class="raw" src="raw/iphone/${scene}.png${bust}" style="margin-top:${-crop}px" alt=""></div>`;
      return `<div class="device" style="bottom:${l.bottom}px">
          <div class="play-card" style="width:${l.cardW}px;height:${imgH - crop}px;border-radius:${l.radius}px">
            ${img(slide.scene, false)}${slide.sceneDark ? img(slide.sceneDark, true) : ''}
          </div>
        </div>`;
    }
    const l = LAYOUT[target];
    const screenH = l.screenW * RAW_RATIO[target];
    const island = target === 'iphone'
      ? `<div class="island" style="top:${11 * l.screenW / l.pt}px;width:${126 * l.screenW / l.pt}px;height:${37 * l.screenW / l.pt}px"></div>`
      : '';
    return `<div class="device" style="bottom:${l.bottom}px">
        <div class="device-frame" style="padding:${l.bezel}px;border-radius:${l.radius}px">
          <div class="device-screen" style="width:${l.screenW}px;height:${screenH}px;border-radius:${l.radius - l.bezel}px">
            ${screenLayer(target, slide.scene, l.screenW, false, slide)}
            ${slide.sceneDark ? screenLayer(target, slide.sceneDark, l.screenW, true, slide) : ''}
            ${island}
          </div>
        </div>
      </div>`;
  }

  function watermark(size = 1500, right = -420, bottom = -260) {
    return `<img class="watermark" src="../../images/lilie.svg" alt=""
      style="width:${size}px;right:${right}px;bottom:${bottom}px;transform:rotate(-12deg)">`;
  }

  function defaultStyle() {
    try {
      return localStorage.getItem('store-style') || 'navy';
    } catch (_) {
      return 'navy';
    }
  }

  return { device, watermark, defaultStyle, bust };
})();
