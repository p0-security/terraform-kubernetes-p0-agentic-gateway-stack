# terraform-kubernetes-p0-agentic-gateway-stack

Terraform module that deploys [agentic-gateway](https://github.com/p0-security/agentic-gateway) via the [agentic-gateway-stack](https://github.com/p0-security/p0-helm-oauthed-mcp) umbrella Helm chart. The chart bundles Envoy Gateway, cert-manager, Let's Encrypt (ACME HTTP-01), PostgreSQL, Valkey and VictoriaLogs into a single install.

## Usage

The P0 console generates this block on the gateway install page with every value filled in:

```hcl
provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}

module "p0_agentic_gateway" {
  source  = "p0-security/p0-agentic-gateway-stack/kubernetes"
  version = "1.0.0"

  release_name             = "prod-gateway"
  namespace                = "p0-agentic-gateway"
  gateway_url              = "https://gateway.example.com"
  lets_encrypt_email       = "ops@example.com"
  oidc_client_id           = "<oidc-client-id>"
  storage_class            = "gp2"
  p0_url                   = "https://api.p0.app/o/<tenant>"
  p0_audience              = "https://api.p0.app/o/<tenant>"
  p0_service_account_email = "<service-account>@p0.iam.gserviceaccount.com"
}
```

The module builds the chart's values from these inputs and pins the chart version, so a rename of a chart key is handled by a module release rather than by your configuration. Bad input fails at `terraform plan`: a `gateway_url` with a path, an email without an `@`, a release name with uppercase letters.

There is no secret setup step. The chart creates `app-secrets` from a pre-install hook. The cluster prerequisites still apply: a working block-storage StorageClass for the bundled PostgreSQL, which on EKS means the EBS CSI driver add-on. They are listed in the [chart's deployment guide](https://github.com/p0-security/p0-helm-oauthed-mcp#prerequisites).

### Chart settings without an input

Anything the chart accepts that this module has no input for goes in `extra_values`, a list of YAML documents:

```hcl
  extra_values = [
    file("${path.module}/observability.yaml"),
    yamlencode({
      collector = { gcpProjectId = "my-project" }
    }),
  ]
```

Typed inputs are merged after `extra_values`, so a key that has an input cannot be overridden from `extra_values`. Set it through the input.

Optional inputs are the exception: when one is left empty the module omits its key entirely, so a value you set for it in `extra_values` still applies. `open_id_domain` is the one to know about — it is the login allowlist, and an empty value admits every account your identity provider verifies.

### Helm timeout and wait

Helm waits `timeout` seconds (default 360) for the install or upgrade, hooks included. The default is above the 300 second deadline of the chart's secrets Job on purpose: a stuck Job then fails with its own error rather than a generic Helm timeout. Keep it above 300.

`wait` is off by default. The chart creates a TLS `Certificate` that cannot issue until the DNS record for `gateway_url` points at the gateway's load balancer, so waiting for readiness on a first install times out. Turn it on for upgrades once DNS is in place if you want Terraform to block until pods are ready.

### After apply

Patch in the real OIDC client secret and restart the auth server. The hook writes a placeholder and never overwrites a value once set:

```bash
kubectl -n <namespace> patch secret app-secrets \
  --type merge \
  -p '{"stringData":{"OIDC_CLIENT_SECRET":"<your-oidc-client-secret>"}}'
kubectl -n <namespace> rollout restart deploy/agentic-auth-server
```

Then create the DNS record for `gateway_url` and finish registration in the P0 console. The [chart's deployment guide](https://github.com/p0-security/p0-helm-oauthed-mcp#deploy) walks through both.

Certificates come from the Let's Encrypt staging environment by default, so the
gateway serves a certificate browsers and MCP clients will reject. Staging has
no rate limit, which is what you want while DNS is still propagating and a first
install may need a few attempts. Once the DNS record resolves and a staging
certificate has issued, set `lets_encrypt_env = "prod"` and apply again to get a
trusted certificate:

```hcl
  lets_encrypt_env = "prod"
```

Prod allows five certificates per domain per week, so leave it on staging until
the rest of the install works.

If your secrets come from External Secrets or Vault, set `agentic-gateway.secretsJob.enabled: false` through `extra_values` and create the Secret yourself. It has to exist before the release is created, so with `create_namespace = true` the namespace does not exist yet at that point. Create it outside Terraform and set `create_namespace = false`, or let a separate `kubernetes_namespace` resource own it.

## Immutable inputs

Changing any of these after the first apply is not an in-place upgrade:

| Input | What happens on change |
|-------|------------------------|
| `release_name` | Terraform replaces the Helm release. The PostgreSQL volume survives in the same namespace and is reattached, but the load balancer is recreated, so DNS and the gateway's registered address have to be redone. |
| `namespace` | Terraform replaces the release and the old PostgreSQL volume is left behind in the old namespace. |
| `storage_class` | The plan succeeds and the apply fails: Kubernetes does not allow a StatefulSet's volume claim template to change. Revert the value; to actually move storage classes, destroy and recreate the release. |

## Upgrading from 0.2.x

Version 0.2.x took the chart's values as a raw `values` list. Version 1.0.0 takes typed inputs instead. To upgrade:

1. Move each key you set under `values` to its input in the table below. `letsEncrypt.env` is `lets_encrypt_env`, `agentic-gateway.gateway.host` and both `gatewayIss` keys are `gateway_url`, and so on.
2. Move anything without an input into `extra_values`.
3. Keep `release_name` and `namespace` at the values you already use. Both are replace-forcing in the Helm provider.

`terraform plan` should then report an in-place update of the release, or no changes at all if your values matched the console's. If it reports a replacement, stop and check `release_name` and `namespace`.

## Migrating from `p0-oauthed-mcp`

This module was published as `p0-security/p0-oauthed-mcp/kubernetes` through version 0.1.9. That module is deprecated, pins chart 0.8.6, and will not receive the chart versions that create `app-secrets`.

**The release name and namespace defaults are different**: the old module defaulted both to `oauthed-mcp`, this one to `agentic-gateway` and `p0-agentic-gateway`. Both are replace-forcing in the Helm provider, so if you relied on the old defaults, pin them explicitly or Terraform destroys and recreates the release:

```hcl
module "p0_agentic_gateway_stack" {
  source  = "p0-security/p0-agentic-gateway-stack/kubernetes"
  version = "1.0.0"

  # Required only when migrating an existing release that used the old defaults.
  release_name = "oauthed-mcp"
  namespace    = "oauthed-mcp"

  gateway_url = "https://gateway.example.com"
  # ... remaining typed inputs, see Upgrading from 0.2.x
}
```

The `helm_release` resource was also renamed; a `moved` block in this module handles that. With the names pinned as above, `terraform plan` should report a move plus an in-place update, never a replacement. Confirm that before applying. If you also rename the `module` block itself, add a root-level `moved` block from the old module address to the new one, or Terraform plans a destroy and create.

The chart is published under both `p0-helm-oauthed-mcp` and `agentic-gateway-stack` from version 0.9.1 onward, and the two packages are identical. Values keys followed the same rename: the subchart block is `agentic-gateway` rather than `oauthed-mcp`.

## Compatibility matrix

Each module version pins an exact chart version. To use a specific chart version, use the corresponding module version.

| Module version | Chart version |
|----------------|---------------|
| 1.0.0          | 0.10.2        |
| 0.2.1          | 0.10.2        |
| 0.2.0          | 0.10.0        |

For chart versions 0.8.6 and earlier, see the matrix in
[terraform-kubernetes-p0-oauthed-mcp](https://github.com/p0-security/terraform-kubernetes-p0-oauthed-mcp#compatibility-matrix).

## Versioning

A chart pin bump is a minor release. Any input rename, removal or default change is a major release, ships with a `moved` block where a resource address changes, and gets a migration section in this README. Tags are created only after CI confirms the pinned chart is on the registry.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.7 |
| helm | >= 3.0 |

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| gateway\_url | Public URL of the gateway, `https://` plus a hostname. Sets the Gateway host and the token issuer on both servers. | `string` | required |
| lets\_encrypt\_email | Email registered with Let's Encrypt. | `string` | required |
| oidc\_client\_id | OAuth client ID at your identity provider. | `string` | required |
| storage\_class | StorageClass for PostgreSQL and VictoriaLogs. Immutable. | `string` | required |
| p0\_url | Your P0 tenant URL. | `string` | required |
| p0\_audience | Token audience for your tenant; usually `p0_url`. | `string` | required |
| p0\_service\_account\_email | P0 service account allowed to manage the gateway. | `string` | required |
| release\_name | Helm release name and GatewayClass name. | `string` | `"agentic-gateway"` |
| namespace | Kubernetes namespace to deploy into. | `string` | `"p0-agentic-gateway"` |
| create\_namespace | Create the namespace if it does not exist. | `bool` | `true` |
| lets\_encrypt\_env | `staging` issues untrusted certificates with no rate limit; `prod` issues trusted ones, limited to five per domain per week. Switch to `prod` once a staging certificate has issued. | `string` | `"staging"` |
| open\_id\_domain | Regex a signed-in account's email domain must match. Empty admits every verified account. | `string` | `""` |
| extra\_values | Additional YAML values documents; typed inputs win over them. | `list(string)` | `[]` |
| timeout | Seconds Helm waits, hooks included. Must exceed 300. | `number` | `360` |
| wait | Wait for resources to be ready. | `bool` | `false` |

## Outputs

| Name | Description |
|------|-------------|
| release\_name | Name of the Helm release. |
| namespace | Namespace the release was deployed into. |
| chart\_version | Chart version that was deployed. |
