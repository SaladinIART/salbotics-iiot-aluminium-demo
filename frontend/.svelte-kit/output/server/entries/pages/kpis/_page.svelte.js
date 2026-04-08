import { e as escape_html } from "../../../chunks/escaping.js";
import "clsx";
function _page($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    let window = 8;
    $$renderer2.push(`<div class="page-header svelte-1p3g18k"><div><h1 class="svelte-1p3g18k">KPIs</h1> <p class="subtitle svelte-1p3g18k">Rolling ${escape_html(window)}h window · OEE proxy per asset</p></div> <div class="window-ctrl svelte-1p3g18k"><label for="window-sel">Window</label> `);
    $$renderer2.select(
      { id: "window-sel", value: window, class: "" },
      ($$renderer3) => {
        $$renderer3.option({ value: 1 }, ($$renderer4) => {
          $$renderer4.push(`1 h`);
        });
        $$renderer3.option({ value: 4 }, ($$renderer4) => {
          $$renderer4.push(`4 h`);
        });
        $$renderer3.option({ value: 8 }, ($$renderer4) => {
          $$renderer4.push(`8 h`);
        });
        $$renderer3.option({ value: 24 }, ($$renderer4) => {
          $$renderer4.push(`24 h`);
        });
      },
      "svelte-1p3g18k"
    );
    $$renderer2.push(`</div></div> `);
    {
      $$renderer2.push("<!--[-1-->");
    }
    $$renderer2.push(`<!--]--> `);
    {
      $$renderer2.push("<!--[0-->");
      $$renderer2.push(`<p class="loading svelte-1p3g18k">Loading…</p>`);
    }
    $$renderer2.push(`<!--]-->`);
  });
}
export {
  _page as default
};
