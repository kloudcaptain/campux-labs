// Lab C — the infrastructure-as-code piece.
//
// IMPORTANT: Entra security groups, users, and memberships are NOT ARM resources — they live in
// Microsoft Graph. Bicep cannot create them. (Teams manage those with the Terraform `azuread`
// provider or Graph directly.) So this template does NOT create the group.
//
// What Bicep DOES own — and what belongs alongside your infrastructure — is the role assignment
// that grants an EXISTING group access to a vault. You create the group with the CLI (see the
// walkthrough), then pass its object id here.
//
// Deploy:
//   GROUP_ID=$(az ad group show --group "Campux-KeyVault-Readers" --query id -o tsv)
//   az deployment group create -g <rg> --template-file main.bicep --parameters groupObjectId=$GROUP_ID

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Suffix to keep the vault name globally unique.')
param suffix string = uniqueString(resourceGroup().id)

@description('Object id of an EXISTING Entra security group to grant read access. Create the group first with the CLI.')
param groupObjectId string

@description('Secret name to store.')
param secretName string = 'ProductDbConnection'

@secure()
@description('Fake demo connection string. Never put a real secret here.')
param dbConnectionValue string = 'Server=tcp:campux-sql.database.windows.net,1433;Database=products;Authentication=Active Directory Default;'

var kvName = 'campux-kv-${suffix}'
// Key Vault Secrets User — read secret contents only (least privilege).
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

// Grant the EXISTING group least privilege on this vault. Access for individuals is then managed
// entirely by adding/removing them from the group — no changes to this assignment.
resource groupSecretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kv.id, groupObjectId, secretsUserRoleId)
  scope: kv
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', secretsUserRoleId)
    principalId: groupObjectId
    principalType: 'Group'
  }
}

output vaultName string = kv.name
