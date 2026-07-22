// Lab A — RBAC & Managed Identity, as infrastructure-as-code.
//
// This deploys the SAME thing the CLI walkthrough builds by hand:
//   - a Key Vault in RBAC mode, holding one secret
//   - an App Service (F1 Free, Linux, Node) with a system-assigned managed identity
//   - a least-privilege role assignment (Key Vault Secrets User) on that identity, scoped to the vault
//   - an app setting that is a Key Vault reference
//
// Deploy:   az deployment group create -g <rg> --template-file main.bicep
// Then deploy the app code (../app) and restart — see bicep/README.md.
//
// Note vs. the CLI path: creating the secret here goes through the Key Vault CONTROL plane
// (an ARM resource), so the deployer needs Contributor/Owner — NOT the data-plane
// "Key Vault Secrets Officer" role the CLI path required. Different door, same result.

@description('Location for all resources. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Suffix that keeps globally-unique names unique. Leave default for a deterministic value per resource group.')
param suffix string = uniqueString(resourceGroup().id)

@description('Name of the secret stored in Key Vault.')
param secretName string = 'ProductDbConnection'

@secure()
@description('Fake demo connection string. Never put a real secret here.')
param dbConnectionValue string = 'Server=tcp:campux-sql.database.windows.net,1433;Database=products;Authentication=Active Directory Default;'

var kvName = 'campux-kv-${suffix}'
var appName = 'campux-api-${suffix}'
var planName = 'campux-plan-${suffix}'

// Key Vault Secrets User — read secret contents only (least privilege for this app).
var secretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: kvName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
  }
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: secretName
  properties: {
    value: dbConnectionValue
  }
}

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  kind: 'linux'
  sku: {
    name: 'F1'
    tier: 'Free'
  }
  properties: {
    reserved: true // required for Linux plans
  }
}

resource app 'Microsoft.Web/sites@2023-12-01' = {
  name: appName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      appSettings: [
        {
          // Key Vault reference. App Service resolves this with the managed identity
          // (once the role assignment below has propagated) before the app code runs.
          name: 'DB_CONNECTION'
          value: '@Microsoft.KeyVault(SecretUri=${kv.properties.vaultUri}secrets/${secretName})'
        }
      ]
    }
  }
}

// Grant the app's managed identity least privilege on THIS vault only.
resource secretsUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kv.id, app.id, secretsUserRoleId)
  scope: kv
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', secretsUserRoleId)
    principalId: app.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output appUrl string = 'https://${app.properties.defaultHostName}'
output vaultName string = kv.name
output appName string = app.name
