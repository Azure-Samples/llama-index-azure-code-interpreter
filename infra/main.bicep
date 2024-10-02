targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@secure()
param llamaIndexAzureDynamicSessionDefinition object

@description('Id of the user or app to assign application roles')
param principalId string

@description('Whether the deployment is running on GitHub Actions')
param CI string = ''

@description('Public network access value for all deployed resources')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Enabled'

@allowed(['None', 'AzureServices'])
@description('If allowedIp is set, whether azure services are allowed to bypass the storage and AI services firewall.')
param bypass string = 'AzureServices'

param storageContainerName string = 'files'
param storageSkuName string // Set in main.parameters.json

param disableKeyBasedAuth bool = true
param azureOpenAiDeploymentName string // See main.parameters.json
param azureOpenAiApiVersion string // See main.parameters.json 
param azureOpenAiEmbeddingModel string // See main.parameters.json 
param azureOpenAiEmbeddingDim string // See main.parameters.json 
param azureOpenAiDeploymentCapacity int = 30

// Tags that should be applied to all resources.
// 
// Note that 'azd-service-name' tags should be applied separately to service host resources.
// Example usage:
//   tags: union(tags, { 'azd-service-name': <service name in azure.yaml> })
var tags = {
  'azd-env-name': environmentName
}

var SYSTEM_PROMPT = '''
I want you to process the user's input using the code interpreter tool. 
After processing, ensure that the output image is always returned in base64 format and encoded as a PNG file. 
Include the base64 image using the following format: data:image/png;base64,<string>. 
Additionally, upload the PNG file and render the image in the response using 
the following Markdown format: ![Rendered Image](https://<storage name>.blob.core.windows.net/files/<filename>.png). Ensure the base64-encoded image is included as data:image/png;base64,<string>
'''

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var principalType = empty(CI) ? 'User' : 'ServicePrincipal'

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module llamaIndexAzureDynamicSession './app/llamaindex-azure-dynamic-session.bicep' = {
  name: 'aca-app'
  params: {
    name: '${abbrs.appContainerApps}llamaindex-${resourceToken}'
    location: location
    tags: tags
    identityName: '${abbrs.managedIdentityUserAssignedIdentities}llamaindex-${resourceToken}'
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    containerAppsEnvironmentName: appsEnv.outputs.name
    containerRegistryName: registry.outputs.name
    dynamicSessionsName: '${abbrs.managedIdentityUserAssignedIdentities}llamaindex-session-pool-${resourceToken}'
    appDefinition: llamaIndexAzureDynamicSessionDefinition
    azureOpenAiDeploymentName: azureOpenAiDeploymentName
    azureOpenAiApiVersion: azureOpenAiApiVersion
    azureOpenAiEndpoint: azureOpenAi.outputs.endpoint
  }
  scope: rg
}

module monitoring './shared/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    location: location
    tags: tags
    logAnalyticsName: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: '${abbrs.insightsComponents}${resourceToken}'
  }
  scope: rg
}

module dashboard './shared/dashboard-web.bicep' = {
  name: 'dashboard'
  params: {
    name: '${abbrs.portalDashboards}${resourceToken}'
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    location: location
    tags: tags
  }
  scope: rg
}

module registry './shared/registry.bicep' = {
  name: 'registry'
  params: {
    location: location
    tags: tags
    name: '${abbrs.containerRegistryRegistries}${resourceToken}'
  }
  scope: rg
}

module keyVault './shared/keyvault.bicep' = {
  name: 'keyvault'
  params: {
    location: location
    tags: tags
    name: '${abbrs.keyVaultVaults}${resourceToken}'
    principalId: principalId
  }
  scope: rg
}

module appsEnv './shared/apps-env.bicep' = {
  name: 'apps-env'
  params: {
    name: '${abbrs.appManagedEnvironments}${resourceToken}'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
  }
  scope: rg
}

