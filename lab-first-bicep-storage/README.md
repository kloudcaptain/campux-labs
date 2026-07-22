# Lab — Your first Bicep deploy: a storage account as code

**Track:** Standalone (Infrastructure as Code fundamentals)
**Status:** Authored — **PENDING one real end-to-end certification run** before publish.
**Level:** Beginner · **Time:** ~20 min · **Cost:** effectively free (an empty storage account, deleted at the end)

> Certification note: run in a fresh Azure Cloud Shell (Bash). Fully deterministic — no App Service quota, no browser step. Certified when the deploy succeeds, the idempotency re-run reports "no change," and a parameter change is detected by `what-if`.

---

## Scenario

Campux Retail keeps creating storage accounts by hand in the portal, and they come out inconsistent — one has public access on, another allows old TLS, a third is missing tags. The fix is **infrastructure as code**: describe the storage account once in a **Bicep** file, commit it, and deploy it the same way every time. Change the file, not the clicks.

This is the on-ramp to everything else in cloud engineering. You'll write (well, read) a real Bicep template, preview exactly what it will do, deploy it, and see the superpower of declarative infrastructure: **re-running it changes nothing** unless the file changed.

## What you'll prove you can do (résumé line)

*"Authored and deployed an Azure resource with a Bicep template, using what-if previews and idempotent deployments."*

## Reinforces

- Bootcamp: Bicep modules; Bicep vs Terraform
- Blog: `blog-bicep-modules-explained`, `blog-bicep-vs-terraform`, `blog-azure-storage-account-types`

---

## The two ways to create a resource

There are two ways to create anything in Azure, and this lab is really about the difference:

- **Imperative (CLI):** you run a command that *does* an action. `az storage account create …`. Fine for one-off tasks, but there's no record of intent, and re-running can behave differently.
- **Declarative (Bicep):** you write a file that *describes the desired end state*, and Azure makes reality match it. Re-running is safe and does nothing if reality already matches. This is how real infrastructure is managed.

You'll do it the Bicep way, then see the CLI equivalent at the end for contrast.

---

## Before you start

1. An Azure subscription (a [free account](https://azure.microsoft.com/free) works) with **Contributor** on it.
2. **Azure Cloud Shell (Bash)** — [https://shell.azure.com](https://shell.azure.com). `az` and `bicep` are preinstalled.

**Cost:** an empty StorageV2 account costs effectively nothing at rest; you delete it at the end.

---

## Stage 0 — Variables and get the template

```bash
RG="campux-lab-bicep-rg"
LOCATION="eastus"

# Get the Bicep template from the labs repo.
cd ~
if [ -d campux-labs ]; then git -C campux-labs pull --ff-only; else git clone https://github.com/kloudcaptain/campux-labs.git; fi
cd campux-labs/lab-first-bicep-storage/bicep
ls
```

✅ **Checkpoint:** you see `main.bicep`. Open it (`cat main.bicep`) and read it — parameters, one storage resource, three outputs. That whole file is your infrastructure.

---

## Stage 1 — Resource group

```bash
az group create --name "$RG" --location "$LOCATION"
```

✅ **Checkpoint:** `provisioningState: Succeeded`.

---

## Stage 2 — Preview with what-if (look before you leap)

`what-if` shows exactly what a deployment *would* do without doing it. Professionals run this before every deploy.

```bash
az deployment group what-if --resource-group "$RG" --template-file main.bicep
```

✅ **Checkpoint:** the output shows a line with `+ Microsoft.Storage/storageAccounts/…` (a **Create**). Nothing has been created yet — this is a preview.

---

## Stage 3 — Deploy

```bash
az deployment group create --resource-group "$RG" --template-file main.bicep --name firstbicep
```

✅ **Checkpoint:**

```bash
SA=$(az deployment group show -g "$RG" -n firstbicep --query properties.outputs.storageAccountName.value -o tsv)
echo "Created: $SA"
az storage account show --name "$SA" --resource-group "$RG" \
  --query "{tls:minimumTlsVersion, publicBlob:allowBlobPublicAccess, sku:sku.name}" -o json
```

Shows your storage account with `TLS1_2`, `publicBlob: false`, `Standard_LRS`. The secure defaults from the template are baked in — no way to forget them.

---

## Stage 4 — The payoff: idempotency

Run the **exact same deployment again**:

```bash
az deployment group what-if --resource-group "$RG" --template-file main.bicep
```

✅ **Checkpoint:** the key signal is that there is **no `+ Create` and no `- Delete`** — your storage account is not being recreated. You'll typically see `No change` or an `=`/`* (No effect)` line. (Azure's `what-if` sometimes lists a few `~` managed properties like `networkAcls`, `encryption.services`, or `accessTier` as noise even when nothing meaningful changes — that's a known quirk, not your template recreating anything.) This is the whole point of declarative infrastructure: the file describes the end state, reality already matches, so a re-run doesn't recreate resources. Safe to run a hundred times.

---

## Stage 5 — Change the file, see the diff

Now change one input — the redundancy SKU — and preview again. Bicep detects exactly what would change:

```bash
az deployment group what-if --resource-group "$RG" --template-file main.bicep --parameters sku=Standard_GRS
```

✅ **Checkpoint:** what-if shows a `~ Modify` on the storage account with `sku.name: "Standard_LRS" => "Standard_GRS"`. You changed one value and the tool told you precisely the effect — before touching anything. Apply it for real if you like:

```bash
az deployment group create --resource-group "$RG" --template-file main.bicep --name changesku --parameters sku=Standard_GRS
```

---

## Stage 6 — The CLI contrast (optional, 1 minute)

For comparison, the imperative one-liner that creates a similar account:

```bash
# az storage account create --name <unique> --resource-group "$RG" \
#   --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 --allow-blob-public-access false
```

It works — but there's no file, no record of intent, no what-if, and re-running it isn't guaranteed to be a no-op. Multiply that across a hundred resources and a team, and you can see why real infrastructure lives in Bicep files under source control.

---

## Stage 7 — Teardown

```bash
az group delete --name "$RG" --yes
```

✅ **Checkpoint:** `az group exists --name "$RG"` → `false`.

---

## What you learned

- A **Bicep template** describes desired infrastructure as code: parameters, resources, outputs.
- **`what-if`** previews a deployment before it runs — your safety net.
- **Deployments are idempotent** — re-running with an unchanged file changes nothing.
- **Change the file → the tool shows you the exact diff.** That's reviewable, repeatable, auditable infrastructure.
- **Declarative (Bicep) beats imperative (CLI)** for anything you'll manage over time.

**Next:** apply this to something with access control — [Lab A: RBAC & Managed Identity](../lab-a-rbac-managed-identity/) has a Bicep path that builds on exactly these ideas.

*Part of the full Campux Cloud Engineering Bootcamp → [link to track]*
