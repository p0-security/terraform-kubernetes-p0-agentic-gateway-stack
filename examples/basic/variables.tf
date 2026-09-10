# Helm provider's Kubernetes auth variables

variable "kube_config_path" {
  description = "Path to the kubeconfig file."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "kubectl context name to deploy into."
  type        = string
}

# Gateway settings; the P0 console shows every value on the install page.

variable "release_name" {
  description = "Helm release name and GatewayClass name; the console uses the gateway id."
  type        = string
  default     = "agentic-gateway"
}

variable "namespace" {
  description = "Kubernetes namespace to deploy into."
  type        = string
  default     = "p0-agentic-gateway"
}

variable "gateway_url" {
  description = "Public URL of the gateway, https and hostname only."
  type        = string
}

variable "lets_encrypt_email" {
  description = "Email registered with Let's Encrypt."
  type        = string
}

variable "oidc_client_id" {
  description = "OAuth client ID at your identity provider."
  type        = string
}

variable "storage_class" {
  description = "StorageClass for PostgreSQL and VictoriaLogs volumes, for example gp2 on EKS."
  type        = string
}

variable "p0_url" {
  description = "Your P0 tenant URL."
  type        = string
}

variable "p0_audience" {
  description = "Token audience for your P0 tenant; usually the same as p0_url."
  type        = string
}

variable "p0_service_account_email" {
  description = "P0 service account allowed to manage the gateway."
  type        = string
}
