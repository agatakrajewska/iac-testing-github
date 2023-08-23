{{/*
Expand the name of the chart.
*/}}
{{- define "slurm.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "slurm.fullname" -}}
{{- if $.Values.fullnameOverride -}}
{{- $.Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else -}}
{{- $name := default .Chart.Name $.Values.nameOverride }}
{{- if contains .Release.Name $name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else -}}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end -}}
{{- end -}}
{{- end -}}

Create chart name and version as used by the chart label.
*/}}
{{- define "slurm.chart" -}}
{{- printf "%s" .Chart.Name | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "slurm.munge.secretName" -}}
{{- if empty .Values.munge.existingSecret -}}
{{- printf "%s-munge-secret" (include "slurm.fullname" .) -}}
{{- else }}
{{- printf "%s" .Values.munge.existingSecret -}}
{{- end }}
{{- end }}

{{- define "slurm.jwt.path" -}}
{{- print "/etc/jwt/jwt_hs256.key" -}}
{{- end }}

{{- define "slurm.jwt.secretName" -}}
{{- if empty .Values.jwt.existingSecret -}}
{{- printf "%s-jwt-secret" (include "slurm.fullname" .) -}}
{{- else }}
{{- printf "%s" .Values.jwt.existingSecret -}}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "slurm.labels" -}}
helm.sh/chart: {{ include "slurm.chart" . }}
app.kubernetes.io/part-of: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ $.Release.Service }}
{{- end -}}

{{- define "directories" -}}
{{- $names := list -}}
{{- range .Values.directoryService.directories}}
{{- if .enabled -}}
{{- $names = .name | append $names -}}
{{- end -}}
{{- end -}}
{{- join ","  $names }}
{{- end -}}

{{- define "slurm.dnsConfig" -}}
dnsConfig:
  searches:
    - {{ .Release.Name }}-compute.{{ .Release.Namespace }}.svc.cluster.local
    - {{ .Release.Name }}-controller.{{ .Release.Namespace }}.svc.cluster.local

{{- end -}}

{{- define "slurm.config.volume" -}}
- name: slurm-conf
  projected:
    sources:
      - configMap:
          name: {{ .Release.Name }}-slurm-conf
      {{- if eq .Values.slurmConfig.slurmCtld.procTrackType "proctrack/cgroup" }}
      - configMap:
          name: {{ .Release.Name }}-cgroup-conf
      {{- end }}
      {{- if .Values.slurmConfig.slurmCtld.etcConfigMap }}
      - configMap:
          name: {{ .Values.slurmConfig.slurmCtld.etcConfigMap }}
      {{- end }}
      {{- range $name, $v := .Values.compute.nodes }}
      {{- if $v.enabled }}
      - configMap:
          name: {{ $.Release.Name }}-{{ $name }}-nodes-conf
      - configMap:
          name: {{ $.Release.Name }}-{{ $name }}-topology-conf
      {{- end }}
      {{- end }}
{{- end -}}

{{- define "slurm.mungedContainer" -}}
image: "{{ .Values.controller.image.repository }}:{{ default (print "v" .Chart.Version ) .Values.controller.image.tag -}}"
command: ["munged", "-F"]
resources:
    {{- toYaml .Values.munge.resources | nindent 2 }}
volumeMounts:
- name: run
  mountPath: /run
- name: etc
  mountPath: /etc
lifecycle:
  preStop:
    exec:
      # Give other containers a chance to do what they need to do to stop beore munge dies
      command: ["sleep", "10"]
securityContext:
  runAsNonRoot: true
  runAsUser: 96 # Assume that munge is 96 always
  runAsGroup: 96
{{- end -}}

