# Dify Kubernetes Deployment

このディレクトリには、DifyアプリケーションのKubernetes用デプロイメント設定が含まれています。

## ディレクトリ構造

```
kubernetes/
├── base/                     # ベース設定
│   ├── configmap/           # 共有設定
│   ├── secret/              # 機密情報
│   ├── storage/             # ストレージ設定
│   └── deployments/         # アプリケーションデプロイメント
└── overlays/                # 環境別設定
    └── local/               # ローカル環境用設定
```

## 前提条件

- Kubernetes クラスター（Docker Desktop Kubernetes または Minikube）
- kubectl
- kustomize

## デプロイ手順

1. ネームスペースの作成
```bash
kubectl apply -f kubernetes/base/namespace.yaml
```

2. ローカル環境へのデプロイ
```bash
kubectl apply -k kubernetes/overlays/local
```

3. デプロイの確認
```bash
# Podの状態確認
kubectl get pods -n dify

# サービスの確認
kubectl get services -n dify
```

## アクセス方法

デプロイが完了すると、以下のURLでアクセスできます：

- Web UI: http://localhost:30080
- API: http://localhost:30081

## トラブルシューティング

1. Podのログ確認
```bash
kubectl logs -n dify <pod-name>
```

2. Podの詳細確認
```bash
kubectl describe pod -n dify <pod-name>
```

3. 全リソースの状態確認
```bash
kubectl get all -n dify
```

## クリーンアップ

環境を削除する場合は以下のコマンドを実行：

```bash
kubectl delete -k kubernetes/overlays/local
```

## 注意事項

- ローカル環境ではNodePortを使用してサービスを公開
- 永続データは`PersistentVolumeClaim`を使用して保存
- 本番環境での使用時は、適切なストレージクラスとリソース制限の設定が必要
