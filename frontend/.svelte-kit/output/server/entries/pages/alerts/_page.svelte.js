import { e as ensure_array_like, a as attr_class } from "../../../chunks/renderer.js";
import { e as escape_html } from "../../../chunks/escaping.js";
function _page($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    let alerts = [];
    let filter = "OPEN";
    $$renderer2.push(`<div class="page-header svelte-dpbch8"><div><h1 class="svelte-dpbch8">Alerts</h1> <p class="subtitle svelte-dpbch8">${escape_html(alerts.length)} alert${escape_html(alerts.length !== 1 ? "s" : "")} shown</p></div> <div class="filters svelte-dpbch8"><!--[-->`);
    const each_array = ensure_array_like(["OPEN", "ACKED", "CLOSED", "ALL"]);
    for (let $$index = 0, $$length = each_array.length; $$index < $$length; $$index++) {
      let s = each_array[$$index];
      $$renderer2.push(`<button${attr_class("filter-btn svelte-dpbch8", void 0, { "active": filter === s })}>${escape_html(s)}</button>`);
    }
    $$renderer2.push(`<!--]--></div></div> `);
    {
      $$renderer2.push("<!--[-1-->");
    }
    $$renderer2.push(`<!--]--> `);
    {
      $$renderer2.push("<!--[0-->");
      $$renderer2.push(`<p class="loading svelte-dpbch8">Loading…</p>`);
    }
    $$renderer2.push(`<!--]-->`);
  });
}
export {
  _page as default
};
