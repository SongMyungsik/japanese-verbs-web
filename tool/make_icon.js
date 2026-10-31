// 앱 아이콘을 그려 Android·웹·Windows·스토어용 파일로 내보낸다.
//   npm i puppeteer-core   (저장소에 넣지 않음)
//   node tool/make_icon.js <프로젝트 폴더> [--preview <폴더>]
// 글자는 앱의 NotoSansJP-subset.ttf로 그리므로 動·活이 글꼴에 있어야 한다.
const fs = require('fs'), path = require('path');
const puppeteer = require('puppeteer-core');

const root = path.resolve(process.argv[2] || '.');
const previewAt = process.argv.indexOf('--preview');
const previewDir = previewAt > 0 ? path.resolve(process.argv[previewAt + 1]) : null;
const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';

const font = fs.readFileSync(path.join(root, 'assets/fonts/NotoSansJP-subset.ttf')).toString('base64');

const BG = `<rect width="1024" height="1024" fill="url(#bg)"/>
  <rect width="1024" height="1024" fill="url(#glow)"/>`;

// 動과 도장 활자. 흑백(themed icon)은 도장 안의 活을 뚫어 표현한다.
function mark(mono) {
  const ink = mono ? '#fff' : 'url(#ink)';
  const seal = mono
    ? `<rect x="-132" y="-132" width="264" height="264" rx="44" fill="#fff" mask="url(#cut)"/>`
    : `<rect x="-132" y="-132" width="264" height="264" rx="44" fill="#2F3779"/>
       <rect x="-114" y="-114" width="228" height="228" rx="30" fill="url(#seal)"/>
       <text class="k s" y="66" font-size="176" text-anchor="middle" fill="#FFF7EF">活</text>`;
  return `<text class="k" x="462" y="722" font-size="660" text-anchor="middle" fill="${ink}">動</text>
    <g transform="translate(744 754) rotate(-6)">${seal}</g>`;
}

