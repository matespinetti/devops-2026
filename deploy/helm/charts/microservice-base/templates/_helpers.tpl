{{- define "microservice-base.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "microservice-base.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "microservice-base.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "microservice-base.labels" -}}
helm.sh/chart: {{ include "microservice-base.chart" . }}
app.kubernetes.io/name: {{ include "microservice-base.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/component: {{ default "api" .Values.component | quote }}
app.kubernetes.io/part-of: {{ default .Chart.Name .Values.global.projectName | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.labels }}
{{- if .environment }}
environment: {{ .environment | quote }}
{{- end }}
{{- if .team }}
team: {{ .team | quote }}
{{- end }}
{{- if .owner }}
owner: {{ .owner | quote }}
{{- end }}
{{- end }}
{{- end -}}

{{- define "microservice-base.selectorLabels" -}}
app.kubernetes.io/name: {{ include "microservice-base.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "microservice-base.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "microservice-base.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}
