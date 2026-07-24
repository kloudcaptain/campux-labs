# Cost guardrails — budgets, Advisor & a storage lifecycle policy

**Track:** Cost / FinOps · **Level:** Beginner · **Time:** ~30 min · **Cost:** free (guardrails are governance features; the empty storage account is free)
**Status:** Authored — pending one real end-to-end certification run before publish.
**Full walkthrough (illustrated):** https://azure.campux.co/lab-cost-guardrails

> Run in **Azure Cloud Shell (Bash)**. Put your own email in the budget notification.

## Scenario

"Drive cost optimization" is in every senior cloud job, and it is not a spreadsheet — it is controls you put in the platform. Set a budget that emails you before spend runs away, read what Advisor says you are wasting, and make storage tier and expire itself.

## Résumé line

*"Implemented Azure cost guardrails: a Cost Management budget with threshold alerts, Advisor-driven right-sizing, and a storage lifecycle policy that tiers and expires data automatically."*

## Files

- `policy.json` — the storage lifecycle policy (cool at 30 days, delete at 365).

## Steps

```bash
RG="campux-lab-cost-rg"
az group create -n "$RG" -l eastus

# 1. a monthly budget scoped to the group, alerting at 80% of actual spend
START=$(date -u +%Y-%m-01)
az consumption budget create-with-rg --budget-name campux-monthly --resource-group "$RG" \
  --amount 50 --category Cost --time-grain Monthly \
  --time-period "{\"start-date\":\"$START\",\"end-date\":\"2027-12-31\"}" \
  --notifications "{\"actual-80\":{\"enabled\":true,\"operator\":\"GreaterThanOrEqualTo\",\"threshold\":80.0,\"contact-emails\":[\"you@example.com\"]}}"

# 2. what is Advisor telling you to right-size? (may be empty on a fresh sub)
az advisor recommendation list --category Cost --query "[].{impact:impact,problem:shortDescription.problem}" -o table

# 3. make storage tier + expire itself
SA="campuxcost$RANDOM"
az storage account create -n "$SA" -g "$RG" -l eastus --sku Standard_LRS
az storage account management-policy create --account-name "$SA" -g "$RG" --policy @policy.json
az storage account management-policy show --account-name "$SA" -g "$RG" --query "policy.rules[0].definition.actions.baseBlob" -o json
```

✅ **Checkpoints:** the budget create returns JSON with `amount: 50` and your 80% notification; the lifecycle policy shows `tierToCool` @30 and `delete` @365.

## Teardown

```bash
az consumption budget delete-with-rg --budget-name campux-monthly -g "$RG"
az group delete -n campux-lab-cost-rg --yes
```

> **Note:** budgets *alert*, they do not *cap* — Azure does not hard-stop spending. Automatic enforcement needs the alert wired to an action group; the email is the sane default.
