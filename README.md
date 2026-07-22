# Campux Labs

Free, hands-on Azure cloud-engineering labs. Each lab is a self-contained folder you can clone and run in **Azure Cloud Shell (Bash)** — real Azure resources, real verification at every step, and a mandatory teardown so you never get a surprise bill.

These labs accompany the [CAMPUX Cloud Engineering Bootcamp](https://campux.example). Do a lab in ~30 minutes; walk away able to say you've *built* it, not just read about it.

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

_More labs are added regularly._

## Safety

- Every lab estimates cost up front and ends with teardown. **Always run teardown.**
- Secrets used in labs are fake demo values. Never put a real secret in a lab.
- Labs create resources in **your** subscription and spend **your** money (usually pennies). You are responsible for tearing them down.

## License

MIT — see [LICENSE](LICENSE). Use these labs freely, including in your own teaching, with attribution.
