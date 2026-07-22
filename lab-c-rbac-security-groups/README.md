# Lab C — RBAC at scale with Entra security groups

**Track:** Identity & Governance (Lab C of 4)
**Status:** Authored — **PENDING one real end-to-end certification run** before publish.
**Level:** Intermediate · **Time:** ~30 min · **Cost:** effectively free (a Key Vault + one secret; pennies)

> Certification note for the author: run every block below, in order, in a **fresh Azure Cloud Shell (Bash)**. Certified only after a clean pass where the `--include-groups` checkpoints flip correctly as members are added/removed, and teardown leaves nothing behind.

---

## Scenario

In [Lab A](../lab-a-rbac-managed-identity/) you assigned a role to a single identity. That's fine for one app — but imagine Campux Retail has twelve engineers who all need to read Key Vault secrets, and people join and leave every month. Assigning `Key Vault Secrets User` to each person one by one is how access sprawl and security incidents happen: nobody can answer "who can read this?" and offboarding gets missed.

The professional pattern: **assign the role once to a security group**, then manage access purely through **group membership**. Onboarding = add to group. Offboarding = remove from group. The role assignment never changes. This is how real organizations manage Azure access at scale.

You'll prove it by showing a user *inherits* the role through the group — and that adding/removing them from the group flips their effective access, with zero changes to any role assignment.

## What you'll prove you can do (résumé line)

*"Implemented group-based Azure RBAC: assigned a least-privilege role to a Microsoft Entra security group and managed access at scale through group membership, verified with effective-access inspection."*

## Reinforces

- Builds directly on [Lab A](../lab-a-rbac-managed-identity/) (RBAC & managed identity)
- Bootcamp: Management groups & scope; least privilege
- Blog: `blog-managed-identity-vs-service-principal`

---

## Architecture

```
   engineers (join/leave over time)
   ┌────────┐   ┌────────┐
   │  Ava   │   │  Ben   │        add/remove membership  ← the only thing you change
   └───┬────┘   └───┬────┘
       │            │
       ▼            ▼
   ┌─────────────────────────────┐
   │ Entra security group:       │
   │ "Campux-KeyVault-Readers"   │
   └──────────────┬──────────────┘
                  │  ONE role assignment (never changes):
                  │  Key Vault Secrets User
                  ▼
        ┌──────────────────────┐
        │ Azure Key Vault (RBAC)│
        │ secret: ProductDb...  │
        └──────────────────────┘

   Effective access = "is the user in the group?"  ← managed by membership, not role edits
```

---

## Before you start (read this — Lab C needs TWO kinds of permission)

1. **Azure permission to assign roles** — **Owner** or **User Access Administrator** on the subscription (same as Lab A). A plain Contributor can't create role assignments.
2. **Entra directory permission to manage users and groups** — this is *separate* from Azure RBAC. To create groups/users and manage membership you need a directory role such as **Global Administrator**, or **Groups Administrator + User Administrator**.
   - On a **personal / free Azure tenant**, the first account you signed up with is Global Administrator — you're fine.
   - On a **work/school tenant**, you are almost certainly **not** allowed to create users/groups. Don't attempt this lab there; use a personal test tenant. Every `az ad ...` command below will fail with `Insufficient privileges` otherwise — that's a permissions block, not a mistake in your commands.
