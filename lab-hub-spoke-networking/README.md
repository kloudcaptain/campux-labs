# Hub-and-spoke networking & segmentation

**Track:** Networking · **Level:** Intermediate · **Time:** ~35 min · **Cost:** free (no VMs — VNets, peerings, and NSGs carry no hourly charge)
**Status:** Authored — pending one real end-to-end certification run before publish.
**Full walkthrough (illustrated):** https://azure.campux.co/lab-hub-spoke-networking

> Run in **Azure Cloud Shell (Bash)**. This lab deliberately uses **no virtual machines**, so it is genuinely free while it runs.

## Scenario

A flat network trusts everything once; when one workload is compromised the blast spreads to all of them. The enterprise answer is hub-and-spoke: a shared hub, each workload in its own spoke, peered to the hub but not to its siblings. This lab builds that shape and **proves the isolation from the routing itself**.

## Résumé line

*"Designed a hub-and-spoke Azure network with VNet peering and NSGs enforcing least-privilege segmentation between workloads, verified via non-transitive peering."*

## Steps

```bash
RG="campux-lab-net-rg"
az group create -n "$RG" -l eastus

# hub + two spokes with non-overlapping address spaces
az network vnet create -g "$RG" -n hub-vnet    --address-prefix 10.0.0.0/16 --subnet-name shared   --subnet-prefix 10.0.1.0/24
az network vnet create -g "$RG" -n spoke1-vnet --address-prefix 10.1.0.0/16 --subnet-name workload --subnet-prefix 10.1.1.0/24
az network vnet create -g "$RG" -n spoke2-vnet --address-prefix 10.2.0.0/16 --subnet-name workload --subnet-prefix 10.2.1.0/24

# peer each spoke to the hub (both directions)
for S in spoke1 spoke2; do
  az network vnet peering create -g "$RG" -n "${S}-to-hub" --vnet-name "${S}-vnet" --remote-vnet hub-vnet --allow-vnet-access
  az network vnet peering create -g "$RG" -n "hub-to-${S}" --vnet-name hub-vnet --remote-vnet "${S}-vnet" --allow-vnet-access
done
az network vnet peering list -g "$RG" --vnet-name hub-vnet --query "[].{name:name,state:peeringState}" -o table

# prove isolation: spoke1 peers ONLY with the hub (non-transitive)
az network vnet peering list -g "$RG" --vnet-name spoke1-vnet --query "[].{name:name,remote:remoteVirtualNetwork.id}" -o table

# make the intent explicit with an NSG on spoke1
az network nsg create -g "$RG" -n spoke1-nsg
az network nsg rule create -g "$RG" --nsg-name spoke1-nsg -n allow-hub   --priority 100 --direction Inbound --access Allow --protocol '*' --source-address-prefixes 10.0.0.0/16 --destination-address-prefixes '*' --destination-port-ranges '*'
az network nsg rule create -g "$RG" --nsg-name spoke1-nsg -n deny-spoke2 --priority 200 --direction Inbound --access Deny  --protocol '*' --source-address-prefixes 10.2.0.0/16 --destination-address-prefixes '*' --destination-port-ranges '*'
az network vnet subnet update -g "$RG" --vnet-name spoke1-vnet -n workload --network-security-group spoke1-nsg
```

✅ **Checkpoints:** hub peerings report `Connected`; spoke1's only peering remote is `hub-vnet` (never `spoke2-vnet`); the NSG lists allow-hub@100 and deny-spoke2@200.

## Teardown

```bash
az group delete -n campux-lab-net-rg --yes
az group exists -n campux-lab-net-rg      # -> false
```
