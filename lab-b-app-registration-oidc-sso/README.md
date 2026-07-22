# Lab B — App Registration & OIDC SSO: sign in with Microsoft Entra ID

**Track:** Identity & Governance (Lab B of 4)
**Status:** Authored — **PENDING certification**, which for this lab has TWO parts (see note).
**Level:** Intermediate · **Time:** ~35 min · **Cost:** effectively free (F1 App Service)

> **Certification note — read this, it's different from the other labs.** Lab B has a payoff that Cloud Shell cannot exercise: the actual *browser sign-in* and the ID-token claims. So certification is split:
> - **CLI-verifiable (a scripted run proves this):** the app registration, redirect URI, ID-token issuance, the wired Microsoft provider, "require login" being on, and the OIDC discovery document being reachable.
> - **Manual, must be done once in a real browser (NOT scriptable):** open the site → get redirected to Microsoft sign-in → land on the app → view `/.auth/me` claims.
>
> This lab is not "certified" until BOTH have been done once, including the browser pass. Don't flip it to certified off a CLI-only run.

---

## Scenario

Campux Retail is building an internal staff portal. Staff shouldn't get yet another username and password — they should sign in with the Microsoft account they already have, and the portal should never see or store their password. That's **single sign-on via OpenID Connect (OIDC)**, and the front door to it is an **app registration** in Microsoft Entra ID.

You'll register the portal as an application in Entra, wire Microsoft as its identity provider using **App Service built-in authentication (Easy Auth)** — so you write *zero* authentication code — and then sign in as yourself and inspect the identity claims Entra hands back.

## What you'll prove you can do (résumé line)

*"Registered an application in Microsoft Entra ID and configured OpenID Connect single sign-on for an Azure App Service using built-in authentication, with no custom auth code."*

## Reinforces

- Builds on [Lab A](../lab-a-rbac-managed-identity/) (App Service + identity)
- Bootcamp: Conditional Access; identity fundamentals
- Blog: `blog-conditional-access-basics`

---

## Architecture

```
   Campux staff
   (browser)
      │  1. GET https://<app>.azurewebsites.net
      ▼
  ┌─────────────────────────────┐   2. no session → redirect to sign in
  │ Azure App Service           │──────────────────────────────────────┐
  │ (Campux staff portal)       │                                        ▼
  │  Built-in auth "Easy Auth"  │                          ┌──────────────────────────┐
  │  — no auth code in the app  │◀───3. user signs in──────│  Microsoft Entra ID       │
  └─────────────┬───────────────┘   (OIDC id_token)        │  App registration:        │
      4. identity injected as       returned to            │  "Campux Staff Portal"    │
         request headers            /.auth/login/aad/callback└──────────────────────────┘
      ▼
  your code sees X-MS-CLIENT-PRINCIPAL-NAME
  full claims at /.auth/me
```

---

## Before you start

