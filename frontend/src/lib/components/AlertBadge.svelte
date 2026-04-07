<script lang="ts">
	export let count: number = 0;
	export let severity: 'warning' | 'critical' | 'info' = 'warning';

	const colors: Record<string, string> = {
		critical: 'badge--red',
		warning:  'badge--amber',
		info:     'badge--blue',
	};
	$: colorClass = colors[severity] ?? 'badge--amber';
</script>

{#if count > 0}
	<span class="badge {colorClass}">{count}</span>
{/if}

<style>
	.badge {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		min-width: 20px;
		height: 20px;
		padding: 0 6px;
		border-radius: 999px;
		font-size: 0.7rem;
		font-weight: 700;
	}
	.badge--red   { background: #ef4444; color: #fff; }
	.badge--amber { background: #f59e0b; color: #fff; }
	.badge--blue  { background: #3b82f6; color: #fff; }
</style>
