<script lang="ts">
  import type {
    LogisticsStatus,
    MaintenanceStatus,
    ProductionStatus,
    RecommendedAction,
  } from '$lib/types';

  export let production: ProductionStatus;
  export let maintenance: MaintenanceStatus;
  export let logistics: LogisticsStatus;
  export let actions: RecommendedAction[];

  const STATUS_COLOR: Record<string, string> = {
    ON_TRACK:   'text-green-400',
    MONITORING: 'text-blue-400',
    AT_RISK:    'text-amber-400',
    DELAYED:    'text-red-400',
    FULFILLED:  'text-gray-400',
  };

  const STATUS_DOT: Record<string, string> = {
    ON_TRACK:   'bg-green-400',
    MONITORING: 'bg-blue-400',
    AT_RISK:    'bg-amber-400',
    DELAYED:    'bg-red-500',
    FULFILLED:  'bg-gray-500',
  };

  const URGENCY_COLOR: Record<string, string> = {
    IMMEDIATE: 'border-red-500 bg-red-900/30',
    URGENT:    'border-amber-500 bg-amber-900/30',
    SOON:      'border-blue-500 bg-blue-900/20',
    INFO:      'border-gray-600 bg-gray-800/30',
  };

  const URGENCY_BADGE: Record<string, string> = {
    IMMEDIATE: 'bg-red-600 text-white',
    URGENT:    'bg-amber-500 text-black',
    SOON:      'bg-blue-600 text-white',
    INFO:      'bg-gray-600 text-white',
  };

  const PM_COLOR: Record<string, string> = {
    LOW:     'text-green-400',
    MEDIUM:  'text-amber-400',
    HIGH:    'text-red-400',
    UNKNOWN: 'text-gray-400',
  };

  function fmtDue(iso: string): string {
    const d = new Date(iso);
    const now = new Date();
    const diffH = (d.getTime() - now.getTime()) / 3_600_000;
    if (diffH < 0) return 'OVERDUE';
    if (diffH < 1) return `${Math.round(diffH * 60)} min`;
    if (diffH < 24) return `${Math.round(diffH)} hr`;
    return `${Math.round(diffH / 24)} days`;
  }

  function circle(state: string): string {
    if (state === 'RUNNING') return 'bg-green-500';
    if (state === 'FAULTED' || state === 'MAINTENANCE') return 'bg-red-500';
    if (state === 'IDLE' || state === 'STARTUP') return 'bg-amber-400';
    return 'bg-gray-500';
  }
</script>

