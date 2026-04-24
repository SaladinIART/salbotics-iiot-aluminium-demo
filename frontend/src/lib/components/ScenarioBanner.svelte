<script lang="ts">
  export let health: string = 'GREEN';
  export let scenario: string = 'NORMAL';
  export let message: string = '';

  const BG: Record<string, string> = {
    GREEN:    'bg-green-600',
    AMBER:    'bg-amber-500',
    RED:      'bg-red-600',
    CRITICAL: 'bg-red-900',
  };

  const ICON: Record<string, string> = {
    GREEN:    '✓',
    AMBER:    '⚠',
    RED:      '✕',
    CRITICAL: '⛔',
  };

  const LABEL: Record<string, string> = {
    NORMAL:                 'ALL SYSTEMS NORMAL',
    QUALITY_HOLD_QUENCH:    'QUENCH QUALITY HOLD — T5/T6 TEMPER AT RISK',
    PRESS_BOTTLENECK:       'EXTRUSION PRESS OVERLOAD — LINE STARVED',
    STRETCHER_BACKLOG:      'STRETCHER OFFLINE — WIP ACCUMULATING',
    AGEING_OVEN_DEVIATION:  'AGEING OVEN OUT OF T6 BAND — BATCH SUSPECT',
    EMERGENCY_PRESS_TRIP:   'EMERGENCY PRESS TRIP — FULL LINE DOWN',
  };

  $: bgClass = BG[health] ?? 'bg-gray-700';
  $: icon = ICON[health] ?? '?';
  $: label = LABEL[scenario] ?? scenario;
</script>

<div class="w-full {bgClass} text-white px-6 py-4 flex items-center gap-4 rounded-lg shadow-lg">
  <span class="text-3xl font-bold leading-none">{icon}</span>
  <div class="flex-1 min-w-0">
    <div class="font-bold text-lg tracking-wide">{label}</div>
    <div class="text-sm text-white/80 truncate">{message}</div>
  </div>
  <div class="text-right shrink-0">
    <div class="text-xs uppercase tracking-widest text-white/60">Health</div>
    <div class="font-mono font-bold text-xl">{health}</div>
  </div>
</div>
