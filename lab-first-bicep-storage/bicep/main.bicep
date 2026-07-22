// Lab: First Bicep deploy — a storage account as code.
//
// This is a complete, deployable Bicep template. Read it top to bottom: it shows the four things
// every Bicep file is made of — parameters (inputs), variables, resources (what to create), and
// outputs (values to hand back). Deploy it with:
//   az deployment group create -g <rg> --template-file main.bicep

@description('Location for the storage account. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Globally-unique storage account name: 3-24 lowercase letters/digits. The default derives a unique name from the resource group so it is stable per RG.')
param storageAccountName string = 'campux${uniqueString(resourceGroup().id)}'

@description('Redundancy SKU. Try changing this and re-running what-if to see Bicep detect the diff.')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_ZRS'
])
param sku string = 'Standard_LRS'

@description('Tags applied to the storage account.')
param tags object = {
  environment: 'lab'
  project: 'campux-retail'
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: sku
  }
  kind: 'StorageV2'
  tags: tags
  properties: {
    // Secure-by-default settings — the reason to template storage instead of clicking it.
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
  }
}

output storageAccountName string = storage.name
output storageAccountId string = storage.id
output primaryBlobEndpoint string = storage.properties.primaryEndpoints.blob
