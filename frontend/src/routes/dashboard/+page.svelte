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

<section class="dashboard-page">
  <header class="page-header">
    <div>
      <h1>Executive Dashboard</h1>
      <p>Aluminium Profile Line 1 — Penang Plant 1</p>
    </div>

    <div class="live-status">
      <span>Refreshes every 5s</span>
      {#if !loading && !error}
        <span class="status-chip status-chip--live">Live</span>
      {:else if loading}
        <span class="status-chip status-chip--loading">Loading</span>
      {/if}
    </div>
  </header>

  {#if error}
    <div class="message message--error">{error}</div>
  {/if}

  {#if loading && !data}
    <div class="message message--loading">
      <div class="loading-glyph">[ ]</div>
      <div>Loading executive dashboard...</div>
    </div>
  {:else if data}
    <ScenarioBanner health={data.health} scenario={data.scenario} message={data.health_message} />

    <FinancialImpactRow
      financial={data.financial}
      mttrMin={data.maintenance.current_mttr_estimate_min}
    />

    <StakeholderColumn
      production={data.production}
      maintenance={data.maintenance}
      logistics={data.logistics}
      actions={data.recommended_actions}
    />

    <MachineFloorMap assets={data.assets} />

    <DemoControlPanel {currentScenario} on:change={onScenarioChange} />

    <footer class="dashboard-footer">
      <span>
        MTBF values derived from
        <a
          href="https://archive.ics.uci.edu/dataset/601/ai4i+2020+predictive+maintenance+dataset"
          target="_blank"
          rel="noopener noreferrer"
        >
          AI4I 2020 Predictive Maintenance Dataset (UCI ML Repository)
        </a>
      </span>
      <span>Cost rates based on Penang SMT line benchmarks (2024)</span>
      <span>Scenario engine: 6 aluminium demo scenarios, auto-reset 10 min</span>
    </footer>
  {/if}
</section>

<style>
  .dashboard-page {
    display: flex;
    flex-direction: column;
    gap: 18px;
    padding-bottom: 24px;
  }

  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 16px;
  }

  h1 {
    font-size: 2rem;
    line-height: 1.1;
    font-weight: 800;
    color: #0f172a;
    margin-bottom: 6px;
  }

  .page-header p {
    color: #475569;
    font-size: 0.96rem;
  }

  .live-status {
    display: flex;
    align-items: center;
    gap: 10px;
    flex-wrap: wrap;
    justify-content: flex-end;
    color: #64748b;
    font-size: 0.85rem;
  }

  .status-chip {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 6px 10px;
    border-radius: 999px;
    font-weight: 600;
    border: 1px solid transparent;
  }

  .status-chip::before {
    content: "";
    width: 8px;
    height: 8px;
    border-radius: 50%;
    display: inline-block;
  }

  .status-chip--live {
    color: #166534;
    background: #dcfce7;
    border-color: #86efac;
  }

  .status-chip--live::before {
    background: #16a34a;
  }

  .status-chip--loading {
    color: #1d4ed8;
    background: #dbeafe;
    border-color: #93c5fd;
  }

  .status-chip--loading::before {
    background: #2563eb;
  }

  .message {
    border-radius: 14px;
    padding: 18px 20px;
    border: 1px solid #cbd5e1;
    background: #ffffff;
  }

  .message--error {
    background: #fef2f2;
    border-color: #fecaca;
    color: #b91c1c;
  }

  .message--loading {
    min-height: 240px;
    display: grid;
    place-items: center;
    text-align: center;
    color: #64748b;
    gap: 10px;
  }

  .loading-glyph {
    font-size: 2rem;
    color: #475569;
  }

  .dashboard-footer {
    display: flex;
    flex-wrap: wrap;
    gap: 10px 20px;
    padding-top: 14px;
    border-top: 1px solid #dbe2ea;
    color: #64748b;
    font-size: 0.8rem;
  }

  .dashboard-footer a {
    color: #334155;
    text-decoration: underline;
  }

  @media (max-width: 900px) {
    .page-header {
      flex-direction: column;
      align-items: stretch;
    }

    .live-status {
      justify-content: flex-start;
    }

    h1 {
      font-size: 1.7rem;
    }
  }
</style>
