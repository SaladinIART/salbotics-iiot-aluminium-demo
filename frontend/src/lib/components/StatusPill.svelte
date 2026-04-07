<script lang="ts">
	export let state: string;
	export let quality: string = 'good';

	const stateColors: Record<string, string> = {
		RUNNING: 'pill--green',
		IDLE: 'pill--blue',
		FAULT: 'pill--red',
		OFFLINE: 'pill--grey',
		UNKNOWN: 'pill--grey',
	};

	$: colorClass = quality !== 'good' ? 'pill--grey' : (stateColors[state] ?? 'pill--grey');
	$: label = quality !== 'good' ? quality.toUpperCase() : state;
</script>

<span class="pill {colorClass}">{label}</span>

<style>
	.pill {
		display: inline-block;
		padding: 2px 10px;
		border-radius: 999px;
		font-size: 0.72rem;
		font-weight: 600;
		letter-spacing: 0.04em;
		text-transform: uppercase;
	}
	.pill--green  { background: #d1fae5; color: #065f46; }
	.pill--blue   { background: #dbeafe; color: #1e40af; }
	.pill--red    { background: #fee2e2; color: #991b1b; }
	.pill--grey   { background: #f3f4f6; color: #6b7280; }
</style>
