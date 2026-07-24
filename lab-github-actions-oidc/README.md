# GitHub Actions + OIDC — deploy to Azure with zero stored secrets

**Track:** CI/CD · **Level:** Intermediate · **Time:** ~40 min · **Cost:** free (app registration) + pennies (deployed storage)
**Status:** Authored — pending one real end-to-end certification run before publish.
**Full walkthrough (illustrated):** https://azure.campux.co/lab-github-actions-oidc

> You need a **GitHub repository you own** plus **Azure Cloud Shell (Bash)** for the `az` commands. Replace `OWNER/REPO` with your repository throughout.

## Scenario

The long-lived client secret pasted into a pipeline is the credential most likely to leak. Replace it with OIDC: the workflow requests a short-lived token at run time, Azure trusts the request because of *who is asking*, and nothing sensitive is ever stored.

## Résumé line

*"Federated GitHub Actions to Microsoft Entra ID with OIDC, deploying infrastructure to Azure from CI with no stored secrets and a resource-group-scoped least-privilege role."*

## Files

- `workflow/deploy.yml` — copy to `.github/workflows/deploy.yml` in **your** repo.
- `bicep/main.bicep` — the storage account the pipeline deploys (referenced by `--template-uri`).

## Steps

```bash
# 1. an identity for the pipeline
SUB_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
APP_ID=$(az ad app create --display-name "campux-gh-oidc" --query appId -o tsv)
az ad sp create --id "$APP_ID"

# 2. a scoped, least-privilege role
RG="campux-lab-oidc-rg"
az group create -n "$RG" -l eastus
az role assignment create --assignee "$APP_ID" --role Contributor \
  --scope "/subscriptions/$SUB_ID/resourceGroups/$RG"

# 3. tell Azure which workflow to trust (federated credential)
az ad app federated-credential create --id "$APP_ID" --parameters '{
  "name": "gh-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:OWNER/REPO:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'

# 4. store the three (non-secret) IDs as repo variables
gh variable set AZURE_CLIENT_ID --body "$APP_ID"
gh variable set AZURE_TENANT_ID --body "$TENANT_ID"
gh variable set AZURE_SUBSCRIPTION_ID --body "$SUB_ID"

# 5. commit workflow/deploy.yml to .github/workflows/deploy.yml, push to main, watch Actions

# verify it was real and secret-free
az resource list -g "$RG" --query "[].{name:name,type:type}" -o table
az ad app credential list --id "$APP_ID" --query "length(@)"   # -> 0 client secrets
```

✅ **Checkpoints:** the Actions run logs `Login successful` with no secret; the storage account appears; the app has **0** credentials.

## Teardown

```bash
az group delete -n campux-lab-oidc-rg --yes
az ad app delete --id "$APP_ID"
```

> **Gotcha:** the federated-credential `subject` must match GitHub's token exactly — `repo:OWNER/REPO:ref:refs/heads/main` for a branch. Most "login failed" cases are a subject typo.
