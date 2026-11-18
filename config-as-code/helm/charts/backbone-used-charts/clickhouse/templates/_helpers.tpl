{{/*
Merge the per-environment overrides (the `clickhouse:` block in
environments/who-afro-hcm.yaml) over the chart defaults, so templates can read
plain .Values.* keys. Mirrors the pattern used by the other charts in this repo.
*/}}
{{- define "clickhouse.init" -}}
{{- $envOverrides := index .Values (default .Chart.Name .Values.name) -}}
{{- if $envOverrides -}}
{{- $_ := mustMergeOverwrite .Values $envOverrides -}}
{{- end -}}
{{- end -}}

{{- define "clickhouse.name" -}}
{{- default .Chart.Name .Values.name -}}
{{- end -}}

{{- define "clickhouse.labels" -}}
app: {{ include "clickhouse.name" . }}
group: {{ .Values.labels.group }}
{{- end -}}