1. **Permission to register apps in Entra ID.** Creating an app registration + service principal needs a directory role such as **Application Administrator**, **Cloud Application Administrator**, or **Global Administrator**. On a **personal / free tenant** you're Global Admin — fine. On a work tenant you're likely blocked (`Insufficient privileges`) — use a personal test tenant.
2. **Azure Cloud Shell (Bash)** — [https://shell.azure.com](https://shell.azure.com).
3. **A browser you can sign into your Entra tenant with** — needed for the manual sign-in pass at the end.

**Cost:** App Service **F1 (Free)**. Fractions of a cent. Teardown removes everything.

---

## Stage 0 — Variables

```bash
SUFFIX=$RANDOM
RG="campux-lab-sso-rg"
LOCATION="eastus"
APP="campux-portal-$SUFFIX"       # globally unique across *.azurewebsites.net
PLAN="campux-plan-$SUFFIX"
APP_DISPLAY="Campux Staff Portal $SUFFIX"

TENANT_ID=$(az account show --query tenantId -o tsv)
# The exact redirect URI Easy Auth uses for the Microsoft provider. Must match precisely.
REDIRECT="https://$APP.azurewebsites.net/.auth/login/aad/callback"

echo "App=$APP"
echo "Redirect=$REDIRECT"
echo "Tenant=$TENANT_ID"
```

✅ **Checkpoint:** all three echo non-empty. The app name is now fixed, so the redirect URI is stable — this matters, because the app registration must reference this exact URL.

---

## Stage 1 — Deploy the portal (still unprotected)

```bash
az group create --name "$RG" --location "$LOCATION"
az appservice plan create --name "$PLAN" --resource-group "$RG" --sku F1 --is-linux
az webapp create --name "$APP" --resource-group "$RG" --plan "$PLAN" --runtime "NODE:20-lts"
```

Get the app code (`server.js` + `package.json`) by cloning the labs repo, then deploy it:

```bash
git clone https://github.com/kloudcaptain/campux-labs.git
cd campux-labs/lab-b-app-registration-oidc-sso/app
zip app.zip server.js package.json
az webapp deploy --name "$APP" --resource-group "$RG" --src-path app.zip --type zip

# Warm the free-tier (F1) container so the first request isn't a cold-start 502.
az webapp restart --name "$APP" --resource-group "$RG"
sleep 30
for i in 1 2 3 4 5; do
  curl -sS "https://$APP.azurewebsites.net" && break
  sleep 20
done
```

✅ **Checkpoint:** the `curl` output says `Signed-in user: (no authenticated user)`. The site loads and, right now, anyone can reach it. We'll fix that. (If you get a 502, the loop retries; F1 can take a moment on first boot.)

---

## Stage 2 — Register the app in Microsoft Entra ID

This is the "app registration" — telling Entra that this portal is an application allowed to sign users in. Note `--enable-id-token-issuance true`: Easy Auth uses the OIDC hybrid flow, and **without this the sign-in fails later** with `AADSTS700054`.

```bash
APP_ID=$(az ad app create \
  --display-name "$APP_DISPLAY" \
  --sign-in-audience AzureADMyOrg \
  --web-redirect-uris "$REDIRECT" \
  --enable-id-token-issuance true \
  --query appId -o tsv)

# A just-created app registration can lag Graph replication; pause so the next calls don't 404.
sleep 15

# Create the service principal (enterprise app) in your tenant — sign-in needs it.
az ad sp create --id "$APP_ID"

# Create a client secret for App Service to authenticate as this app.
CLIENT_SECRET=$(az ad app credential reset --id "$APP_ID" --query password -o tsv)

echo "App (client) id: $APP_ID"
```

✅ **Checkpoint:**

```bash
az ad app show --id "$APP_ID" --query "{redirect:web.redirectUris, idToken:web.implicitGrantSettings.enableIdTokenIssuance}" -o json
```

Shows your exact redirect URI and `"idToken": true`. Both are required for sign-in to work.

---

## Stage 3 — Turn on sign-in (wire Microsoft as the identity provider)

One command enables App Service authentication, sets Microsoft Entra as the provider, and requires every visitor to log in. (This is the classic single-command form — no extension needed.)

```bash
az webapp auth update \
  --resource-group "$RG" --name "$APP" \
  --enabled true \
  --action LoginWithAzureActiveDirectory \
  --aad-client-id "$APP_ID" \
  --aad-client-secret "$CLIENT_SECRET" \
  --aad-token-issuer-url "https://sts.windows.net/$TENANT_ID/" \
  --aad-allowed-token-audiences "$REDIRECT"
```

✅ **Checkpoint (CLI-verifiable):**

```bash
az webapp auth show --name "$APP" --resource-group "$RG" \
  --query "{enabled:enabled, action:unauthenticatedClientAction, clientId:clientId}" -o json
```

Shows `enabled: true`, the unauthenticated action set to redirect/login, and your `clientId`. And confirm Entra's OIDC discovery document — the metadata the whole flow relies on — is reachable:

```bash
curl -s "https://login.microsoftonline.com/$TENANT_ID/v2.0/.well-known/openid-configuration" \
  | head -c 200; echo
```

Returns JSON starting with `{"token_endpoint":...`. The configuration is complete and valid.

> Enabling auth restarts the app. Give it ~30 seconds to come back before the browser step so you don't hit a cold-start hiccup mid sign-in:
> ```bash
> sleep 30
> ```

---

## Stage 4 — Sign in (MANUAL browser step — the real payoff)

This part **cannot be scripted** — that's the nature of interactive SSO. Do it in a browser:

1. Open a **new private/incognito window** and go to `https://$APP.azurewebsites.net`.
2. You're redirected to the **Microsoft sign-in page**. Sign in with an account in your tenant. (First time, you may see a consent prompt — accept it.)
3. You land back on the portal, which now shows **`Signed-in user: your@email`** — the identity came from Entra, and the app never saw your password.
4. View the full claims Entra issued: browse to `https://$APP.azurewebsites.net/.auth/me`. You'll see JSON with claims like `name`, `preferred_username`, `oid` (your object id), `tid` (tenant id), and token expiry.

✅ **Certification checkpoint (manual):** the portal shows your email after sign-in, and `/.auth/me` lists your claims. That is OIDC SSO working end to end.

> **Troubleshooting — the three usual failures, in order of likelihood:**
> 1. **`AADSTS700054: response_type 'id_token' is not enabled`** → Stage 2's `--enable-id-token-issuance true` didn't take. Re-run: `az ad app update --id "$APP_ID" --enable-id-token-issuance true`.
> 2. **Redirect / reply-URL mismatch** → the app registration's redirect URI must be *exactly* `$REDIRECT`. Re-check the Stage 2 checkpoint output.
> 3. **Issuer/audience error** → your app may be issuing v2 tokens. Re-run Stage 3 with the v2 issuer instead: `--aad-token-issuer-url "https://login.microsoftonline.com/$TENANT_ID/v2.0"`. This is the first thing to try if sign-in completes but the app rejects the token.

---

## Stage 5 — Teardown (do not skip)

The app registration and service principal are **directory objects** — they survive `az group delete`, so delete them explicitly.

```bash
az group delete --name "$RG" --yes
az ad app delete --id "$APP_ID"   # also removes the service principal
```

✅ **Checkpoint:**

```bash
az ad app list --app-id "$APP_ID" --query "[].appId" -o tsv   # -> empty
az group exists --name "$RG"                                   # -> false
```

Both empty/`false` — no orphaned app registration, no resources.

---

## What you learned

- An **app registration** is how Entra ID knows about your application and is willing to sign users into it.
- **OpenID Connect** lets users sign in with their existing Microsoft identity; your app receives an **ID token** of claims and never handles a password.
- **App Service Easy Auth** implements the entire OIDC flow for you — zero auth code — and hands the identity to your app as request headers, with full claims at `/.auth/me`.
- **Redirect URI, ID-token issuance, and issuer/token-version** are the three settings that make or break a sign-in.

## The infrastructure-as-code angle

See [`bicep/`](bicep/). As in Lab C, the **app registration itself is a Microsoft Graph object that Bicep can't create** — but the **App Service auth configuration** (`authsettingsV2`) that consumes an existing app registration *is* ARM, and belongs with your infrastructure. The Bicep template shows that piece.

**Next:** Lab D — Azure Policy & policy-as-code, to govern everything you've built across the track.

*Part of the full Campux Cloud Engineering Bootcamp → [link to track]*
