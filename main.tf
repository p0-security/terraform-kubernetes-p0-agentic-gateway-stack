locals {
  # Pinned chart version for this module release. Update in lockstep with
  # module version tags — see the compatibility matrix in README.md.
  chart_version = "0.10.2"

  gateway_host = trimprefix(var.gateway_url, "https://")

  # Chart keys are mapped here so a rename on the chart side is absorbed by a
  # module release instead of reaching callers.
  values = {
    letsEncrypt = {
      env   = var.lets_encrypt_env
      email = var.lets_encrypt_email
    }
    postgresql = {
      storageClass = var.storage_class
    }
    victorialogs = {
      storageClass = var.storage_class
    }
    "agentic-gateway" = {
      gateway = {
        className = var.release_name
        host      = local.gateway_host
      }
      # Optional inputs are omitted when empty. The typed document wins over
      # extra_values, so writing a key here unconditionally would override a
      # caller's value with an empty one — and for openIdDomain, an empty
      # value is the permissive setting that admits every verified account.
      agenticAuthServer = merge(
        {
          oidcClientId = var.oidc_client_id
          p0Url        = var.p0_url
          p0Audience   = var.p0_audience
          gatewayIss   = var.gateway_url
        },
        var.open_id_domain == "" ? {} : { openIdDomain = var.open_id_domain },
      )
      agenticGatewayServer = {
        p0Url               = var.p0_url
        p0Audience          = var.p0_audience
        gatewayIss          = var.gateway_url
        manageAllowedEmails = var.p0_service_account_email
      }
    }
  }
}

resource "helm_release" "p0_agentic_gateway_stack" {
  name             = var.release_name
  namespace        = var.namespace
  create_namespace = var.create_namespace
  repository       = "oci://registry-1.docker.io/p0security"
  chart            = "agentic-gateway-stack"
  version          = local.chart_version
  timeout          = var.timeout
  wait             = var.wait

  # Later documents win, so the typed inputs go last.
  values = concat(var.extra_values, [yamlencode(local.values)])
}

# Keeps consumers of the p0-oauthed-mcp module on a no-op plan when they swap
# `source` to this module: without it, the resource rename reads as a
# destroy/create of the whole release.
moved {
  from = helm_release.oauthed_mcp
  to   = helm_release.p0_agentic_gateway_stack
}
