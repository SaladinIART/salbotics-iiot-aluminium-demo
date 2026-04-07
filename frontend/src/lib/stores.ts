import { writable } from 'svelte/store';
import type { Alert, Asset, TelemetryPoint } from './types';

/** Live asset map keyed by asset id — updated via SSE telemetry stream */
export const assetMap = writable<Map<string, Asset>>(new Map());

/** Latest telemetry points — updated via SSE telemetry stream */
export const latestTelemetry = writable<Map<string, TelemetryPoint>>(new Map());

/** Open alert list — updated via SSE alerts stream */
export const openAlerts = writable<Alert[]>([]);

/** Selected site for filtering */
export const selectedSite = writable<string>('all');
