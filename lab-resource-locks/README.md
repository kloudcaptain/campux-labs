# Lab — Resource Locks: stop accidental deletion

**Track:** Standalone (Governance)
**Status:** Authored — **PENDING one real end-to-end certification run** before publish.
**Level:** Beginner–Intermediate · **Time:** ~20 min · **Cost:** effectively free (one storage account, deleted at the end)

> Certification note: run in a fresh Azure Cloud Shell (Bash). Deterministic. Certified when the locked resource refuses to delete (with a lock error), then deletes cleanly after the lock is removed, and teardown leaves nothing behind.

---

## Scenario

Someone at Campux Retail runs `az group delete` against the wrong resource group at 4 p.m. on a Friday, and the production database goes with it. RBAC decides *who* can delete things; it does nothing to stop an authorized person from deleting the *wrong* thing by mistake. That last-line defense is a **resource lock** — a small object you attach to a subscription, resource group, or resource that makes Azure itself refuse a destructive operation until the lock is deliberately removed.

You'll lock a resource group so its contents can't be deleted, prove the lock blocks a real delete, then remove it and watch the delete go through.

## What you'll prove you can do (résumé line)

*"Applied Azure resource locks (CanNotDelete) to protect production resources from accidental deletion, and deployed the lock as code with Bicep."*

## Reinforces

- Pairs with [Lab D — Azure Policy as code](../lab-d-azure-policy-as-code/) (locks stop deletion; policy stops non-compliant creation — two different guardrails)
- Bootcamp: Resource locks; governance
- Blog: `blog-azure-resource-locks`

---

## Locks vs. policy vs. RBAC (know the difference)

These three get confused constantly, and interviewers probe exactly here:

- **RBAC** decides *who is allowed* to perform an action.
- **Azure Policy** decides *what configurations are allowed* to be created or changed (see Lab D).
- **Resource locks** stop a *specific destructive action* — delete, or delete-and-modify — regardless of who you are, even an Owner. A lock is the seatbelt: it doesn't care that you're allowed to drive; it stops you going through the windscreen.

There are two lock levels: **`CanNotDelete`** (you can read and modify, but not delete) and **`ReadOnly`** (you can't modify or delete). This lab uses `CanNotDelete`, the common one.

---

## Before you start

1. An Azure subscription with **Owner** or **User Access Administrator** (managing locks needs `Microsoft.Authorization/locks/*`, which those roles include; plain Contributor does **not**).
2. **Azure Cloud Shell (Bash)** — [https://shell.azure.com](https://shell.azure.com).

**Cost:** one empty storage account (pennies), deleted at the end.

---

## Stage 0 — Variables

```bash
SUFFIX=$RANDOM
RG="campux-lab-locks-rg"
LOCATION="eastus"
SA="campuxlock$SUFFIX"          # 3-24 lowercase alphanumeric
LOCK_NAME="campux-prod-donotdelete"

echo "RG=$RG  SA=$SA"
```

✅ **Checkpoint:** names echo; `SA` is ≤24 chars and lowercase.

---

## Stage 1 — A resource group with something worth protecting

```bash
az group create --name "$RG" --location "$LOCATION"
az storage account create --name "$SA" --resource-group "$RG" \
  --location "$LOCATION" --sku Standard_LRS -o none
echo "Created storage account $SA"
```

✅ **Checkpoint:** `az storage account show --name "$SA" --resource-group "$RG" --query name -o tsv` returns `$SA`.

---

## Stage 2 — Lock the resource group

One lock on the group protects everything inside it.

```bash
az lock create \
  --name "$LOCK_NAME" \
  --lock-type CanNotDelete \
  --resource-group "$RG" \
  --notes "Protect Campux production resources from accidental deletion."
```

✅ **Checkpoint:**

```bash
az lock list --resource-group "$RG" --query "[].{name:name, level:level}" -o table
```

Shows your lock with level `CanNotDelete`.

---

## Stage 3 — Prove it: the delete is refused

Try to delete the storage account. The lock must block it. (Lock changes usually take effect within seconds; occasionally ARM takes a minute to recognize a new lock.)

```bash
if az storage account delete --name "$SA" --resource-group "$RG" --yes 2>/tmp/lockerr; then
  echo "!! Delete SUCCEEDED — the lock isn't enforcing yet. Wait ~60s, recreate the account, and retry Stage 3."
else
  if grep -qi "ScopeLocked\|is locked\|locked and can" /tmp/lockerr; then
    echo ">>> BLOCKED by the lock — exactly right."
  else
    echo "Delete failed for a NON-lock reason (not the proof):"
    cat /tmp/lockerr
  fi
fi
```

✅ **Checkpoint:** you see `>>> BLOCKED by the lock`. An authorized delete was stopped cold — not by permissions, but by the lock. That message prints **only** when the failure reason is a lock (`ScopeLocked`), so a green result is real proof.

---

## Stage 4 — Remove the lock, then the delete works

```bash
az lock delete --name "$LOCK_NAME" --resource-group "$RG"

# Lock removal can also take a few seconds to register. Retry the delete until it goes through.
for i in 1 2 3 4 5; do
  if az storage account delete --name "$SA" --resource-group "$RG" --yes 2>/tmp/lockerr2; then
    echo ">>> Deleted on attempt $i — with the lock gone, the same command now works."
    break
  fi
  echo "attempt $i: still blocked (lock removal registering) — waiting 20s"
  sleep 20
done
```

✅ **Checkpoint:** `>>> Deleted`. The identical command that was refused in Stage 3 now succeeds — the only thing that changed is the lock. That is the entire lesson: the lock, not your permissions, was the gate.

---

## Stage 5 — Locks as code (Bicep)

In production you don't hand-place locks — they're declared with the infrastructure they protect, so a rebuild can't forget them. See [`bicep/`](bicep/): it creates a resource-group lock as code.

---

## Stage 6 — Teardown

The storage account is already gone. Remove the group (no lock remains to block it):

```bash
az group delete --name "$RG" --yes
```

✅ **Checkpoint:** `az group exists --name "$RG"` → `false`.

> If `az group delete` ever refuses with a lock error, a lock is still present — list with `az lock list -g "$RG"` and delete it first. A locked resource group cannot be deleted; that's the whole point of the lock.

---

## What you learned

- A **resource lock** stops a destructive operation regardless of RBAC — even an Owner is blocked.
- **`CanNotDelete`** blocks deletion but allows changes; **`ReadOnly`** blocks changes too.
- Locks are inherited: a lock on a resource group protects everything inside it.
- A locked resource group **cannot be deleted** until the lock is removed — remember this at teardown time.
- **Declare locks as code** so a rebuild never ships an unprotected production resource.

*Part of the free [CAMPUX Cloud Engineering Bootcamp](https://azure.campux.co) — see all labs at [azure.campux.co/labs](https://azure.campux.co/labs).*
