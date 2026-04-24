<script lang="ts">
  import { api } from '$lib/api';
  import { createEventDispatcher } from 'svelte';

  export let currentScenario: string = 'NORMAL';

  const dispatch = createEventDispatcher<{ change: { scenario: string } }>();

  let loading = false;
  let error = '';

  const SCENARIOS = [
    {
      name: 'NORMAL',
      label: 'Normal',
      description: 'All 7 stations running. Profile throughput on target.',
      tone: 'normal',
      flagship: false,
    },
    {
      name: 'QUALITY_HOLD_QUENCH',
      label: 'Quality Hold — Quench',
      description: 'Quench flow drops and exit temp rises. Automotive Customer B batch on P2 hold.',
      tone: 'flagship',
      flagship: true,
    },
    {
      name: 'PRESS_BOTTLENECK',
      label: 'Press Bottleneck',
      description: 'Extrusion overload. Downstream starved, all 3 orders exposed.',
      tone: 'warning',
      flagship: false,
    },
    {
      name: 'STRETCHER_BACKLOG',
      label: 'Stretcher Backlog',
      description: 'Stretcher offline for grip change. WIP accumulates on cooling table.',
      tone: 'warning',
      flagship: false,
    },
    {
      name: 'AGEING_OVEN_DEVIATION',
      label: 'Ageing Oven Deviation',
      description: 'Oven out of T6 band. MNC Customer A batch suspect and queued for retest.',
      tone: 'warning',
      flagship: false,
    },
    {
      name: 'EMERGENCY_PRESS_TRIP',
      label: 'Emergency Press Trip',
      description: 'Line down. All 3 customer orders at risk. Invoke BCP.',
      tone: 'critical',
      flagship: false,
    },
  ] as const;

  async function trigger(name: string) {
    loading = true;
    error = '';
    try {
      await api.demo.setScenario(name);
      dispatch('change', { scenario: name });
    } catch (e) {
      error = `Failed: ${e instanceof Error ? e.message : String(e)}`;
    } finally {
      loading = false;
    }
  }
</script>

<section class="control-panel">
  <header class="control-panel__header">
    <div>
      <div class="control-panel__eyebrow">Demo Control Panel</div>
      <div class="control-panel__subhead">Scenario rehearsal and live-switch controls</div>
    </div>
    <div class="control-panel__note">For presentation use only</div>
  </header>

  <div class="scenario-grid">
    {#each SCENARIOS as scenario}
      <button
        on:click={() => trigger(scenario.name)}
        disabled={loading}
        class="scenario-button scenario-button--{scenario.tone} {currentScenario === scenario.name ? 'scenario-button--active' : ''}"
      >
        <div class="scenario-button__row">
          <span class="scenario-button__label">{scenario.label}</span>
          {#if scenario.flagship}
            <span class="scenario-button__flag">Flagship</span>
          {/if}
        </div>
        <div class="scenario-button__description">{scenario.description}</div>
      </button>
    {/each}
  </div>

  {#if error}
    <div class="panel-message panel-message--error">{error}</div>
  {/if}

  {#if loading}
    <div class="panel-message panel-message--loading">Switching scenario...</div>
  {/if}

  <div class="control-panel__footer">Scenarios auto-reset to NORMAL after 10 minutes.</div>
</section>

<style>
  .control-panel {
    background: #ffffff;
    border: 1px solid #dbe2ea;
    border-radius: 16px;
    padding: 20px;
    box-shadow: 0 8px 22px rgba(15, 23, 42, 0.05);
  }

  .control-panel__header {
    display: flex;
    justify-content: space-between;
    gap: 16px;
    align-items: flex-start;
    margin-bottom: 16px;
  }

  .control-panel__eyebrow {
    font-size: 0.78rem;
    font-weight: 700;
    color: #64748b;
    letter-spacing: 0.12em;
    text-transform: uppercase;
  }

  .control-panel__subhead {
    margin-top: 6px;
    color: #475569;
    font-size: 0.92rem;
  }

  .control-panel__note {
    color: #64748b;
    font-size: 0.82rem;
    font-style: italic;
    white-space: nowrap;
  }

  .scenario-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 12px;
  }

  .scenario-button {
    border-radius: 14px;
    border: 1px solid #cbd5e1;
    background: #f8fafc;
    color: #0f172a;
    padding: 14px;
    text-align: left;
    cursor: pointer;
    transition: transform 0.15s ease, box-shadow 0.15s ease, border-color 0.15s ease;
  }

  .scenario-button:hover:not(:disabled) {
    transform: translateY(-1px);
    box-shadow: 0 10px 18px rgba(15, 23, 42, 0.08);
  }

  .scenario-button:disabled {
    opacity: 0.6;
    cursor: wait;
  }

  .scenario-button--normal {
    border-color: #86efac;
    background: linear-gradient(180deg, #ecfdf5, #f0fdf4);
  }

  .scenario-button--flagship,
  .scenario-button--warning {
    border-color: #fcd34d;
    background: linear-gradient(180deg, #fffbeb, #fffbeb);
  }

  .scenario-button--critical {
    border-color: #fca5a5;
    background: linear-gradient(180deg, #fef2f2, #fff1f2);
  }

  .scenario-button--active {
    box-shadow: 0 0 0 2px rgba(37, 99, 235, 0.18);
    border-color: #60a5fa;
  }

  .scenario-button__row {
    display: flex;
    justify-content: space-between;
    gap: 10px;
    align-items: center;
    margin-bottom: 8px;
  }

  .scenario-button__label {
    font-size: 0.95rem;
    font-weight: 700;
  }

  .scenario-button__flag {
    flex: 0 0 auto;
    padding: 3px 8px;
    border-radius: 999px;
    background: #f59e0b;
    color: #111827;
    font-size: 0.68rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.08em;
  }

  .scenario-button__description {
    color: #475569;
    font-size: 0.84rem;
    line-height: 1.45;
  }

  .panel-message {
    margin-top: 12px;
    border-radius: 12px;
    padding: 10px 12px;
    font-size: 0.84rem;
    font-weight: 600;
  }

  .panel-message--error {
    background: #fef2f2;
    color: #b91c1c;
    border: 1px solid #fecaca;
  }

  .panel-message--loading {
    background: #eff6ff;
    color: #1d4ed8;
    border: 1px solid #bfdbfe;
  }

  .control-panel__footer {
    margin-top: 12px;
    color: #64748b;
    font-size: 0.8rem;
    text-align: center;
  }

  @media (max-width: 1100px) {
    .scenario-grid {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }
  }

  @media (max-width: 720px) {
    .control-panel__header {
      flex-direction: column;
    }

    .control-panel__note {
      white-space: normal;
    }

    .scenario-grid {
      grid-template-columns: 1fr;
    }
  }
</style>
