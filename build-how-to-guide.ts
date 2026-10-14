/**
 * Builds public/guides/Solar-Surge-Sales-Dojo-How-To-Guide.pdf from the Help & Guides content
 * (src/data/guide-sections.ts) and the screenshots in public/guides/, using headless Edge.
 *
 *   npm run guide:pdf
 */
import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { GUIDE_SECTIONS, GUIDE_TROUBLESHOOTING, GUIDE_UPDATED } from "../src/data/guide-sections";

const ROOT = path.resolve(import.meta.dirname, "..");
const OUT = path.join(ROOT, "public/guides/Solar-Surge-Sales-Dojo-How-To-Guide.pdf");
const EDGE = "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe";

const esc = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
const img = (p: string) => pathToFileURL(path.join(ROOT, "public", p)).href;

const AUDIENCES = ["Rep", "Manager", "Admin"] as const;
const AUDIENCE_TITLE = { Rep: "For reps", Manager: "For managers", Admin: "For admins" };

let n = 0;
const body = AUDIENCES.map((a) => {
  const sections = GUIDE_SECTIONS.filter((s) => s.audience === a);
  return `<h1 class="part">${AUDIENCE_TITLE[a]}</h1>
${sections
  .map(
    (s) => `<section>
  <p class="num">${String(++n).padStart(2, "0")} · ${s.audience}</p>
  <h2>${esc(s.title)}</h2>
  <p class="cap">${esc(s.caption)}</p>
  <img src="${img(s.screenshot)}" alt="">
  <ol>${s.steps.map((t) => `<li>${esc(t)}</li>`).join("")}</ol>
</section>`,
  )
  .join("\n")}`;
}).join("\n");

const html = `<!doctype html><html><head><meta charset="utf-8"><title>Solar Surge Sales Dojo: How-To Guide</title>
<style>
  @page { size: A4; margin: 14mm 14mm 16mm; }
  body { font-family: "Segoe UI", Arial, sans-serif; color: #0f1b2d; font-size: 10.5pt; line-height: 1.45; }
  .cover { height: 250mm; display: flex; flex-direction: column; justify-content: center; page-break-after: always; }
  .cover .kicker { font: 600 9pt Consolas, monospace; letter-spacing: .18em; color: #c77800; }
  .cover h1 { font-size: 32pt; margin: 8px 0 6px; }
  .cover p { color: #475569; max-width: 140mm; }
  .toc { columns: 2; font-size: 9.5pt; margin-top: 18px; }
  .toc div { break-inside: avoid; margin: 2px 0; }
  h1.part { font-size: 18pt; border-bottom: 3px solid #f29400; padding-bottom: 4px; page-break-before: always; }
  section { page-break-inside: avoid; margin: 0 0 10mm; }
  .num { font: 600 8pt Consolas, monospace; letter-spacing: .14em; color: #c77800; margin: 0; }
  h2 { font-size: 14pt; margin: 2px 0 2px; }
  .cap { color: #475569; margin: 0 0 6px; }
  img { width: 100%; border: 1px solid #d5dbe3; border-radius: 6px; }
  ol { margin: 8px 0 0; padding-left: 18px; }
  li { margin: 3px 0; }
  table { border-collapse: collapse; width: 100%; font-size: 9.5pt; }
  td { border-top: 1px solid #d5dbe3; padding: 6px 4px; vertical-align: top; }
  td:first-child { font-weight: 600; width: 38%; }
</style></head><body>
<div class="cover">
  <p class="kicker">SOLAR SURGE QLD ACADEMY</p>
  <h1>Sales Dojo how-to guide</h1>
  <p>Every screen of the platform, with a screenshot and the steps to use it, for reps, managers and admins. Updated ${GUIDE_UPDATED}.</p>
  <div class="toc">${(() => {
    let i = 0;
    return GUIDE_SECTIONS.map(
      (s) => `<div>${String(++i).padStart(2, "0")}&nbsp; ${esc(s.title)}</div>`,
    ).join("");
  })()}</div>
</div>
${body}
<h1 class="part">Troubleshooting</h1>
<table>${GUIDE_TROUBLESHOOTING.map((t) => `<tr><td>${esc(t.problem)}</td><td>${esc(t.fix)}</td></tr>`).join("")}</table>
<p style="margin-top:12px;color:#475569">Support: 1300 206 321 · Solar Surge HQ, Coomera QLD</p>
</body></html>`;

const dir = mkdtempSync(path.join(tmpdir(), "ss-guide-"));
const file = path.join(dir, "guide.html");
writeFileSync(file, html);
execFileSync(EDGE, [
  "--headless",
  "--disable-gpu",
  "--no-pdf-header-footer",
  "--allow-file-access-from-files",
  `--print-to-pdf=${OUT}`,
  pathToFileURL(file).href,
]);
console.log(`Wrote ${path.relative(ROOT, OUT)} (${GUIDE_SECTIONS.length} sections)`);
