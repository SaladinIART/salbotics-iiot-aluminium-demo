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

  const STATUS_TONE: Record<string, string> = {
    ON_TRACK: 'on-track',
    MONITORING: 'monitoring',
    AT_RISK: 'at-risk',
    DELAYED: 'delayed',
    FULFILLED: 'fulfilled',
  };

  const ACTION_TONE: Record<string, string> = {
    IMMEDIATE: 'immediate',
    URGENT: 'urgent',
    SOON: 'soon',
    INFO: 'info',
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

  $: throughputTone =
    production.throughput_pct >= 80 ? 'good' : production.throughput_pct >= 40 ? 'warn' : 'risk';
</script>

<section class="stakeholder-grid">
  <article class="panel-card">
    <div class="panel-card__title">Production</div>

    <div class="throughput">
      <div class="throughput__row">
        <span>Throughput</span>
        <strong class="throughput__value throughput__value--{throughputTone}">
          {production.throughput_pct}%
        </strong>
      </div>
      <div class="throughput__track">
        <div class="throughput__fill throughput__fill--{throughputTone}" style="width: {production.throughput_pct}%"></div>
      </div>
    </div>

    <div class="metric-stack">
      <strong>{production.units_today.toLocaleString()}</strong>
      <span>of {production.target_today.toLocaleString()} target</span>
    </div>

    {#if production.faulted_machine_count > 0}
      <div class="panel-chip panel-chip--risk">
        {production.faulted_machine_count} machine{production.faulted_machine_count > 1 ? 's' : ''} faulted — line impact
      </div>
    {:else}
      <div class="panel-chip panel-chip--good">All machines running</div>
    {/if}
  </article>

  <article class="panel-card">
    <div class="panel-card__title">Maintenance</div>

    <div class="maintenance-grid">
      <div>
        <strong class="metric-good">{maintenance.machines_healthy}</strong>
        <span>Healthy</span>
      </div>
      <div>
        <strong class="metric-warn">{maintenance.machines_at_risk}</strong>
        <span>PM Due</span>
      </div>
      <div>
        <strong class="metric-risk">{maintenance.machines_faulted}</strong>
        <span>Faulted</span>
      </div>
    </div>

    {#if maintenance.current_mttr_estimate_min}
      <div class="panel-chip panel-chip--info">ETA: ~{maintenance.current_mttr_estimate_min} min to resolve</div>
    {/if}
  </article>

  <article class="panel-card">
    <div class="panel-card__title">Logistics</div>

    <div class="order-list">
      {#each logistics.orders as order}
        <div class="order-row">
          <div class="order-row__left">
            <span class="order-dot order-dot--{STATUS_TONE[order.computed_status] ?? 'fulfilled'}"></span>
            <span class="order-row__name">{order.customer}</span>
          </div>
          <span class="order-row__eta order-row__eta--{STATUS_TONE[order.computed_status] ?? 'fulfilled'}">
            {fmtDue(order.due_at)}
          </span>
        </div>
      {/each}
    </div>

    {#if logistics.next_deadline_customer}
      <div class="next-deadline">
        Next: <strong>{logistics.next_deadline_customer}</strong>
      </div>
    {/if}
  </article>

  <article class="panel-card">
    <div class="panel-card__title">Management Actions</div>

    <div class="action-list">
      {#each actions as action}
        <div class="action-card action-card--{ACTION_TONE[action.urgency] ?? 'info'}">
          <div class="action-card__meta">
            <span class="action-badge action-badge--{ACTION_TONE[action.urgency] ?? 'info'}">{action.urgency}</span>
            <span>{action.owner}</span>
          </div>
          <div class="action-card__body">{action.action}</div>
        </div>
      {/each}
    </div>
  </article>
</section>

<style>
  .stakeholder-grid {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 16px;
  }

  .panel-card {
    display: flex;
    flex-direction: column;
    gap: 14px;
    background: #ffffff;
    border: 1px solid #dbe2ea;
    border-radius: 16px;
    padding: 18px;
    box-shadow: 0 8px 22px rgba(15, 23, 42, 0.05);
    min-width: 0;
  }

  .panel-card__title {
    padding-bottom: 10px;
    border-bottom: 1px solid #e2e8f0;
    color: #64748b;
    font-size: 0.78rem;
    font-weight: 700;
    letter-spacing: 0.12em;
    text-transform: uppercase;
  }

  .throughput {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .throughput__row {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    font-size: 0.84rem;
    color: #64748b;
  }

  .throughput__value {
    font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    font-weight: 700;
  }

  .throughput__value--good { color: #15803d; }
  .throughput__value--warn { color: #d97706; }
  .throughput__value--risk { color: #dc2626; }

  .throughput__track {
    height: 10px;
    border-radius: 999px;
    background: #e2e8f0;
    overflow: hidden;
  }

  .throughput__fill {
    height: 100%;
    border-radius: 999px;
  }

  .throughput__fill--good { background: #22c55e; }
  .throughput__fill--warn { background: #f59e0b; }
  .throughput__fill--risk { background: #ef4444; }

  .metric-stack {
    text-align: center;
  }

  .metric-stack strong {
    display: block;
    font-size: 1.9rem;
    color: #0f172a;
  }

  .metric-stack span {
    color: #64748b;
    font-size: 0.86rem;
  }

  .panel-chip {
    padding: 10px 12px;
    border-radius: 12px;
    font-size: 0.82rem;
    font-weight: 600;
    text-align: center;
  }

  .panel-chip--good {
    background: #ecfdf5;
    color: #166534;
  }

  .panel-chip--risk {
    background: #fef2f2;
    color: #b91c1c;
  }

  .panel-chip--info {
    background: #eff6ff;
    color: #1d4ed8;
  }

  .maintenance-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 12px;
    text-align: center;
  }

  .maintenance-grid strong {
    display: block;
    font-size: 1.5rem;
    margin-bottom: 4px;
  }

  .maintenance-grid span {
    color: #64748b;
    font-size: 0.78rem;
  }

  .metric-good { color: #15803d; }
  .metric-warn { color: #d97706; }
  .metric-risk { color: #dc2626; }

  .order-list,
  .action-list {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .order-row {
    display: flex;
    justify-content: space-between;
    gap: 10px;
    align-items: center;
    font-size: 0.82rem;
  }

  .order-row__left {
    display: flex;
    align-items: center;
    gap: 8px;
    min-width: 0;
  }

  .order-row__name {
    color: #334155;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .order-row__eta {
    flex: 0 0 auto;
    font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    font-weight: 700;
  }

  .order-dot {
    width: 9px;
    height: 9px;
    border-radius: 50%;
    flex: 0 0 auto;
  }

  .order-dot--on-track, .order-row__eta--on-track { color: #15803d; background: #22c55e; }
  .order-dot--monitoring, .order-row__eta--monitoring { color: #2563eb; background: #3b82f6; }
  .order-dot--at-risk, .order-row__eta--at-risk { color: #d97706; background: #f59e0b; }
  .order-dot--delayed, .order-row__eta--delayed { color: #dc2626; background: #ef4444; }
  .order-dot--fulfilled, .order-row__eta--fulfilled { color: #64748b; background: #94a3b8; }

  .next-deadline {
    margin-top: auto;
    padding-top: 10px;
    border-top: 1px solid #e2e8f0;
    color: #64748b;
    font-size: 0.82rem;
  }

  .next-deadline strong {
    color: #0f172a;
  }

  .action-card {
    border-left: 4px solid #94a3b8;
    border-radius: 12px;
    padding: 10px 12px;
    background: #f8fafc;
  }

  .action-card--immediate {
    border-left-color: #dc2626;
    background: #fef2f2;
  }

  .action-card--urgent {
    border-left-color: #d97706;
    background: #fffbeb;
  }

  .action-card--soon {
    border-left-color: #2563eb;
    background: #eff6ff;
  }

  .action-card--info {
    border-left-color: #64748b;
    background: #f8fafc;
  }

  .action-card__meta {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 6px;
    color: #64748b;
    font-size: 0.76rem;
    font-weight: 600;
  }

  .action-badge {
    border-radius: 999px;
    padding: 3px 8px;
    font-size: 0.68rem;
    font-weight: 700;
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }

  .action-badge--immediate {
    background: #dc2626;
    color: #ffffff;
  }

  .action-badge--urgent {
    background: #f59e0b;
    color: #111827;
  }

  .action-badge--soon {
    background: #2563eb;
    color: #ffffff;
  }

  .action-badge--info {
    background: #64748b;
    color: #ffffff;
  }

  .action-card__body {
    color: #1e293b;
    font-size: 0.84rem;
    line-height: 1.45;
  }

  @media (max-width: 1200px) {
    .stakeholder-grid {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }
  }

  @media (max-width: 720px) {
    .stakeholder-grid {
      grid-template-columns: 1fr;
    }
  }
</style>
