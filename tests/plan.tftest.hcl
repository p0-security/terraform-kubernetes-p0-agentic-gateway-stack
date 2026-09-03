# Tests run in plan mode against a mock helm provider — no cluster required.
mock_provider "helm" {}

run "defaults" {
  command = plan

  variables {
    values = []
  }

  assert {
    condition     = helm_release.p0_agentic_gateway_stack.chart == "agentic-gateway-stack"
    error_message = "unexpected chart name"
  }

  assert {
    condition     = helm_release.p0_agentic_gateway_stack.repository == "oci://registry-1.docker.io/p0security"
    error_message = "unexpected repository"
  }

  assert {
    condition     = helm_release.p0_agentic_gateway_stack.name == "agentic-gateway"
    error_message = "default release name should be agentic-gateway"
  }

  assert {
    condition     = helm_release.p0_agentic_gateway_stack.namespace == "agentic-gateway"
    error_message = "default namespace should be agentic-gateway"
  }

  assert {
    condition     = helm_release.p0_agentic_gateway_stack.create_namespace == true
    error_message = "create_namespace should default to true"
  }

  assert {
    condition     = helm_release.p0_agentic_gateway_stack.version == local.chart_version
    error_message = "chart version should be pinned to local.chart_version"
  }

  assert {
    condition     = output.chart_version == local.chart_version
    error_message = "chart_version output should match the pinned local"
  }
}

run "override_release_metadata" {
  command = plan

  variables {
    release_name     = "my-mcp"
    namespace        = "platform"
    create_namespace = false
    values           = []
  }

  assert {
    condition     = helm_release.p0_agentic_gateway_stack.name == "my-mcp"
    error_message = "release name override not applied"
  }

  assert {
    condition     = helm_release.p0_agentic_gateway_stack.namespace == "platform"
    error_message = "namespace override not applied"
  }

  assert {
    condition     = helm_release.p0_agentic_gateway_stack.create_namespace == false
    error_message = "create_namespace override not applied"
  }

  assert {
    condition     = helm_release.p0_agentic_gateway_stack.version == local.chart_version
    error_message = "chart version should remain pinned even when other metadata is overridden"
  }
}

run "values_passthrough" {
  command = plan

  variables {
    values = [
      "letsEncrypt:\n  env: staging\n",
      "letsEncrypt:\n  env: prod\n",
    ]
  }

  assert {
    condition     = length(helm_release.p0_agentic_gateway_stack.values) == 2
    error_message = "both values entries should be passed through to the helm release"
  }
}