3. **Azure Cloud Shell (Bash)** — [https://shell.azure.com](https://shell.azure.com).

**Cost:** one Key Vault + one secret. Fractions of a cent. The users and group are free. Teardown removes everything.

---

## Stage 0 — Variables

```bash
SUFFIX=$RANDOM
RG="campux-lab-groups-rg"
LOCATION="eastus"
KV="campux-kv-$SUFFIX"
SECRET_NAME="ProductDbConnection"
GROUP_NAME="Campux-KeyVault-Readers"
GROUP_NICK="campux-kv-readers-$SUFFIX"

SUB=$(az account show --query id -o tsv)
VAULT_SCOPE="/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.KeyVault/vaults/$KV"

# Default verified domain of your tenant (the *.onmicrosoft.com), used for test user names.
DOMAIN=$(az rest --method GET --url "https://graph.microsoft.com/v1.0/domains" --query "value[?isDefault].id | [0]" -o tsv)

# A password that meets Entra complexity rules, for the throwaway test users.
USER_PWD="Cx-$(openssl rand -hex 6)-9A!"

echo "Suffix=$SUFFIX  Domain=$DOMAIN"
```

✅ **Checkpoint:** `$DOMAIN` prints something like `yourtenant.onmicrosoft.com`. If it's empty, you don't have directory read permission — re-read the prerequisites; you can't do this lab on this tenant.

---

## Stage 1 — Vault + secret (the thing access protects)

```bash
az group create --name "$RG" --location "$LOCATION"
az keyvault create --name "$KV" --resource-group "$RG" --location "$LOCATION" --enable-rbac-authorization true

# Let yourself write one secret (RBAC vaults don't grant the creator data access automatically).
ME=$(az ad signed-in-user show --query id -o tsv)
az role assignment create --role "Key Vault Secrets Officer" \
  --assignee-object-id "$ME" --assignee-principal-type User --scope "$VAULT_SCOPE"

sleep 60
az keyvault secret set --vault-name "$KV" --name "$SECRET_NAME" \
  --value "Server=tcp:campux-sql.database.windows.net,1433;Database=products;Authentication=Active Directory Default;"
```

✅ **Checkpoint:** `az keyvault secret show --vault-name "$KV" --name "$SECRET_NAME" --query value -o tsv` prints the string. (If `Forbidden`, the role is still propagating — wait 60s and re-run the `secret set` line.)

---

## Stage 2 — Create the security group

```bash
az ad group create --display-name "$GROUP_NAME" --mail-nickname "$GROUP_NICK"
GROUP_ID=$(az ad group show --group "$GROUP_NAME" --query id -o tsv)
echo "Group object id: $GROUP_ID"
```

✅ **Checkpoint:** `$GROUP_ID` is a GUID. The group exists and is empty.

---

## Stage 3 — Assign the role to the GROUP (once)

This is the whole idea: one assignment, to the group, scoped to just this vault.

```bash
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee-object-id "$GROUP_ID" \
  --assignee-principal-type Group \
  --scope "$VAULT_SCOPE"
```

✅ **Checkpoint:**

```bash
az role assignment list --scope "$VAULT_SCOPE" --assignee-object-id "$GROUP_ID" \
  --query "[].roleDefinitionName" -o tsv
```

Prints `Key Vault Secrets User`. The group can read secrets. Nobody's in it yet, so nobody has access — exactly right.

---

## Stage 4 — Create two test engineers

```bash
AVA_UPN="ava.okoro@$DOMAIN"
BEN_UPN="ben.carter@$DOMAIN"

az ad user create --display-name "Ava Okoro" --user-principal-name "$AVA_UPN" \
  --password "$USER_PWD" --force-change-password-next-sign-in true
az ad user create --display-name "Ben Carter" --user-principal-name "$BEN_UPN" \
  --password "$USER_PWD" --force-change-password-next-sign-in true

AVA_ID=$(az ad user show --id "$AVA_UPN" --query id -o tsv)
BEN_ID=$(az ad user show --id "$BEN_UPN" --query id -o tsv)
echo "Ava=$AVA_ID  Ben=$BEN_ID"

# A brand-new user can take a few seconds to replicate across Microsoft Graph.
# Give it a moment so the next stage's "member add" doesn't fail with "does not exist".
sleep 15
```

✅ **Checkpoint:** both `$AVA_ID` and `$BEN_ID` are GUIDs. Two throwaway users exist. Neither has any Key Vault access yet.

---

## Stage 5 — Onboard Ava (add to group) and prove she inherited access

```bash
az ad group member add --group "$GROUP_ID" --member-id "$AVA_ID"
```

**The deterministic proof (this is the core checkpoint).** Ava's effective access is simply: *is she in the group?* AND *does the group hold the role?* You already proved the group holds `Key Vault Secrets User` in Stage 3. Now confirm her membership:

```bash
az ad group member check --group "$GROUP_ID" --member-id "$AVA_ID" --query value -o tsv
```

✅ **Checkpoint:** prints `true`. Membership `true` + the group's role from Stage 3 = Ava can read the vault's secrets, with **no role assignment on Ava herself**.

**Now see it the way an admin does — the contrast that makes it click.** First list what's assigned directly to Ava (nothing), then the same query *including* group inheritance:

```bash
echo "Directly assigned to Ava (expect empty):"
az role assignment list --assignee "$AVA_ID" --scope "$VAULT_SCOPE" \
  --query "[].roleDefinitionName" -o tsv

echo "Effective for Ava, including groups (expect: Key Vault Secrets User):"
az role assignment list --assignee "$AVA_ID" --scope "$VAULT_SCOPE" --include-groups \
  --query "[].roleDefinitionName" -o tsv
```

The first is empty; the second shows `Key Vault Secrets User`. That gap is the whole lesson: nothing is assigned to Ava, yet she has access — through the group.

> If the second command is **empty** too: (a) group membership reflects transitively within a minute — wait 30–60s and re-run; (b) some CLI builds don't apply `--include-groups` together with a resource `--scope`. If waiting doesn't help, drop the scope and use `--all`:
> ```bash
> az role assignment list --assignee "$AVA_ID" --include-groups --all \
>   --query "[?scope=='$VAULT_SCOPE'].roleDefinitionName" -o tsv
> ```
> The deterministic checkpoint above (membership `true` + Stage 3 role) already proves the outcome regardless — this query is how you'd *confirm* it in a real access review.

---

## Stage 6 — Offboard Ava, onboard Ben (the scale story)

A month passes. Ava moves teams; Ben joins. Watch how access changes with **membership only — zero role-assignment edits**.

```bash
az ad group member remove --group "$GROUP_ID" --member-id "$AVA_ID"
az ad group member add    --group "$GROUP_ID" --member-id "$BEN_ID"
```

Verify the swap:

```bash
echo "Ava in group? $(az ad group member check --group "$GROUP_ID" --member-id "$AVA_ID" --query value -o tsv)"
echo "Ben in group? $(az ad group member check --group "$GROUP_ID" --member-id "$BEN_ID" --query value -o tsv)"

echo "Ava effective KV role (expect empty): $(az role assignment list --assignee "$AVA_ID" --scope "$VAULT_SCOPE" --include-groups --query "[].roleDefinitionName" -o tsv)"
echo "Ben effective KV role (expect Key Vault Secrets User): $(az role assignment list --assignee "$BEN_ID" --scope "$VAULT_SCOPE" --include-groups --query "[].roleDefinitionName" -o tsv)"
```

✅ **Checkpoint:** Ava in group → `false`, Ben → `true`. Ava's effective KV role is now **empty**; Ben's is `Key Vault Secrets User`. Ava's access was revoked and Ben's granted — and you never touched a role assignment. That is access management at scale. (Allow up to a minute for the transitive change to reflect.)

---

## Stage 7 — Teardown (do not skip)

```bash
az ad group member remove --group "$GROUP_ID" --member-id "$BEN_ID" 2>/dev/null
az ad user delete --id "$AVA_UPN"
az ad user delete --id "$BEN_UPN"
az ad group delete --group "$GROUP_ID"
az group delete --name "$RG" --yes
az keyvault purge --name "$KV" --location "$LOCATION"
```

✅ **Checkpoint:**

```bash
az ad group list --display-name "$GROUP_NAME" --query "[].id" -o tsv   # -> empty
az group exists --name "$RG"                                            # -> false
```

Both empty/`false` — directory and subscription are back to zero. No stray test users, no reserved names.

---

## What you learned

- **Assign roles to groups, not people.** One role assignment + group membership scales; per-user assignments sprawl.
- **Membership is the access control.** Onboarding/offboarding becomes add/remove from a group — auditable and reversible.
- **`--include-groups` answers "what can this person actually do?"** including everything inherited transitively through groups. This is the query you run in a real access review.
- **Directory permissions ≠ Azure RBAC.** Managing users/groups needs Entra directory roles; assigning Azure roles needs Owner/User Access Administrator. Two different systems.

## The infrastructure-as-code angle

See [`bicep/`](bicep/). Note an important reality: **Entra users, groups, and memberships are not ARM resources** — they live in Microsoft Graph, so Bicep can't create them (teams use the Terraform `azuread` provider or Graph for that). What Bicep *can* own is the piece that belongs with your infrastructure: the **role assignment to an existing group**. The Bicep template shows exactly that pattern.

**Next:** Lab B — App Registration & OIDC SSO, so Campux staff sign in with single sign-on.

*Part of the full Campux Cloud Engineering Bootcamp → [link to track]*
