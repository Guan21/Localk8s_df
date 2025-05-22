# Dify on AKS

## Prerequisites
- Azure CLI
- kubectl
- Azure Subscription

## Setup Steps

1. Create Azure Container Registry (ACR)
```bash
# Create ACR
az acr create --resource-group dify-rg --name difyacr --sku Basic --location japaneast

# Import required images to ACR
az acr import --name difyacr --source docker.io/langgenius/dify-api:1.3.1 --image dify-api:1.3.1
az acr import --name difyacr --source docker.io/langgenius/dify-web:1.3.1 --image dify-web:1.3.1
az acr import --name difyacr --source docker.io/langgenius/dify-plugin-daemon:0.0.9-local --image dify-plugin-daemon:0.0.9-local
az acr import --name difyacr --source docker.io/library/postgres:15-alpine --image postgres:15-alpine
az acr import --name difyacr --source docker.io/library/redis:6-alpine --image redis:6-alpine
az acr import --name difyacr --source docker.io/library/busybox:latest --image busybox:latest
az acr import --name difyacr --source docker.io/langgenius/dify-sandbox:0.2.11 --image dify-sandbox:0.2.11
az acr import --name difyacr --source docker.io/ubuntu/squid:latest --image ubuntu/squid:latest
az acr import --name difyacr --source docker.io/semitechnologies/weaviate:1.19.0 --image semitechnologies/weaviate:1.19.0
```

2. Create AKS Cluster
```bash
# Create Resource Group
az group create --name dify-rg --location japaneast

# Create AKS Cluster
az aks create \
  --resource-group dify-rg \
  --name dify-aks \
  --node-count 1 \
  --node-vm-size Standard_D8s_v3 \
  --location japaneast

# Get Credentials
az aks get-credentials --resource-group dify-rg --name dify-aks

# Attach ACR to AKS
az aks update -n dify-aks -g dify-rg --attach-acr difyacr
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

# Delete AKS Cluster
az aks delete --resource-group dify-rg --name dify-aks

# Delete ACR
az acr delete --name difyacr --resource-group dify-rg

# Delete Resource Group
az group delete --name dify-rg
