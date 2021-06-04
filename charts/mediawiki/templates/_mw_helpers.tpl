{{/*

 Labels for releases.
 Typical values for a cluster of appservers will be
 app: MediaWiki
 chart: MediaWiki-0.1
 release: canary (or production)
 heritage: helm
 deployment: parsoid
*/}}
{{ define "mw.labels" }}
labels:
  app: {{ template "wmf.chartname" . }}
  chart: {{ template "wmf.chartid" . }}
  release: {{ .Release.Name }}
  heritage: {{ .Release.Service }}
{{ end }}

{{/*

Network egress for MediaWiki

*/}}
{{- define "mediawiki.networkpolicy.egress" -}}
{{/* memcached */}}
{{- if .mcrouter.enabled }}
  {{- $mcrouter_zone := .mcrouter.zone -}}
  {{- range .mcrouter.pools -}}
    {{- $is_local := eq $mcrouter_zone .zone }}
    {{- range .servers }}
- to:
  - ipBlock:
      cidr: {{ . }}/32
  ports:
  - protocol: TCP
    port: {{if $is_local }}11211{{- else -}}11214{{- end -}}
    {{- end }}
  {{- end }}
{{- end }}
{{- if .nutcracker.enabled }}
  {{- range .nutcracker.pools }}
    {{- range .servers }}
- to:
  - ipBlock:
      cidr: {{ .host }}/32
  ports:
  - protocol: TCP
    port: {{ .port }}
    {{- end }}
  {{- end }}
{{- end }}
{{- with .egress.database_networks }}
{{/* databases. For now we just ask for a CIDR and open ports 3306 and 3311 through 3320 */}}
- to:
  - ipBlock:
      cidr: {{ . }}
  ports:
  {{- $ports := list 3306 3310 3311 3312 3313 3314 3315 3316 3317 3318 3319 3320 -}}
  {{- range $ports }}
  - protocol: TCP
    port: {{.}}
  {{- end }}
{{- end }}
{{- range .egress.etcd_servers }}
- to:
  - ipBlock:
      cidr: {{ .ip }}/32
  ports:
  - protocol: TCP
    port: {{ .port }}
{{- end -}}
{{- end -}}