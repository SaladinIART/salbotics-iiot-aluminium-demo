<script lang="ts">
	import { onMount } from 'svelte';
	import { api } from '$lib/api';
	import type { Alert } from '$lib/types';

	let alerts: Alert[] = [];
	let loading = true;
	let error = '';
	let filter: string = 'OPEN';
	let ackingId: string | null = null;

	async function load() {
		loading = true;
		error = '';
		try {
			alerts = await api.alerts.list({ state: filter === 'ALL' ? undefined : filter, limit: 200 });
		} catch (e) {
			error = String(e);
		} finally {
			loading = false;
		}
	}

	async function acknowledge(id: string) {
		ackingId = id;
		try {
			await api.alerts.acknowledge(id);
			await load();
		} catch (e) {
			error = String(e);
		} finally {
			ackingId = null;
		}
	}

	onMount(load);

	const sevColor: Record<string, string> = {
		critical: '#dc2626',
		warning: '#d97706',
		info: '#2563eb',
	};
</script>

<div class="page-header">
	<div>
		<h1>Alerts</h1>
		<p class="subtitle">{alerts.length} alert{alerts.length !== 1 ? 's' : ''} shown</p>
	</div>
	<div class="filters">
		{#each ['OPEN', 'ACKED', 'CLOSED', 'ALL'] as s}
			<button class="filter-btn" class:active={filter === s} on:click={() => { filter = s; load(); }}>
				{s}
			</button>
		{/each}
	</div>
</div>

{#if error}
	<p class="error">{error}</p>
{/if}

{#if loading}
	<p class="loading">Loading…</p>
{:else if alerts.length === 0}
	<p class="empty">No alerts in this view.</p>
{:else}
	<div class="alert-list">
		{#each alerts as al (al.id)}
			<div class="alert-row" style="border-left: 4px solid {sevColor[al.severity] ?? '#6b7280'}">
				<div class="alert-main">
					<div class="alert-top">
						<span class="asset">{al.asset_display_name ?? al.asset}</span>
						<span class="signal">· {al.signal}</span>
						<span class="type">[{al.alert_type}]</span>
						<span class="sev" style="color: {sevColor[al.severity]}">{al.severity.toUpperCase()}</span>
					</div>
					<div class="alert-msg">{al.message}</div>
					<div class="alert-meta">
						<span>{new Date(al.opened_at).toLocaleString()}</span>
						{#if al.threshold != null}
							<span>threshold: {al.threshold}</span>
						{/if}
						<span>value: {al.value}</span>
					</div>
				</div>
				<div class="alert-actions">
					<span class="state-badge state-{al.state.toLowerCase()}">{al.state}</span>
					{#if al.state === 'OPEN'}
						<button
							class="ack-btn"
							disabled={ackingId === al.id}
							on:click={() => acknowledge(al.id)}
						>
							{ackingId === al.id ? 'Acking…' : 'Acknowledge'}
						</button>
					{/if}
				</div>
			</div>
		{/each}
	</div>
{/if}

<style>
	.page-header { display: flex; align-items: flex-start; justify-content: space-between; margin-bottom: 20px; flex-wrap: wrap; gap: 12px; }
	h1 { font-size: 1.5rem; font-weight: 700; }
	.subtitle { font-size: 0.82rem; color: #6b7280; margin-top: 2px; }
	.filters { display: flex; gap: 6px; }
	.filter-btn { padding: 5px 14px; border-radius: 6px; border: 1px solid #d1d5db; background: #fff; font-size: 0.8rem; cursor: pointer; color: #374151; }
	.filter-btn.active { background: #4f46e5; color: #fff; border-color: #4f46e5; }
	.alert-list { display: flex; flex-direction: column; gap: 10px; }
	.alert-row {
		background: #fff;
		border-radius: 8px;
		border: 1px solid #e5e7eb;
		padding: 14px 16px;
		display: flex;
		align-items: flex-start;
		justify-content: space-between;
		gap: 16px;
	}
	.alert-main { flex: 1; }
	.alert-top { display: flex; align-items: center; gap: 6px; font-size: 0.9rem; flex-wrap: wrap; }
	.asset { font-weight: 600; color: #111827; }
	.signal { color: #6b7280; }
	.type { font-size: 0.75rem; color: #9ca3af; }
	.sev { font-weight: 700; font-size: 0.78rem; }
	.alert-msg { font-size: 0.82rem; color: #374151; margin: 4px 0; }
	.alert-meta { display: flex; gap: 12px; font-size: 0.72rem; color: #9ca3af; }
	.alert-actions { display: flex; flex-direction: column; align-items: flex-end; gap: 6px; flex-shrink: 0; }
	.state-badge { font-size: 0.7rem; font-weight: 600; padding: 2px 8px; border-radius: 999px; }
	.state-open   { background: #fee2e2; color: #991b1b; }
	.state-acked  { background: #fef3c7; color: #92400e; }
	.state-closed { background: #d1fae5; color: #065f46; }
	.ack-btn { font-size: 0.78rem; padding: 4px 12px; border-radius: 6px; border: 1px solid #6366f1; background: #fff; color: #4f46e5; cursor: pointer; font-weight: 600; }
	.ack-btn:hover { background: #4f46e5; color: #fff; }
	.ack-btn:disabled { opacity: 0.5; cursor: not-allowed; }
	.loading, .empty { color: #6b7280; font-size: 0.9rem; }
	.error { color: #dc2626; margin-bottom: 12px; font-size: 0.85rem; }
</style>
