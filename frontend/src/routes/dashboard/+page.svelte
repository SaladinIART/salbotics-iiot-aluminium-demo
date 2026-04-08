<script lang="ts">
  import { onDestroy, onMount } from 'svelte';
  import { api } from '$lib/api';
  import type { DashboardResponse } from '$lib/types';
  import ScenarioBanner from '$lib/components/ScenarioBanner.svelte';
  import FinancialImpactRow from '$lib/components/FinancialImpactRow.svelte';
  import StakeholderColumn from '$lib/components/StakeholderColumn.svelte';
  import MachineFloorMap from '$lib/components/MachineFloorMap.svelte';
  import DemoControlPanel from '$lib/components/DemoControlPanel.svelte';

  let data: DashboardResponse | null = null;
  let error = '';
  let loading = true;
  let interval: ReturnType<typeof setInterval>;

  async function refresh() {
    try {
      data = await api.dashboard.get();
      error = '';
    } catch (e) {
      error = `Failed to load dashboard: ${e instanceof Error ? e.message : String(e)}`;
    } finally {
      loading = false;
    }
  }

  function onScenarioChange() {
    // Refresh immediately after a scenario switch so the banner updates
    setTimeout(refresh, 800);
  }

  onMount(() => {
    refresh();
    interval = setInterval(refresh, 5000);
  });

  onDestroy(() => {
    clearInterval(interval);
  });

  $: currentScenario = data?.scenario ?? 'NORMAL';
</script>

<svelte:head>
  <title>Executive Dashboard — NEXUS IIoT</title>
</svelte:head>

<div class="space-y-4">
  <!-- Page header -->
  <div class="flex items-center justify-between">
    <div>
      <h1 class="text-2xl font-bold text-white">Executive Dashboard</h1>
      <p class="text-sm text-gray-400">REL-2000 Assembly Line — Penang Plant 1</p>
    </div>
    <div class="text-xs text-gray-500">
      Refreshes every 5s
      {#if !loading && !error}
        · <span class="text-green-400">●</span> Live
      {:else if loading}
        · <span class="text-blue-400 animate-pulse">↻</span> Loading
      {/if}
    </div>
  </div>

  {#if error}
    <div class="bg-red-900/40 border border-red-700 rounded-lg p-4 text-red-300 text-sm">{error}</div>
  {/if}

  {#if loading && !data}
    <div class="text-center text-gray-500 py-16">
      <div class="text-4xl mb-3 animate-pulse">⚙</div>
      Loading executive dashboard…
    </div>
  {:else if data}
    <!-- 1. Scenario banner -->
    <ScenarioBanner health={data.health} scenario={data.scenario} message={data.health_message} />

    <!-- 2. Financial impact row -->
    <FinancialImpactRow
      financial={data.financial}
      mttrMin={data.maintenance.current_mttr_estimate_min}
    />

    <!-- 3. Four-column stakeholder view -->
    <StakeholderColumn
      production={data.production}
      maintenance={data.maintenance}
      logistics={data.logistics}
      actions={data.recommended_actions}
    />

    <!-- 4. Machine floor map -->
    <MachineFloorMap assets={data.assets} />

    <!-- 5. Demo control panel -->
    <DemoControlPanel {currentScenario} on:change={onScenarioChange} />

    <!-- 6. Dataset attribution footer -->
    <div class="border-t border-gray-800 pt-3 flex flex-wrap gap-x-6 gap-y-1 text-xs text-gray-600">
      <span>MTBF values derived from <a href="https://archive.ics.uci.edu/dataset/601/ai4i+2020+predictive+maintenance+dataset" target="_blank" rel="noopener noreferrer" class="underline hover:text-gray-400">AI4I 2020 Predictive Maintenance Dataset (UCI ML Repository)</a></span>
      <span>Cost rates based on Penang SMT line benchmarks (2024)</span>
      <span>Scenario engine: 4 named demo states, auto-reset 10 min</span>
    </div>
  {/if}
</div>