{{- define "slurm.sssdContainer" -}}
{{- if (include "directories" . ) }}
- name: sssd
  image: "{{ .Values.controller.image.repository }}:{{ default (print "v" .Chart.Version ) .Values.controller.image.tag }}"
  command: ["sssd", "-i"]
  resources:
      {{- toYaml .Values.munge.resources | nindent 4 }}
  volumeMounts:
  - name: sssd-pipes
    mountPath: /var/lib/sss/pipes
  - name: sssd-cache
    mountPath: /var/lib/sss/db
  - name: etc
    mountPath: /etc
  - name: krb5-conf
    mountPath: /etc/krb5.conf
    subPath: krb5.conf
  - name: sssd-conf
    mountPath: /etc/sssd/sssd.conf
    subPath: sssd.conf
{{- range .Values.directoryService.directories }}
{{- if .existingSecret }}
  - name: sssd-ldap-password-secret
    mountPath: /etc/sssd/conf.d
    readOnly: true
{{- end }}
{{- if .ldapsCert }}
  - name: sssd-ldaps-certificate-{{ (.name | replace "." "-") }}
    mountPath: /var/lib/sss/pipes/certificate/{{ .name }}
{{- end }}
{{- end }}
# The user lookup is needed to get AD SIDs mapped automatically
# See: https://www.mail-archive.com/sssd-users@lists.fedorahosted.org/msg07533.html
- name: user-lookup
  image: "{{ .Values.controller.image.repository }}:{{ default (print "v" .Chart.Version ) .Values.controller.image.tag }}"
  command:
    - "bash"
    - "-c"
    - |
      while true; do
        getent passwd{{ range .Values.directoryService.directories }} {{ (.user).canary }}{{- end }}
        sleep 5
      done;
  resources:
      {{- toYaml .Values.munge.resources | nindent 4 }}
  volumeMounts:
  - name: sssd-pipes
    mountPath: /var/lib/sss/pipes
  - name: sssd-cache
    mountPath: /var/lib/sss/db
  - name: etc
    mountPath: /etc
  - name: run
    mountPath: /run
  securityContext:
    runAsNonRoot: true
    runAsUser: 96 # Assume that munge is 96 always
    runAsGroup: 96
{{- end }}
{{- end -}}


{{- define "slurm.runtimeVolumes" -}}
- name: sssd-pipes
  emptyDir:
    medium: Memory
- name: sssd-cache
  emptyDir:
    medium: Memory
- name: run
  emptyDir:
    medium: Memory
- name: etc
  emptyDir:
    medium: Memory
- name: munge
  secret:
    secretName: {{ include "slurm.munge.secretName" . }}
  {{- if (include "directories" . ) }}
- name: krb5-conf
  configMap:
    name: {{ .Release.Name }}-krb5-conf
    defaultMode: 0600
- name: sssd-conf
  configMap:
    name: {{ .Release.Name }}-sssd-conf
    defaultMode: 0600
	{{- range .Values.directoryService.directories }}
    {{- if .ldapsCert }}
- name: sssd-ldaps-certificate-{{ (.name | replace "." "-") }}
  secret:
    secretName: {{ .ldapsCert }}
    defaultMode: 0600
    {{- end}}
    {{- if (.user).existingSecret }}
- name: sssd-ldap-password-secret-{{ (.name | replace "." "-") }}
  secret:
    secretName: {{ .user.existingSecret }}
    defaultMode: 0600
    {{- end }}
    {{- end }}
    {{- if .Values.directoryService.sudoGroups }}
- name: sudoers-groups
  secret:
    secretName: {{ .Release.Name }}-slurm-sudoers
    defaultMode: 0400
    {{- end}}
  {{- end }}
{{- end -}}

{{- define "vpcList" -}}
{{- $names := list -}}
{{- range .Values.network.vpcs }}
{{- $names = .name | append $names -}}
{{- end -}}
{{- join ","  $names }}
{{- end -}}

{{- define "slurm.networkAffinities" -}}
vpc.coreweave.cloud/kubernetes-networking: "{{- not .Values.network.disableK8sNetworking}}"
{{- if .Values.network.vpcs }}
vpc.coreweave.cloud/name: "{{ include "vpcList" . }}"
{{- end }}
{{- end -}}

# Takes a source and base object and returns a version where objects in the source are treated as updates
# to current values.
# new objects in the source are added to the base.
# making updates to list objects occurs by matching the key "name"

