// Lab: Resource Locks as code.
//
// Declares a CanNotDelete lock on the resource group this template is deployed into. In production,
// locks live with the infrastructure they protect so a rebuild can never ship an unprotected
// resource. Resource locks are fully ARM-native (Microsoft.Authorization/locks) — no Graph split.
//
// Deploy:
//   az deployment group create -g <rg> --template-file main.bicep
//
// NOTE: once this lock exists, the resource group cannot be deleted until you remove the lock:
//   az lock delete --name campux-prod-donotdelete --resource-group <rg>

@description('Name of the lock.')
param lockName string = 'campux-prod-donotdelete'

resource lock 'Microsoft.Authorization/locks@2020-05-01' = {
  name: lockName
  // No scope property: in a resource-group deployment this locks the resource group itself,
  // protecting every resource inside it.
  properties: {
    level: 'CanNotDelete'
    notes: 'Protect Campux production resources from accidental deletion.'
  }
}

output lockId string = lock.id
