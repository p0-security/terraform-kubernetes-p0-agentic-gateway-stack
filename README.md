# terraform-kubernetes-p0-agentic-gateway-stack

Terraform module that deploys [agentic-gateway](https://github.com/p0-security/agentic-gateway) via the [agentic-gateway-stack](https://github.com/p0-security/p0-helm-oauthed-mcp) umbrella Helm chart. The chart bundles Envoy Gateway, cert-manager, Let's Encrypt (ACME HTTP-01), PostgreSQL, and Valkey into a single install.

## Usage

```hcl
provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}

module "p0_agentic_gateway_stack" {
  source  = "p0-security/p0-agentic-gateway-stack/kubernetes"
  version = "0.2.1"

  values = [
    file("${path.module}/values.yaml"),
    yamlencode({
      letsEncrypt = {
        email = var.acme_email
        env   = "prod"
      }
      "agentic-gateway" = {
        gateway = {
          className = "agentic-gateway"  # must be unique per release in the cluster
        }
      }
    }),
  ]
}
```

Values are merged left-to-right (last wins), equivalent to `helm install -f`. See the [chart's values.yaml](https://github.com/p0-security/p0-helm-oauthed-mcp/blob/main/values.yaml) for the full schema.

There is no secret setup step to run before `terraform apply`. The chart creates `app-secrets` itself, from a pre-install hook. The cluster prerequisites still apply, though — a working block-storage StorageClass for the bundled PostgreSQL, which on EKS means the EBS CSI driver add-on. Those are listed in the [chart's deployment guide](https://github.com/p0-security/p0-helm-oauthed-mcp#prerequisites).

Afterwards, patch in the real OIDC client secret, and on an external database the real PostgreSQL password. The hook writes a placeholder for the first and never overwrites either once set. Restart both Deployments after patching — they read the Secret when a pod starts, so running pods keep the old value until they are replaced:

```bash
kubectl -n <namespace> patch secret app-secrets \
  --type merge \
  -p '{"stringData":{"OIDC_CLIENT_SECRET":"<your-oidc-client-secret>"}}'

kubectl -n <namespace> rollout restart deploy/agentic-auth-server deploy/agentic-gateway-server
```

If your secrets already come from External Secrets or Vault, set `agentic-gateway.secretsJob.enabled: false` in `values` and create the Secret yourself. It has to exist before the release is created, so with `create_namespace = true` the namespace does not exist yet at that point — create it outside Terraform and set `create_namespace = false`, or let a separate `kubernetes_namespace` resource own it.

For all post-deploy steps (DNS, verification, staging→prod), follow the [deployment guide](https://github.com/p0-security/p0-helm-oauthed-mcp#deploy).

## Migrating from `p0-oauthed-mcp`

This module was published as `p0-security/p0-oauthed-mcp/kubernetes` through
version 0.1.9. That module is now a thin wrapper around this one and will stop
receiving updates — switch to this address.

**The release name and namespace defaults changed** from `oauthed-mcp` to
`agentic-gateway`. Both are replace-forcing in the Helm provider, so if you
relied on the defaults you must pin the old values explicitly, or Terraform will
destroy and recreate the release (losing PostgreSQL and Valkey data):

```hcl
module "p0_agentic_gateway_stack" {
  source  = "p0-security/p0-agentic-gateway-stack/kubernetes"
  version = "0.2.1"

  # Required only when migrating an existing release that used the old defaults.
  release_name = "oauthed-mcp"
  namespace    = "oauthed-mcp"

  values = [...]
}
```

The `helm_release` resource was also renamed, but a `moved` block in this module
handles that for you. With the names pinned as above, `terraform plan` should
report a move plus an in-place update — never a replacement. Confirm that before
applying.

The chart itself is published under both `p0-helm-oauthed-mcp` and
`agentic-gateway-stack` from version 0.9.1 onward, and the two packages are
identical, so repointing at the new chart name changes no rendered manifests.

Values keys followed the same rename: the subchart block is now
`agentic-gateway` rather than `oauthed-mcp`.

## Compatibility matrix

Each module version pins an exact chart version. To use a specific chart version, use the corresponding module version.

| Module version | Chart version |
|----------------|---------------|
| 0.2.1          | 0.10.2        |
| 0.2.0          | 0.10.0        |

For chart versions 0.8.6 and earlier, see the matrix in
[terraform-kubernetes-p0-oauthed-mcp](https://github.com/p0-security/terraform-kubernetes-p0-oauthed-mcp#compatibility-matrix).

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.7 |
| helm | >= 3.0 |

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| release\_name | Helm release name. | `string` | `"agentic-gateway"` |
| namespace | Kubernetes namespace to deploy into. | `string` | `"agentic-gateway"` |
| create\_namespace | Create the namespace if it does not exist. | `bool` | `true` |
| values | List of YAML values strings merged left-to-right. | `list(string)` | `[]` |

## Outputs

| Name | Description |
|------|-------------|
| release\_name | Name of the Helm release. |
| namespace | Namespace the release was deployed into. |
| chart\_version | Chart version that was deployed. |
