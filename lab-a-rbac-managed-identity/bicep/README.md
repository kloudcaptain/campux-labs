# Lab A — the Bicep (infra-as-code) path

The `README.md` one folder up walks you through building this by hand with the Azure CLI — do that first to *learn* it. This folder does the same thing declaratively: one template, one deploy command. This is how teams actually ship infrastructure — reviewed in a pull request, repeatable, no click-ops.

`main.bicep` provisions: the RBAC-mode Key Vault + secret, the F1 Linux App Service with a system-assigned managed identity, the app setting Key Vault reference, and the least-privilege `Key Vault Secrets User` role assignment scoped to the vault.

## Deploy

In Azure Cloud Shell (Bash), from this folder:

```bash
RG="campux-lab-rbac-bicep-rg"
az group create --name "$RG" --location eastus

az deployment group create \
  --resource-group "$RG" \
  --template-file main.bicep
```

✅ **Checkpoint:** the deployment finishes `Succeeded` and prints outputs (`appUrl`, `vaultName`, `appName`). The Bicep created the identity, the role assignment, and the reference for you.

## Deploy the app code and prove it

Bicep provisions infrastructure; your application code is deployed separately. Grab the app name from the output, push the code, restart, and hit it:

```bash
APP=$(az deployment group show -g "$RG" -n main --query properties.outputs.appName.value -o tsv)

cd ../app
zip app.zip server.js package.json
az webapp deploy --name "$APP" --resource-group "$RG" --src-path app.zip --type zip
az webapp restart --name "$APP" --resource-group "$RG"

sleep 45
for i in 1 2 3 4 5; do
  curl -sS "https://$APP.azurewebsites.net" && break
  sleep 20
done
```

✅ **Checkpoint:** the response shows the real connection string on the "Value App Service resolved" line — the managed identity read it from Key Vault with zero credentials in code, exactly as in the CLI lab.

## Teardown

```bash
VAULT=$(az deployment group show -g "$RG" -n main --query properties.outputs.vaultName.value -o tsv)
az group delete --name "$RG" --yes
az keyvault purge --name "$VAULT" --location eastus
```

## How this differs from the CLI walkthrough

- **Secret creation door.** Here the secret is an ARM resource, created through the Key Vault **control plane** — so the deployer needs Contributor/Owner, *not* the data-plane `Key Vault Secrets Officer` role the CLI path required. Same secret, different access model. Worth understanding both.
- **Ordering is declared, not manual.** You never `sleep` for the identity to exist or manually order the role assignment — Bicep works out dependencies from the resource references. You still restart the app once so it re-fetches the reference after the role assignment propagates.
