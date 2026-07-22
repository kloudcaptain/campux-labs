// Lab D — policy as code.
//
// Unlike Labs B and C, there is NO Graph/ARM split here: Azure Policy is fully ARM-native, so both
// the policy definition and the assignment are declared as Bicep.
//
// Scope note: policy DEFINITIONS live at subscription (or management group) level — they cannot be
// deployed into a resource group. So this template targets the subscription. The ASSIGNMENT here is
// also at subscription scope for simplicity; in production you'd often scope the assignment to a
// management group or a specific resource group instead.
//
// Deploy (subscription-scoped deployment needs a location for its metadata):
//   az deployment sub create --location eastus --template-file main.bicep
//
// WARNING: while assigned, this denies creation of ANY public-blob storage account in the whole
// subscription. That's a legitimate guardrail, but tear it down after the lab (see below).

targetScope = 'subscription'

@description('Name for the custom policy definition and assignment.')
param policyName string = 'campux-deny-public-blob'

resource definition 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: policyName
  properties: {
    policyType: 'Custom'
    mode: 'Indexed'
    displayName: 'Campux: deny storage accounts with public blob access'
    description: 'Denies creation of storage accounts that allow public blob access.'
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Storage/storageAccounts'
          }
          {
            field: 'Microsoft.Storage/storageAccounts/allowBlobPublicAccess'
            equals: 'true'
          }
        ]
      }
      then: {
        effect: 'deny'
      }
    }
  }
}

resource assignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: policyName
  properties: {
    displayName: 'Campux: deny public blob storage (as code)'
    policyDefinitionId: definition.id
    enforcementMode: 'Default'
  }
}

output definitionId string = definition.id
output assignmentName string = assignment.name
