provider "helm" {
  kubernetes = {
    config_path    = var.kube_config_path
    config_context = var.kube_context
  }
}

module "p0_agentic_gateway_stack" {
  source  = "p0-security/p0-agentic-gateway-stack/kubernetes"
  version = "1.0.0"

  release_name             = var.release_name
  namespace                = var.namespace
  gateway_url              = var.gateway_url
  lets_encrypt_email       = var.lets_encrypt_email
  oidc_client_id           = var.oidc_client_id
  storage_class            = var.storage_class
  p0_url                   = var.p0_url
  p0_audience              = var.p0_audience
  p0_service_account_email = var.p0_service_account_email
}

output "release_name" { value = module.p0_agentic_gateway_stack.release_name }
output "namespace" { value = module.p0_agentic_gateway_stack.namespace }
output "chart_version" { value = module.p0_agentic_gateway_stack.chart_version }
