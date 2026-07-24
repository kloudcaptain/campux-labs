# Build & govern an MCP server on Azure

**Track:** AI Platform · **Level:** Advanced · **Time:** ~50 min · **Cost:** scale-to-zero (a Container App + registry — pennies while up)
**Status:** Authored — pending one real end-to-end certification run before publish.
**Full walkthrough (illustrated):** https://azure.campux.co/lab-mcp-server-azure

> Run in **Azure Cloud Shell (Bash)** — `az containerapp up` builds the image in the cloud, no local Docker needed. **This lab creates a container + registry, so the teardown is not optional.**

## Scenario

The Model Context Protocol is how an AI assistant reaches into enterprise systems — and "administer and govern MCP integrations" is now written into senior cloud roles. Ship a real MCP server to Azure Container Apps, connect a client, and put an Entra ID gate and a secret-free managed identity in front of it.

## Résumé line

*"Built and deployed a Model Context Protocol server to Azure Container Apps over streamable HTTP, governing it with Microsoft Entra ID built-in auth and a managed identity for secret-free downstream access."*

## Files

- `server.py` — FastMCP server exposing a `get_inventory` tool over streamable HTTP (`/mcp`, port 8080).
- `client.py` — a minimal MCP client that initialises, lists tools, and calls one.
- `Dockerfile`, `requirements.txt` — container build.

## Steps

```bash
# 1. deploy to Container Apps (from this folder)
cd lab-mcp-server-azure
RG="campux-lab-mcp-rg"
az group create -n "$RG" -l eastus
az containerapp up --name campux-mcp --resource-group "$RG" --environment campux-mcp-env \
  --source . --ingress external --target-port 8080
FQDN=$(az containerapp show -n campux-mcp -g "$RG" --query properties.configuration.ingress.fqdn -o tsv)
echo "MCP endpoint: https://$FQDN/mcp"

# 2. prove it works
pip install --quiet mcp
python client.py "https://$FQDN/mcp"     # -> tools: ['get_inventory'] ; result: Stock at Camden - ...

# 3. govern outbound: a managed identity (grant it a scoped role in production)
az containerapp identity assign -n campux-mcp -g "$RG" --system-assigned

# 4. govern inbound: shut the anonymous door
curl -s -o /dev/null -w "before auth: %{http_code}\n" "https://$FQDN/mcp"
APP_ID=$(az ad app create --display-name "campux-mcp-guard" --query appId -o tsv)
TENANT=$(az account show --query tenantId -o tsv)
az containerapp auth microsoft update -n campux-mcp -g "$RG" --client-id "$APP_ID" --issuer "https://sts.windows.net/$TENANT/" --yes
az containerapp auth update -n campux-mcp -g "$RG" --unauthenticated-client-action Return401
curl -s -o /dev/null -w "after auth:  %{http_code}\n" "https://$FQDN/mcp"   # 200 -> 401
```

✅ **Checkpoints:** the client prints the tool list and a real result; the anonymous curl flips from a normal status to `401`.

## Teardown

```bash
az ad app delete --id "$APP_ID"
az group delete -n campux-lab-mcp-rg --yes
```

> Grounded against Microsoft Learn "Host MCP servers on Azure Container Apps" and the MCP Python SDK (streamable HTTP, protocol 2025-03-26).
