# Lab A — RBAC & Managed Identity: read a secret with zero credentials

**Track:** Identity & Governance (Lab A of 4)
**Status:** Authored — **PENDING one real end-to-end certification run** before publish.
**Level:** Intermediate · **Time:** ~35 min · **Cost:** effectively free (see below)

> Certification note for the author: run every command block below, in order, in a **fresh Azure Cloud Shell (Bash)** on a throwaway resource group. It is certified only after a clean pass ending with `curl` returning the real connection string and teardown leaving nothing behind.

---

## Scenario

Campux Retail's product API needs a database connection string. Juniors paste it into code or an app-setting in plain text — and it leaks. The professional pattern: keep the secret in **Azure Key Vault**, give the app a **managed identity** (an Azure-managed credential with no password to leak), and grant that identity the **least-privilege RBAC role** that lets it *read* the secret and nothing else. The app then reads the secret at runtime with **zero credentials in the code**.

By the end you'll have proven, on real Azure, that the app retrieves a Key Vault secret using only its identity and a scoped role assignment.

## What you'll prove you can do (résumé line)

*"Configured an Azure App Service with a system-assigned managed identity and a least-privilege `Key Vault Secrets User` RBAC role, enabling secret retrieval from Key Vault with no credentials in code."*

## Two ways to build it

This lab below is the **CLI walkthrough** — build it by hand and prove each piece. Once you've done that, deploy the **same infrastructure as code** with the Bicep template in [`bicep/`](bicep/) to see the professional, repeatable version.

## Reinforces

- Bootcamp: Managed Identity vs Service Principal; Key Vault
- Blog: `blog-managed-identity-vs-service-principal`, `blog-azure-key-vault-explained`, `blog-key-vault-references`

---

## Architecture

```
        ┌─────────────────────────┐
        │  Azure App Service       │
        │  (Campux product API)    │
        │                          │
        │  System-assigned         │
        │  managed identity  ──────┼──┐  (1) "I'm this app, prove it" → Microsoft Entra ID
        └─────────────┬────────────┘  │       returns a token, no password involved
                      │               │
   app setting:       │               │
   DB_CONNECTION =    │               ▼
   @Microsoft.KeyVault │        ┌──────────────────────┐
   (SecretUri=...)     │        │  Microsoft Entra ID  │
                      │        └──────────────────────┘
                      │ (2) present token + read secret
                      ▼
        ┌─────────────────────────┐
        │  Azure Key Vault (RBAC) │
        │  secret: ProductDb...   │
        │  role on identity:      │
        │  Key Vault Secrets User │  ← read secrets ONLY (no write, no keys, no certs)
        └─────────────────────────┘
```

---

## Before you start (read this — it's where people get blocked)

