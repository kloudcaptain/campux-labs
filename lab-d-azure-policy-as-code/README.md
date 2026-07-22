# Lab D — Azure Policy & policy-as-code: govern what can be built

**Track:** Identity & Governance (Lab D of 4)
**Status:** Authored — **PENDING one real end-to-end certification run** before publish.
**Level:** Advanced · **Time:** ~30 min (plus a few minutes waiting for policy to enforce) · **Cost:** effectively free (storage accounts created and deleted immediately)

> Certification note: run in a fresh Azure Cloud Shell (Bash). The one non-deterministic part — a newly-assigned Deny policy taking a few minutes to enforce — is handled by a poll loop that retries until the non-compliant create is actually blocked. Certified when the negative test is denied, the positive test succeeds, and teardown removes the policy objects.

---

## Scenario

Campux Retail keeps having incidents where someone spins up a storage account with **public blob access** turned on, and customer data ends up exposed to the internet. Telling people "don't do that" doesn't scale. **Azure Policy** lets you make it *impossible*: a rule evaluated by Azure itself that **denies** the creation of any non-compliant resource, across an entire scope, automatically.

You'll assign a built-in policy (the easy path), then **author your own custom policy** that denies public-blob storage accounts, prove it actually blocks a bad resource while allowing a good one, and finally deploy the same policy **as code** with Bicep — the way governance is managed in real organizations.

## What you'll prove you can do (résumé line)

*"Authored and assigned a custom Azure Policy with a Deny effect to enforce storage security, and deployed governance as code with Bicep."*

## Reinforces

- Caps the Identity & Governance track (Labs A–C)
- Bootcamp: Azure Policy effects; remediation; management groups & scope
- Blog: `blog-azure-policy-effects`, `blog-azure-policy-remediation`, `blog-bicep-modules-explained`

---

## Architecture

```
   You (or anyone) tries to create a resource in the scope
                     │
                     ▼
        ┌──────────────────────────┐
        │  Azure Resource Manager   │
        │  evaluates every create   │
        │  against assigned policies │
        └─────────────┬────────────┘
             ┌─────────┴──────────┐
             ▼                    ▼
   storage account with     storage account with
   allowBlobPublicAccess     allowBlobPublicAccess
        = true                    = false
             │                    │
        ┌────▼────┐          ┌────▼────┐
        │ DENIED  │          │ CREATED │
        │ (blocked│          │ (allowed│
        │ at ARM) │          │         │
        └─────────┘          └─────────┘
   Custom policy: "deny public blob storage"  →  enforced automatically, no human in the loop
```

---

## Before you start

1. **Permission to author and assign policy.** You need **Resource Policy Contributor** or **Owner** on the subscription (Owner on a personal sub is fine).
2. **Azure Cloud Shell (Bash)** — [https://shell.azure.com](https://shell.azure.com).

**Cost:** the storage accounts you create are deleted seconds later; policy objects are free. Effectively $0.

---

## Stage 0 — Variables

```bash
SUFFIX=$RANDOM
RG="campux-lab-policy-rg"
LOCATION="eastus"
DEF_NAME="campux-deny-public-blob"
ASSIGN_NAME="campux-deny-public-blob"

SUB=$(az account show --query id -o tsv)
RG_SCOPE="/subscriptions/$SUB/resourceGroups/$RG"

# Storage account names: 3–24 chars, lowercase letters + digits only.
BAD_SA="campuxbad$SUFFIX"
GOOD_SA="campuxgood$SUFFIX"

echo "RG=$RG  BAD_SA=$BAD_SA  GOOD_SA=$GOOD_SA"
```

✅ **Checkpoint:** names echo, `BAD_SA`/`GOOD_SA` are ≤24 chars and lowercase.

---

## Stage 1 — Resource group

```bash
az group create --name "$RG" --location "$LOCATION"
```

✅ **Checkpoint:** `provisioningState: Succeeded`.

---

## Stage 2 — The easy path: assign a built-in policy

You don't always write your own — Azure ships hundreds of built-in policies. Assign a built-in that audits storage accounts lacking secure transfer. (We look it up by display name so there's no fragile hard-coded ID.)

```bash
BUILTIN=$(az policy definition list \
  --query "[?displayName=='Secure transfer to storage accounts should be enabled'].name | [0]" -o tsv)
echo "Built-in definition name: $BUILTIN"
[ -n "$BUILTIN" ] || echo "!! built-in not found — the display name may have changed; list built-ins with: az policy definition list --query \"[?policyType=='BuiltIn'].displayName\" -o tsv"

az policy assignment create \
  --name "campux-secure-transfer" \
  --policy "$BUILTIN" \
  --scope "$RG_SCOPE"
```

✅ **Checkpoint:**

```bash
az policy assignment show --name "campux-secure-transfer" --scope "$RG_SCOPE" --query "displayName" -o tsv
```

Returns the assignment. (This built-in uses the *Audit* effect — its compliance results appear after Azure's next evaluation scan, which can take up to ~30 min. We won't wait on that; the enforcement we *prove* comes from the custom Deny policy next.)

---

## Stage 3 — Author your own custom policy (Deny)

