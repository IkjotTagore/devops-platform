variable "cilium_version"          { default = "1.14.5" }
variable "argocd_chart_version"    { default = "6.4.0" }
variable "kyverno_version"         { default = "3.1.4" }
variable "prometheus_stack_version"{ default = "57.0.3" }
variable "loki_version"            { default = "2.10.2" }
variable "keda_version"            { default = "2.13.1" }
variable "harbor_version"          { default = "1.14.0" }

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = "admin"
}

variable "registry_host" {
  description = "Hostname for the Harbor registry"
  type        = string
  default     = "registry.platform.local"
}
