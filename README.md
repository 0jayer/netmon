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

## Progress so far

- [x] **Terraform provider + resource group** — `azurerm` provider configured, authenticated via Azure CLI
- [x] **Virtual network + subnet** — `netmon-vnet` (10.0.0.0/16) with a dedicated `aks-subnet` (10.0.1.0/24), deployed in `eastasia` (required by the Azure for Students region policy)
- [ ] AKS cluster
- [ ] Azure Container Registry
- [ ] Azure Database for PostgreSQL
- [ ] Key Vault + secrets
- [ ] Helm chart for the monitoring stack
- [ ] GitHub Actions CI/CD pipeline
- [ ] Prometheus + node_exporter + Grafana + Alertmanager, live
- [ ] RBAC + network policy hardening

## Next steps

1. Provision the AKS cluster itself (the first resource in this project with a real, ongoing cost, a `Standard_B2s` node, $30/month if left running continuously)
2. Provision ACR and Azure Database for PostgreSQL
3. Provision Key Vault and wire up secrets
4. Write the Helm chart(s) for the monitoring stack
5. Set up GitHub Actions for automated build/deploy
6. Simulate office computers as additional VMs in the same VNet, then extend with Tailscale to connect genuinely separate machines

## Cost management

Runs on an Azure for Students account ($100 credit, renews annually while enrolled). Discipline used to keep this near-zero cost:
- `terraform plan` for iteration (free)
- `apply` only when actually testing end-to-end
- `terraform destroy` at the end of every work session, `apply` again next session
- Budget alerts configured in the Azure portal
- Smallest available SKUs throughout (burstable VM/DB tiers)

