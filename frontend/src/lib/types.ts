export interface Asset {
	asset: string;
	display_name: string;
	asset_type: string;
	site: string;
	line_name: string;
	cell_name: string | null;
	state: string;
	fault_code: number;
	quality: string;
	last_seen: string | null;
	open_alert_count: number;
}

export interface TelemetryPoint {
	ts: string;
	asset: string;
	signal: string;
	value: number;
	quality: string;
	state: string;
}

export interface Alert {
	id: string;
	opened_at: string;
	site: string;
	line_name: string;
	asset: string;
	asset_display_name: string | null;
	signal: string;
	alert_type: 'threshold' | 'statistical' | 'ml';
	severity: 'info' | 'warning' | 'critical';
	value: number;
	threshold: number | null;
	state: 'OPEN' | 'ACKED' | 'CLOSED';
	message: string;
	acked_at: string | null;
	closed_at: string | null;
	rule_id: string | null;
}

export interface KpiSummary {
	asset: string;
	display_name: string | null;
	asset_type: string | null;
	window_hours: number;
	total_readings: number;
	good_readings: number;
	quality_rate: number;
	running_minutes: number;
	fault_minutes: number;
	availability: number;
	open_alert_count: number;
}

export interface Site {
	site_id: string;
	display_name: string;
	location: string;
	timezone: string;
	active: boolean;
}
