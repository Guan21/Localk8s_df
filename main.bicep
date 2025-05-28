@description('AKSクラスターの名前')
param clusterName string = 'dify-aks'

@description('Azure Container Registryの名前')
param acrName string = 'difyaksacr'

@description('リソースのデプロイ先リージョン')
param location string = 'japaneast'

@description('AKSノードのVM size')
param nodeVMSize string = 'Standard_D8ps_v5'

@description('AKSノードの数')
param nodeCount int = 1

@description('AKSクラスターのKubernetesバージョン')
param kubernetesVersion string = '1.32.4'

@description('ACRをデプロイするかどうか')
param deployAcr bool = false

// ACRの条件付きデプロイ
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = if (deployAcr) {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

// 既存のACRを参照
resource existingAcr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = if (!deployAcr) {
  name: acrName
}

// AKS Identity
resource aksIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${clusterName}-identity'
  location: location
}

// ACRのPull権限をAKS Identityに付与
@description('ACRのPull権限をAKS Identityに付与')
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(deployAcr ? acr.id : existingAcr.id, aksIdentity.id, 'acrpull')
  scope: deployAcr ? acr : existingAcr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: aksIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// AKSクラスターの作成
resource aks 'Microsoft.ContainerService/managedClusters@2023-07-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${aksIdentity.id}': {}
    }
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: '${clusterName}-dns'
    enableRBAC: true
    
    agentPoolProfiles: [
      {
        name: 'agentpool'
        count: nodeCount
        vmSize: nodeVMSize
        mode: 'System'
        osType: 'Linux'
        osSKU: 'Ubuntu'
      }
    ]
    
    networkProfile: {
      networkPlugin: 'kubenet'
      loadBalancerSku: 'standard'
    }

    // ACRとの統合
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
  }
}

// Outputs
output aksClusterName string = aks.name
output acrLoginServer string = deployAcr ? acr.properties.loginServer : existingAcr.properties.loginServer
output nodeResourceGroup string = aks.properties.nodeResourceGroup
