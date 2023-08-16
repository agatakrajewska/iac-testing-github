{{- define "slurm.compute.s6" -}}
{{- if .Values.compute.ssh.enabled }}
sshd:
  type: longrun
  script: |
    #!/usr/bin/env bash
    /usr/sbin/sshd -D
{{- end -}}
{{- end -}}

{{- define "slurm.compute.s6.volumes" -}}
{{- range $name, $v := (fromYaml (include "slurm.compute.s6" .)) -}}
- name: s6-service-{{ $name }}
  configMap:
    name: {{ $.Release.Name }}-s6-service-{{ $name }}
    defaultMode: 0755
    items:
      - key: type
        path: type
      {{- if eq $v.type "oneshot" }}
      - key: up
        path: up
      {{- else }}
      - key: run
        path: run
      {{- end }}
      - key: script.sh
        path: script.sh
      - key: base
        path: dependencies.d/base
{{- end }}
{{- range $name, $v := .Values.compute.s6 }}
- name: s6-service-{{ $name }}
  configMap:
    name: {{ $.Release.Name }}-s6-service-{{ $name }}
    defaultMode: 0755
    items:
      - key: type
        path: type
      {{- if eq $v.type "oneshot" }}
      - key: up
        path: up
      {{- else }}
      - key: run
        path: run
      {{- end }}
      - key: script.sh
        path: script.sh
      - key: base
        path: dependencies.d/base
{{- end }}
{{- $s6_sources := list}}
{{- $s6_sources = concat $s6_sources (keys .Values.compute.s6)}}
{{- $s6_sources = concat $s6_sources (keys (fromYaml (include "slurm.compute.s6" .)))}}
{{- if gt (len $s6_sources) 0}}
- name: s6-sources
  projected:
    sources:
  {{- range $s6_sources }}
    - configMap:
        name: {{ $.Release.Name }}-s6-source-{{ . }}
        items:
          - key: {{ . }}
            path: {{ . }}
  {{- end }}
{{- end}}
{{ end }}

{{- define "slurm.compute.s6.volumeMounts" -}}
{{- range $name, $v := .Values.compute.s6 }}
- name: s6-service-{{ $name }}
  mountPath: /etc/s6-overlay/s6-rc.d/{{ $name }}
{{- end }}
{{- range $name, $v := (fromYaml (include "slurm.compute.s6" .)) }}
- name: s6-service-{{ $name }}
  mountPath: /etc/s6-overlay/s6-rc.d/{{ $name }}
{{- end }}
{{- $s6_sources := list}}
{{- $s6_sources = concat $s6_sources (keys .Values.compute.s6)}}
{{- $s6_sources = concat $s6_sources (keys (fromYaml (include "slurm.compute.s6" .)))}}
{{- if gt (len $s6_sources) 0}}
- name: s6-sources
  mountPath: /etc/s6-overlay/s6-rc.d/user/contents.d
{{- end}}
{{- end -}}
