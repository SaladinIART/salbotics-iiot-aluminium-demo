<script lang="ts">
	import { onMount } from 'svelte';
	import { api } from '$lib/api';
	import KpiGauge from '$lib/components/KpiGauge.svelte';
	import type { KpiSummary } from '$lib/types';

	let kpis: KpiSummary[] = [];
	let loading = true;
	let error = '';
	let window = 8;

	async function load() {
		loading = true;
		error = '';
		try {
			kpis = await api.kpis.list(window);
		} catch (e) {
			error = String(e);
		} finally {
			loading = false;
		}
	}

	onMount(load);
</script>

<div class="page-header">
	<div>
		<h1>KPIs</h1>
		<p class="subtitle">Rolling {window}h window · OEE proxy per asset</p>
	</div>
	<div class="window-ctrl">
		<label for="window-sel">Window</label>
		<select id="window-sel" bind:value={window} on:change={load}>
			<option value={1}>1 h</option>
			<option value={4}>4 h</option>
			<option value={8}>8 h</option>
			<option value={24}>24 h</option>
		</select>
	</div>
</div>

{#if error}
	<p class="error">{error}</p>
{/if}

{#if loading}
	<p class="loading">Loading…</p>
{:else if kpis.length === 0}
	<p class="empty">No KPI data. Make sure the simulator is running.</p>
{:else}
	<div class="kpi-grid">
		{#each kpis as kpi (kpi.asset)}
			<div class="kpi-card">
				<div class="kpi-name">{kpi.display_name ?? kpi.asset}</div>
				<div class="kpi-type">{kpi.asset_type ?? ''}</div>
				<div class="gauges">
					<KpiGauge label="Availability" value={kpi.availability} />
					<KpiGauge label="Quality Rate" value={kpi.quality_rate} />
				</div>
				<div class="kpi-stats">
					<div class="kpi-stat">
						<span class="kpi-stat-label">Running</span>
						<span>{kpi.running_minutes.toFixed(0)} min</span>
					</div>
					<div class="kpi-stat">
						<span class="kpi-stat-label">Fault</span>
						<span class="fault">{kpi.fault_minutes.toFixed(0)} min</span>
					</div>
					<div class="kpi-stat">
						<span class="kpi-stat-label">Open Alerts</span>
						<span class:alert-num={kpi.open_alert_count > 0}>{kpi.open_alert_count}</span>
					</div>
				</div>
			</div>
		{/each}
	</div>
{/if}

<style>
	.page-header { display: flex; align-items: flex-start; justify-content: space-between; margin-bottom: 24px; flex-wrap: wrap; gap: 12px; }
	h1 { font-size: 1.5rem; font-weight: 700; }
	.subtitle { font-size: 0.82rem; color: #6b7280; margin-top: 2px; }
	.window-ctrl { display: flex; align-items: center; gap: 8px; font-size: 0.82rem; color: #6b7280; }
	select { font-size: 0.85rem; padding: 4px 8px; border: 1px solid #d1d5db; border-radius: 6px; }
	.kpi-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 16px; }
	.kpi-card { background: #fff; border: 1px solid #e5e7eb; border-radius: 10px; padding: 20px; }
	.kpi-name { font-weight: 600; font-size: 1rem; color: #111827; }
	.kpi-type { font-size: 0.72rem; color: #9ca3af; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 12px; }
	.gauges { display: flex; justify-content: space-around; margin-bottom: 16px; }
	.kpi-stats { display: flex; justify-content: space-between; }
	.kpi-stat { display: flex; flex-direction: column; align-items: center; font-size: 0.78rem; color: #374151; gap: 2px; }
	.kpi-stat-label { font-size: 0.68rem; color: #9ca3af; }
	.fault { color: #dc2626; }
	.alert-num { color: #dc2626; font-weight: 700; }
	.loading, .empty { color: #6b7280; font-size: 0.9rem; }
	.error { color: #dc2626; margin-bottom: 12px; }
</style>
