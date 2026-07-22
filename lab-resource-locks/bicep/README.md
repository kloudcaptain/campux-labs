# Lab — the Bicep (locks-as-code) piece

The CLI walkthrough (`../README.md`) places the lock by hand. This declares it as code, the way production does it — the lock ships with the infrastructure it protects. Resource locks are fully ARM-native, so the whole thing is Bicep (no Graph split).

## Deploy

```bash
RG="campux-lab-locks-bicep-rg"
az group create --name "$RG" --location eastus
az deployment group create -g "$RG" --template-file main.bicep
```

✅ **Checkpoint:**

```bash
az lock list --resource-group "$RG" --query "[].{name:name, level:level}" -o table
```

Shows a `CanNotDelete` lock. The group is now protected by code.

## Teardown (important — the lock blocks the delete)

A locked resource group **cannot be deleted** until you remove the lock. Do it in this order:

```bash
az lock delete --name campux-prod-donotdelete --resource-group "$RG"
az group delete --name "$RG" --yes
```

## Note

This template is authored against current ARM schemas but has **not been compile-checked locally** (no `az`/`bicep` in the authoring environment) — it is validated when you deploy it in Cloud Shell.
