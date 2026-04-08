<script lang="ts">
  import type { FinancialSummary } from '$lib/types';

  export let financial: FinancialSummary;
  export let mttrMin: number | null = null;

  function fmt(n: number): string {
    return n.toLocaleString('en-MY', { minimumFractionDigits: 0, maximumFractionDigits: 0 });
  }
</script>

<div class="grid grid-cols-3 gap-4">
  <!-- Cost rate -->
  <div class="bg-gray-800 border border-gray-700 rounded-lg p-5 text-center">
    <div class="text-xs uppercase tracking-widest text-gray-400 mb-1">Cost Rate</div>
    <div class="text-3xl font-bold {financial.cost_rate_myr_hr > 0 ? 'text-red-400' : 'text-green-400'}">
      RM {fmt(financial.cost_rate_myr_hr)}<span class="text-lg font-normal text-gray-400">/hr</span>
    </div>
    <div class="text-sm text-gray-400 mt-1">
      {#if financial.cost_so_far_myr > 0}
        RM {fmt(financial.cost_so_far_myr)} accumulated
      {:else}
        No active downtime
      {/if}
    </div>
  </div>

  <!-- Orders at risk -->
  <div class="bg-gray-800 border border-gray-700 rounded-lg p-5 text-center">
    <div class="text-xs uppercase tracking-widest text-gray-400 mb-1">Orders at Risk</div>
    <div class="text-3xl font-bold {financial.orders_at_risk_count > 0 ? 'text-amber-400' : 'text-green-400'}">
      {financial.orders_at_risk_count}
      <span class="text-lg font-normal text-gray-400">
        {financial.orders_at_risk_count === 1 ? 'order' : 'orders'}
      </span>
    </div>
    <div class="text-sm text-gray-400 mt-1">
      {#if financial.orders_at_risk_value_myr > 0}
        RM {fmt(financial.orders_at_risk_value_myr)} exposure
      {:else}
        All orders on track
      {/if}
    </div>
  </div>

  <!-- MTTR estimate -->
  <div class="bg-gray-800 border border-gray-700 rounded-lg p-5 text-center">
    <div class="text-xs uppercase tracking-widest text-gray-400 mb-1">Est. Recovery</div>
    <div class="text-3xl font-bold {mttrMin ? 'text-blue-400' : 'text-green-400'}">
      {#if mttrMin}
        ~{mttrMin}<span class="text-lg font-normal text-gray-400"> min</span>
      {:else}
        —
      {/if}
    </div>
    <div class="text-sm text-gray-400 mt-1">
      {#if mttrMin}
        maintenance estimate
      {:else}
        No active fault
      {/if}
    </div>
  </div>
</div>
