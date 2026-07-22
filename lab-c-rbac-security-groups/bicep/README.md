# Lab C — the Bicep (infra-as-code) piece

Do the CLI walkthrough (`../README.md`) first — it's where the group, users, and membership live, because **those are Microsoft Graph objects that Bicep cannot create.** That's the key lesson of this folder: not everything is ARM/Bicep. Identity objects belong to the directory; your Bicep owns the *infrastructure* and the *role assignment that connects the two*.

`main.bicep` deploys a Key Vault + secret and grants an **existing** Entra security group the least-privilege `Key Vault Secrets User` role. You create the group with the CLI, then hand its object id to Bicep.

## Deploy

```bash
RG="campux-lab-groups-bicep-rg"
az group create --name "$RG" --location eastus

# The group must already exist (create it as in the CLI walkthrough):
az ad group create --display-name "Campux-KeyVault-Readers" --mail-nickname "campux-kv-readers-bicep"
GROUP_ID=$(az ad group show --group "Campux-KeyVault-Readers" --query id -o tsv)

az deployment group create \
  --resource-group "$RG" \
  --template-file main.bicep \
  --parameters groupObjectId="$GROUP_ID"
```

✅ **Checkpoint:** deployment `Succeeded`. Confirm the group holds the role:

```bash
VAULT=$(az deployment group show -g "$RG" -n main --query properties.outputs.vaultName.value -o tsv)
SUB=$(az account show --query id -o tsv)
az role assignment list \
  --scope "/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.KeyVault/vaults/$VAULT" \
  --assignee-object-id "$GROUP_ID" --query "[].roleDefinitionName" -o tsv
```

Prints `Key Vault Secrets User`. From here, access for individuals is managed purely by group membership — exactly as in the walkthrough.

## Teardown

```bash
az group delete --name "$RG" --yes
az keyvault purge --name "$VAULT" --location eastus
az ad group delete --group "$GROUP_ID"
```

## Why the group isn't in the template

If you tried to model the group, users, or memberships in Bicep you'd find no resource types for them — `Microsoft.Graph` identity objects aren't part of Azure Resource Manager. In production, teams manage directory objects with the **Terraform `azuread` provider**, **Microsoft Graph Bicep extension (preview)**, or Graph API/PowerShell, and keep the **Azure role assignment** (this template) with the rest of their infrastructure code. Knowing which system owns what is the point.
