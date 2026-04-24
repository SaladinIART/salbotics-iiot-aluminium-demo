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
    $$renderer2.push(`<section class="dashboard-page svelte-x1i5gj"><header class="page-header svelte-x1i5gj"><div><h1 class="svelte-x1i5gj">Executive Dashboard</h1> <p class="svelte-x1i5gj">Aluminium Profile Line 1 — Penang Plant 1</p></div> <div class="live-status svelte-x1i5gj"><span>Refreshes every 5s</span> `);
    {
      $$renderer2.push("<!--[1-->");
      $$renderer2.push(`<span class="status-chip status-chip--loading svelte-x1i5gj">Loading</span>`);
    }
    $$renderer2.push(`<!--]--></div></header> `);
    {
      $$renderer2.push("<!--[-1-->");
    }
    $$renderer2.push(`<!--]--> `);
    {
      $$renderer2.push("<!--[0-->");
      $$renderer2.push(`<div class="message message--loading svelte-x1i5gj"><div class="loading-glyph svelte-x1i5gj">[ ]</div> <div>Loading executive dashboard...</div></div>`);
    }
    $$renderer2.push(`<!--]--></section>`);
  });
}
export {
  _page as default
};
