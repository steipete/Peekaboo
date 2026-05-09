export function css() {
  return `
:root{
  --bg0:#07080a;
  --bg1:#0a0b0f;
  --bg2:#0e1020;
  --panel:rgba(255,255,255,0.045);
  --panel2:rgba(255,255,255,0.075);
  --line:rgba(255,255,255,0.10);
  --line-soft:rgba(255,255,255,0.05);
  --ink:rgba(255,255,255,0.96);
  --text:rgba(255,255,255,0.86);
  --muted:rgba(255,255,255,0.62);
  --subtle:rgba(255,255,255,0.42);
  --ecto:#00f5a0;
  --ecto2:#00c08f;
  --moon:#ffd24a;
  --hot:#ff3d78;
  --accent:var(--ecto);
  --accent-soft:rgba(0,245,160,0.14);
  --accent-strong:#3affba;
  --paper:rgba(255,255,255,0.03);
  --code-bg:#06080d;
  --code-fg:#e6edf3;
  --code-border:rgba(255,255,255,0.08);
  --shadow-card:0 18px 40px rgba(0,0,0,0.55);
  --hl-keyword:#7aa2ff;
  --hl-string:#a6e3a1;
  --hl-number:#f0a868;
  --hl-comment:#6b7388;
  --hl-flag:#c4a4ff;
  --hl-meta:#ff8aa0;
  --hl-prompt:#7e8ba3;
  --glow-primary:rgba(0,245,160,0.10);
  --glow-secondary:rgba(255,210,74,0.07);
  --chrome-bg:rgba(7,8,10,0.85);
  --chrome-bg-solid:rgba(7,8,10,0.96);
  --toggle-bg:rgba(7,8,10,0.8);
  --selection-fg:#04130c;
  --mark-core:#04130c;
  --mark-glint:rgba(255,255,255,0.2);
  --pre-scrollbar:#334155;
  --copy-bg:rgba(255,255,255,.06);
  --copy-border:rgba(255,255,255,.16);
  --mobile-shadow:0 18px 40px rgba(0,0,0,.45);
  --serif:"Fraunces",ui-serif,Georgia,serif;
  --sans:"Recursive",ui-sans-serif,system-ui,-apple-system,"Segoe UI",sans-serif;
  --mono:"JetBrains Mono",ui-monospace,SFMono-Regular,Menlo,monospace;
  color-scheme:dark;
}
html[data-theme="light"]{
  --bg0:#f7faf8;
  --bg1:#eef5f1;
  --bg2:#e8eef8;
  --panel:rgba(8,24,20,0.055);
  --panel2:rgba(8,24,20,0.085);
  --line:rgba(8,24,20,0.14);
  --line-soft:rgba(8,24,20,0.07);
  --ink:#08120f;
  --text:rgba(8,18,15,0.84);
  --muted:rgba(8,18,15,0.60);
  --subtle:rgba(8,18,15,0.42);
  --ecto:#007f61;
  --ecto2:#006f59;
  --moon:#b67800;
  --hot:#c83264;
  --accent:var(--ecto);
  --accent-soft:rgba(0,127,97,0.12);
  --accent-strong:#00684f;
  --paper:rgba(8,24,20,0.035);
  --code-bg:#10151d;
  --code-fg:#eef6f2;
  --code-border:rgba(8,24,20,0.12);
  --shadow-card:0 18px 40px rgba(8,24,20,0.14);
  --hl-keyword:#7aa2ff;
  --hl-string:#95d98f;
  --hl-number:#f0a868;
  --hl-comment:#8790a2;
  --hl-flag:#c4a4ff;
  --hl-meta:#ff8aa0;
  --hl-prompt:#9aa6ba;
  --glow-primary:rgba(0,127,97,0.13);
  --glow-secondary:rgba(182,120,0,0.10);
  --chrome-bg:rgba(247,250,248,0.88);
  --chrome-bg-solid:rgba(247,250,248,0.97);
  --toggle-bg:rgba(247,250,248,0.82);
  --selection-fg:#ffffff;
  --mark-core:#edfdf6;
  --mark-glint:rgba(8,18,15,0.24);
  --pre-scrollbar:#94a3b8;
  --copy-bg:rgba(255,255,255,.08);
  --copy-border:rgba(255,255,255,.18);
  --mobile-shadow:0 18px 40px rgba(8,24,20,.18);
  color-scheme:light;
}
*{box-sizing:border-box}
html{scroll-behavior:smooth;scroll-padding-top:24px}
body{
  margin:0;
  background:radial-gradient(1200px 600px at 70% -10%,var(--glow-primary),transparent 60%),
             radial-gradient(900px 500px at 0% 110%,var(--glow-secondary),transparent 55%),
             var(--bg0);
  color:var(--text);
  font-family:var(--sans);
  line-height:1.65;
  overflow-x:hidden;
  -webkit-font-smoothing:antialiased;
  font-feature-settings:"ss02","ss03";
}
::selection{background:var(--ecto);color:var(--selection-fg)}
a{color:var(--ecto);text-decoration:none;transition:color .12s,opacity .12s}
a:hover{opacity:.85;text-decoration:underline;text-underline-offset:.2em}

.shell{display:grid;grid-template-columns:280px minmax(0,1fr);min-height:100vh}
.sidebar{position:sticky;top:0;height:100vh;overflow:auto;padding:24px 22px;background:var(--chrome-bg);backdrop-filter:saturate(140%) blur(8px);border-right:1px solid var(--line);scrollbar-width:thin;scrollbar-color:var(--line) transparent}
.sidebar::-webkit-scrollbar{width:6px}
.sidebar::-webkit-scrollbar-thumb{background:var(--line);border-radius:6px}

.sidebar-head{display:flex;align-items:center;gap:10px;margin-bottom:24px}
.brand{display:flex;align-items:center;gap:11px;color:var(--ink);text-decoration:none;flex:1;min-width:0}
.brand:hover{text-decoration:none;opacity:1}
.brand .mark{display:flex;align-items:center;justify-content:center;width:32px;height:32px;border-radius:10px;background:radial-gradient(circle at 35% 25%,#00f5a0,#00c08f 60%,#04130c 100%);box-shadow:0 0 0 1px rgba(0,245,160,0.4),0 8px 18px rgba(0,245,160,0.25)}
.brand .mark::after{content:"";display:block;width:10px;height:10px;border-radius:50%;background:var(--mark-core);box-shadow:0 0 0 2px var(--mark-glint)}
.brand strong{display:block;font-family:var(--serif);font-size:1.15rem;line-height:1;font-weight:600;letter-spacing:0.01em;color:var(--ink)}
.brand small{display:block;color:var(--muted);font-size:.74rem;margin-top:4px;font-weight:400}

.theme-toggle{display:inline-flex;align-items:center;gap:7px;height:32px;border:1px solid var(--line);border-radius:8px;background:var(--panel);color:var(--text);font:600 .74rem/1 var(--sans);cursor:pointer;padding:0 9px;transition:border-color .15s,color .15s,background .15s}
.theme-toggle:hover{border-color:var(--ecto);color:var(--ink);background:var(--panel2)}
.theme-toggle:focus-visible{outline:0;box-shadow:0 0 0 3px var(--accent-soft);border-color:var(--ecto)}
.theme-toggle__icon{width:14px;height:14px;border-radius:50%;border:2px solid var(--moon);box-shadow:inset -4px -3px 0 var(--moon);transition:background .15s,box-shadow .15s,border-color .15s}
html[data-theme="light"] .theme-toggle__icon{background:var(--moon);box-shadow:0 0 0 3px rgba(182,120,0,.14);border-color:var(--moon)}

.search{display:block;margin:0 0 22px}
.search span{display:block;color:var(--muted);font-size:.7rem;font-weight:600;text-transform:uppercase;letter-spacing:0.06em;margin-bottom:7px}
.search input{width:100%;border:1px solid var(--line);background:var(--panel);border-radius:8px;padding:9px 12px;font:inherit;font-size:.9rem;color:var(--text);outline:none;transition:border-color .15s,box-shadow .15s}
.search input::placeholder{color:var(--subtle)}
.search input:focus{border-color:var(--ecto);box-shadow:0 0 0 3px var(--accent-soft)}

nav section{margin:0 0 18px}
nav h2{font-size:.66rem;color:var(--muted);text-transform:uppercase;letter-spacing:0.10em;margin:0 0 6px;font-weight:600}
.nav-link{display:block;color:var(--text);text-decoration:none;border-radius:6px;padding:5px 10px;margin:1px 0;font-size:.9rem;line-height:1.4;transition:background .12s,color .12s}
.nav-link:hover{background:var(--panel);color:var(--ink);text-decoration:none;opacity:1}
.nav-link.active{background:var(--accent-soft);color:var(--ecto);font-weight:600}

main{min-width:0;padding:32px clamp(20px,4.5vw,56px) 80px;max-width:1180px;margin:0 auto;width:100%}

.hero{display:flex;align-items:flex-end;justify-content:space-between;gap:22px;border-bottom:1px solid var(--line);padding:8px 0 22px;margin-bottom:8px;flex-wrap:wrap}
.hero-text{min-width:0;flex:1 1 320px}
.eyebrow{margin:0 0 8px;color:var(--ecto);font-weight:600;text-transform:uppercase;letter-spacing:0.10em;font-size:.7rem}
.hero h1{font-family:var(--serif);font-size:2.4rem;line-height:1.05;letter-spacing:0;margin:0;font-weight:600;color:var(--ink)}
.hero-meta{display:flex;gap:8px;flex:0 0 auto;flex-wrap:wrap}
.repo,.edit,.btn-ghost{border:1px solid var(--line);color:var(--text);text-decoration:none;border-radius:8px;padding:7px 12px;font-weight:500;font-size:.83rem;background:var(--panel);transition:border-color .15s,color .15s,background .15s}
.repo:hover,.edit:hover,.btn-ghost:hover{border-color:var(--ecto);color:var(--ink);text-decoration:none;opacity:1}
.edit{color:var(--muted)}

.doc-grid{display:grid;grid-template-columns:minmax(0,1fr);gap:48px;margin-top:24px}
@media(min-width:1180px){.doc-grid{grid-template-columns:minmax(0,72ch) 220px;justify-content:start}}
.doc{min-width:0;max-width:72ch;overflow-wrap:break-word}
.doc h1{font-family:var(--serif);font-size:2.6rem;line-height:1.08;letter-spacing:0;margin:0 0 .4em;font-weight:600;color:var(--ink)}
body:not(.home) .doc>h1:first-child{display:none}
.doc h2{font-family:var(--serif);font-size:1.55rem;line-height:1.2;margin:2em 0 .5em;font-weight:600;letter-spacing:0;color:var(--ink);position:relative}
.doc h3{font-family:var(--serif);font-size:1.2rem;margin:1.7em 0 .35em;position:relative;font-weight:600;color:var(--ink);letter-spacing:0}
.doc h4{font-size:1rem;margin:1.4em 0 .25em;color:var(--ink);position:relative;font-weight:600}
.doc h2:first-child,.doc h3:first-child,.doc h4:first-child{margin-top:.2em}
.doc :is(h2,h3,h4) .anchor{position:absolute;left:-1.05em;top:0;color:var(--subtle);opacity:0;text-decoration:none;font-weight:400;padding-right:.3em;transition:opacity .12s,color .12s}
.doc :is(h2,h3,h4):hover .anchor{opacity:.7}
.doc :is(h2,h3,h4) .anchor:hover{opacity:1;color:var(--ecto);text-decoration:none}
.doc p{margin:0 0 1.05em}
.doc ul,.doc ol{padding-left:1.3rem;margin:0 0 1.15em}
.doc li{margin:.25em 0}
.doc li>p{margin:0 0 .4em}
.doc strong{font-weight:600;color:var(--ink)}
.doc em{font-style:italic;color:var(--ink)}
.doc code{font-family:var(--mono);font-size:.84em;background:var(--panel);border:1px solid var(--line);border-radius:5px;padding:.08em .35em;color:var(--ink)}
.doc pre{position:relative;overflow:auto;background:var(--code-bg);color:var(--code-fg);border-radius:10px;padding:14px 18px;margin:1.3em 0;font-size:.85em;line-height:1.6;scrollbar-width:thin;scrollbar-color:var(--pre-scrollbar) transparent;border:1px solid var(--code-border)}
.doc pre::-webkit-scrollbar{height:8px;width:8px}
.doc pre::-webkit-scrollbar-thumb{background:var(--pre-scrollbar);border-radius:8px}
.doc pre code{display:block;background:transparent;border:0;color:inherit;padding:0;font-size:1em;white-space:pre}
.doc pre .copy{position:absolute;top:8px;right:8px;background:var(--copy-bg);color:var(--code-fg);border:1px solid var(--copy-border);border-radius:6px;padding:3px 9px;font:500 .7rem/1 var(--sans);cursor:pointer;opacity:0;transition:opacity .15s,background .15s,border-color .15s}
.doc pre:hover .copy,.doc pre .copy:focus{opacity:1}
.doc pre .copy:hover{background:rgba(255,255,255,.12)}
.doc pre .copy.copied{background:var(--ecto);border-color:var(--ecto);color:var(--selection-fg);opacity:1}
.doc pre .hl-c{color:var(--hl-comment);font-style:italic}
.doc pre .hl-s{color:var(--hl-string)}
.doc pre .hl-n{color:var(--hl-number)}
.doc pre .hl-k{color:var(--hl-keyword);font-weight:600}
.doc pre .hl-f{color:var(--hl-flag)}
.doc pre .hl-m{color:var(--hl-meta);font-weight:600}
.doc pre .hl-p{color:var(--hl-prompt);user-select:none}
.doc pre .hl-cmd{color:var(--ecto);font-weight:600}
.doc blockquote{margin:1.4em 0;padding:10px 16px;border-left:3px solid var(--ecto);background:var(--accent-soft);border-radius:0 8px 8px 0;color:var(--text)}
.doc blockquote p:last-child{margin-bottom:0}
.doc table{width:100%;border-collapse:collapse;margin:1.2em 0;font-size:.92em}
.doc th,.doc td{border-bottom:1px solid var(--line);padding:9px 10px;text-align:left;vertical-align:top}
.doc th{font-weight:600;color:var(--ink);background:var(--panel);border-bottom:1px solid var(--line)}
.doc hr{border:0;border-top:1px solid var(--line);margin:2.2em 0}

.toc{position:sticky;top:24px;align-self:start;font-size:.84rem;padding-left:14px;border-left:1px solid var(--line);max-height:calc(100vh - 48px);overflow:auto;scrollbar-width:thin;scrollbar-color:var(--line) transparent}
.toc::-webkit-scrollbar{width:5px}
.toc::-webkit-scrollbar-thumb{background:var(--line);border-radius:5px}
.toc h2{font-size:.66rem;color:var(--muted);text-transform:uppercase;letter-spacing:0.10em;margin:0 0 10px;font-weight:600}
.toc a{display:block;color:var(--muted);text-decoration:none;padding:4px 0 4px 10px;line-height:1.35;border-left:2px solid transparent;margin-left:-12px;transition:color .12s,border-color .12s}
.toc a:hover{color:var(--ink);text-decoration:none;opacity:1}
.toc a.active{color:var(--ecto);border-left-color:var(--ecto);font-weight:500}
.toc-l3{padding-left:22px!important;font-size:.94em}
@media(max-width:1179px){.toc{display:none}}

.page-nav{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-top:48px;border-top:1px solid var(--line);padding-top:20px}
.page-nav>a{display:block;border:1px solid var(--line);background:var(--panel);border-radius:10px;padding:13px 16px;text-decoration:none;color:var(--text);transition:border-color .15s,transform .15s,background .18s}
.page-nav>a:hover{border-color:var(--ecto);text-decoration:none;color:var(--ink);opacity:1}
.page-nav small{display:block;color:var(--muted);font-size:.7rem;text-transform:uppercase;letter-spacing:0.10em;margin-bottom:5px;font-weight:600}
.page-nav span{display:block;font-weight:600;line-height:1.3;color:var(--ink)}
.page-nav-prev{text-align:left}
.page-nav-next{text-align:right;grid-column:2}
.page-nav-prev:only-child{grid-column:1}

.nav-toggle{display:none;position:fixed;top:14px;right:14px;top:calc(14px + env(safe-area-inset-top, 0px));right:calc(14px + env(safe-area-inset-right, 0px));z-index:20;width:42px;height:42px;border-radius:10px;background:var(--toggle-bg);backdrop-filter:blur(10px);border:1px solid var(--line);color:var(--ink);cursor:pointer;padding:11px 10px;flex-direction:column;align-items:stretch;justify-content:space-between}
.nav-toggle span{display:block;width:100%;height:2px;flex:0 0 2px;background:currentColor;border-radius:2px;transition:transform .2s,opacity .2s}
.nav-toggle[aria-expanded="true"] span:nth-child(1){transform:translateY(8px) rotate(45deg)}
.nav-toggle[aria-expanded="true"] span:nth-child(2){opacity:0}
.nav-toggle[aria-expanded="true"] span:nth-child(3){transform:translateY(-8px) rotate(-45deg)}
@media(max-width:900px){
  .shell{display:block}
  .sidebar{position:fixed;inset:0 30% 0 0;max-width:320px;height:100vh;z-index:15;transform:translateX(-100%);transition:transform .25s ease;box-shadow:var(--mobile-shadow);background:var(--chrome-bg-solid);pointer-events:none}
  .sidebar.open{transform:translateX(0);pointer-events:auto}
  .nav-toggle{display:flex}
  main{padding:64px 18px 56px}
  .hero{padding-top:6px}
  .hero h1{font-size:1.9rem}
  .doc h1{font-size:2.1rem}
  .hero-meta{width:100%;justify-content:flex-start}
  .doc{padding:0}
  .doc-grid{margin-top:18px;gap:24px}
  .doc :is(h2,h3,h4) .anchor{display:none}
}
@media(max-width:520px){
  main{padding:60px 14px 48px}
  .doc pre{margin-left:-14px;margin-right:-14px;border-radius:0;border-left:0;border-right:0}
}
`;
}

