variable "release_name" {
  description = "Helm release name."
  type        = string
  default     = "agentic-gateway"
}

variable "namespace" {
  description = "Kubernetes namespace to deploy into."
  type        = string
  default     = "agentic-gateway"
}

variable "create_namespace" {
  description = "Create the namespace if it does not exist."
  type        = bool
  default     = true
}

variable "values" {
  description = "List of YAML values strings merged left-to-right (last wins), equivalent to helm install -f. See the chart's values.yaml for the full schema."
  type        = list(string)
  default     = []
}
