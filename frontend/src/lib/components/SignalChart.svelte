<script lang="ts">
	import { onDestroy, onMount } from 'svelte';
	import type { TelemetryPoint } from '$lib/types';

	export let points: TelemetryPoint[] = [];
	export let signal: string = '';
	export let color: string = '#6366f1';

	let canvas: HTMLCanvasElement;
	let chart: import('chart.js').Chart | null = null;

	async function initChart() {
		const { Chart, LineElement, PointElement, LinearScale, TimeScale, Tooltip, Legend, CategoryScale } =
			await import('chart.js');
		Chart.register(LineElement, PointElement, LinearScale, TimeScale, Tooltip, Legend, CategoryScale);

		chart = new Chart(canvas, {
			type: 'line',
			data: {
				labels: points.map((p) => new Date(p.ts).toLocaleTimeString()),
				datasets: [
					{
						label: signal,
						data: points.map((p) => p.value),
						borderColor: color,
						backgroundColor: color + '22',
						borderWidth: 2,
						pointRadius: 2,
						tension: 0.3,
						fill: true,
					},
				],
			},
			options: {
				responsive: true,
				maintainAspectRatio: false,
				plugins: { legend: { display: false } },
				scales: {
					x: { ticks: { maxTicksLimit: 8 } },
					y: { beginAtZero: false },
				},
			},
		});
	}

	$: if (chart && points.length) {
		chart.data.labels = points.map((p) => new Date(p.ts).toLocaleTimeString());
		chart.data.datasets[0].data = points.map((p) => p.value);
		chart.update('none');
	}

	onMount(initChart);
	onDestroy(() => chart?.destroy());
</script>

<div class="chart-wrap">
	<canvas bind:this={canvas}></canvas>
</div>

<style>
	.chart-wrap {
		position: relative;
		height: 200px;
		width: 100%;
	}
</style>
