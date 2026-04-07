<script lang="ts">
	export let label: string;
	export let value: number;   // 0.0 – 1.0
	export let unit: string = '%';

	$: pct = Math.round(value * 100);
	$: color =
		pct >= 85 ? '#10b981' :
		pct >= 60 ? '#f59e0b' : '#ef4444';

	// Arc path: half-circle (180°) scoreboard style
	const R = 40;
	const CX = 60;
	const CY = 55;
	function arc(ratio: number): string {
		const angle = Math.PI * Math.min(ratio, 0.999);
		const x = CX - R * Math.cos(angle);
		const y = CY - R * Math.sin(angle);
		return `M ${CX - R} ${CY} A ${R} ${R} 0 0 1 ${x.toFixed(2)} ${y.toFixed(2)}`;
	}
</script>

<div class="gauge">
	<svg viewBox="0 0 120 65" width="120" height="65">
		<!-- background track -->
		<path d={arc(1)} stroke="#e5e7eb" stroke-width="8" fill="none" />
		<!-- value arc -->
		<path d={arc(value)} stroke={color} stroke-width="8" fill="none" stroke-linecap="round" />
		<!-- value text -->
		<text x={CX} y={CY + 2} text-anchor="middle" font-size="14" font-weight="700" fill="#111827">
			{pct}{unit}
		</text>
	</svg>
	<div class="gauge-label">{label}</div>
</div>

<style>
	.gauge {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 2px;
	}
	.gauge-label {
		font-size: 0.75rem;
		color: #6b7280;
		text-align: center;
	}
</style>
