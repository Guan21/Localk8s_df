# Dify on AKS

## Prerequisites
- Azure CLI
- kubectl
- Azure Subscription
- Docker環境（ローカルイメージのプッシュに必要）

## Setup Steps

1. Deploy Infrastructure using Bicep
```bash
# Login to Azure
az login

# Create Resource Group
az group create --name dify-rg --location japaneast

# Deploy AKS and integrate with existing ACR
az deployment group create \
  --name dify-deployment \
  --resource-group dify-rg \
  --template-file main.bicep \
  --parameters parameters.json

# Note: parameters.json has deployAcr=false to use existing ACR
# If you want to deploy a new ACR, set deployAcr=true

# Get AKS Credentials
az aks get-credentials --resource-group dify-rg --name dify-aks
```

2. Push Images to ACR (if not already done)
```bash
# Login to ACR
az acr login --name difyaksacr

# Tag and Push Images
# アプリケーションイメージ
docker tag langgenius/dify-api:1.3.1 difyaksacr.azurecr.io/dify-api:1.3.1
docker tag langgenius/dify-web:1.3.1 difyaksacr.azurecr.io/dify-web:1.3.1
docker tag langgenius/dify-plugin-daemon:0.0.9-local difyaksacr.azurecr.io/dify-plugin-daemon:0.0.9-local
docker tag langgenius/dify-sandbox:0.2.11 difyaksacr.azurecr.io/dify-sandbox:0.2.11

# インフラストラクチャイメージ
docker tag postgres:15-alpine difyaksacr.azurecr.io/postgres:15-alpine
docker tag redis:6-alpine difyaksacr.azurecr.io/redis:6-alpine
docker tag semitechnologies/weaviate:1.19.0 difyaksacr.azurecr.io/semitechnologies/weaviate:1.19.0
docker tag busybox:latest difyaksacr.azurecr.io/busybox:latest
docker tag ubuntu/squid:latest difyaksacr.azurecr.io/ubuntu/squid:latest

# Push Images to ACR
docker push difyaksacr.azurecr.io/dify-api:1.3.1
docker push difyaksacr.azurecr.io/dify-web:1.3.1
docker push difyaksacr.azurecr.io/dify-plugin-daemon:0.0.9-local
docker push difyaksacr.azurecr.io/dify-sandbox:0.2.11
docker push difyaksacr.azurecr.io/postgres:15-alpine
docker push difyaksacr.azurecr.io/redis:6-alpine
docker push difyaksacr.azurecr.io/semitechnologies/weaviate:1.19.0
docker push difyaksacr.azurecr.io/busybox:latest
docker push difyaksacr.azurecr.io/ubuntu/squid:latest
```

3. Deploy Application
```bash
# Deploy using Azure overlay
kubectl apply -k overlays/azure

# Check deployment status
kubectl get pods -n dify

# Get service external IPs
kubectl get services -n dify
```

4. Access the Application
- Web UI: `http://<web-svc-external-ip>`
- API: `http://<api-svc-external-ip>:5001`

## Cleanup
```bash
# Delete AKS Resources
kubectl delete -k overlays/azure

# Delete Azure Resources
az group delete --name dify-rg --yes
```

## Infrastructure Details
インフラストラクチャは以下のBicepファイルで定義されています：

- `main.bicep`: ACRとAKSクラスターの主要なインフラストラクチャ定義
  - 条件付きACRデプロイ（deployAcr パラメータで制御）
  - AKSクラスター設定
  - ACRとAKSの統合設定

- `parameters.json`: デプロイメントパラメータ
  - deployAcr: ACRを新規作成するかどうか（false=既存のACRを使用）
  - その他の設定パラメータ

主な設定：
- AKSクラスター: Standard_D8s_v3 VMサイズ、1ノード
- ACR: Basic SKU（新規作成時）
- Kubernetes version: 1.32.4（AKS LTS）
- リージョン: Japan East
