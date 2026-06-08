targetScope = 'resourceGroup'

@description('Azure region for the Foundry resource and project.')
param location string = 'eastus'

@description('Name of the Azure AI Services / Foundry account. Must be globally unique enough for custom subdomain use.')
param foundryAccountName string = 'wave-app-foundry-${uniqueString(resourceGroup().id)}'

@description('Name of the Foundry project.')
param projectName string = 'wave-app-project'

@description('Policy assignment resource ID for the Azure Policy that blocks API-key/local-auth based Cognitive Services accounts.')
@minLength(1)
param apiKeyAuthPolicyAssignmentId string

@description('Policy definition reference ID inside the assigned initiative for the Cognitive Services local-auth policy.')
param apiKeyAuthPolicyDefinitionReferenceId string = 'CognitiveServicesDisableLocalAuth'

@description('Expiration timestamp for the API-key auth policy exemption, in ISO 8601 format.')
param apiKeyAuthPolicyExemptionExpiresOn string = '2027-06-08T00:00:00Z'

@description('Deployment owner or ticket identifier to place in policy exemption metadata.')
param policyExemptionRequestedBy string = 'wave-app'

@description('Foundry model deployments to create in eastus. These defaults match the current eastus catalog/quota checked for Wave AI Mode.')
param modelDeployments array = [
  {
    deploymentName: 'gpt-5-4-mini'
    format: 'OpenAI'
    modelName: 'gpt-5.4-mini'
    version: '2026-03-17'
    skuName: 'GlobalStandard'
    capacity: 1
  }
  {
    deploymentName: 'gpt-5-4'
    format: 'OpenAI'
    modelName: 'gpt-5.4'
    version: '2026-03-05'
    skuName: 'GlobalStandard'
    capacity: 1
  }
  {
    deploymentName: 'gpt-5-4-nano'
    format: 'OpenAI'
    modelName: 'gpt-5.4-nano'
    version: '2026-03-17'
    skuName: 'GlobalStandard'
    capacity: 1
  }
]

resource apiKeyAuthPolicyExemption 'Microsoft.Authorization/policyExemptions@2024-12-01-preview' = {
  name: 'wave-app-api-key-auth'
  scope: resourceGroup()
  properties: {
    displayName: 'Wave app API-key auth exemption'
    description: 'Allows Wave to use Azure AI Services API-key auth for local desktop transcription and AI Mode.'
    exemptionCategory: 'Waiver'
    expiresOn: apiKeyAuthPolicyExemptionExpiresOn
    policyAssignmentId: apiKeyAuthPolicyAssignmentId
    policyDefinitionReferenceIds: [
      apiKeyAuthPolicyDefinitionReferenceId
    ]
    metadata: {
      requestedBy: policyExemptionRequestedBy
      projectName: projectName
      foundryAccountName: foundryAccountName
    }
  }
}

resource foundryAccount 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: foundryAccountName
  location: location
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    allowProjectManagement: true
    customSubDomainName: foundryAccountName
    disableLocalAuth: false
    publicNetworkAccess: 'Enabled'
  }
  dependsOn: [
    apiKeyAuthPolicyExemption
  ]
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  parent: foundryAccount
  name: projectName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    description: 'Wave app Foundry project'
    displayName: projectName
  }
}

@batchSize(1)
resource deployments 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = [for deployment in modelDeployments: {
  parent: foundryAccount
  name: deployment.deploymentName
  sku: {
    name: deployment.skuName
    capacity: deployment.capacity
  }
  properties: {
    model: {
      format: deployment.format
      name: deployment.modelName
      version: deployment.version
    }
  }
}]

output foundryAccountName string = foundryAccount.name
output projectName string = project.name
output location string = foundryAccount.location
output cognitiveServicesEndpoint string = foundryAccount.properties.endpoint
output foundryProjectEndpoint string = project.properties.endpoints['AI Foundry API']
output openAIEndpoint string = foundryAccount.properties.endpoints['Azure OpenAI Legacy API - Latest moniker']
output servicesAIEndpoint string = foundryAccount.properties.endpoints['Azure AI Model Inference API']
output deployedModelNames array = [for deployment in modelDeployments: deployment.deploymentName]
