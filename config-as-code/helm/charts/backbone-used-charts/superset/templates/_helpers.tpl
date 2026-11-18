{{/*
Merge the per-environment overrides (the `superset:` block in
environments/who-afro-hcm.yaml) over the chart defaults, so templates can read
plain .Values.* keys.
*/}}
{{- define "superset.init" -}}
{{- $envOverrides := index .Values (default .Chart.Name .Values.name) -}}
{{- if $envOverrides -}}
{{- $_ := mustMergeOverwrite .Values $envOverrides -}}
{{- end -}}
{{- end -}}

{{/*
Shell snippet shared by every pod: the drivers installed by the init container
live outside site-packages, so PYTHONPATH has to pick them up first.
*/}}
{{- define "superset.pythonPath" -}}
export PYTHONPATH="/python-packages:/app/pythonpath:$PYTHONPATH"
{{- end -}}

{{/*
Init container that installs the extra DB drivers into the shared emptyDir.
*/}}
{{- define "superset.installDrivers" -}}
- name: install-drivers
  image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
  imagePullPolicy: {{ .Values.image.pullPolicy }}
  command:
    - /bin/sh
    - -c
    - |
      set -e
      echo "Installing DB drivers: {{ join " " .Values.drivers }}"
      pip install --no-cache-dir --target=/python-packages {{ join " " .Values.drivers }}
      echo "Drivers installed."
  volumeMounts:
    - name: python-packages
      mountPath: /python-packages
  resources:
    {{- toYaml .Values.initContainers.resources | nindent 4 }}
{{- end -}}
