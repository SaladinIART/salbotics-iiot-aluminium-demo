import { s as store_get, e as ensure_array_like, u as unsubscribe_stores, c as bind_props } from "../../chunks/renderer.js";
/* empty css                                                   */
/* empty css                                                    */
import { s as selectedSite, a as assetMap } from "../../chunks/stores2.js";
import { e as escape_html } from "../../chunks/escaping.js";
import { f as fallback } from "../../chunks/attributes.js";
function SiteSelector($$renderer, $$props) {
  var $$store_subs;
  let sites = fallback($$props["sites"], () => [], true);
  $$renderer.push(`<div class="site-selector svelte-3bch42"><label for="site-select" class="svelte-3bch42">Site</label> `);
  $$renderer.select(
    {
      id: "site-select",
      value: store_get($$store_subs ??= {}, "$selectedSite", selectedSite),
      class: ""
    },
    ($$renderer2) => {
      $$renderer2.option({ value: "all" }, ($$renderer3) => {
        $$renderer3.push(`All sites`);
      });
      $$renderer2.push(`<!--[-->`);
      const each_array = ensure_array_like(sites);
      for (let $$index = 0, $$length = each_array.length; $$index < $$length; $$index++) {
        let site = each_array[$$index];
        $$renderer2.option({ value: site.site_id }, ($$renderer3) => {
          $$renderer3.push(`${escape_html(site.display_name)}`);
        });
      }
      $$renderer2.push(`<!--]-->`);
    },
    "svelte-3bch42"
  );
  $$renderer.push(`</div>`);
  if ($$store_subs) unsubscribe_stores($$store_subs);
  bind_props($$props, { sites });
}
function _page($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    var $$store_subs;
    let sites = [];
    Array.from(store_get($$store_subs ??= {}, "$assetMap", assetMap).values()).filter((a) => store_get($$store_subs ??= {}, "$selectedSite", selectedSite) === "all" || a.site === store_get($$store_subs ??= {}, "$selectedSite", selectedSite));
    $$renderer2.push(`<div class="page-header svelte-1uha8ag"><div><h1 class="svelte-1uha8ag">Floor Overview</h1> <p class="subtitle svelte-1uha8ag">Live asset status — updates every 2 seconds via SSE</p></div> `);
    SiteSelector($$renderer2, { sites });
    $$renderer2.push(`<!----></div> `);
    {
      $$renderer2.push("<!--[0-->");
      $$renderer2.push(`<p class="loading svelte-1uha8ag">Loading assets…</p>`);
    }
    $$renderer2.push(`<!--]-->`);
    if ($$store_subs) unsubscribe_stores($$store_subs);
  });
}
export {
  _page as default
};
