import { a as attr } from "../../../chunks/attributes.js";
import { e as escape_html } from "../../../chunks/escaping.js";
function _page($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    let apiKey = "";
    $$renderer2.push(`<h1 class="svelte-1jef3w8">Admin</h1> <p class="subtitle svelte-1jef3w8">Platform configuration and diagnostics</p> <section class="card svelte-1jef3w8"><h2 class="svelte-1jef3w8">API Key</h2> <p class="help svelte-1jef3w8">The API key is stored in your browser's localStorage and sent as the <code class="svelte-1jef3w8">X-API-Key</code> header on every request.</p> <div class="key-row svelte-1jef3w8"><input type="text"${attr("value", apiKey)} class="key-input svelte-1jef3w8" autocomplete="off"/> <button class="save-btn svelte-1jef3w8">${escape_html("Save")}</button></div></section> <section class="card svelte-1jef3w8"><h2 class="svelte-1jef3w8">Sites</h2> `);
    {
      $$renderer2.push("<!--[0-->");
      $$renderer2.push(`<p class="loading svelte-1jef3w8">Loading…</p>`);
    }
    $$renderer2.push(`<!--]--></section> <section class="card svelte-1jef3w8"><h2 class="svelte-1jef3w8">Quick Links</h2> <ul class="links svelte-1jef3w8"><li><a href="/docs" target="_blank" rel="noreferrer" class="svelte-1jef3w8">API Documentation (Swagger UI)</a></li> <li><a href="/redoc" target="_blank" rel="noreferrer" class="svelte-1jef3w8">API Documentation (ReDoc)</a></li> <li><a href="http://localhost:3000" target="_blank" rel="noreferrer" class="svelte-1jef3w8">Grafana Operator Dashboards</a></li></ul></section>`);
  });
}
export {
  _page as default
};
