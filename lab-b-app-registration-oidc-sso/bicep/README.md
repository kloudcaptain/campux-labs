# Lab B — the Bicep (infra-as-code) piece

Do the CLI walkthrough (`../README.md`) first. As in Lab C, the **app registration is a Microsoft Graph object Bicep can't create** — so you make it with the CLI, and Bicep owns the App Service **authentication config** (`authsettingsV2`) that switches on OIDC sign-in using that registration.

There's an ordering wrinkle worth understanding: the app registration's redirect URI must match the web app's hostname, but the hostname isn't known until the app is deployed. So the clean sequence is **create the registration → deploy the app with Bicep → then set the redirect URI on the registration from the Bicep output.**

## Deploy

```bash
RG="campux-lab-sso-bicep-rg"
az group create --name "$RG" --location eastus

# 1. Create the app registration + service principal + secret (Graph — CLI only).
APP_ID=$(az ad app create --display-name "Campux Staff Portal (bicep)" \
  --sign-in-audience AzureADMyOrg --enable-id-token-issuance true --query appId -o tsv)
az ad sp create --id "$APP_ID"
CLIENT_SECRET=$(az ad app credential reset --id "$APP_ID" --query password -o tsv)

# 2. Deploy the app + auth config. Bicep outputs the exact redirect URI to register.
az deployment group create -g "$RG" --template-file main.bicep \
  --parameters clientId="$APP_ID" clientSecret="$CLIENT_SECRET"

REDIRECT=$(az deployment group show -g "$RG" -n main --query properties.outputs.redirectUri.value -o tsv)

# 3. Register that redirect URI back on the app registration.
az ad app update --id "$APP_ID" --web-redirect-uris "$REDIRECT"
echo "Registered redirect: $REDIRECT"

# 4. Deploy the app code (Bicep provisions infra + auth, not your application code).
APP=$(az deployment group show -g "$RG" -n main --query properties.outputs.appName.value -o tsv)
cd ../app
zip app.zip server.js package.json
az webapp deploy --name "$APP" --resource-group "$RG" --src-path app.zip --type zip
az webapp restart --name "$APP" --resource-group "$RG"
sleep 30
```

✅ **Checkpoint (CLI-verifiable):**

```bash
APP=$(az deployment group show -g "$RG" -n main --query properties.outputs.appName.value -o tsv)
az webapp auth show -g "$RG" --name "$APP" \
  --query "{requireAuth:globalValidation.requireAuthentication, clientId:identityProviders.azureActiveDirectory.registration.clientId}" -o json
```

Shows `requireAuth: true` and your `clientId`. Auth is wired by code.

✅ **Certification checkpoint (manual browser):** open the `appUrl` output in a private window → sign in with Microsoft → land on the portal → view `/.auth/me`. Same OIDC payoff as the CLI walkthrough. (If sign-in fails on issuer/audience, your app is likely issuing v2 tokens — change `openIdIssuer` in `main.bicep` to `https://login.microsoftonline.com/<tenantId>/v2.0` and redeploy.)

## Teardown

```bash
az group delete --name "$RG" --yes
az ad app delete --id "$APP_ID"
```

## Note

This template is authored against current ARM schemas but has **not been compile-checked locally** (no `az`/`bicep` in the authoring environment) — it is validated when you deploy it in Cloud Shell. The secret is stored as an app setting (`MICROSOFT_PROVIDER_AUTHENTICATION_SECRET`) and referenced by name from the auth config, never inlined — the same pattern the portal uses.
