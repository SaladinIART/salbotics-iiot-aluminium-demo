<script lang="ts">
  import type { AssetDashboard } from '$lib/types';

  export let assets: AssetDashboard[] = [];

  // Ordered display sequence: left to right on the line
  const ORDER = ['feeder-01', 'mixer-01', 'conveyor-01', 'packer-01'];

  const ICONS: Record<string, string> = {
    feeder:   '📦',
    mixer:    '🔥',
    conveyor: '➡',
    packer:   '✅',
  };

  const STATE_BG: Record<string, string> = {
    RUNNING:     'bg-green-800/60 border-green-500',
    STARTUP:     'bg-blue-800/60 border-blue-400',
    IDLE:        'bg-gray-700/60 border-gray-500',
    FAULTED:     'bg-red-900/70 border-red-500',
    MAINTENANCE: 'bg-amber-900/60 border-amber-500',
    UNKNOWN:     'bg-gray-800/60 border-gray-600',
  };

  const STATE_DOT: Record<string, string> = {
    RUNNING:     'bg-green-400 animate-pulse',
    STARTUP:     'bg-blue-400 animate-pulse',
    IDLE:        'bg-gray-500',
    FAULTED:     'bg-red-500 animate-ping',
    MAINTENANCE: 'bg-amber-400',
    UNKNOWN:     'bg-gray-600',
  };

  const FAULT_LABELS: Record<number, string> = {
    0:   '',
    101: 'LOW MATERIAL',
    102: 'MOTOR TRIP',
    201: 'HIGH TEMP',
    202: 'LOW PRESSURE',
    301: 'JAM DETECTED',
    302: 'SPEED VARIANCE',
    401: 'FILM BREAK',
    402: 'SEAL TEMP LOW',
  };

  $: ordered = ORDER.map(id => assets.find(a => a.asset === id)).filter(Boolean) as AssetDashboard[];
</script>

<div class="bg-gray-800 border border-gray-700 rounded-lg p-5">
  <div class="text-xs uppercase tracking-widest text-gray-400 mb-4 font-bold">
    REL-2000 Assembly Line — Live Floor View
  </div>

  <div class="flex items-center gap-0 overflow-x-auto">
    {#each ordered as asset, i}
      <!-- Machine card -->
      <div
        class="shrink-0 w-44 border-2 rounded-lg p-3 transition-all duration-500 {STATE_BG[asset.state] ?? STATE_BG.UNKNOWN}"
      >
        <!-- Icon + status dot -->
        <div class="flex items-center justify-between mb-2">
          <span class="text-2xl">{ICONS[asset.asset_type] ?? '⚙'}</span>
          <div class="relative">
            <div class="w-3 h-3 rounded-full {STATE_DOT[asset.state] ?? 'bg-gray-600'}"></div>
          </div>
        </div>

        <!-- Name -->
        <div class="text-xs font-bold text-white leading-tight mb-1">{asset.display_name}</div>

        <!-- State -->
        <div class="text-xs font-mono {asset.state === 'FAULTED' ? 'text-red-300' : asset.state === 'RUNNING' ? 'text-green-300' : 'text-gray-400'}">
          {asset.state}
        </div>

        <!-- Fault label -->
        {#if asset.fault_code > 0}
          <div class="mt-1 text-xs text-red-300 bg-red-900/50 rounded px-1 py-0.5 leading-tight">
            {FAULT_LABELS[asset.fault_code] ?? `F${asset.fault_code}`}
          </div>
        {/if}

        <!-- Cost accumulating -->
        {#if asset.cost_so_far_myr > 0.01}
          <div class="mt-1 text-xs text-amber-300 font-mono">
            −RM {asset.cost_so_far_myr.toFixed(0)}
          </div>
        {/if}
      </div>

      <!-- Arrow between machines -->
      {#if i < ordered.length - 1}
        <div class="shrink-0 flex flex-col items-center px-1 text-gray-500">
          <svg width="32" height="16" viewBox="0 0 32 16" fill="none">
            <path d="M0 8 H26 M22 3 L28 8 L22 13" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
          <div class="text-xs text-gray-600 -mt-1">WIP</div>
        </div>
      {/if}
    {/each}

    <!-- Finished goods indicator -->
    <div class="shrink-0 flex flex-col items-center pl-2 text-green-600">
      <svg width="28" height="16" viewBox="0 0 28 16" fill="none">
        <path d="M0 8 H20 M16 3 L22 8 L16 13" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>
      <div class="text-xs text-green-700 -mt-1 font-semibold">FG</div>
    </div>
  </div>
</div>
