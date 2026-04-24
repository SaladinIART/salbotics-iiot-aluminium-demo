<script lang="ts">
  export let health: string = 'GREEN';
  export let scenario: string = 'NORMAL';
  export let message: string = '';

  const ICON: Record<string, string> = {
    GREEN: '✓',
    AMBER: '!',
    RED: 'X',
    CRITICAL: '!!',
  };

  const LABEL: Record<string, string> = {
    NORMAL: 'ALL SYSTEMS NORMAL',
    QUALITY_HOLD_QUENCH: 'QUENCH QUALITY HOLD — T5/T6 TEMPER AT RISK',
    PRESS_BOTTLENECK: 'EXTRUSION PRESS OVERLOAD — LINE STARVED',
    STRETCHER_BACKLOG: 'STRETCHER OFFLINE — WIP ACCUMULATING',
    AGEING_OVEN_DEVIATION: 'AGEING OVEN OUT OF T6 BAND — BATCH SUSPECT',
    EMERGENCY_PRESS_TRIP: 'EMERGENCY PRESS TRIP — FULL LINE DOWN',
  };

  const TONE: Record<string, string> = {
    GREEN: 'green',
    AMBER: 'amber',
    RED: 'red',
    CRITICAL: 'critical',
  };

  $: tone = TONE[health] ?? 'neutral';
  $: icon = ICON[health] ?? '?';
  $: label = LABEL[scenario] ?? scenario;
</script>

<section class="banner banner--{tone}">
  <div class="banner__icon">{icon}</div>

  <div class="banner__body">
    <div class="banner__label">{label}</div>
    <div class="banner__message">{message}</div>
  </div>

  <div class="banner__health">
    <span class="banner__health-label">Health</span>
    <strong>{health}</strong>
  </div>
</section>

<style>
  .banner {
    display: grid;
    grid-template-columns: auto 1fr auto;
    gap: 16px;
    align-items: center;
    padding: 18px 22px;
    border-radius: 16px;
    color: #ffffff;
    box-shadow: 0 12px 28px rgba(15, 23, 42, 0.14);
  }

  .banner--green {
    background: linear-gradient(135deg, #166534, #15803d);
  }

  .banner--amber {
    background: linear-gradient(135deg, #b45309, #d97706);
  }

  .banner--red {
    background: linear-gradient(135deg, #b91c1c, #dc2626);
  }

  .banner--critical {
    background: linear-gradient(135deg, #7f1d1d, #991b1b);
  }

  .banner--neutral {
    background: linear-gradient(135deg, #334155, #475569);
  }

  .banner__icon {
    width: 52px;
    height: 52px;
    border-radius: 14px;
    display: grid;
    place-items: center;
    font-size: 1.35rem;
    font-weight: 800;
    background: rgba(255, 255, 255, 0.16);
    border: 1px solid rgba(255, 255, 255, 0.22);
  }

  .banner__body {
    min-width: 0;
  }

  .banner__label {
    font-size: 1.05rem;
    font-weight: 800;
    letter-spacing: 0.04em;
    margin-bottom: 6px;
  }

  .banner__message {
    color: rgba(255, 255, 255, 0.88);
    line-height: 1.45;
  }

  .banner__health {
    text-align: right;
    min-width: 92px;
  }

  .banner__health-label {
    display: block;
    font-size: 0.74rem;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    color: rgba(255, 255, 255, 0.72);
    margin-bottom: 4px;
  }

  .banner__health strong {
    font-size: 1.25rem;
    font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  }

  @media (max-width: 720px) {
    .banner {
      grid-template-columns: auto 1fr;
    }

    .banner__health {
      grid-column: 1 / -1;
      text-align: left;
      padding-top: 10px;
      border-top: 1px solid rgba(255, 255, 255, 0.16);
    }
  }
</style>
