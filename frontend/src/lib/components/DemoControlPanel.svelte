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
      label: '🟢 Normal',
      description: 'All machines running. Production on target.',
      cls: 'border-green-600 hover:bg-green-900/40',
      active: 'bg-green-800/60 border-green-400 ring-2 ring-green-500',
    },
    {
      name: 'QUALITY_HOLD',
      label: '🟡 Quality Hold',
      description: 'Reflow oven temperature drift. 1 batch on hold.',
      cls: 'border-amber-600 hover:bg-amber-900/30',
      active: 'bg-amber-800/60 border-amber-400 ring-2 ring-amber-500',
    },
    {
      name: 'LINE_FAULT',
      label: '🔴 Line Fault',
      description: 'Conveyor jam + film break. Production stopped.',
      cls: 'border-red-600 hover:bg-red-900/30',
      active: 'bg-red-900/60 border-red-400 ring-2 ring-red-500',
    },
    {
      name: 'EMERGENCY',
      label: '⛔ Emergency',
      description: 'Full line shutdown. All orders at risk.',
      cls: 'border-red-900 hover:bg-red-950/40',
      active: 'bg-red-950/70 border-red-300 ring-2 ring-red-400',
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

<div class="bg-gray-900 border border-gray-600 rounded-lg p-4">
  <div class="flex items-center justify-between mb-3">
    <div class="text-xs uppercase tracking-widest text-gray-400 font-bold">
      Demo Control Panel
    </div>
    <div class="text-xs text-gray-500 italic">For presentation use only</div>
  </div>

  <div class="grid grid-cols-4 gap-2">
    {#each SCENARIOS as scenario}
      <button
        on:click={() => trigger(scenario.name)}
        disabled={loading}
        class="border rounded-lg p-3 text-left transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed
          {currentScenario === scenario.name ? scenario.active : 'border-opacity-60 ' + scenario.cls}"
      >
        <div class="font-semibold text-sm text-white mb-1">{scenario.label}</div>
        <div class="text-xs text-gray-400 leading-tight">{scenario.description}</div>
      </button>
    {/each}
  </div>

  {#if error}
    <div class="mt-2 text-xs text-red-400 bg-red-900/30 rounded px-2 py-1">{error}</div>
  {/if}

  {#if loading}
    <div class="mt-2 text-xs text-blue-400 text-center animate-pulse">Switching scenario…</div>
  {/if}

  <div class="mt-2 text-xs text-gray-600 text-center">
    Scenarios auto-reset to NORMAL after 10 minutes
  </div>
</div>
