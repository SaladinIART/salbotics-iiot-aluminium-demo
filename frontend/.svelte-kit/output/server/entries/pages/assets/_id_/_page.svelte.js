import { s as store_get, u as unsubscribe_stores } from "../../../../chunks/renderer.js";
import { p as page } from "../../../../chunks/stores.js";
/* empty css                                                          */
function _page($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    var $$store_subs;
    store_get($$store_subs ??= {}, "$page", page).params.id;
    $$renderer2.push(`<a class="back svelte-1p7tsxq" href="/assets">← Assets</a> `);
    {
      $$renderer2.push("<!--[0-->");
      $$renderer2.push(`<p class="loading svelte-1p7tsxq">Loading…</p>`);
    }
    $$renderer2.push(`<!--]-->`);
    if ($$store_subs) unsubscribe_stores($$store_subs);
  });
}
export {
  _page as default
};
