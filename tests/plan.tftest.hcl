# Tests run in plan mode against a mock helm provider — no cluster required.
mock_provider "helm" {}

variables {
  gateway_url              = "https://gateway.example.com"
  lets_encrypt_email       = "ops@example.com"
  oidc_client_id           = "client-123"
  storage_class            = "gp2"
  p0_url                   = "https://api.p0.app/o/acme"
  p0_audience              = "https://api.p0.app/o/acme"
  p0_service_account_email = "gw@p0.iam.gserviceaccount.com"
}

run "defaults" {
  command = plan

  assert {
    condition     = helm_release.p0_agentic_gateway_stack.chart == "agentic-gateway-stack"
    error_message = "unexpected chart name"
  }

  assert {
    condition     = helm_release.p0_agentic_gateway_stack.repository == "oci://registry-1.docker.io/p0security"
    error_message = "unexpected repository"
  }

  assert {
    condition     = helm_release.p0_agentic_gateway_stack.version == "0.10.2"
    error_message = "chart version should be 0.10.2; when bumping the pin, update this test and the compatibility matrix together"
  }

  assert {
    condition     = output.chart_version == "0.10.2"
    error_message = "chart_version output should match the pinned chart"
  }

  assert {
    condition     = helm_release.p0_agentic_gateway_stack.name == "agentic-gateway"
    error_message = "default release name should be agentic-gateway"
  }

  assert {
    condition     = helm_release.p0_agentic_gateway_stack.namespace == "p0-agentic-gateway"
    error_message = "default namespace should be p0-agentic-gateway, the namespace the console, the deploy guide and the provider examples all use"
  }

  assert {
    condition     = helm_release.p0_agentic_gateway_stack.create_namespace == true
    error_message = "create_namespace should default to true"
  }

  assert {
    condition     = helm_release.p0_agentic_gateway_stack.timeout == 360
    error_message = "timeout should default to 360 so it outlasts the secrets Job's 300 second deadline"
  }

  assert {
    condition     = helm_release.p0_agentic_gateway_stack.wait == false
    error_message = "wait should default to false; the TLS certificate cannot issue before the DNS record exists"
  }
}

run "renders_typed_inputs_into_chart_values" {
  command = plan

  assert {
    condition     = length(helm_release.p0_agentic_gateway_stack.values) == 1
    error_message = "with no extra_values the release should carry exactly one values document"
  }

  assert {
    condition     = yamldecode(helm_release.p0_agentic_gateway_stack.values[0])["agentic-gateway"]["gateway"]["host"] == "gateway.example.com"
    error_message = "gateway host should be the hostname of gateway_url"
  }

  assert {
    condition     = yamldecode(helm_release.p0_agentic_gateway_stack.values[0])["agentic-gateway"]["gateway"]["className"] == "agentic-gateway"
    error_message = "GatewayClass name should be the release name"
  }

  assert {
    condition     = yamldecode(helm_release.p0_agentic_gateway_stack.values[0])["agentic-gateway"]["agenticAuthServer"]["gatewayIss"] == "https://gateway.example.com"
    error_message = "auth server issuer should be gateway_url"
  }

  assert {
    condition     = yamldecode(helm_release.p0_agentic_gateway_stack.values[0])["agentic-gateway"]["agenticGatewayServer"]["gatewayIss"] == "https://gateway.example.com"
    error_message = "gateway server issuer should be gateway_url"
  }

  assert {
    condition     = yamldecode(helm_release.p0_agentic_gateway_stack.values[0])["agentic-gateway"]["agenticAuthServer"]["oidcClientId"] == "client-123"
    error_message = "oidcClientId should be oidc_client_id"
  }

  assert {
    condition     = !can(yamldecode(helm_release.p0_agentic_gateway_stack.values[0])["agentic-gateway"]["agenticAuthServer"]["openIdDomain"])
    error_message = "an unset open_id_domain should omit the key, leaving the chart default and extra_values in force"
  }

  assert {
    condition     = yamldecode(helm_release.p0_agentic_gateway_stack.values[0])["agentic-gateway"]["agenticGatewayServer"]["manageAllowedEmails"] == "gw@p0.iam.gserviceaccount.com"
    error_message = "manageAllowedEmails should be p0_service_account_email"
  }

  assert {
    condition     = yamldecode(helm_release.p0_agentic_gateway_stack.values[0])["agentic-gateway"]["agenticAuthServer"]["p0Url"] == "https://api.p0.app/o/acme" && yamldecode(helm_release.p0_agentic_gateway_stack.values[0])["agentic-gateway"]["agenticGatewayServer"]["p0Audience"] == "https://api.p0.app/o/acme"
    error_message = "p0_url and p0_audience should reach both servers"
  }

  assert {
    condition     = yamldecode(helm_release.p0_agentic_gateway_stack.values[0])["letsEncrypt"]["env"] == "staging" && yamldecode(helm_release.p0_agentic_gateway_stack.values[0])["letsEncrypt"]["email"] == "ops@example.com"
    error_message = "lets_encrypt_env should default to staging so a failing first install cannot exhaust the prod rate limit"
  }

  assert {
    condition     = yamldecode(helm_release.p0_agentic_gateway_stack.values[0])["postgresql"]["storageClass"] == "gp2" && yamldecode(helm_release.p0_agentic_gateway_stack.values[0])["victorialogs"]["storageClass"] == "gp2"
    error_message = "storage_class should reach both StatefulSets"
  }
}