module storage './shared/storage-account.bicep' = {
  name: 'storage'
  params: {
    name: '${abbrs.storageStorageAccounts}${resourceToken}'
    location: location
    tags: tags
    publicNetworkAccess: publicNetworkAccess
    bypass: bypass
    allowBlobPublicAccess: true
    allowSharedKeyAccess: false
    sku: {
      name: storageSkuName
    }
    deleteRetentionPolicy: {
      enabled: true
      days: 2
    }
    containers: [
      {
        name: storageContainerName
        publicAccess: 'Blob'
      }
    ]
  }
  scope: rg
}

module azureOpenAi 'shared/cognitive-services.bicep' = {
  name: 'openai'
  params: {
    name: '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    tags: tags
    disableLocalAuth: disableKeyBasedAuth
    sku: {
      name: 'S0'
    }
    deployments: [
      {
        name: azureOpenAiDeploymentName
        model: {
          format: 'OpenAI'
          name: azureOpenAiDeploymentName
          version: azureOpenAiApiVersion
        }
        sku: {
          name: 'GlobalStandard'
          capacity: azureOpenAiDeploymentCapacity
        }
      }
    ]
  }
  scope: rg
}

module openAiRoleUser 'shared/security-role.bicep' = {
  name: 'openai-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
    principalType: principalType
  }
  scope: rg
}

module openAiRoleBackend 'shared/security-role.bicep' = {
  name: 'openai-role-backend'
  params: {
    principalId: llamaIndexAzureDynamicSession.outputs.principalId
    roleDefinitionId: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
    principalType: 'ServicePrincipal'
  }
  scope: rg
}

module acaSessionExecutorRoleUser 'shared/security-role.bicep' = {
  name: 'aca-session-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '0fb8eba5-a2bb-4abe-b1c1-49dfad359bb0'
    principalType: principalType
  }
  scope: rg
}

module acaSessionExecutorRoleBackend 'shared/security-role.bicep' = {
  name: 'aca-session-role-backend'
  params: {
    principalId: llamaIndexAzureDynamicSession.outputs.principalId
    roleDefinitionId: '0fb8eba5-a2bb-4abe-b1c1-49dfad359bb0'
    principalType: 'ServicePrincipal'
  }
  scope: rg
}

module storageRoleUser 'shared/security-role.bicep' = {
  name: 'storage-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
    principalType: principalType
  }
  scope: rg
}

module storageContribRoleUser 'shared/security-role.bicep' = {
  name: 'storage-contrib-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
    principalType: principalType
  }
  scope: rg
}

module storageRoleBackend 'shared/security-role.bicep' = {
  name: 'storage-role-backend'
  params: {
    principalId: llamaIndexAzureDynamicSession.outputs.principalId
    roleDefinitionId: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
    principalType: 'ServicePrincipal'
  }
  scope: rg
}

output AZURE_STORAGE_ACCOUNT string = storage.outputs.name
output AZURE_STORAGE_CONTAINER string = storageContainerName
output AZURE_STORAGE_RESOURCE_GROUP string = rg.name
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = llamaIndexAzureDynamicSession.outputs.registryLoginServer
output AZURE_CONTAINER_REGISTRY_NAME string = llamaIndexAzureDynamicSession.outputs.registryName
output AZURE_POOL_MANAGEMENT_ENDPOINT string = llamaIndexAzureDynamicSession.outputs.poolManagementEndpoint
output AZURE_OPENAI_ENDPOINT string = azureOpenAi.outputs.endpoint
output OPENAI_API_VERSION string = azureOpenAiApiVersion
output AZURE_DEPLOYMENT_NAME string = azureOpenAiDeploymentName
output EMBEDDING_MODEL string = azureOpenAiEmbeddingModel
output EMBEDDING_DIM string = azureOpenAiEmbeddingDim
output SYSTEM_PROMPT string = SYSTEM_PROMPT
