locals {
  # Pinned chart version for this module release. Update in lockstep with
  # module version tags — see the compatibility matrix in README.md.
  chart_version = "0.10.2"
}

resource "helm_release" "p0_agentic_gateway_stack" {
  name             = var.release_name
  namespace        = var.namespace
  create_namespace = var.create_namespace
  repository       = "oci://registry-1.docker.io/p0security"
  chart            = "agentic-gateway-stack"
  version          = local.chart_version

  values = var.values
}

# Keeps consumers of the p0-oauthed-mcp module on a no-op plan when they swap
# `source` to this module: without it, the resource rename reads as a
# destroy/create of the whole release.
moved {
  from = helm_release.oauthed_mcp
  to   = helm_release.p0_agentic_gateway_stack
}
