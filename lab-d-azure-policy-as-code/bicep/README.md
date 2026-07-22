# Lab D — the Bicep (policy-as-code) piece

The CLI walkthrough (`../README.md`) teaches you to author and assign the policy by hand. This folder declares the **same custom policy definition and assignment as code** — how governance is actually managed in production: reviewed in a pull request, versioned, repeatable.

Azure Policy is fully ARM-native, so — unlike Labs B and C — there's no Graph/ARM split. The whole thing is Bicep.

## Scope: why this targets the subscription

Policy **definitions cannot live in a resource group** — they're a subscription- (or management-group-) level resource. So `main.bicep` uses `targetScope = 'subscription'` and is deployed with `az deployment sub create` (which needs a `--location` for the deployment's metadata).

## Deploy

```bash
az deployment sub create --location eastus --template-file main.bicep
```

✅ **Checkpoint:**

```bash
az policy assignment show --name "campux-deny-public-blob" --query "displayName" -o tsv
```

Returns `Campux: deny public blob storage (as code)`. The guardrail is now defined and enforced by code.

You can prove enforcement exactly as in the CLI walkthrough's Stage 5 (try to create a public-blob storage account — it's denied). Note the assignment here is at **subscription** scope, so the test works in any resource group.

## Teardown (important)

Deleting the deployment does **not** remove policy objects — delete them explicitly:

```bash
az policy assignment delete --name "campux-deny-public-blob"
az policy definition delete --name "campux-deny-public-blob"
```

## Note

This template is authored against current ARM schemas but has **not been compile-checked locally** (no `az`/`bicep` in the authoring environment) — it is validated when you run `az deployment sub create` in Cloud Shell.
