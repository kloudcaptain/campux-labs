# Azure Container Apps + ACR — managed-identity pull, scale-to-zero

**Track:** Compute / Containers · **Level:** Intermediate · **Time:** ~35 min · **Cost:** scale-to-zero app + a Basic registry (pennies/day)
**Status:** Authored — pending one real end-to-end certification run before publish.
**Full walkthrough (illustrated):** https://azure.campux.co/lab-container-apps-acr

> Run in **Azure Cloud Shell (Bash)**. **This lab creates a registry, so run the teardown.**

## Scenario

Not every workload needs a Kubernetes cluster. Azure Container Apps runs your container, scales it to zero when idle, and pulls the image from your registry with a **managed identity** — no admin password anywhere. The container pattern most workloads actually want, without the AKS bill.

## Résumé line

*"Deployed a containerized workload to Azure Container Apps with scale-to-zero, pulling from ACR via a user-assigned managed identity (AcrPull) with the registry admin account disabled."*

## Steps

```bash
RG="campux-lab-aca-rg"
az group create -n "$RG" -l eastus

# registry with admin DISABLED + an imported sample image
ACR="campuxacr$RANDOM"
az acr create -n "$ACR" -g "$RG" --sku Basic --admin-enabled false
az acr import -n "$ACR" --source mcr.microsoft.com/k8se/quickstart:latest --image quickstart:v1
ACR_ID=$(az acr show -n "$ACR" -g "$RG" --query id -o tsv)

# an identity that may only pull
az identity create -n campux-aca-id -g "$RG"
ID_ID=$(az identity show -n campux-aca-id -g "$RG" --query id -o tsv)
ID_PRINCIPAL=$(az identity show -n campux-aca-id -g "$RG" --query principalId -o tsv)
az role assignment create --assignee "$ID_PRINCIPAL" --role AcrPull --scope "$ACR_ID"

# deploy, scaled to zero, pulling via the identity
az containerapp env create -n campux-aca-env -g "$RG" -l eastus
az containerapp create -n campux-quickstart -g "$RG" --environment campux-aca-env \
  --image "$ACR.azurecr.io/quickstart:v1" \
  --registry-server "$ACR.azurecr.io" --registry-identity "$ID_ID" --user-assigned "$ID_ID" \
  --ingress external --target-port 80 --min-replicas 0 --max-replicas 3
FQDN=$(az containerapp show -n campux-quickstart -g "$RG" --query properties.configuration.ingress.fqdn -o tsv)

# prove it serves and scales to zero
curl -s -o /dev/null -w "app: %{http_code}\n" "https://$FQDN"
az containerapp show -n campux-quickstart -g "$RG" --query "properties.template.scale.{min:minReplicas,max:maxReplicas}" -o table
```

✅ **Checkpoints:** `app: 200`; `min: 0`; the pull succeeded despite the registry having no admin account (`az acr show -n "$ACR" -g "$RG" --query adminUserEnabled` is `false`).

## Teardown

```bash
az group delete -n campux-lab-aca-rg --yes
```
