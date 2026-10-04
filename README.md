# NetMon - Network Monitoring System

A cloud-based network monitoring stack, built as a portfolio project to demonstrate the DevOps toolchain used in production environments: Terraform, Docker, Azure (AKS), Helm, GitHub Actions CI/CD, and Prometheus/Grafana monitoring.

## What this is

NetMon simulates monitoring network usage across a fleet of machines, modeled on an IT firm monitoring its office computers.
- node_exporter runs on each monitored machine and exposes local metrics
- Prometheus pulls and stores them; Grafana turns that history into dashboards
- Alertmanager sends notifications to Slack when something crosses a defined threshold

The whole stack is deployed to a managed Kubernetes cluster (AKS) on Azure, provisioned entirely through Terraform. GitHub Actions tests the code, builds a container image, pushes it to Azure Container Registry and deploys it to the cluster on every push to `main`.

This project exists to build real, demonstrable experience with the DevOps stack (Terraform, Docker, Azure, AKS/Kubernetes, Helm, CI/CD, monitoring, IAM/RBAC, secrets management), not because there is a real fleet that needs monitoring.

## Tech stack

| Layer | Tools |
| --- | --- |
| Infrastructure as Code | Terraform |
| Cloud provider | Azure (Azure for Students subscription) |
| Container orchestration | Azure Kubernetes Service (AKS) |
| Package management (K8s) | Helm |
| Container registry | Azure Container Registry (ACR) |
| Database | Azure Database for PostgreSQL (Grafana's data store) |
| Secrets management | Azure Key Vault, AKS workload identity |
| Monitoring | Prometheus, node_exporter, Grafana, Alertmanager |
| Alert delivery | Slack (incoming webhook) |
| CI/CD | GitHub Actions, OIDC login to Azure (no stored passwords) |
| Networking | Azure VNet, (planned) NSGs and Tailscale |

## Progress

- [x] **Terraform provider + resource group**: `azurerm` provider, authenticated via Azure CLI
- [x] **Virtual network + subnets**: `netmon-vnet` (10.0.0.0/16) with `aks-subnet` (10.0.1.0/24) and a PostgreSQL-delegated `db-subnet` (10.0.2.0/24), in `eastasia` (required by the Azure for Students region policy)
- [x] **AKS cluster**: single node, Free tier, Azure CNI overlay, OIDC issuer and workload identity enabled
- [x] **Azure Container Registry**: Basic SKU, admin user disabled, AKS pulls through the `AcrPull` role
- [x] **Azure Database for PostgreSQL**: Flexible Server (burstable B1ms), private access only, with a `grafana` database
- [x] **Key Vault + secrets**: RBAC-authorized vault holding the database admin password
- [x] **Monitoring stack**: `kube-prometheus-stack` Helm chart with our own values in `helm/kps_values.yaml`
- [x] **Grafana on PostgreSQL**: Grafana stores its data in the Azure database; the password comes from Key Vault through workload identity, so no secret is in the repo, Helm values or chat
- [x] **Alert rules as code**: `NetmonHostDown` and `NetmonHighCPU` in `k8s/alert_rules.yaml`
- [x] **Alertmanager to Slack**: webhook stored as a cluster secret and mounted into Alertmanager; firing and resolved messages verified with a CPU stress test
- [x] **CI**: GitHub Actions runs the unit tests and builds the Docker image for the sample app in `app/`
- [x] **Push to ACR from CI**: OIDC login to Azure, image tagged with the commit SHA
- [x] **Deploy to AKS from CI**: the app runs in its own namespace (`k8s/app.yaml`) and every push to `main` rolls out the new image
- [ ] Simulated office machines as additional VMs in the same VNet, extended with Tailscale to connect separate machines
- [ ] Hardening: least-privilege database user, RBAC, network policies, NSGs, Terraform remote state, persistent volumes for Prometheus

## How secrets reach Grafana

Pod -> Kubernetes service account `kps-grafana` -> federated credential -> user-assigned managed identity -> Key Vault (Secrets User role) -> Secrets Store CSI mount -> Kubernetes secret `grafana-db` -> `GF_DATABASE_PASSWORD` env var.

The managed identity's client ID changes on every rebuild, so it is read from `terraform output` and rendered into the manifests with `sed` at deploy time. The rendered files are never committed.

## How CI/CD reaches Azure (no stored passwords)

GitHub job -> short-lived OIDC token signed by GitHub -> `azure/login` -> federated credential `github-main` on the user-assigned identity `netmon-ci-identity` (trusts only this repo's `main` branch) -> two roles, granted in `infra/identity.tf`: `AcrPush` on the registry and `Azure Kubernetes Service Cluster User Role` on the cluster -> push the image / fetch cluster credentials.

Pull requests only run `test` and `build`; they cannot push or deploy, because Azure only trusts tokens from `main`.

GitHub puts permanent numeric IDs in the token subject, so the credential subject has this form (a plain `repo:owner/name` subject is rejected):

```
repo:<owner>@<owner-id>/<repo>@<repo-id>:ref:refs/heads/main
```

The identity lives in its own resource group, `netmon-persist-rg`, which is created once by hand and never destroyed. That keeps its client ID, and the GitHub variables that hold it, valid across rebuilds. Terraform only looks the identity up (a `data` source) and re-grants the two roles on each new registry and cluster.

### One-time setup (survives `terraform destroy`)

```bash
# Persistent group and identity
az group create -n netmon-persist-rg -l eastasia
az identity create -g netmon-persist-rg -n netmon-ci-identity -l eastasia

# Numeric IDs GitHub puts in the token subject
gh api repos/<owner>/<repo> --jq '.owner.id, .id'

# Trust this repo's main branch
az identity federated-credential create \
  --name github-main \
  --identity-name netmon-ci-identity \
  --resource-group netmon-persist-rg \
  --issuer "https://token.actions.githubusercontent.com" \
  --subject "repo:<owner>@<owner-id>/<repo>@<repo-id>:ref:refs/heads/main" \
  --audiences "api://AzureADTokenExchange"

# Repository variables read by the workflow (none of these is a secret)
gh variable set AZURE_CLIENT_ID --body "$(az identity show -g netmon-persist-rg -n netmon-ci-identity --query clientId -o tsv)" --repo <owner>/<repo>
gh variable set AZURE_TENANT_ID --body "$(az account show --query tenantId -o tsv)" --repo <owner>/<repo>
gh variable set AZURE_SUBSCRIPTION_ID --body "$(az account show --query id -o tsv)" --repo <owner>/<repo>
```

`ACR_NAME` in `.github/workflows/ci.yml` must match the registry name built from `unique_suffix`.

## Running it

Rebuild from nothing, in this order. Run from the repo root.

```bash
# 1. Infrastructure (the password prompt is hidden; use letters and digits only)
read -rsp 'DB admin password: ' TF_VAR_pg_admin_password; echo
export TF_VAR_pg_admin_password
terraform -chdir=infra init
terraform -chdir=infra plan
terraform -chdir=infra apply

# 2. Cluster access and namespace
az aks get-credentials -g netmon-rg -n netmon-aks --overwrite-existing
kubectl get nodes
kubectl create namespace monitoring

# 3. Key Vault secret provider (must exist before Helm)
sed -e "s/__CLIENT_ID__/$(terraform -chdir=infra output -raw grafana_identity_client_id)/" \
    -e "s/__KV_NAME__/$(terraform -chdir=infra output -raw key_vault_name)/" \
    -e "s/__TENANT_ID__/$(terraform -chdir=infra output -raw tenant_id)/" \
    k8s/secretproviderclass.yaml | kubectl apply -f -

# 4. Slack webhook secret (lives only in the cluster; paste the URL at the hidden prompt)
read -rsp 'Slack webhook URL: ' URL; echo
kubectl create secret generic slack-webhook -n monitoring --from-literal=url="$URL"
unset URL

# 5. Monitoring stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
sed -e "s/__CLIENT_ID__/$(terraform -chdir=infra output -raw grafana_identity_client_id)/" \
    -e "s/__PG_FQDN__/$(terraform -chdir=infra output -raw pg_fqdn)/" \
    helm/kps_values.yaml > /tmp/kps-values.rendered.yaml
helm upgrade --install kps prometheus-community/kube-prometheus-stack \
    -n monitoring -f /tmp/kps-values.rendered.yaml --timeout 10m

# 6. Alert rules (after Helm, because the operator creates the PrometheusRule type)
kubectl apply -f k8s/alert_rules.yaml

# 7. Sample app (the pod stays in ImagePullBackOff until CI pushes an image to the new registry)
kubectl apply -f k8s/app.yaml
# then push a commit that touches app/ or .github/workflows/ci.yml so CI builds, pushes and deploys

# 8. Grafana at http://localhost:3000
kubectl port-forward -n monitoring deploy/kps-grafana 3000:3000
```

Set `unique_suffix` in `infra/terraform.tfvars` (lowercase letters and digits) so the ACR, PostgreSQL and Key Vault names are globally unique. `*.tfvars`, state files and saved plans are gitignored.

Check that Grafana is using PostgreSQL:

```bash
kubectl logs -n monitoring deploy/kps-grafana -c grafana | grep dbtype
```

## CI/CD

`.github/workflows/ci.yml` runs on pushes to `main` that touch `app/` or the workflow file, and on pull requests:
1. `test`: runs the unit tests of the sample app (`app/`)
2. `build`: builds its Docker image
3. `push` (`main` only): logs in to Azure with OIDC, builds the image again and pushes it to ACR tagged with the commit SHA
4. `deploy` (`main` only, after `push`): fetches cluster credentials, sets the Deployment's image to the new tag and waits for the rollout

## Cost management

Runs on an Azure for Students account ($100 credit, renews annually while enrolled). Discipline used to keep this near zero cost:
- `terraform plan` for iteration (free)
- `apply` only when actually testing end to end
- `terraform destroy` at the end of every work session, `apply` again next session
- `netmon-persist-rg` (the CI identity) is free and is the only thing left running
- Budget alerts configured in the Azure portal
- Smallest available SKUs throughout (burstable VM and DB tiers)