export function js() {
  return `
const root=document.documentElement;
const themeToggle=document.querySelector('[data-theme-toggle]');
const themeLabel=document.querySelector('[data-theme-label]');
const themeMedia=window.matchMedia('(prefers-color-scheme: light)');
function storedTheme(){try{const theme=localStorage.getItem('peekaboo-theme');return theme==='light'||theme==='dark'?theme:null}catch{return null}}
function systemTheme(){return themeMedia.matches?'light':'dark'}
function applyTheme(theme){
  root.dataset.theme=theme;
  if(themeLabel)themeLabel.textContent=theme==='light'?'Light':'Dark';
  themeToggle?.setAttribute('aria-pressed',theme==='dark'?'true':'false');
}
applyTheme(root.dataset.theme||storedTheme()||systemTheme());
themeToggle?.addEventListener('click',()=>{
  const next=root.dataset.theme==='dark'?'light':'dark';
  try{localStorage.setItem('peekaboo-theme',next)}catch{}
  applyTheme(next);
});
const syncSystemTheme=()=>{if(!storedTheme())applyTheme(systemTheme())};
if(themeMedia.addEventListener)themeMedia.addEventListener('change',syncSystemTheme);
else themeMedia.addListener?.(syncSystemTheme);
const sidebar=document.querySelector('.sidebar');
const toggle=document.querySelector('.nav-toggle');
const mobileNav=window.matchMedia('(max-width: 900px)');
const sidebarFocusable='a[href],button,input,select,textarea,[tabindex]';
function setSidebarFocusable(enabled){
  sidebar?.querySelectorAll(sidebarFocusable).forEach((el)=>{
    if(enabled){
      if(el.dataset.sidebarTabindex!==undefined){
        if(el.dataset.sidebarTabindex)el.setAttribute('tabindex',el.dataset.sidebarTabindex);
        else el.removeAttribute('tabindex');
        delete el.dataset.sidebarTabindex;
      }
    }else if(el.dataset.sidebarTabindex===undefined){
      el.dataset.sidebarTabindex=el.getAttribute('tabindex')??'';
      el.setAttribute('tabindex','-1');
    }
  });
}
function setSidebarOpen(open){
  if(!sidebar||!toggle)return;
  sidebar.classList.toggle('open',open);
  toggle.setAttribute('aria-expanded',open?'true':'false');
  if(mobileNav.matches){
    sidebar.inert=!open;
    if(open)sidebar.removeAttribute('aria-hidden');
    else sidebar.setAttribute('aria-hidden','true');
    setSidebarFocusable(open);
  }else{
    sidebar.inert=false;
    sidebar.removeAttribute('aria-hidden');
    setSidebarFocusable(true);
  }
}
setSidebarOpen(false);
toggle?.addEventListener('click',()=>setSidebarOpen(!sidebar?.classList.contains('open')));
document.addEventListener('click',(e)=>{if(!sidebar?.classList.contains('open'))return;if(sidebar.contains(e.target)||toggle?.contains(e.target))return;setSidebarOpen(false)});
document.addEventListener('keydown',(e)=>{if(e.key==='Escape')setSidebarOpen(false)});
const syncSidebarForViewport=()=>setSidebarOpen(sidebar?.classList.contains('open')??false);
if(mobileNav.addEventListener)mobileNav.addEventListener('change',syncSidebarForViewport);
else mobileNav.addListener?.(syncSidebarForViewport);
const input=document.getElementById('doc-search');
input?.addEventListener('input',()=>{const q=input.value.trim().toLowerCase();document.querySelectorAll('nav section').forEach(sec=>{let any=false;sec.querySelectorAll('.nav-link').forEach(a=>{const m=!q||a.textContent.toLowerCase().includes(q);a.style.display=m?'block':'none';if(m)any=true});sec.style.display=any?'block':'none'})});
function attachCopy(target,getText){const btn=document.createElement('button');btn.type='button';btn.className='copy';btn.textContent='Copy';btn.addEventListener('click',async()=>{try{await navigator.clipboard.writeText(getText());btn.textContent='Copied';btn.classList.add('copied');setTimeout(()=>{btn.textContent='Copy';btn.classList.remove('copied')},1400)}catch{btn.textContent='Failed';setTimeout(()=>{btn.textContent='Copy'},1400)}});target.appendChild(btn)}
document.querySelectorAll('.doc pre').forEach(pre=>attachCopy(pre,()=>pre.querySelector('code')?.textContent??''));
const tocLinks=document.querySelectorAll('.toc a');
if(tocLinks.length){const map=new Map();tocLinks.forEach(a=>{const id=a.getAttribute('href').slice(1);const el=document.getElementById(id);if(el)map.set(el,a)});const setActive=l=>{tocLinks.forEach(x=>x.classList.remove('active'));l.classList.add('active')};const obs=new IntersectionObserver(entries=>{const visible=entries.filter(e=>e.isIntersecting).sort((a,b)=>a.boundingClientRect.top-b.boundingClientRect.top);if(visible.length){const link=map.get(visible[0].target);if(link)setActive(link)}},{rootMargin:'-15% 0px -65% 0px',threshold:0});map.forEach((_,el)=>obs.observe(el))}
`;
}

export function faviconSvg() {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" role="img" aria-label="Peekaboo">
<defs>
<radialGradient id="g" cx="0.45" cy="0.32" r="0.65">
<stop offset="0" stop-color="#00f5a0"/>
<stop offset="0.6" stop-color="#00c08f"/>
<stop offset="1" stop-color="#053826"/>
</radialGradient>
</defs>
<rect width="64" height="64" rx="14" fill="#07080a"/>
<circle cx="32" cy="32" r="22" fill="url(#g)"/>
<circle cx="32" cy="32" r="10" fill="#04130c"/>
<circle cx="28" cy="28" r="3.6" fill="rgba(255,255,255,0.85)"/>
</svg>`;
}
