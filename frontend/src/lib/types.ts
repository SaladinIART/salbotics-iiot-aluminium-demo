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

// ── Dashboard / Executive View ─────────────────────────────────────────────

export interface RecommendedAction {
	urgency: 'IMMEDIATE' | 'URGENT' | 'SOON' | 'INFO';
	owner: 'MANAGEMENT' | 'MAINTENANCE' | 'LOGISTICS' | 'PRODUCTION';
	action: string;
}

export interface FinancialSummary {
	cost_rate_myr_hr: number;
	cost_so_far_myr: number;
	orders_at_risk_count: number;
	orders_at_risk_value_myr: number;
}

export interface ProductionStatus {
	throughput_pct: number;
	units_today: number;
	target_today: number;
	faulted_machine_count: number;
}

export interface MaintenanceStatus {
	machines_healthy: number;
	machines_at_risk: number;
	machines_faulted: number;
	current_mttr_estimate_min: number | null;
}

export interface OrderSummary {
	id: string;
	customer: string;
	quantity_ordered: number;
	due_at: string;
	order_value_myr: number;
	computed_status: 'ON_TRACK' | 'MONITORING' | 'AT_RISK' | 'DELAYED' | 'FULFILLED';
}

export interface LogisticsStatus {
	orders_on_track: number;
	orders_monitoring: number;
	orders_at_risk: number;
	orders_delayed: number;
	next_deadline_at: string | null;
	next_deadline_customer: string | null;
	orders: OrderSummary[];
}

export interface AssetDashboard {
	asset: string;
	display_name: string;
	asset_type: string;
	state: string;
	fault_code: number;
	cost_rate_myr_hr: number;
	cost_so_far_myr: number;
	last_maint_at: string | null;
	pm_risk: string | null;
}

export interface DashboardResponse {
	scenario: 'NORMAL' | 'QUALITY_HOLD' | 'LINE_FAULT' | 'EMERGENCY';
	health: 'GREEN' | 'AMBER' | 'RED' | 'CRITICAL';
	health_message: string;
	financial: FinancialSummary;
	recommended_actions: RecommendedAction[];
	production: ProductionStatus;
	maintenance: MaintenanceStatus;
	logistics: LogisticsStatus;
	assets: AssetDashboard[];
}

export interface Site {
	site_id: string;
	display_name: string;
	location: string;
	timezone: string;
	active: boolean;
}
