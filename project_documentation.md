# Dify on AKS プロジェクト説明資料

## 1. システム概要
```mermaid
graph TB
    subgraph Azure["Azure Cloud"]
        subgraph AKS["AKS Cluster (Japan East)"]
            API["API Service<br/>[Port: 5001]"]
            WEB["Web UI<br/>[Port: 3000]"]
            WORKER["Worker<br/>[Celery Worker]"]
            PLUGIN["Plugin Daemon<br/>[Port: 5002, 5003]"]
            SANDBOX["Sandbox<br/>[Port: 8194]"]
            subgraph Infrastructure
                DB["PostgreSQL<br/>[Port: 5432]"]
                REDIS["Redis<br/>[Port: 6379]"]
                WEAVIATE["Weaviate<br/>[Port: 8080]"]
                PROXY["SSRF Proxy<br/>[Port: 3128]"]
            end
        end
        ACR["Azure Container Registry<br/>(difyaksacr)"]
    end
    USER["User"]
    ACR -->|Image Pull| AKS
    USER -->|Access| WEB
    USER -->|API Call| API
    WEB -->|Internal Call| API
    API -->|Vector Operations| WEAVIATE
    WORKER -->|Tasks & Results| REDIS
    WORKER -->|Data Storage| DB
    WORKER -->|Via API| API
    PLUGIN -->|Plugin Data Storage| DB
    PLUGIN -->|Cache| REDIS
    SANDBOX <-->|HTTP/HTTPS Proxy| PROXY
```

## 2. 環境構成

### 2.1 インフラストラクチャ仕様
- **AKSクラスター**
  - リージョン: Japan East
  - ノードサイズ: Standard_D8ps_v5
  - ノード数: 1
  - Kubernetesバージョン: 1.32.4

### 2.2 主要コンポーネント
```mermaid
graph LR
    subgraph Applications
        A[API Service<br/>1.3.1]
        W[Web UI<br/>1.3.1]
        P[Plugin Daemon<br/>0.0.9-local]
        S[Sandbox<br/>0.2.11]
    end
    subgraph Infrastructure
        DB[PostgreSQL<br/>15-alpine]
        R[Redis<br/>6-alpine]
        WV[Weaviate<br/>1.19.0]
        SQ[Squid Proxy]
    end
```

## 3. ディレクトリ構造
```mermaid
graph TB
    ROOT["Project Root"]
    BASE["base/"]
    OVERLAYS["overlays/"]
    
    ROOT --> BASE
    ROOT --> OVERLAYS
    
    subgraph "Base Configuration"
        BASE --> CONF["configmap/"]
        BASE --> DEPLOY["deployments/"]
        BASE --> SECRET["secret/"]
        BASE --> STORAGE["storage/"]
    end
    
    subgraph "Environment Overlays"
        OVERLAYS --> AZURE["azure/"]
        OVERLAYS --> LOCAL["local/"]
    end
```

### 詳細なディレクトリ構造
```
.
├── main.bicep                         # AKSインフラストラクチャ定義
├── parameters.json                    # Bicepパラメータ
├── base/                             # ベース設定
│   ├── kustomization.yaml            # ベース設定のKustomize定義
│   ├── namespace.yaml                # 名前空間定義
│   ├── configmap/                    # ConfigMap定義
│   │   ├── postgres-config.yaml      # PostgreSQL設定
│   │   ├── postgres-init.yaml        # PostgreSQL初期化スクリプト
│   │   ├── sandbox-config.yaml       # Sandbox設定
│   │   └── shared-config.yaml        # 共有設定
│   ├── deployments/                  # デプロイメント定義
│   │   ├── api.yaml                  # APIサービス
│   │   ├── db.yaml                   # PostgreSQL
│   │   ├── plugin-daemon.yaml        # プラグインデーモン
│   │   ├── redis.yaml               # Redisキャッシュ
│   │   ├── sandbox.yaml             # サンドボックス
│   │   ├── ssrf-proxy.yaml          # SSRFプロキシ
│   │   ├── weaviate.yaml            # ベクトルDB
│   │   ├── web.yaml                 # WebUI
│   │   └── worker.yaml              # Celeryワーカー
│   ├── secret/                      # シークレット定義
│   │   ├── db-secret.yaml           # DB認証情報
│   │   ├── mail-secret.yaml         # メール設定
│   │   ├── model-provider-secret.yaml # AIモデル設定
│   │   ├── plugin-daemon-secret.yaml  # プラグイン認証情報
│   │   └── redis-secret.yaml         # Redis認証情報
│   └── storage/                      # ストレージ設定
│       └── persistent-volume-claims.yaml # 永続ボリューム要求
└── overlays/                         # 環境固有の設定
    ├── azure/                        # Azure環境設定
    │   ├── api-init-patch.yaml       # API初期化パッチ
    │   ├── api-service-patch.yaml    # APIサービスパッチ
    │   ├── configmap-patch.yaml      # ConfigMapパッチ
    │   ├── configmap-updater-rbac.yaml # RBAC設定
    │   ├── image-patch.yaml          # イメージパッチ
    │   ├── init-configmap-job.yaml   # 初期化ジョブ
    │   ├── kustomization.yaml        # Azure用Kustomize
    │   ├── storage-patch.yaml        # ストレージパッチ
    │   └── web-service-patch.yaml    # WebUIパッチ
    └── local/                        # ローカル環境設定
        └── kustomization.yaml        # ローカル用Kustomize
```