# params:
# .src the source object
# .base the base object
# .key the list object key to match on, default "name"
# .forceAffinityUpdate Treats the first affinity match expression as if it is the only match expression and updates it using key "key"
{{define "common.general.update"}}
    {{- $base := .base}}
    {{- $src := .src }}
    {{- $key := default "name" .key}}
    {{- if and (kindIs "slice" $base) (hasKey $base $key)}}
      {{- $base = ((include "common.general.update-named-array" (dict "base" $base "src" $src "key" $key "forceAffinityUpdate" $.forceAffinityUpdate)) | fromYaml ).output }}
    {{- else}}
      {{- range (keys $src) }}
          {{-  if hasKey $base . }}
              {{- if kindIs "slice" (get $src .)}}
                  {{- if and (eq "nodeSelectorTerms" .) $.forceAffinityUpdate }}
                    {{- $base_exp := (get ((index (get ($base) .) 0)) "matchExpressions") }}
                    {{- $src_exp := (get ((index (get ($src) .) 0)) "matchExpressions") }}
                    {{- $base_exp = ((include "common.general.update-named-array" (dict "base" $base_exp "src" $src_exp  "key" "key" "forceAffinityUpdate" $.forceAffinityUpdate)) | fromYaml ).output }}
                    {{- $base = set $base . ((concat (list (dict "matchExpressions" $base_exp)) (get $base . | rest))| uniq)}}
                  {{- else if kindIs "string" ((index (get ($src) .) 0))}}
                    {{- $base = set $base . (concat (get $src .) (get $base .)| uniq) }}
                  {{- else if hasKey (index (get ($src) .) 0) $key}}
                    {{- $base = set $base . ((include "common.general.update-named-array" (dict "base" (get $base .) "src" (get $src .) "key" $key "forceAffinityUpdate" $.forceAffinityUpdate)) | fromYaml ).output }}
                  {{- else}}
                    {{- $base = set $base . (concat (get $src .) (get $base .)| uniq) }}
                  {{- end}}
              {{- else if kindIs "map" (get $src .) }}
                  {{- $base = set $base . (include "common.general.update" (dict "base" (get $base .) "src" (get $src .) "forceAffinityUpdate" $.forceAffinityUpdate) | fromYaml) }}
              {{- else }}
                  {{- $base = set $base . (get $src .) }}
              {{- end }}
          {{- else }}
              {{- $base = set $base . (get $src .) }}
          {{- end }}
      {{- end }}
    {{- end}}
{{- toYaml $base}}
{{- end}}


# Helper for update, takes two arrays and returns
# a new array where objects in the source are treated as updates to the base
# new objects in the source are added to the base.
# making updates to list objects occurs by matching the field with name .key
# params:
# .src the source array
# .base the base array
# .key the field to match on
{{- define "common.general.update-named-array"}}
    {{- $base := .base}}
    {{- $src := .src }}
    {{- $output := list}}
    {{- $modified_keys:= list}}
    {{- $key := .key}}
    {{- range $base }}
        {{- $base_val := .}}
        {{- $matched := false}}
        {{- range $src}}
            {{- if hasKey . $key}}
                {{- if eq ( get . $.key) (get $base_val $.key)}}
                    {{- $output = append $output (include "common.general.update" (dict "base" $base_val "src" . "key" .key "forceAffinityUpdate" $.forceAffinityUpdate) | fromYaml) }}
                    {{- $matched = true}}
                {{- end}}
            {{- end}}
        {{- end}}
        {{- if not $matched}}
            {{- $output = append $output $base_val }}
        {{- end}}
    {{- end }}
    {{- toYaml (dict "output" (concat $output $src | uniq ))}}
{{- end}}

# Takes a source and base object and returns a version
# where new keys and all array objects in source are appended to the base object
# params:
# .src the source object
# .base the base object
{{define "common.general.merge"}}
    {{$base := .base}}
    {{$src := .src }}
    {{- range (keys $src) }}
        {{-  if hasKey $base . }}
            {{- if kindIs "slice" (get $src .) }}
                {{- $base = set $base . (concat (get $src .) (get $base .)| uniq) }}
            {{- else if kindIs "map" (get $src .) }}
                {{- $base = set $base . (deepCopy (get $src .) | merge (get $base .) ) }}
            {{- else }}
                {{- $base = set $base . (get $src .) }}
            {{- end }}
        {{- else }}
            {{- $base = set $base . (get $src .) }}
        {{- end }}
    {{- end }}
{{ toYaml $base}}
{{- end}}

{{- define "retemplate"}}
  {{- if typeIs "string" .value }}
        {{- tpl .value .context }}
    {{- else }}
        {{- tpl (.value | toYaml) .context }}
    {{- end }}
{{- end}}
