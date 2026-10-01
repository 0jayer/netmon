# NetMon - Ntwork Monitoring System

A cloud based network monitoring stack, built as a portfolio project to demonstrate the exact DevOps toolchain used in production environments: Terraform, Docker, Azure (AKS), Helm, GitHub Actions CI/CD, and Prometheus/Grafana based monitoring.

## What this is

NetMon simulates monitoring network usage across a fleet of machines. Modeled on an IT firm monitoring its office computers. 
- node_exporter runs on each monitored machine and exposes local metrics 
- Prometheus pulls and stores them; Grafana turns that history into dashboards 
- Alertmanager fires notifications when something crosses a defined threshold. 

The whole stack is deployed to a managed Kubernetes cluster (AKS) on Azure, provisioned entirely through Terraform, with GitHub Actions handling build-and-deploy on every push.

This project exists specifically to build real, demonstrable experience with the DevOps stack (Terraform, Docker, Azure, AKS/Kubernetes, Helm, CI/CD, monitoring, IAM/RBAC, secrets management), not because there's a real fleet of machines that needs monitoring.

## Tech stack

| Layer | Tools |
| --- | --- |
| Infrastructure as Code | Terraform |
| Cloud provider | Azure (Azure for Students subscription) |
| Container orchestration | Azure Kubernetes Service (AKS) |
| Package management (K8s) | Helm |
| Container registry | Azure Container Registry (ACR) |
| Database | Azure Database for PostgreSQL (Grafana's own metadata store) |
| Secrets management | Azure Key Vault |
| Monitoring | Prometheus, node_exporter, Grafana, Alertmanager |
| CI/CD | GitHub Actions |
| Networking | Azure VNet, NSGs, (planned) Tailscale for cross-network connectivity |

## Progress 

- [x] **Terraform provider + resource group**: `azurerm` provider, authenticated via Azure CLI
- [x] **Virtual network + subnets**: `netmon-vnet` (10.0.0.0/16) with `aks-subnet` (10.0.1.0/24) and a PostgreSQL-delegated `db-subnet` (10.0.2.0/24), deployed in `eastasia` (required by the Azure for Students region policy)
- [x] **AKS cluster**: single-node, Free tier, Azure CNI overlay, OIDC issuer and workload identity enabled
- [x] **Azure Container Registry**: Basic SKU, admin user disabled, AKS access through the `AcrPull` role
- [x] **Azure Database for PostgreSQL**: Flexible Server (burstable B1ms) with private access only, plus a `grafana` database
- [x] **Key Vault + secrets**: RBAC-authorized vault, database admin password stored as a secret
- [x] **Prometheus + node_exporter + Grafana + Alertmanager, live**: deployed with the `kube-prometheus-stack` Helm chart (default values), dashboards verified in Grafana
- [ ] Custom Helm values (alert rules, dashboards as code)
- [ ] Grafana connected to PostgreSQL, with the password pulled from Key Vault through workload identity
- [ ] GitHub Actions CI/CD pipeline
- [ ] Simulated office machines as additional VMs in the same VNet, extended with Tailscale to connect genuinely separate machines
- [ ] RBAC + network policy hardening


## Next steps

1. Wire Grafana to the PostgreSQL database, pulling the credential from Key Vault (workload identity)
2. Move the stack configuration into our own Helm values, including alert rules and provisioned dashboards
3. Set up GitHub Actions for automated build/deploy (OIDC login to Azure)
4. Add simulated monitored machines and connect them to Prometheus
5. Harden with RBAC and network policies


## Running it
 
```bash
cd infra
export TF_VAR_pg_admin_password='<choose a strong password>'
terraform init
terraform plan -out=tfplan
terraform apply tfplan
 
az aks get-credentials -g netmon-rg -n netmon-aks --overwrite-existing
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kps prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
 
kubectl port-forward -n monitoring svc/kps-grafana 3000:80   # http://localhost:3000
```
 
Set `unique_suffix` in `terraform.tfvars` (lowercase letters and digits) so the ACR, PostgreSQL and Key Vault names are globally unique. `*.tfvars`, state files and saved plans are gitignored.


## Cost management

Runs on an Azure for Students account ($100 credit, renews annually while enrolled). Discipline used to keep this near-zero cost:
- `terraform plan` for iteration (free)
- `apply` only when actually testing end-to-end
- `terraform destroy` at the end of every work session, `apply` again next session
- Budget alerts configured in the Azure portal
- Smallest available SKUs throughout (burstable VM/DB tiers)