## 4. デプロイメントフロー
```mermaid
sequenceDiagram
    participant User
    participant Azure as Azure CLI
    participant ACR as Container Registry
    participant AKS as Kubernetes Cluster
    
    User->>Azure: 1. az login
    User->>Azure: 2. Create Resource Group
    User->>Azure: 3. Deploy Infrastructure (Bicep)
    User->>ACR: 4. Push Container Images
    User->>AKS: 5. Apply Kustomize Configs
    AKS->>ACR: 6. Pull Images
    AKS->>AKS: 7. Deploy Services
```

## 5. Kustomize構成管理

### 5.1 Kustomizeとは
Kustomizeは、Kubernetesのネイティブな設定管理ツールです。以下の特徴があります：

- **設定の階層化**：
  - ベース設定（base）：全環境で共通の基本設定
  - オーバーレイ（overlays）：環境固有のカスタマイズ

- **パッチによるカスタマイズ**：
  - 既存のマニフェストを変更せずに設定を上書き
  - 環境ごとの違いを最小限の記述で管理

- **主な機能**：
  - CommonLabelsの一括設定
  - イメージタグの変更
  - ConfigMapとSecretの生成
  - リソース間の依存関係管理

- **使用方法**：
  - `kubectl apply -k <ディレクトリ>` でデプロイ
  - `kustomization.yaml` で設定をまとめて管理

### 5.2 プロジェクトのKustomize構成

- **ベース設定（`base/`）**
  - 共通のKubernetesマニフェスト
  - ConfigMap、Secret定義
  - 基本的なデプロイメント設定

- **Azure環境オーバーレイ（`overlays/azure/`）**
  - LoadBalancerサービス設定
  - ストレージクラス設定
  - イメージレジストリパッチ
  - 初期化ジョブ設定

- **ローカル環境オーバーレイ（`overlays/local/`）**
  - 開発環境用の設定

## 6. デプロイ手順書

### 6.1 前提条件
```mermaid
graph LR
    A[Azure CLI<br/>インストール済み] --> D[デプロイ準備完了]
    B[kubectl<br/>インストール済み] --> D
    C[Azure<br/>サブスクリプション] --> D
    E[Docker環境] --> D
```

### 6.2 デプロイステップ
1. **環境準備**
   ```bash
   # Azureログイン
   az login

   # リソースグループ作成
   az group create --name dify-rg --location japaneast
   ```

2. **インフラストラクチャのデプロイ**
   ```bash
   # Bicepテンプレートを使用したデプロイ
   az deployment group create \
     --name dify-deployment \
     --resource-group dify-rg \
     --template-file main.bicep \
     --parameters parameters.json

   # AKS認証情報の取得
   az aks get-credentials --resource-group dify-rg --name dify-aks
   ```

3. **コンテナイメージの準備**
   ```mermaid
   flowchart TD
    A[ACRログイン] -->|az acr login| B[イメージタグ付け]
    B --> C[イメージプッシュ]
    C --> D[デプロイ準備完了]
   ```

   ```bash
   # ACRログイン
   az acr login --name difyaksacr
   
   # イメージのタグ付けとプッシュ
   for img in \
     "langgenius/dify-api:1.3.1" \
     "langgenius/dify-web:1.3.1" \
     "langgenius/dify-plugin-daemon:0.0.9-local" \
     "langgenius/dify-sandbox:0.2.11" \
     "postgres:15-alpine" \
     "redis:6-alpine" \
     "semitechnologies/weaviate:1.19.0" \
     "busybox:latest" \
     "ubuntu/squid:latest"
   do
     name=$(echo $img | cut -d/ -f2)
     docker tag $img difyaksacr.azurecr.io/$name
     docker push difyaksacr.azurecr.io/$name
   done
   ```

