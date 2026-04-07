<script lang="ts">
	import { assetMap } from '$lib/stores';
	import AssetCard from '$lib/components/AssetCard.svelte';

	$: assets = Array.from($assetMap.values()).sort((a, b) =>
		a.line_name.localeCompare(b.line_name) || a.asset.localeCompare(b.asset),
	);

	// Group by line
	$: byLine = assets.reduce<Record<string, typeof assets>>((acc, a) => {
		(acc[a.line_name] ??= []).push(a);
		return acc;
	}, {});
</script>

<h1>Assets</h1>
<p class="subtitle">{assets.length} asset{assets.length !== 1 ? 's' : ''} registered</p>

{#each Object.entries(byLine) as [line, group]}
	<section>
		<h2 class="line-heading">{line}</h2>
		<div class="grid">
			{#each group as asset (asset.asset)}
				<AssetCard {asset} />
			{/each}
		</div>
	</section>
{/each}

<style>
	h1 { font-size: 1.5rem; font-weight: 700; margin-bottom: 4px; }
	.subtitle { font-size: 0.82rem; color: #6b7280; margin-bottom: 24px; }
	section { margin-bottom: 32px; }
	.line-heading {
		font-size: 0.85rem;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.06em;
		color: #6b7280;
		margin-bottom: 12px;
		padding-bottom: 6px;
		border-bottom: 1px solid #e5e7eb;
	}
	.grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
		gap: 16px;
	}
</style>