function svg({ size, bg = true, scale = 1, radius = 0, mono = false, content = true }) {
  const t = (1 - scale) * 512;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#3D4AA6"/><stop offset="1" stop-color="#232A63"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.22" cy="0.14" r="0.8">
      <stop offset="0" stop-color="#8E9BF0" stop-opacity="0.5"/>
      <stop offset="1" stop-color="#8E9BF0" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="ink" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#DDE2FF"/>
    </linearGradient>
    <linearGradient id="seal" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#F0654A"/><stop offset="1" stop-color="#CF3A2B"/>
    </linearGradient>
    <mask id="cut">
      <rect x="-132" y="-132" width="264" height="264" fill="#fff"/>
      <text class="k s" y="66" font-size="176" text-anchor="middle" fill="#000">活</text>
    </mask>
    <clipPath id="round"><rect width="1024" height="1024" rx="${radius}"/></clipPath>
  </defs>
  <g clip-path="url(#round)">
    ${bg ? BG : ''}
    ${content ? `<g transform="translate(${t} ${t}) scale(${scale})">${mark(mono)}</g>` : ''}
  </g>
</svg>`;
}

const html = s => `<!doctype html><meta charset="utf-8"><style>
@font-face { font-family: Noto; src: url(data:font/ttf;base64,${font}); font-weight: 100 900; }
html, body { margin: 0; background: transparent; }
svg { display: block; }
.k { font-family: Noto; font-weight: 600; }
.s { font-weight: 800; }
</style>${s}`;

const browser_ = puppeteer.launch({ executablePath: CHROME, headless: true });

async function render(opts) {
  const browser = await browser_;
  const page = await browser.newPage();
  await page.setViewport({ width: opts.size, height: opts.size });
  await page.setContent(html(svg(opts)));
  await page.evaluate(async () => { await document.fonts.load('600 100px Noto', '動活'); await document.fonts.ready; });
  const png = await page.screenshot({ omitBackground: true, clip: { x: 0, y: 0, width: opts.size, height: opts.size } });
  await page.close();
  return Buffer.from(png);
}

async function out(file, opts) {
  const f = path.join(root, file);
  fs.mkdirSync(path.dirname(f), { recursive: true });
  fs.writeFileSync(f, await render(opts));
}

// 여러 크기의 PNG를 그대로 담은 .ico
function ico(pngs) {
  const head = Buffer.alloc(6 + 16 * pngs.length);
  head.writeUInt16LE(1, 2);
  head.writeUInt16LE(pngs.length, 4);
  let offset = head.length;
  pngs.forEach(([size, data], i) => {
    const at = 6 + 16 * i;
    head[at] = size % 256;
    head[at + 1] = size % 256;
    head.writeUInt16LE(1, at + 4);
    head.writeUInt16LE(32, at + 6);
    head.writeUInt32LE(data.length, at + 8);
    head.writeUInt32LE(offset, at + 12);
    offset += data.length;
  });
  return Buffer.concat([head, ...pngs.map(p => p[1])]);
}

const ROUND = 228; // 일반 아이콘의 둥근 모서리
const FULL = { scale: 0.92, radius: ROUND };
const ADAPTIVE = 0.6; // Android는 가운데 66/108만 항상 보인다
const MASKABLE = 0.76; // 웹 maskable은 가운데 80% 원이 안전 영역

(async () => {
  if (previewDir) {
    fs.mkdirSync(previewDir, { recursive: true });
    const cases = {
      full: { size: 512, ...FULL }, adaptive: { size: 512, scale: ADAPTIVE },
      maskable: { size: 512, scale: MASKABLE },
      mono: { size: 512, bg: false, scale: ADAPTIVE, mono: true }, s48: { size: 48, ...FULL }, s32: { size: 32, ...FULL },
    };
    for (const [k, v] of Object.entries(cases)) fs.writeFileSync(path.join(previewDir, k + '.png'), await render(v));
    return (await browser_).close();
  }

  const res = 'android/app/src/main/res';
  for (const [dpi, size] of Object.entries({ mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 })) {
    const big = Math.round(size * 2.25); // 적응형 아이콘은 108dp 기준
    await out(`${res}/mipmap-${dpi}/ic_launcher.png`, { size, ...FULL });
    await out(`${res}/mipmap-${dpi}/ic_launcher_background.png`, { size: big, content: false });
    await out(`${res}/mipmap-${dpi}/ic_launcher_foreground.png`, { size: big, bg: false, scale: ADAPTIVE });
    await out(`${res}/mipmap-${dpi}/ic_launcher_monochrome.png`, { size: big, bg: false, scale: ADAPTIVE, mono: true });
  }
  fs.mkdirSync(path.join(root, `${res}/mipmap-anydpi-v26`), { recursive: true });
  fs.writeFileSync(path.join(root, `${res}/mipmap-anydpi-v26/ic_launcher.xml`),
    `<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
`);
  // 구글 플레이 등록용: 모서리는 스토어가 둥글게 깎으므로 꽉 채운다
  await out('store/play_icon_512.png', { size: 512, scale: 0.92 });

  if (fs.existsSync(path.join(root, 'web'))) {
    await out('web/favicon.png', { size: 32, ...FULL });
    await out('web/icons/Icon-192.png', { size: 192, ...FULL });
    await out('web/icons/Icon-512.png', { size: 512, ...FULL });
    await out('web/icons/Icon-maskable-192.png', { size: 192, scale: MASKABLE });
    await out('web/icons/Icon-maskable-512.png', { size: 512, scale: MASKABLE });
    // iOS는 투명한 부분을 검게 칠하므로 꽉 채운 그림을 따로 쓴다
    await out('web/icons/apple-touch-icon.png', { size: 180, scale: 0.92 });
  }

  const sizes = [16, 32, 48, 256];
  const pngs = [];
  for (const size of sizes) pngs.push([size, await render({ size, ...FULL })]);
  fs.writeFileSync(path.join(root, 'windows/runner/resources/app_icon.ico'), ico(pngs));

  await (await browser_).close();
})().catch(e => { console.error(e); process.exit(1); });