4. **アプリケーションのデプロイ**
   ```mermaid
   sequenceDiagram
       participant U as User
       participant K as Kubernetes
       participant P as Pods
       
       U->>K: kubectl apply -k overlays/azure
       K->>P: Create Namespaces
       K->>P: Deploy ConfigMaps
       K->>P: Deploy Secrets
       K->>P: Deploy Storage
       K->>P: Deploy Applications
       U->>K: kubectl get pods -n dify
       K-->>U: Show Pod Status
       U->>K: kubectl get services -n dify
       K-->>U: Show Service IPs
   ```

5. **デプロイ検証**
   ```bash
   # Podの状態確認
   kubectl get pods -n dify -w

   # サービスの外部IP確認
   kubectl get services -n dify
   ```

### 6.3 アクセス情報
- Web UI: `http://<web-svc-external-ip>`
- API: `http://<api-svc-external-ip>:5001`

### 6.4 トラブルシューティング
```mermaid
graph TD
    A[Pod起動失敗] --> B{ログ確認}
    B -->|イメージプル失敗| C[ACR認証確認]
    B -->|アプリケーションエラー| D[アプリログ確認]
    B -->|ストレージエラー| E[PVC状態確認]
    
    C --> F[az aks check-acr]
    D --> G[kubectl logs]
    E --> H[kubectl describe pvc]
```

### 6.5 クリーンアップ手順
```bash
# Kubernetesリソースの削除
kubectl delete -k overlays/azure

# Azureリソースの削除
az group delete --name dify-rg --yes
```

## 7. イメージアーキテクチャ情報

### 7.1 実行環境
- AKSノードタイプ: Standard_D8ps_v5 (ARM64  ❌x86_64)
- リージョン: Japan East

### 7.2 コンテナイメージ一覧
```mermaid
graph TB
    subgraph アプリケーションイメージ["アプリケーションイメージ (ARM64対応)"]
        API["dify-api:1.3.1<br/>ARM64"]
        WEB["dify-web:1.3.1<br/>ARM64"]
        PLUGIN["dify-plugin-daemon:0.0.9-local<br/>ARM64"]
        SANDBOX["dify-sandbox:0.2.11<br/>ARM64"]
    end
    
    subgraph インフラストラクチャイメージ["インフラストラクチャイメージ (マルチアーキテクチャ対応)"]
        PG["postgres:15-alpine<br/>Multi-arch"]
        REDIS["redis:6-alpine<br/>Multi-arch"]
        WEAVIATE["weaviate:1.19.0<br/>Multi-arch"]
        BUSYBOX["busybox:latest<br/>Multi-arch"]
        SQUID["ubuntu/squid:latest<br/>Multi-arch"]
    end
```

### 7.3 イメージ詳細
| コンポーネント | イメージ名 | バージョン | アーキテクチャ対応 |
|--------------|-----------|------------|----------------|
| API Service | dify-api | 1.3.1 | ARM64 |
| Web UI | dify-web | 1.3.1 | ARM64 |
| Plugin Daemon | dify-plugin-daemon | 0.0.9-local | ARM64 |
| Sandbox | dify-sandbox | 0.2.11 | ARM64 |
| Database | postgres | 15-alpine | Multi-arch |
| Cache | redis | 6-alpine | Multi-arch |
| Vector DB | weaviate | 1.19.0 | Multi-arch |
| Init Container | busybox | latest | Multi-arch |
| SSRF Proxy | ubuntu/squid | latest | Multi-arch |

### 7.4 アーキテクチャ互換性に関する注意事項
- すべてのアプリケーションイメージは ARM64 アーキテクチャ向けに最適化されています
- インフラストラクチャコンポーネントは公式のマルチアーキテクチャイメージを使用し、ARM64プラットフォームに自動的に対応します
- AKSクラスターはARM64ベースのノード（Standard_D8ps_v5）を使用しているため、すべてのイメージがこのアーキテクチャで実行可能です
