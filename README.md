# Campux Labs

Free, hands-on Azure cloud-engineering labs. Each lab is a self-contained folder you can clone and run in **Azure Cloud Shell (Bash)** — real Azure resources, real verification at every step, and a mandatory teardown so you never get a surprise bill.

These labs accompany the [CAMPUX Cloud Engineering Bootcamp](https://azure.campux.co). Do a lab in ~30 minutes; walk away able to say you've *built* it, not just read about it.

## How to use a lab

1. Open [Azure Cloud Shell](https://shell.azure.com) and choose **Bash**.
2. Clone this repo:
   ```bash
   git clone https://github.com/kloudcaptain/campux-labs.git
   cd campux-labs
   ```
3. Open the lab folder's `README.md` and follow it top to bottom.
4. **Run the teardown at the end** — every lab has one. It leaves your subscription at zero.

Each lab ships **two ways to build the same thing**:

- **`README.md` — the CLI walkthrough.** Step-by-step Azure CLI, with a ✅ verification checkpoint after every stage. Best for *learning* — you see each resource appear and prove it works before moving on.
- **`bicep/` — infra-as-code.** The same infrastructure as a Bicep template you deploy in one command. Best for *understanding the professional pattern*: declarative, repeatable, reviewable.

Do the CLI path first to learn it, then deploy the Bicep to see the whole thing described as code.

## Prerequisites (all labs)

- An Azure subscription. A [free account](https://azure.microsoft.com/free) works.
- **Permission to assign roles** on the subscription (**Owner** or **User Access Administrator**). A plain *Contributor* cannot create the role assignments these labs use.
- Azure Cloud Shell (Bash) — no local install needed; `az`, `bicep`, `zip`, `curl`, and `git` are all preinstalled and current.

## Labs

| Lab | What you build | Level | Cost |
| --- | --- | --- | --- |
| [lab-a-rbac-managed-identity](lab-a-rbac-managed-identity/) | An App Service that reads a Key Vault secret using a managed identity + least-privilege RBAC — zero credentials in code | Intermediate | ~free (F1) |
| [lab-b-app-registration-oidc-sso](lab-b-app-registration-oidc-sso/) | Register an app in Microsoft Entra ID and wire OpenID Connect single sign-on for an App Service with zero auth code | Intermediate | ~free (F1) |
| [lab-c-rbac-security-groups](lab-c-rbac-security-groups/) | Manage Key Vault access at scale by assigning a role to an Entra security group and controlling access through membership | Intermediate | ~free |
| [lab-d-azure-policy-as-code](lab-d-azure-policy-as-code/) | Author a custom Azure Policy that denies public-blob storage, prove it blocks bad resources, and deploy it as code with Bicep | Advanced | ~free |
| [lab-first-bicep-storage](lab-first-bicep-storage/) | Your first Bicep deploy: create a storage account as code, preview with what-if, and see idempotency in action | Beginner | ~free |
| [lab-resource-locks](lab-resource-locks/) | Protect resources from accidental deletion with a CanNotDelete lock, prove it blocks a real delete, and deploy the lock as code | Beginner–Intermediate | ~free |
| [lab-terraform-landing-zone](lab-terraform-landing-zone/) | Provision a landing zone with Terraform, then migrate state to a locked remote backend in Azure Storage — with a state-lock proof | Intermediate | ~free |
| [lab-github-actions-oidc](lab-github-actions-oidc/) | Federate GitHub Actions to Entra ID with OIDC and deploy to Azure with zero stored secrets — a scoped role and a 0-credential app | Intermediate | ~free |
| [lab-hub-spoke-networking](lab-hub-spoke-networking/) | Build a hub-and-spoke network with VNet peering and NSGs that enforce least-privilege segmentation — proven from the routing, no VMs | Intermediate | free |
| [lab-observability-kql](lab-observability-kql/) | Stream the Activity log to a Log Analytics workspace, query it in KQL, and fire a scheduled-query alert through an action group | Intermediate | ~free |
| [lab-container-apps-acr](lab-container-apps-acr/) | Run a container on Azure Container Apps, pulling from ACR with a managed identity (no admin creds) and scaling to zero | Intermediate | ~free |
| [lab-mcp-server-azure](lab-mcp-server-azure/) | Build and govern an MCP server on Container Apps — streamable HTTP, Entra ID built-in auth, and a managed identity | Advanced | ~free |
| [lab-rag-azure-ai-search](lab-rag-azure-ai-search/) | Build grounded RAG on Azure AI Search with Azure OpenAI embeddings — cited answers, and a refusal when the answer isn't in the data | Advanced | ~free |
| [lab-cost-guardrails](lab-cost-guardrails/) | Set a Cost Management budget with alerts, read Advisor recommendations, and apply a storage lifecycle policy that tiers and expires blobs | Beginner | free |

_More labs are added regularly._

## Safety

- Every lab estimates cost up front and ends with teardown. **Always run teardown.**
- Secrets used in labs are fake demo values. Never put a real secret in a lab.
- Labs create resources in **your** subscription and spend **your** money (usually pennies). You are responsible for tearing them down.

## License

MIT — see [LICENSE](LICENSE). Use these labs freely, including in your own teaching, with attribution.