Now the real skill: write a policy that **denies** any storage account with public blob access enabled. The rule is `if (type is storage account AND allowBlobPublicAccess == true) then deny`.

```bash
az policy definition create \
  --name "$DEF_NAME" \
  --display-name "Campux: deny storage accounts with public blob access" \
  --description "Denies creation of storage accounts that allow public blob access." \
  --mode Indexed \
  --rules "{ 'if': { 'allOf': [ { 'field': 'type', 'equals': 'Microsoft.Storage/storageAccounts' }, { 'field': 'Microsoft.Storage/storageAccounts/allowBlobPublicAccess', 'equals': 'true' } ] }, 'then': { 'effect': 'deny' } }"
```

✅ **Checkpoint:**

```bash
az policy definition show --name "$DEF_NAME" --query "{name:name, effect:policyRule.then.effect}" -o json
```

Shows your definition with `"effect": "deny"`.

---

## Stage 4 — Assign the custom policy to the resource group

```bash
az policy assignment create \
  --name "$ASSIGN_NAME" \
  --policy "$DEF_NAME" \
  --scope "$RG_SCOPE"
```

✅ **Checkpoint:** `az policy assignment show --name "$ASSIGN_NAME" --scope "$RG_SCOPE" --query name -o tsv` returns the name. The rule is now enforced for this resource group.

---

## Stage 5 — Prove it: bad is blocked, good is allowed

**Negative test.** Try to create a storage account with public blob access — it must be **denied**. A freshly-assigned policy takes a few minutes to start enforcing, so this loop retries until it's actually blocked (and cleans up any account that slips through while the policy is still propagating):

```bash
echo "Testing the Deny policy (it can take a few minutes to start enforcing)..."
for i in $(seq 1 20); do
  if az storage account create --name "$BAD_SA" --resource-group "$RG" \
       --location "$LOCATION" --sku Standard_LRS --allow-blob-public-access true -o none 2>/tmp/policyerr; then
    echo "attempt $i: not blocked yet — policy still propagating. Deleting and waiting 30s."
    az storage account delete --name "$BAD_SA" --resource-group "$RG" --yes -o none
    sleep 30
  else
    # Only a POLICY denial counts as success. Any other failure (e.g. the name is briefly
    # reserved after the delete above) is not proof — keep waiting.
    if grep -qi "RequestDisallowedByPolicy\|disallowed by policy" /tmp/policyerr; then
      echo ">>> DENIED on attempt $i — the policy is enforcing."
      break
    else
      echo "attempt $i: create failed for a NON-policy reason (not proof yet):"
      cat /tmp/policyerr
      az storage account delete --name "$BAD_SA" --resource-group "$RG" --yes -o none 2>/dev/null
      sleep 30
    fi
  fi
done
```

✅ **Checkpoint:** you see `>>> DENIED on attempt N — the policy is enforcing.` That message prints **only** when the failure reason is `RequestDisallowedByPolicy` — an unrelated failure keeps the loop going, so a green result is real proof, not a coincidence.

**Positive test.** A compliant storage account (public blob access disabled) must **succeed**:

```bash
az storage account create --name "$GOOD_SA" --resource-group "$RG" \
  --location "$LOCATION" --sku Standard_LRS --allow-blob-public-access false -o none \
  && echo ">>> CREATED — compliant storage account allowed."
```

✅ **Checkpoint:** `>>> CREATED`. The policy blocks only the insecure configuration, not legitimate resources. That's governance: guardrails, not roadblocks.

---

## Stage 6 — Policy as code (Bicep)

Clicking policies into the portal doesn't scale or survive audits. Real teams keep policy in source control. See [`bicep/`](bicep/) — it declares the **same** custom policy definition and assignment as code. Unlike Labs B and C, policy *is* fully ARM-native, so the whole thing (definition + assignment) is Bicep — no Graph split here.

---

## Stage 7 — Teardown (do not skip)

Assignments and definitions are not inside the resource group — delete them explicitly, then the group.

```bash
az policy assignment delete --name "$ASSIGN_NAME" --scope "$RG_SCOPE"
az policy assignment delete --name "campux-secure-transfer" --scope "$RG_SCOPE"
az policy definition delete --name "$DEF_NAME"
az group delete --name "$RG" --yes
```

✅ **Checkpoint:**

```bash
az policy definition list --query "[?name=='$DEF_NAME'].name" -o tsv   # -> empty
az group exists --name "$RG"                                           # -> false
```

Both empty/`false`.

---

## What you learned

- **Azure Policy enforces rules at resource-creation time** — a Deny policy makes a bad configuration *impossible*, not merely discouraged.
- **Built-in vs custom:** hundreds of built-ins exist; when none fits, you author a policy rule (`if`/`then` with an `effect`).
- **Effects matter:** `Audit` reports; `Deny` blocks. This lab used Deny for immediate, provable enforcement.
- **Scope controls blast radius:** definitions live at subscription/management-group level; assignments apply the rule to a subscription, resource group, or below.
- **Policy as code** (Bicep) makes governance reviewable, repeatable, and auditable.

*This completes the Identity & Governance track (Labs A–D). Part of the full Campux Cloud Engineering Bootcamp → [link to track]*
