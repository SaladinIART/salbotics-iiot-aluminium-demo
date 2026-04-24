import { a6 as head } from "../../../chunks/renderer.js";
import { o as onDestroy } from "../../../chunks/index-server.js";
function _page($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    let interval;
    onDestroy(() => {
      clearInterval(interval);
    });
    head("x1i5gj", $$renderer2, ($$renderer3) => {
      $$renderer3.title(($$renderer4) => {
        $$renderer4.push(`<title>Executive Dashboard — NEXUS IIoT</title>`);
      });
    });
    $$renderer2.push(`<div class="space-y-4"><div class="flex items-center justify-between"><div><h1 class="text-2xl font-bold text-white">Executive Dashboard</h1> <p class="text-sm text-gray-400">Aluminium Profile Line 1 — Penang Plant 1</p></div> <div class="text-xs text-gray-500">Refreshes every 5s `);
    {
      $$renderer2.push("<!--[1-->");
      $$renderer2.push(`· <span class="text-blue-400 animate-pulse">↻</span> Loading`);
    }
    $$renderer2.push(`<!--]--></div></div> `);
    {
      $$renderer2.push("<!--[-1-->");
    }
    $$renderer2.push(`<!--]--> `);
    {
      $$renderer2.push("<!--[0-->");
      $$renderer2.push(`<div class="text-center text-gray-500 py-16"><div class="text-4xl mb-3 animate-pulse">⚙</div> Loading executive dashboard…</div>`);
    }
    $$renderer2.push(`<!--]--></div>`);
  });
}
export {
  _page as default
};
