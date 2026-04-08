import { s as store_get, e as ensure_array_like, a as attr_class, b as slot, u as unsubscribe_stores } from "../../chunks/renderer.js";
import { o as onDestroy } from "../../chunks/index-server.js";
import { p as page } from "../../chunks/stores.js";
import { o as openAlerts } from "../../chunks/stores2.js";
import { a as attr } from "../../chunks/attributes.js";
import { e as escape_html } from "../../chunks/escaping.js";
function _layout($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    var $$store_subs;
    let openCount;
    const nav = [
      { href: "/dashboard", label: "Executive View", icon: "🏭" },
      { href: "/", label: "Floor Overview", icon: "⬛" },
      { href: "/assets", label: "Assets", icon: "🔧" },
      { href: "/alerts", label: "Alerts", icon: "🔔" },
      { href: "/kpis", label: "KPIs", icon: "📊" },
      { href: "/admin", label: "Admin", icon: "⚙️" }
    ];
    onDestroy(() => {
    });
    openCount = store_get($$store_subs ??= {}, "$openAlerts", openAlerts).filter((a) => a.state === "OPEN").length;
    $$renderer2.push(`<div class="layout svelte-12qhfyh"><aside class="sidebar svelte-12qhfyh"><div class="logo svelte-12qhfyh"><span class="logo-mark svelte-12qhfyh">⬡</span> <span class="logo-text svelte-12qhfyh">NEXUS</span></div> <nav class="svelte-12qhfyh"><!--[-->`);
    const each_array = ensure_array_like(nav);
    for (let $$index = 0, $$length = each_array.length; $$index < $$length; $$index++) {
      let item = each_array[$$index];
      $$renderer2.push(`<a${attr_class("nav-item svelte-12qhfyh", void 0, {
        "active": item.href === "/" ? store_get($$store_subs ??= {}, "$page", page).url.pathname === "/" : store_get($$store_subs ??= {}, "$page", page).url.pathname.startsWith(item.href)
      })}${attr("href", item.href)}><span class="nav-icon svelte-12qhfyh">${escape_html(item.icon)}</span> <span class="nav-label">${escape_html(item.label)}</span> `);
      if (item.href === "/alerts" && openCount > 0) {
        $$renderer2.push("<!--[0-->");
        $$renderer2.push(`<span class="nav-badge svelte-12qhfyh">${escape_html(openCount)}</span>`);
      } else {
        $$renderer2.push("<!--[-1-->");
      }
      $$renderer2.push(`<!--]--></a>`);
    }
    $$renderer2.push(`<!--]--></nav> <div class="sidebar-footer svelte-12qhfyh">IIoT Platform v1.0</div></aside> <main class="content svelte-12qhfyh"><!--[-->`);
    slot($$renderer2, $$props, "default", {});
    $$renderer2.push(`<!--]--></main></div>`);
    if ($$store_subs) unsubscribe_stores($$store_subs);
  });
}
export {
  _layout as default
};
