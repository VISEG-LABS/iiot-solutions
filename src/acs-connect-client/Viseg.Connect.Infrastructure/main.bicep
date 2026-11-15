targetScope = 'resourceGroup'

@description('Lowercase letters/digits only; a deterministic suffix makes resource names unique.')
@minLength(3)
@maxLength(12)
param namePrefix string = 'visegconnect'

param location string = resourceGroup().location

@description('Microsoft Entra Object ID of an existing SQL administrator security group in the resource tenant. Copy it from Entra ID > Groups > group > Overview; do not use an application/client, tenant, or user ID.')
param sqlAdministratorObjectId string

param sqlAdministratorDisplayName string = 'CONNECT sandbox SQL administrators'

@allowed(['B1', 'B2'])
param appServiceSku string = 'B1'

@description('Application setting only; synthetic-data handling is implemented by the application in later work packages.')
param useSyntheticData bool = true

@description('Optional resource-tenant administrator IPv4 address for SQL bootstrap; leave blank to omit the firewall rule.')
param sqlBootstrapIp string = ''

@minValue(1)
@maxValue(10)
param logDailyCapGb int = 1

var suffix = uniqueString(resourceGroup().id)
var baseName = '${namePrefix}-${suffix}'
var tags = {
  application: 'viseg-connect'
  environment: 'sandbox'
  managedBy: 'bicep'
}

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${baseName}-plan'
  location: location
  tags: tags
  kind: 'linux'
  sku: {
    name: appServiceSku
    tier: 'Basic'
    capacity: 1
  }
  properties: {
    reserved: true
  }
}

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${baseName}-logs'
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
    workspaceCapping: { dailyQuotaGb: logDailyCapGb }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource insights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${baseName}-insights'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspace.id
    DisableLocalAuth: true
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: toLower(take('${namePrefix}${suffix}', 24))
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: { name: 'Standard_LRS' }
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
  properties: {}
}

resource keyContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'data-protection'
  properties: { publicAccess: 'None' }
}

resource vault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'kv-${suffix}'
  location: location
  tags: tags
  properties: {
    tenantId: tenant().tenantId
    sku: { family: 'A', name: 'standard' }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: true
    accessPolicies: []
  }
}

resource protectionKey 'Microsoft.KeyVault/vaults/keys@2023-07-01' = {
  parent: vault
  name: 'data-protection'
  properties: {
    kty: 'RSA'
    keySize: 2048
    keyOps: ['wrapKey', 'unwrapKey']
    attributes: { enabled: true }
  }
}

resource sql 'Microsoft.Sql/servers@2023-08-01' = {
  name: '${baseName}-sql'
  location: location
  tags: tags
  properties: {
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    administrators: {
      administratorType: 'ActiveDirectory'
      principalType: 'Group'
      login: sqlAdministratorDisplayName
      sid: sqlAdministratorObjectId
      tenantId: tenant().tenantId
      azureADOnlyAuthentication: true
    }
  }
}

resource database 'Microsoft.Sql/servers/databases@2023-08-01' = {
  parent: sql
  name: 'connect'
  location: location
  tags: tags
  sku: { name: 'Basic', tier: 'Basic', capacity: 5 }
  properties: {
    maxSizeBytes: 2147483648
    requestedBackupStorageRedundancy: 'Local'
  }
}

// Demo-only network baseline. Authentication remains Entra-only. Replace with
// explicit App Service outbound-IP rules/private networking before production.
resource azureSqlFirewall 'Microsoft.Sql/servers/firewallRules@2023-08-01' = {
  parent: sql
  name: 'AllowAzureServices-SandboxOnly'
  properties: { startIpAddress: '0.0.0.0', endIpAddress: '0.0.0.0' }
}

resource bootstrapSqlFirewall 'Microsoft.Sql/servers/firewallRules@2023-08-01' = if (!empty(sqlBootstrapIp)) {
  parent: sql
  name: 'BootstrapAdministrator'
  properties: { startIpAddress: sqlBootstrapIp, endIpAddress: sqlBootstrapIp }
}

resource app 'Microsoft.Web/sites@2023-12-01' = {
  name: '${baseName}-web'
  location: location
  tags: tags
  kind: 'app,linux'
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    clientAffinityEnabled: true
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|10.0'
      alwaysOn: true
      webSocketsEnabled: true
      http20Enabled: true
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appSettings: [
        { name: 'ASPNETCORE_ENVIRONMENT', value: 'Sandbox' }
        { name: 'Access__RequireAllowlist', value: 'true' }
        { name: 'Demo__UseSyntheticData', value: string(useSyntheticData) }
        { name: 'Secrets__VaultUri', value: vault.properties.vaultUri }
        { name: 'DataProtection__BlobUri', value: '${storage.properties.primaryEndpoints.blob}${keyContainer.name}/keys.xml' }
        { name: 'DataProtection__KeyIdentifier', value: '${vault.properties.vaultUri}keys/${protectionKey.name}' }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: insights.properties.ConnectionString }
        { name: 'APPLICATIONINSIGHTS_AUTHENTICATION_STRING', value: 'Authorization=AAD' }
        { name: 'Telemetry__SamplingRatio', value: '0.1' }
        { name: 'Telemetry__TraceBasedLogSampling', value: 'false' }
        { name: 'Refresh__MinimumSeconds', value: '30' }
        { name: 'Dashboards__MaxWidgets', value: '20' }
        { name: 'ConnectionStrings__AppDatabase', value: 'Server=tcp:${sql.properties.fullyQualifiedDomainName},1433;Database=${database.name};Authentication=Active Directory Managed Identity;Encrypt=True;TrustServerCertificate=False' }
      ]
    }
  }
}

resource secretAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vault.id, app.id, 'secrets-officer')
  scope: vault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')
    principalId: app.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource keyAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(protectionKey.id, app.id, 'crypto-encryption-user')
  scope: protectionKey
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'e147488a-f6f5-4113-8e2d-b22465e65bf6')
    principalId: app.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource blobAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyContainer.id, app.id, 'blob-contributor')
  scope: keyContainer
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: app.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource telemetryAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(insights.id, app.id, 'monitor-publisher')
  scope: insights
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '3913510d-42f4-4e42-8a64-420c390055eb')
    principalId: app.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output appName string = app.name
output appUrl string = 'https://${app.properties.defaultHostName}'
output appPrincipalId string = app.identity.principalId
output sqlServerHost string = sql.properties.fullyQualifiedDomainName
output databaseName string = database.name
output vaultUri string = vault.properties.vaultUri
output logWorkspaceName string = workspace.name