1. **You need permission to assign roles.** Creating role assignments requires **Owner** or **User Access Administrator** on the subscription (a plain **Contributor** cannot, and every role command below will fail with `AuthorizationFailed`). If this is your own subscription, you're Owner — you're fine. On a work subscription, confirm first.
2. **Use Azure Cloud Shell (Bash).** Open [https://shell.azure.com](https://shell.azure.com) and pick **Bash**. This removes every "works on my machine" problem — `az`, `zip`, and `curl` are all preinstalled and current. Do not use PowerShell for this lab; the commands below are Bash.
3. **One subscription selected.** Run `az account show --query name -o tsv` and confirm it's the subscription you intend to spend (pennies) in.

**Cost:** App Service **F1 (Free)** tier, a Key Vault (≈ $0.03 per 10,000 operations), and one secret. Total for this lab is a fraction of a cent. Teardown at the end removes everything regardless.

---

## Stage 0 — Set your variables

Paste this whole block once. `$RANDOM` gives every resource a globally-unique suffix so names never collide.

```bash
SUFFIX=$RANDOM
RG="campux-lab-rbac-rg"
LOCATION="eastus"
KV="campux-kv-$SUFFIX"        # Key Vault name: 3–24 chars, starts with a letter — this fits
APP="campux-api-$SUFFIX"      # must be globally unique across *.azurewebsites.net
PLAN="campux-plan-$SUFFIX"
SECRET_NAME="ProductDbConnection"

SUB=$(az account show --query id -o tsv)
VAULT_SCOPE="/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.KeyVault/vaults/$KV"

echo "Suffix=$SUFFIX  KV=$KV  APP=$APP"
```

✅ **Checkpoint:** the `echo` prints a suffix and your resource names. If `SUB` is empty, you're not logged in — run `az login` (in a local shell) or reopen Cloud Shell.

---

## Stage 1 — Resource group

```bash
az group create --name "$RG" --location "$LOCATION"
```

✅ **Checkpoint:** output shows `"provisioningState": "Succeeded"`.

---

## Stage 2 — Key Vault (RBAC mode)

```bash
az keyvault create \
  --name "$KV" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --enable-rbac-authorization true
```

✅ **Checkpoint:**

```bash
az keyvault show --name "$KV" --query "properties.enableRbacAuthorization" -o tsv
```

Must print `true`. (This is what makes the vault use Azure roles instead of legacy access policies — the whole point of the lab.)

---

## Stage 3 — Let YOURSELF create a secret, then create it

An RBAC-mode vault does **not** automatically let its creator read or write secret data. You must grant yourself the data-plane role first. This surprises almost everyone.

```bash
ME=$(az ad signed-in-user show --query id -o tsv)

az role assignment create \
  --role "Key Vault Secrets Officer" \
  --assignee-object-id "$ME" \
  --assignee-principal-type User \
  --scope "$VAULT_SCOPE"
```

Role assignments take up to a couple of minutes to propagate. Wait, then create the secret:

```bash
sleep 60
az keyvault secret set \
  --vault-name "$KV" \
  --name "$SECRET_NAME" \
  --value "Server=tcp:campux-sql.database.windows.net,1433;Database=products;Authentication=Active Directory Default;"
```

> If this returns `Forbidden`, the role hasn't propagated yet — wait another 60 seconds and re-run the `az keyvault secret set` line. It is not a mistake in your commands.

✅ **Checkpoint:**

```bash
az keyvault secret show --vault-name "$KV" --name "$SECRET_NAME" --query value -o tsv
```

Prints the connection string. Good — the secret exists and you can read it.

---

## Stage 4 — App Service with a managed identity

> Runtime token: this lab uses `NODE:20-lts`. If `az webapp create` ever rejects it, list the current accepted tokens with `az webapp list-runtimes --os-type linux | grep -i node` and use the newest LTS shown.

```bash
az appservice plan create --name "$PLAN" --resource-group "$RG" --sku F1 --is-linux
az webapp create --name "$APP" --resource-group "$RG" --plan "$PLAN" --runtime "NODE:20-lts"
az webapp identity assign --name "$APP" --resource-group "$RG"
APP_PID=$(az webapp identity show --name "$APP" --resource-group "$RG" --query principalId -o tsv)
echo "App identity object id: $APP_PID"
```

✅ **Checkpoint:** `$APP_PID` is a GUID (not empty). That GUID is the app's identity in Entra ID — no password anywhere.

---

## Stage 5 — Grant the app LEAST privilege on the vault

The app only needs to *read* secrets. Give it exactly that — `Key Vault Secrets User` — scoped to this one vault. Not the resource group, not the subscription. Not Officer (which could write). This is the least-privilege lesson in one command.

```bash
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee-object-id "$APP_PID" \
  --assignee-principal-type ServicePrincipal \
  --scope "$VAULT_SCOPE"
```

✅ **Checkpoint — prove least privilege by inspection:**

```bash
az role assignment list --assignee "$APP_PID" --scope "$VAULT_SCOPE" -o table
```

You should see exactly **one** role: `Key Vault Secrets User`. That role grants read of secret contents only — no secret write, no keys, no certificates. If you ever needed the app to write secrets you'd add `Key Vault Secrets Officer`; you don't, so you don't.

---

## Stage 6 — Wire the secret into the app and deploy

Point an app setting at the secret using a Key Vault reference. App Service resolves it with the managed identity **before your code runs**.

```bash
az webapp config appsettings set \
  --name "$APP" --resource-group "$RG" \
  --settings "DB_CONNECTION=@Microsoft.KeyVault(SecretUri=https://$KV.vault.azure.net/secrets/$SECRET_NAME)"
```

Get the tiny zero-dependency app (`server.js` + `package.json`) into Cloud Shell by cloning the labs repo, then deploy it:

```bash
git clone https://github.com/kloudcaptain/campux-labs.git
cd campux-labs/lab-a-rbac-managed-identity/app
zip app.zip server.js package.json
az webapp deploy --name "$APP" --resource-group "$RG" --src-path app.zip --type zip
```

Now restart the app once. This is not optional: the restart forces App Service to re-fetch the Key Vault reference with the identity + role you just set up, and it warms the free-tier (F1) container so your first request isn't a cold-start 502.

```bash
az webapp restart --name "$APP" --resource-group "$RG"
sleep 45
curl -sS "https://$APP.azurewebsites.net"
```

If you get a `502`/empty response (F1 can take a moment on the very first boot), wait and retry once — this loop does it for you:

```bash
for i in 1 2 3 4 5; do
  echo "--- attempt $i ---"
  curl -sS "https://$APP.azurewebsites.net" && break
  sleep 20
done
```

✅ **Checkpoint — the payoff:** the response prints the **real connection string** on the "Value App Service resolved" line. That string came from Key Vault, fetched by the app's managed identity, with **zero credentials in `server.js`**. That is the entire lab, proven.

> Troubleshooting: if the line still shows `@Microsoft.KeyVault(...)` after the restart, the Stage 5 role assignment is still propagating. Re-run the Stage 5 checkpoint to confirm the `Key Vault Secrets User` role is present, wait a minute, `az webapp restart` again, then `curl`.

---

## Stage 7 — Teardown (do not skip)

Delete everything, then **purge** the vault so its soft-deleted shell doesn't linger (Key Vault keeps deleted vaults recoverable for 90 days by default).

```bash
az group delete --name "$RG" --yes
az keyvault purge --name "$KV" --location "$LOCATION"
```

✅ **Checkpoint:**

```bash
az group exists --name "$RG"        # -> false
az keyvault list-deleted --query "[?name=='$KV']" -o tsv   # -> empty
```

Both empty/`false` means you're back to zero — no surprise bill, no reserved names.

---

## What you learned

- A **managed identity** is a credential Azure manages for you — nothing to store, rotate, or leak.
- **RBAC on Key Vault** grants data-plane access through Azure roles; the creator isn't automatically granted access.
- **Least privilege** = the narrowest role (`Key Vault Secrets User`) at the narrowest scope (one vault).
- **Key Vault references** let App Service inject secrets as app settings with no code changes.

**Next:** Lab C — assign these roles to **Entra security groups** instead of individual identities, the way real orgs manage access at scale.

*Part of the full Campux Cloud Engineering Bootcamp → [link to track]*
