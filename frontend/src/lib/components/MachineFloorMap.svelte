<script lang="ts">
  import type { AssetDashboard } from '$lib/types';

  export let assets: AssetDashboard[] = [];

  const ORDER = [
    'furnace-01',
    'press-01',
    'quench-01',
    'cooling-01',
    'stretcher-01',
    'saw-01',
    'ageing-01',
  ];

  const ICONS: Record<string, string> = {
    furnace: '🏭',
    press: '🔩',
    quench: '💧',
    cooling: '🌬',
    stretcher: '📏',
    saw: '🪚',
    ageing: '🌡',
  };

  const FAULT_LABELS: Record<number, string> = {
    0: '',
    111: 'OVER TEMP',
    112: 'UNDER TEMP',
    113: 'BURNER TRIP',
    211: 'EXTRUSION OVERLOAD',
    212: 'BILLET JAM',
    219: 'EMERGENCY TRIP',
    311: 'QUENCH FLOW LOW',
    312: 'QUENCH TEMP HIGH',
    411: 'COOLING TABLE HOT',
    412: 'AIR FLOW LOW',
    511: 'STRETCH SLIP',
    512: 'STRETCH FORCE HIGH',
    611: 'BLADE WEAR',
    612: 'CUT LENGTH DEV',
    711: 'AGE TEMP DEVIATION',
    712: 'AGE DWELL SHORT',
  };

  function tone(state: string): string {
    if (state === 'RUNNING') return 'running';
    if (state === 'FAULTED') return 'faulted';
    if (state === 'MAINTENANCE') return 'maintenance';
    if (state === 'STARTUP') return 'startup';
    return 'idle';
  }

  $: ordered = ORDER.map((id) => assets.find((asset) => asset.asset === id)).filter(Boolean) as AssetDashboard[];
</script>

<section class="floor-map">
  <div class="floor-map__heading">Aluminium Profile Line 1 — Live Floor View</div>

  <div class="floor-map__strip">
    {#each ordered as asset, i}
      <article class="machine-card machine-card--{tone(asset.state)}">
        <div class="machine-card__top">
          <span class="machine-card__icon">{ICONS[asset.asset_type] ?? '[]'}</span>
          <span class="machine-card__state-dot machine-card__state-dot--{tone(asset.state)}"></span>
        </div>

        <div class="machine-card__name">{asset.display_name}</div>
        <div class="machine-card__state machine-card__state--{tone(asset.state)}">{asset.state}</div>

        {#if asset.fault_code > 0}
          <div class="machine-card__fault">
            {FAULT_LABELS[asset.fault_code] ?? `F${asset.fault_code}`}
          </div>
        {/if}

        {#if asset.cost_so_far_myr > 0.01}
          <div class="machine-card__cost">RM {asset.cost_so_far_myr.toFixed(0)} cost</div>
        {/if}
      </article>

      {#if i < ordered.length - 1}
        <div class="flow-link" aria-hidden="true">
          <svg width="36" height="18" viewBox="0 0 36 18" fill="none">
            <path d="M1 9 H30 M25 4 L33 9 L25 14" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" />
          </svg>
          <span>WIP</span>
        </div>
      {/if}
    {/each}

    <div class="flow-link flow-link--fg" aria-hidden="true">
      <svg width="32" height="18" viewBox="0 0 32 18" fill="none">
        <path d="M1 9 H25 M20 4 L29 9 L20 14" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" />
      </svg>
      <span>FG</span>
    </div>
  </div>
</section>

<style>
  .floor-map {
    background: #ffffff;
    border: 1px solid #dbe2ea;
    border-radius: 16px;
    padding: 20px;
    box-shadow: 0 8px 22px rgba(15, 23, 42, 0.05);
  }

  .floor-map__heading {
    margin-bottom: 16px;
    font-size: 0.8rem;
    font-weight: 700;
    color: #64748b;
    letter-spacing: 0.12em;
    text-transform: uppercase;
  }

  .floor-map__strip {
    display: flex;
    align-items: stretch;
    gap: 8px;
    overflow-x: auto;
    padding-bottom: 4px;
  }

  .machine-card {
    min-width: 168px;
    padding: 14px;
    border-radius: 14px;
    border: 1px solid #cbd5e1;
    background: #f8fafc;
    color: #0f172a;
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.5);
  }

  .machine-card--running {
    background: linear-gradient(180deg, #ecfdf5, #dcfce7);
    border-color: #86efac;
  }

  .machine-card--faulted {
    background: linear-gradient(180deg, #fef2f2, #fee2e2);
    border-color: #fca5a5;
  }

  .machine-card--maintenance {
    background: linear-gradient(180deg, #fffbeb, #fef3c7);
    border-color: #fcd34d;
  }

  .machine-card--startup {
    background: linear-gradient(180deg, #eff6ff, #dbeafe);
    border-color: #93c5fd;
  }

  .machine-card--idle {
    background: linear-gradient(180deg, #f8fafc, #e2e8f0);
    border-color: #cbd5e1;
  }

  .machine-card__top {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 12px;
  }

  .machine-card__icon {
    font-size: 1.45rem;
  }

  .machine-card__state-dot {
    width: 11px;
    height: 11px;
    border-radius: 50%;
    background: #94a3b8;
  }

  .machine-card__state-dot--running { background: #22c55e; }
  .machine-card__state-dot--faulted { background: #ef4444; }
  .machine-card__state-dot--maintenance { background: #f59e0b; }
  .machine-card__state-dot--startup { background: #3b82f6; }
  .machine-card__state-dot--idle { background: #94a3b8; }

  .machine-card__name {
    font-size: 0.95rem;
    font-weight: 700;
    line-height: 1.35;
    margin-bottom: 6px;
  }

  .machine-card__state {
    font-size: 0.8rem;
    font-weight: 700;
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }

  .machine-card__state--running { color: #166534; }
  .machine-card__state--faulted { color: #b91c1c; }
  .machine-card__state--maintenance { color: #b45309; }
  .machine-card__state--startup { color: #1d4ed8; }
  .machine-card__state--idle { color: #475569; }

  .machine-card__fault {
    margin-top: 10px;
    display: inline-flex;
    padding: 4px 8px;
    border-radius: 999px;
    font-size: 0.73rem;
    font-weight: 700;
    background: #7f1d1d;
    color: #ffffff;
  }

  .machine-card__cost {
    margin-top: 10px;
    font-size: 0.76rem;
    color: #9a3412;
    font-weight: 700;
  }

  .flow-link {
    flex: 0 0 auto;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-width: 40px;
    color: #64748b;
    gap: 4px;
    font-size: 0.72rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.08em;
  }

  .flow-link--fg {
    color: #15803d;
  }

  @media (max-width: 720px) {
    .machine-card {
      min-width: 152px;
    }
  }
</style>
