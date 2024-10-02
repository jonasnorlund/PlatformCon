
param location string = resourceGroup().location
param utcValue string = utcNow()
param name string = substring(uniqueString(resourceGroup().id), 0, 5)
param version string = '1.0'
param deploy bool = false


var azureServiceBusDataReceiverRoleId = '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'


resource loganalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'la-${name}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource userAssignedManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: 'umi-${name}'
  location: location
}

resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: 'cae-${name}'
  location: location
  properties: {
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: loganalyticsWorkspace.properties.customerId
        sharedKey: listKeys(loganalyticsWorkspace.id, '2015-03-20').primarySharedKey
      }
    }
  }
}

resource azureContainerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: 'acr${name}'
  location: location
  sku: {
    name: 'Basic'
  }
}

resource rbacAzureContainerRegistry 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: azureContainerRegistry
  name: guid(userAssignedManagedIdentity.id, acrPullRoleId, name)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
    principalId: userAssignedManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2021-06-01-preview' = {
  name: 'ns-${name}'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
}

resource serviceBusQueue 'Microsoft.ServiceBus/namespaces/queues@2021-06-01-preview' = {
  name: 'messages'
  parent: serviceBusNamespace
}

resource rbacServiceBus 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: serviceBusQueue
  name: guid(userAssignedManagedIdentity.id, azureServiceBusDataReceiverRoleId, name)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureServiceBusDataReceiverRoleId)
    principalId: userAssignedManagedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource aca_superman 'Microsoft.App/containerApps@2024-03-01' = if (deploy) {
  name: 'superman'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedManagedIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppEnvironment.id

    configuration: {
      activeRevisionsMode: 'single'

      ingress: {
        external: true
        targetPort: 8080
        allowInsecure: true
        transport: 'auto'
      }
      registries: [
        {
          identity: userAssignedManagedIdentity.id
          server: azureContainerRegistry.properties.loginServer
        }
      ]
      dapr: {
        enabled: true
        appId: 'superman'
        appProtocol: 'http'
        appPort: 8080
        logLevel: 'debug'
      }
    }
    template: {
      containers: [
        {
          image: '${azureContainerRegistry.properties.loginServer}/platformcon/acaapi:${version}'
          name: 'superman'
          env: [
            {
              name: 'id'
              value: utcValue
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 100
      }
    }
  }
}

resource aca_catwomen 'Microsoft.App/containerApps@2024-03-01' = if (deploy) {
  name: 'catwomen'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedManagedIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppEnvironment.id

    configuration: {
      activeRevisionsMode: 'single'

      ingress: {
        external: true
        targetPort: 8080
        allowInsecure: true
        transport: 'auto'
      }
      registries: [
        {
          identity: userAssignedManagedIdentity.id
          server: azureContainerRegistry.properties.loginServer
        }
      ]
      dapr: {
        enabled: true
        appId: 'catwomen'
        appProtocol: 'http'
        appPort: 8080
        logLevel: 'debug'
      }
    }
    template: {
      containers: [
        {
          image: '${azureContainerRegistry.properties.loginServer}/platformcon/acaapi:${version}'
          name: 'catwomen'
          env: [
            {
              name: 'id'
              value: utcValue
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
      }
    }
  }
}

var serviceBusEndpoint = '${serviceBusNamespace.id}/AuthorizationRules/RootManageSharedAccessKey'

resource daprServicebus 'Microsoft.App/managedEnvironments/daprComponents@2023-05-01' = if (deploy) {
  name: 'servicebus'
  parent: containerAppEnvironment
  properties: {
    componentType: 'pubsub.azure.servicebus.queues'
    version: 'v1'
    initTimeout: '5s'
    ignoreErrors: false
    metadata: [
      {
        name: 'connectionString'
        value: listKeys(serviceBusEndpoint, '2021-06-01-preview').primaryConnectionString  
      }
    ]
    scopes: [
      'catwomen'
    ]
  }
}


resource daprSubscription 'Microsoft.App/managedEnvironments/daprSubscriptions@2024-02-02-preview' =  if (deploy) {
  name: 'sbsubscription'
  parent: containerAppEnvironment
  properties: {
    pubsubName: 'servicebus'
    topic: 'messages'
    routes: {
      default: '/processmessage'
    }
    scopes: [
      'catwomen'
    ]
  }
} 