<div class="grid grid-cols-4 gap-4">
  <!-- PRODUCTION -->
  <div class="bg-gray-800 border border-gray-700 rounded-lg p-4 flex flex-col gap-3">
    <div class="text-xs uppercase tracking-widest text-gray-400 font-bold border-b border-gray-700 pb-2">
      Production
    </div>

    <!-- Throughput gauge -->
    <div>
      <div class="flex justify-between text-xs text-gray-400 mb-1">
        <span>Throughput</span>
        <span class="font-mono {production.throughput_pct >= 80 ? 'text-green-400' : production.throughput_pct >= 40 ? 'text-amber-400' : 'text-red-400'}">
          {production.throughput_pct}%
        </span>
      </div>
      <div class="w-full h-2 bg-gray-700 rounded-full overflow-hidden">
        <div
          class="h-full rounded-full transition-all duration-700 {production.throughput_pct >= 80 ? 'bg-green-500' : production.throughput_pct >= 40 ? 'bg-amber-400' : 'bg-red-500'}"
          style="width: {production.throughput_pct}%"
        ></div>
      </div>
    </div>

    <div class="text-center">
      <div class="text-2xl font-bold text-white">{production.units_today.toLocaleString()}</div>
      <div class="text-xs text-gray-400">of {production.target_today.toLocaleString()} target</div>
    </div>

    {#if production.faulted_machine_count > 0}
      <div class="text-xs text-red-400 bg-red-900/30 rounded px-2 py-1 text-center">
        {production.faulted_machine_count} machine{production.faulted_machine_count > 1 ? 's' : ''} faulted — line impact
      </div>
    {:else}
      <div class="text-xs text-green-400 bg-green-900/20 rounded px-2 py-1 text-center">
        All machines running
      </div>
    {/if}
  </div>

  <!-- MAINTENANCE -->
  <div class="bg-gray-800 border border-gray-700 rounded-lg p-4 flex flex-col gap-3">
    <div class="text-xs uppercase tracking-widest text-gray-400 font-bold border-b border-gray-700 pb-2">
      Maintenance
    </div>

    <div class="flex justify-between text-sm">
      <div class="text-center flex-1">
        <div class="text-xl font-bold text-green-400">{maintenance.machines_healthy}</div>
        <div class="text-xs text-gray-500">Healthy</div>
      </div>
      <div class="text-center flex-1">
        <div class="text-xl font-bold text-amber-400">{maintenance.machines_at_risk}</div>
        <div class="text-xs text-gray-500">PM Due</div>
      </div>
      <div class="text-center flex-1">
        <div class="text-xl font-bold text-red-400">{maintenance.machines_faulted}</div>
        <div class="text-xs text-gray-500">Faulted</div>
      </div>
    </div>

    {#if maintenance.current_mttr_estimate_min}
      <div class="text-xs bg-blue-900/30 border border-blue-700 rounded px-2 py-1 text-blue-300 text-center">
        ETA: ~{maintenance.current_mttr_estimate_min} min to resolve
      </div>
    {/if}
  </div>

  <!-- LOGISTICS -->
  <div class="bg-gray-800 border border-gray-700 rounded-lg p-4 flex flex-col gap-3">
    <div class="text-xs uppercase tracking-widest text-gray-400 font-bold border-b border-gray-700 pb-2">
      Logistics
    </div>

    <div class="flex flex-col gap-2">
      {#each logistics.orders as order}
        <div class="flex items-center justify-between gap-2 text-xs">
          <div class="flex items-center gap-1.5 min-w-0">
            <div class="w-2 h-2 rounded-full shrink-0 {STATUS_DOT[order.computed_status] ?? 'bg-gray-500'}"></div>
            <span class="truncate text-gray-300">{order.customer}</span>
          </div>
          <div class="text-right shrink-0">
            <span class="{STATUS_COLOR[order.computed_status] ?? 'text-gray-400'} font-mono">
              {fmtDue(order.due_at)}
            </span>
          </div>
        </div>
      {/each}
    </div>

    {#if logistics.next_deadline_customer}
      <div class="text-xs text-gray-500 border-t border-gray-700 pt-2">
        Next: <span class="text-white">{logistics.next_deadline_customer}</span>
      </div>
    {/if}
  </div>

  <!-- MANAGEMENT ACTIONS -->
  <div class="bg-gray-800 border border-gray-700 rounded-lg p-4 flex flex-col gap-2">
    <div class="text-xs uppercase tracking-widest text-gray-400 font-bold border-b border-gray-700 pb-2">
      Management Actions
    </div>

    <div class="flex flex-col gap-2 overflow-y-auto max-h-48">
      {#each actions as action}
        <div class="border-l-2 rounded px-2 py-1.5 {URGENCY_COLOR[action.urgency] ?? 'border-gray-600'}">
          <div class="flex items-center gap-1.5 mb-0.5">
            <span class="text-xs px-1 py-0.5 rounded font-bold {URGENCY_BADGE[action.urgency] ?? 'bg-gray-600 text-white'}">
              {action.urgency}
            </span>
            <span class="text-xs text-gray-400">{action.owner}</span>
          </div>
          <div class="text-xs text-gray-200 leading-snug">{action.action}</div>
        </div>
      {/each}
    </div>
  </div>
</div>
