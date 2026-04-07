<script lang="ts">
	import { onMount } from 'svelte';
	import { api } from '$lib/api';
	import AssetCard from '$lib/components/AssetCard.svelte';
	import SiteSelector from '$lib/components/SiteSelector.svelte';
	import { assetMap, selectedSite } from '$lib/stores';
	import type { Site } from '$lib/types';

	let sites: Site[] = [];
	let loading = true;
	let error = '';

	onMount(async () => {
		try {
			sites = await api.sites.list();
		} catch (e) {
			error = String(e);
		} finally {
			loading = false;
		}
	});

	$: assets = Array.from($assetMap.values()).filter(
		(a) => $selectedSite === 'all' || a.site === $selectedSite,
	);
</script>

<div class="page-header">
	<div>
		<h1>Floor Overview</h1>
		<p class="subtitle">Live asset status — updates every 2 seconds via SSE</p>
	</div>
	<SiteSelector {sites} />
</div>

{#if loading}
	<p class="loading">Loading assets…</p>
{:else if error}
	<p class="error">{error}</p>
{:else if assets.length === 0}
	<p class="empty">No assets found. Make sure the stack is running and data is flowing.</p>
{:else}
	<div class="grid">
		{#each assets as asset (asset.asset)}
			<AssetCard {asset} />
		{/each}
	</div>
{/if}

<style>
	.page-header {
		display: flex;
		align-items: flex-start;
		justify-content: space-between;
		margin-bottom: 24px;
		flex-wrap: wrap;
		gap: 16px;
	}
	h1 { font-size: 1.5rem; font-weight: 700; color: #111827; }
	.subtitle { font-size: 0.82rem; color: #6b7280; margin-top: 2px; }
	.grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
		gap: 16px;
	}
	.loading, .empty { color: #6b7280; font-size: 0.9rem; }
	.error { color: #dc2626; font-size: 0.9rem; }
</style>
