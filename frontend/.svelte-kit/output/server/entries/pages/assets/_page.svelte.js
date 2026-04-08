import { a as attr_class, c as bind_props, d as stringify, s as store_get, e as ensure_array_like, u as unsubscribe_stores } from "../../../chunks/renderer.js";
import { a as assetMap } from "../../../chunks/stores2.js";
/* empty css                                                      */
import { f as fallback, a as attr } from "../../../chunks/attributes.js";
import { e as escape_html } from "../../../chunks/escaping.js";
/* empty css                                                       */
function AlertBadge($$renderer, $$props) {
  let colorClass;
  let count = fallback($$props["count"], 0);
  let severity = fallback($$props["severity"], "warning");
  const colors = {
    critical: "badge--red",
    warning: "badge--amber",
    info: "badge--blue"
  };
  colorClass = colors[severity] ?? "badge--amber";
  if (count > 0) {
    $$renderer.push("<!--[0-->");
    $$renderer.push(`<span${attr_class(`badge ${stringify(colorClass)}`, "svelte-24ufdz")}>${escape_html(count)}</span>`);
  } else {
    $$renderer.push("<!--[-1-->");
  }
  $$renderer.push(`<!--]-->`);
  bind_props($$props, { count, severity });
}
function StatusPill($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    let colorClass, label;
    let state = $$props["state"];
    let quality = fallback($$props["quality"], "good");
    const stateColors = {
      RUNNING: "pill--green",
      IDLE: "pill--blue",
      FAULT: "pill--red",
      OFFLINE: "pill--grey",
      UNKNOWN: "pill--grey"
    };
    colorClass = quality !== "good" ? "pill--grey" : stateColors[state] ?? "pill--grey";
    label = quality !== "good" ? quality.toUpperCase() : state;
    $$renderer2.push(`<span${attr_class(`pill ${stringify(colorClass)}`, "svelte-1swmi23")}>${escape_html(label)}</span>`);
    bind_props($$props, { state, quality });
  });
}
function AssetCard($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    let asset = $$props["asset"];
    $$renderer2.push(`<a class="card svelte-agnkoy"${attr("href", `/assets/${stringify(asset.asset)}`)}><div class="card-header svelte-agnkoy"><span class="asset-name svelte-agnkoy">${escape_html(asset.display_name)}</span> `);
    AlertBadge($$renderer2, { count: asset.open_alert_count, severity: "warning" });
    $$renderer2.push(`<!----></div> <div class="asset-type svelte-agnkoy">${escape_html(asset.asset_type)} · ${escape_html(asset.line_name)}</div> <div class="card-status svelte-agnkoy">`);
    StatusPill($$renderer2, { state: asset.state, quality: asset.quality });
    $$renderer2.push(`<!----> `);
    if (asset.fault_code > 0) {
      $$renderer2.push("<!--[0-->");
      $$renderer2.push(`<span class="fault-code svelte-agnkoy">F${escape_html(asset.fault_code)}</span>`);
    } else {
      $$renderer2.push("<!--[-1-->");
    }
    $$renderer2.push(`<!--]--></div> <div class="last-seen svelte-agnkoy">${escape_html(asset.last_seen ? new Date(asset.last_seen).toLocaleTimeString() : "No data")}</div></a>`);
    bind_props($$props, { asset });
  });
}
function _page($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    var $$store_subs;
    let assets, byLine;
    assets = Array.from(store_get($$store_subs ??= {}, "$assetMap", assetMap).values()).sort((a, b) => a.line_name.localeCompare(b.line_name) || a.asset.localeCompare(b.asset));
    byLine = assets.reduce(
      (acc, a) => {
        (acc[a.line_name] ??= []).push(a);
        return acc;
      },
      {}
    );
    $$renderer2.push(`<h1 class="svelte-9662h2">Assets</h1> <p class="subtitle svelte-9662h2">${escape_html(assets.length)} asset${escape_html(assets.length !== 1 ? "s" : "")} registered</p> <!--[-->`);
    const each_array = ensure_array_like(Object.entries(byLine));
    for (let $$index_1 = 0, $$length = each_array.length; $$index_1 < $$length; $$index_1++) {
      let [line, group] = each_array[$$index_1];
      $$renderer2.push(`<section class="svelte-9662h2"><h2 class="line-heading svelte-9662h2">${escape_html(line)}</h2> <div class="grid svelte-9662h2"><!--[-->`);
      const each_array_1 = ensure_array_like(group);
      for (let $$index = 0, $$length2 = each_array_1.length; $$index < $$length2; $$index++) {
        let asset = each_array_1[$$index];
        AssetCard($$renderer2, { asset });
      }
      $$renderer2.push(`<!--]--></div></section>`);
    }
    $$renderer2.push(`<!--]-->`);
    if ($$store_subs) unsubscribe_stores($$store_subs);
  });
}
export {
  _page as default
};
