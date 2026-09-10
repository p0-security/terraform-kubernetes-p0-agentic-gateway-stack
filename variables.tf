variable "release_name" {
  description = "Helm release name. Also used as the GatewayClass name, which is cluster-scoped, so it must be unique in the cluster. Changing it replaces the release."
  type        = string
  default     = "agentic-gateway"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.release_name)) && length(var.release_name) <= 53
    error_message = "release_name must be a lowercase DNS label of at most 53 characters: letters, digits and hyphens, starting and ending with a letter or digit."
  }
}

variable "namespace" {
  description = "Kubernetes namespace to deploy into. Changing it replaces the release and leaves the old PostgreSQL volume behind in the old namespace."
  type        = string
  default     = "p0-agentic-gateway"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.namespace)) && length(var.namespace) <= 63
    error_message = "namespace must be a lowercase DNS label of at most 63 characters."
  }
}

variable "create_namespace" {
  description = "Create the namespace if it does not exist."
  type        = bool
  default     = true
  nullable    = false
}

variable "gateway_url" {
  description = "Public URL of the gateway as https:// plus a hostname, for example https://gateway.example.com. Sets the Gateway host and the token issuer on both servers."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^https://[a-z0-9]([-a-z0-9]*[a-z0-9])?(\\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)+$", var.gateway_url))
    error_message = "gateway_url must be https:// followed by a lowercase hostname, with no port, path or trailing slash."
  }
}

variable "lets_encrypt_email" {
  description = "Email address registered with Let's Encrypt for certificate expiry notices."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.lets_encrypt_email))
    error_message = "lets_encrypt_email must be an email address."
  }
}

variable "lets_encrypt_env" {
  description = "Let's Encrypt environment. staging issues untrusted certificates under much higher rate limits; prod issues trusted certificates and allows five per week for the same set of hostnames. Starts on staging so a first install that fails repeatedly does not exhaust the prod limit. Switch to prod once DNS resolves and a staging certificate has issued."
  type        = string
  default     = "staging"
  nullable    = false

  validation {
    condition     = contains(["staging", "prod"], var.lets_encrypt_env)
    error_message = "lets_encrypt_env must be \"staging\" or \"prod\"."
  }
}

variable "oidc_client_id" {
  description = "Client ID of the OAuth client at your identity provider."
  type        = string
  nullable    = false

  validation {
    condition     = length(var.oidc_client_id) > 0
    error_message = "oidc_client_id must not be empty."
  }
}

variable "open_id_domain" {
  description = "Regular expression that a signed-in account's email domain must match. Empty admits every account the identity provider verifies."
  type        = string
  default     = ""
  nullable    = false
}

variable "storage_class" {
  description = "StorageClass for the bundled PostgreSQL and VictoriaLogs volumes. Immutable once applied: Kubernetes rejects changes to a StatefulSet's volume claim template, so changing this fails the upgrade."
  type        = string
  nullable    = false

  validation {
    condition     = length(var.storage_class) > 0
    error_message = "storage_class must not be empty."
  }
}

variable "p0_url" {
  description = "Your P0 tenant URL, for example https://api.p0.app/o/<tenant>."
  type        = string
  nullable    = false

  validation {
    condition     = startswith(var.p0_url, "https://")
    error_message = "p0_url must start with https://."
  }
}

variable "p0_audience" {
  description = "Audience P0 uses in tokens for this tenant; usually the same value as p0_url."
  type        = string
  nullable    = false

  validation {
    condition     = startswith(var.p0_audience, "https://")
    error_message = "p0_audience must start with https://."
  }
}

variable "p0_service_account_email" {
  description = "Email of the P0 service account allowed to call the gateway's management API. Shown by the P0 console, or returned as service_account_email by the p0_agentic_gateway_staged resource."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.p0_service_account_email))
    error_message = "p0_service_account_email must be an email address."
  }
}

variable "extra_values" {
  description = "Additional YAML values documents for chart settings this module has no input for. Merged before the typed inputs, so a typed input always wins over the same key here."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "timeout" {
  description = "Seconds Helm waits for an install or upgrade, hooks included. Must exceed the 300 second deadline of the chart's secrets Job so a stuck Job fails with its own error instead of a generic Helm timeout."
  type        = number
  default     = 360
  nullable    = false

  validation {
    condition     = var.timeout > 300
    error_message = "timeout must be greater than 300 seconds, the secrets Job's deadline."
  }
}

variable "wait" {
  description = "Wait for every resource to be ready before marking the release deployed. Off by default: the TLS certificate cannot issue until the DNS record for gateway_url exists, so waiting on a first install times out."
  type        = bool
  default     = false
  nullable    = false
}