run "typed_inputs_win_over_extra_values" {
  command = plan

  # The input and the extra_values entry must disagree, and neither may be the
  # default. Set both to the same value, or leave the input at its default, and
  # this run passes whatever order the documents are merged in — it stops
  # testing precedence while still looking like coverage.
  variables {
    lets_encrypt_env = "staging"
    extra_values = [
      "letsEncrypt:\n  env: prod\ncollector:\n  gcpProjectId: my-project\n",
    ]
  }

  assert {
    condition     = length(helm_release.p0_agentic_gateway_stack.values) == 2
    error_message = "extra_values should be passed through alongside the typed document"
  }

  assert {
    condition     = yamldecode(helm_release.p0_agentic_gateway_stack.values[1])["letsEncrypt"]["env"] == "staging"
    error_message = "the typed document must be last so typed inputs win over extra_values"
  }

  assert {
    condition     = yamldecode(helm_release.p0_agentic_gateway_stack.values[0])["collector"]["gcpProjectId"] == "my-project"
    error_message = "extra_values should carry keys the module has no input for"
  }
}

run "unset_open_id_domain_leaves_extra_values_alone" {
  command = plan

  variables {
    extra_values = [
      "agentic-gateway:\n  agenticAuthServer:\n    openIdDomain: \"[^@]*@example[.]com\"\n",
    ]
  }

  # The typed document is merged last, so an unconditional openIdDomain = ""
  # would turn a caller's allowlist into open access.
  assert {
    condition     = yamldecode(helm_release.p0_agentic_gateway_stack.values[0])["agentic-gateway"]["agenticAuthServer"]["openIdDomain"] == "[^@]*@example[.]com"
    error_message = "an allowlist set through extra_values must survive when open_id_domain is unset"
  }

  assert {
    condition     = !can(yamldecode(helm_release.p0_agentic_gateway_stack.values[1])["agentic-gateway"]["agenticAuthServer"]["openIdDomain"])
    error_message = "the typed document must not carry openIdDomain when the input is unset"
  }
}

run "open_id_domain_wins_when_set" {
  command = plan

  variables {
    open_id_domain = "[^@]*@p0[.]dev"
    extra_values = [
      "agentic-gateway:\n  agenticAuthServer:\n    openIdDomain: \"[^@]*@example[.]com\"\n",
    ]
  }

  assert {
    condition     = yamldecode(helm_release.p0_agentic_gateway_stack.values[1])["agentic-gateway"]["agenticAuthServer"]["openIdDomain"] == "[^@]*@p0[.]dev"
    error_message = "a set open_id_domain must win over extra_values"
  }
}

run "override_release_metadata" {
  command = plan

  variables {
    release_name     = "my-gateway"
    namespace        = "platform"
    create_namespace = false
    timeout          = 900
    wait             = true
  }

  assert {
    condition     = helm_release.p0_agentic_gateway_stack.name == "my-gateway"
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
    condition     = helm_release.p0_agentic_gateway_stack.timeout == 900 && helm_release.p0_agentic_gateway_stack.wait == true
    error_message = "timeout and wait overrides not applied"
  }

  assert {
    condition     = yamldecode(helm_release.p0_agentic_gateway_stack.values[0])["agentic-gateway"]["gateway"]["className"] == "my-gateway"
    error_message = "GatewayClass name should follow the release name"
  }
}

run "rejects_gateway_url_that_is_not_https" {
  command = plan

  variables {
    gateway_url = "http://gateway.example.com"
  }

  expect_failures = [var.gateway_url]
}

run "rejects_gateway_url_with_a_path_or_trailing_slash" {
  command = plan

  variables {
    gateway_url = "https://gateway.example.com/"
  }

  expect_failures = [var.gateway_url]
}

run "rejects_release_name_that_is_not_a_dns_label" {
  command = plan

  variables {
    release_name = "Prod_Gateway"
  }

  expect_failures = [var.release_name]
}

run "rejects_timeout_at_or_below_the_secrets_job_deadline" {
  command = plan

  variables {
    timeout = 300
  }

  expect_failures = [var.timeout]
}

run "rejects_bad_lets_encrypt_env" {
  command = plan

  variables {
    lets_encrypt_env = "production"
  }

  expect_failures = [var.lets_encrypt_env]
}
