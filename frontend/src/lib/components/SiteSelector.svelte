<script lang="ts">
	import type { Site } from '$lib/types';
	import { selectedSite } from '$lib/stores';

	export let sites: Site[] = [];
</script>

<div class="site-selector">
	<label for="site-select">Site</label>
	<select id="site-select" bind:value={$selectedSite}>
		<option value="all">All sites</option>
		{#each sites as site}
			<option value={site.site_id}>{site.display_name}</option>
		{/each}
	</select>
</div>

<style>
	.site-selector {
		display: flex;
		align-items: center;
		gap: 8px;
	}
	label {
		font-size: 0.8rem;
		color: #6b7280;
		font-weight: 500;
	}
	select {
		font-size: 0.85rem;
		padding: 4px 8px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		background: #fff;
		color: #111827;
		cursor: pointer;
	}
</style>
