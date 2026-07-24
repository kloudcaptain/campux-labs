# Observability — Log Analytics, App Insights & a KQL alert

**Track:** Observability · **Level:** Intermediate · **Time:** ~35 min · **Cost:** free (within the Log Analytics daily ingestion allowance)
**Status:** Authored — pending one real end-to-end certification run before publish.
**Full walkthrough (illustrated):** https://azure.campux.co/lab-observability-kql

> Run in **Azure Cloud Shell (Bash)**. Uses the subscription Activity log — telemetry you already generate for free.

## Scenario

Anyone can deploy a resource; the job is knowing what it does next. Pool telemetry in a Log Analytics workspace, ask it questions in **KQL**, and turn a query into an alert — the monitoring loop every posting lists.

## Résumé line

*"Built Azure observability with Log Analytics and KQL, streaming the Activity log and configuring a scheduled-query alert with an action group on failure conditions."*

## Steps

```bash
RG="campux-lab-obs-rg"
az group create -n "$RG" -l eastus

# workspace
az monitor log-analytics workspace create -g "$RG" -n campux-logs
WS_ID=$(az monitor log-analytics workspace show -g "$RG" -n campux-logs --query id -o tsv)
WS_GUID=$(az monitor log-analytics workspace show -g "$RG" -n campux-logs --query customerId -o tsv)

# stream the subscription Activity log in
SUB_ID=$(az account show --query id -o tsv)
az monitor diagnostic-settings subscription create --name campux-activity-to-logs --location eastus \
  --subscription "$SUB_ID" --workspace "$WS_ID" \
  --logs '[{"category":"Administrative","enabled":true},{"category":"Alert","enabled":true}]'

# generate a little activity
az group create -n campux-obs-ping -l eastus && az group delete -n campux-obs-ping --yes

# ask a question in KQL (wait a few minutes for data to land)
az monitor log-analytics query -w "$WS_GUID" --analytics-query '
AzureActivity
| where TimeGenerated > ago(1h)
| summarize count() by OperationNameValue, ActivityStatusValue
| sort by count_ desc
' -o table

# turn a query into an alert
az monitor action-group create -g "$RG" -n campux-oncall --short-name cxoncall --email me you@example.com
AG_ID=$(az monitor action-group show -g "$RG" -n campux-oncall --query id -o tsv)
az monitor scheduled-query create -g "$RG" -n campux-failed-ops --scopes "$WS_ID" \
  --condition "count 'placeholder' > 0" \
  --condition-query placeholder='AzureActivity | where ActivityStatusValue == "Failure"' \
  --evaluation-frequency 5m --window-size 5m --severity 2 --action-groups "$AG_ID" \
  --description "A management operation failed"
```

✅ **Checkpoints:** the KQL query returns your own operations; `az monitor scheduled-query show -g "$RG" -n campux-failed-ops --query enabled` is `true`.

## Teardown

```bash
az monitor diagnostic-settings subscription delete --name campux-activity-to-logs --subscription "$SUB_ID" --yes
az group delete -n campux-lab-obs-rg --yes
```
