{{/*
Expand the name of the chart.
*/}}
{{- define "nexus.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to every resource.
*/}}
{{- define "nexus.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Selector labels for a given component.
Usage: {{ include "nexus.selectorLabels" (dict "root" . "component" "api") }}
*/}}
{{- define "nexus.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nexus.name" .root }}
app.kubernetes.io/component: {{ .component }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
{{- end }}

{{/*
Full image reference for a NEXUS service.
Usage: {{ include "nexus.image" (dict "root" . "repo" .Values.api.image.repository) }}
*/}}
{{- define "nexus.image" -}}
{{ .root.Values.imageRegistry }}/{{ .repo }}:{{ .root.Values.imageTag }}
{{- end }}

{{/*
Common environment variables shared by all services that need DB + MQTT access.
*/}}
{{- define "nexus.commonEnv" -}}
- name: PGHOST
  value: {{ .Release.Name }}-timescaledb
- name: PGPORT
  value: "5432"
- name: PGDATABASE
  value: iiot
- name: PGUSER
  value: iiot
- name: PGPASSWORD
  valueFrom:
    secretKeyRef:
      name: nexus-secrets
      key: postgresPassword
- name: MQTT_HOST
  value: {{ .Release.Name }}-emqx
- name: MQTT_PORT
  value: "1883"
- name: MQTT_USER
  value: iiot
- name: MQTT_PASSWORD
  valueFrom:
    secretKeyRef:
      name: nexus-secrets
      key: mqttPassword
{{- end }}
