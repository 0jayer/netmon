# NetMon - Network Monitoring System

A cloud-based network monitoring stack, built as a portfolio project to demonstrate the DevOps toolchain used in production environments: Terraform, Docker, Azure (AKS), Helm, GitHub Actions CI/CD, and Prometheus/Grafana monitoring.

## What this is

NetMon simulates monitoring network usage across a fleet of machines, modeled on an IT firm monitoring its office computers.
- node_exporter runs on each monitored machine and exposes local metrics
- Prometheus pulls and stores them; Grafana turns that history into dashboards
- Alertmanager sends notifications to Slack when something crosses a defined threshold

The whole stack is deployed to a managed Kubernetes cluster (AKS) on Azure, provisioned entirely through Terraform, with GitHub Actions running tests and builds on every push.

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
| CI/CD | GitHub Actions |
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
- [x] **CI (test + build)**: GitHub Actions runs the unit tests and builds the Docker image for the sample app in `app/`
- [ ] Push the image to ACR from CI (OIDC login to Azure)
- [ ] Dashboards as code (provisioned from the repo)
- [ ] Simulated office machines as additional VMs in the same VNet, extended with Tailscale to connect separate machines
- [ ] Hardening: least-privilege database user, RBAC, network policies, NSGs, Terraform remote state, persistent volumes for Prometheus

## How secrets reach Grafana

Pod -> Kubernetes service account `kps-grafana` -> federated credential -> user-assigned managed identity -> Key Vault (Secrets User role) -> Secrets Store CSI mount -> Kubernetes secret `grafana-db` -> `GF_DATABASE_PASSWORD` env var.

The managed identity's client ID changes on every rebuild, so it is read from `terraform output` and rendered into the manifests with `sed` at deploy time. The rendered files are never committed.

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

# 7. Grafana at http://localhost:3000
kubectl port-forward -n monitoring deploy/kps-grafana 3000:3000
```

Set `unique_suffix` in `infra/terraform.tfvars` (lowercase letters and digits) so the ACR, PostgreSQL and Key Vault names are globally unique. `*.tfvars`, state files and saved plans are gitignored.

Check that Grafana is using PostgreSQL:

```bash
kubectl logs -n monitoring deploy/kps-grafana -c grafana | grep dbtype
```

## CI

`.github/workflows/ci.yml` runs on pushes to `main` that touch `app/` and on pull requests:
1. `test`: runs the unit tests of the sample app (`app/`)
2. `build`: builds its Docker image

Pushing the image to ACR with OIDC login to Azure is the next step.

## Cost management

Runs on an Azure for Students account ($100 credit, renews annually while enrolled). Discipline used to keep this near zero cost:
- `terraform plan` for iteration (free)
- `apply` only when actually testing end to end
- `terraform destroy` at the end of every work session, `apply` again next session
- Budget alerts configured in the Azure portal
- Smallest available SKUs throughout (burstable VM and DB tiers)
