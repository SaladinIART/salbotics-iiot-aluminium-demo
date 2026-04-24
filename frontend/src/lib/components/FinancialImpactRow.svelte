<script lang="ts">
  import type { FinancialSummary } from '$lib/types';

  export let financial: FinancialSummary;
  export let mttrMin: number | null = null;

  function fmt(n: number): string {
    return n.toLocaleString('en-MY', { minimumFractionDigits: 0, maximumFractionDigits: 0 });
  }

  $: costTone = financial.cost_rate_myr_hr > 0 ? 'risk' : 'good';
  $: orderTone = financial.orders_at_risk_count > 0 ? 'warn' : 'good';
  $: recoveryTone = mttrMin ? 'info' : 'good';
</script>

<section class="impact-row">
  <article class="impact-card">
    <span class="impact-card__label">Cost Rate</span>
    <div class="impact-card__value impact-card__value--{costTone}">
      RM {fmt(financial.cost_rate_myr_hr)}<span>/hr</span>
    </div>
    <p class="impact-card__meta">
      {#if financial.cost_so_far_myr > 0}
        RM {fmt(financial.cost_so_far_myr)} accumulated
      {:else}
        No active downtime
      {/if}
    </p>
  </article>

  <article class="impact-card">
    <span class="impact-card__label">Orders at Risk</span>
    <div class="impact-card__value impact-card__value--{orderTone}">
      {financial.orders_at_risk_count}
      <span>{financial.orders_at_risk_count === 1 ? 'order' : 'orders'}</span>
    </div>
    <p class="impact-card__meta">
      {#if financial.orders_at_risk_value_myr > 0}
        RM {fmt(financial.orders_at_risk_value_myr)} exposure
      {:else}
        All orders on track
      {/if}
    </p>
  </article>

  <article class="impact-card">
    <span class="impact-card__label">Est. Recovery</span>
    <div class="impact-card__value impact-card__value--{recoveryTone}">
      {#if mttrMin}
        ~{mttrMin}<span>min</span>
      {:else}
        -
      {/if}
    </div>
    <p class="impact-card__meta">
      {#if mttrMin}
        maintenance estimate
      {:else}
        No active fault
      {/if}
    </p>
  </article>
</section>

<style>
  .impact-row {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 16px;
  }

  .impact-card {
    background: #ffffff;
    border: 1px solid #dbe2ea;
    border-radius: 16px;
    padding: 18px 20px;
    text-align: center;
    box-shadow: 0 8px 22px rgba(15, 23, 42, 0.05);
  }

  .impact-card__label {
    display: block;
    margin-bottom: 10px;
    font-size: 0.74rem;
    font-weight: 700;
    color: #64748b;
    letter-spacing: 0.12em;
    text-transform: uppercase;
  }

  .impact-card__value {
    font-size: 2rem;
    font-weight: 800;
    color: #0f172a;
    line-height: 1.1;
  }

  .impact-card__value span {
    margin-left: 4px;
    font-size: 1rem;
    font-weight: 500;
    color: #64748b;
  }

  .impact-card__value--good {
    color: #15803d;
  }

  .impact-card__value--warn {
    color: #d97706;
  }

  .impact-card__value--risk {
    color: #dc2626;
  }

  .impact-card__value--info {
    color: #2563eb;
  }

  .impact-card__meta {
    margin-top: 10px;
    color: #64748b;
    font-size: 0.92rem;
  }

  @media (max-width: 900px) {
    .impact-row {
      grid-template-columns: 1fr;
    }
  }
</style>
