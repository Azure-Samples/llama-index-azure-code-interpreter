targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

param llamaIndexAzureDynamicSessionExists bool
@secure()
param llamaIndexAzureDynamicSessionDefinition object

@description('Id of the user or app to assign application roles')
param principalId string

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

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
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

module llamaIndexAzureDynamicSession './app/llama-index-azure-dynamic-session.bicep' = {
  name: 'llama-index-azure-dynamic-session'
  params: {
    name: '${abbrs.appContainerApps}llama-index-${resourceToken}'
    location: location
    tags: tags
    identityName: '${abbrs.managedIdentityUserAssignedIdentities}llama-index-${resourceToken}'
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    containerAppsEnvironmentName: appsEnv.outputs.name
    containerRegistryName: registry.outputs.name
    exists: llamaIndexAzureDynamicSessionExists
    appDefinition: llamaIndexAzureDynamicSessionDefinition
    azureOpenAiDeploymentName: azureOpenAiDeploymentName
    azureOpenAiApiVersion: azureOpenAiApiVersion
    azureOpenAiEndpoint: azureOpenAi.outputs.endpoint
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
    principalType: 'User'
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

output AZURE_POOL_MANAGEMENT_ENDPOINT string = llamaIndexAzureDynamicSession.outputs.uri
output AZURE_OPENAI_ENDPOINT string = azureOpenAi.outputs.endpoint
output OPENAI_API_VERSION string = azureOpenAiApiVersion
output AZURE_DEPLOYMENT_NAME string = azureOpenAiDeploymentName
output EMBEDDING_MODEL string = azureOpenAiEmbeddingModel
output EMBEDDING_DIM string = azureOpenAiEmbeddingDim
