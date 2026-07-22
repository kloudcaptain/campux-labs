// Lab B — the infrastructure-as-code piece.
//
// IMPORTANT (same honest split as Lab C): the Entra ID **app registration** is a Microsoft Graph
// object — Bicep cannot create it. You create the app registration + secret with the CLI (see the
// walkthrough), then pass its client id and secret here. What Bicep DOES own is the App Service
// **authentication configuration** (authsettingsV2) that turns on OIDC sign-in using that app
// registration — and that config belongs with your infrastructure.
//
// Deploy (after creating the app registration with the CLI):
//   az deployment group create -g <rg> --template-file main.bicep \
//     --parameters clientId=<appId> clientSecret=<secret>

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Suffix to keep the app name globally unique.')
param suffix string = uniqueString(resourceGroup().id)

@description('Client (application) id of an EXISTING Entra app registration. Create it with the CLI first.')
param clientId string

@secure()
@description('A client secret for that app registration (from `az ad app credential reset`).')
param clientSecret string

var appName = 'campux-portal-${suffix}'
var planName = 'campux-plan-${suffix}'
var secretSettingName = 'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET'

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  kind: 'linux'
  sku: {
    name: 'F1'
    tier: 'Free'
  }
  properties: {
    reserved: true
  }
}

resource app 'Microsoft.Web/sites@2023-12-01' = {
  name: appName
  location: location
  properties: {
    serverFarmId: plan.id
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
    }
  }
}

// Store the client secret as an app setting; authsettingsV2 references it by name (never inline).
resource appSettings 'Microsoft.Web/sites/config@2023-12-01' = {
  parent: app
  name: 'appsettings'
  properties: {
    '${secretSettingName}': clientSecret
  }
}

// The App Service authentication config — turns on OIDC sign-in with the existing app registration.
resource authSettings 'Microsoft.Web/sites/config@2023-12-01' = {
  parent: app
  name: 'authsettingsV2'
  properties: {
    platform: {
      enabled: true
    }
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'RedirectToLoginPage'
      redirectToProvider: 'azureactivedirectory'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: clientId
          clientSecretSettingName: secretSettingName
          openIdIssuer: 'https://sts.windows.net/${subscription().tenantId}/'
        }
        validation: {
          allowedAudiences: [
            'https://${app.properties.defaultHostName}/.auth/login/aad/callback'
          ]
        }
      }
    }
    login: {
      tokenStore: {
        enabled: true
      }
    }
  }
  dependsOn: [
    appSettings // the secret app setting must exist before auth references it
  ]
}

output appName string = app.name
output appUrl string = 'https://${app.properties.defaultHostName}'
output redirectUri string = 'https://${app.properties.defaultHostName}/.auth/login/aad/callback'
