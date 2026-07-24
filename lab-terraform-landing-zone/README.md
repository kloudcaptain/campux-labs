# Terraform on Azure — a landing zone with remote state

**Track:** Infrastructure as Code · **Level:** Intermediate · **Time:** ~40 min · **Cost:** effectively free (a resource group + a tiny storage account)
**Status:** Authored — pending one real end-to-end certification run before publish.
**Full walkthrough (illustrated):** https://azure.campux.co/lab-terraform-landing-zone

> Run everything in **Azure Cloud Shell (Bash)** at https://shell.azure.com — `terraform` and `az` are preinstalled and already signed in to your subscription.

## Scenario

Every cloud-engineer posting names Terraform. This lab gets it onto your résumé honestly: stand up a landing zone, then move its state to a **locked remote backend** in Azure Storage — the detail that separates a laptop demo from a team that ships.

## Résumé line

*"Provisioned Azure infrastructure with Terraform and migrated state to a locked azurerm remote backend, enabling safe concurrent team workflows with state locking."*

## Files

- `main.tf` — the landing zone (a tagged resource group).
- `backend.tf.example` — the remote backend block; rename to `backend.tf` and fill in your storage account.

## Steps

```bash
# 1. init + plan (Terraform's what-if)
cd lab-terraform-landing-zone
terraform init
terraform plan            # -> Plan: 1 to add

# 2. apply, then prove idempotency
terraform apply -auto-approve
terraform plan            # -> No changes. Your infrastructure matches the configuration.

# 3. build a remote backend
RG_TF="campux-lab-tfstate-rg"
SA="campuxtf$RANDOM"
az group create -n "$RG_TF" -l eastus
az storage account create -n "$SA" -g "$RG_TF" -l eastus --sku Standard_LRS --allow-blob-public-access false
az storage container create -n tfstate --account-name "$SA" --auth-mode login
echo "backend storage account: $SA"

# 4. migrate state: put $SA into backend.tf, then
cp backend.tf.example backend.tf
sed -i "s/REPLACE_WITH_YOUR_SA/$SA/" backend.tf
terraform init -migrate-state       # answer 'yes' to copy state up
az storage blob list --container-name tfstate --account-name "$SA" --auth-mode login --query "[].name" -o tsv

# 5. the payoff: state locking (second apply is refused a lease)
terraform plan -lock-timeout=0s & sleep 1; terraform apply -auto-approve -lock-timeout=0s; wait
```

✅ **Checkpoints:** first plan adds 1; second plan reports no changes; the blob `landing-zone.tfstate` exists; the concurrent apply fails with `Error acquiring the state lock`.

## Teardown

```bash
terraform destroy -auto-approve
az group delete -n campux-lab-tfstate-rg --yes
az group exists -n campux-lab-lz-rg      # -> false
```
