# Catalog Helm Release

This release deploys `catalog` workload to EKS while keeping the data plane in AWS (RDS + Secrets Manager).

## Prerequisites

- EKS cluster provisioned from `terraform_src/02_EKS`
- Catalog infrastructure applied from `terraform_src/04_MicroServices/catalog`
- Secrets Store CSI driver + AWS provider installed (already provisioned in your EKS Terraform)
- Pod Identity association exists for service account `catalog`

## Configure Values

1. Update `values-dev.yaml`:
- `RETAIL_CATALOG_PERSISTENCE_ENDPOINT`

2. Ensure secret name/path matches Terraform:
- `retail/dev/catalog/secrets`

3. Optional: create an in-cluster DNS alias to external RDS with `ExternalName` service:
- set `externalServices.enabled=true`
- add a `services` item in `values-common.yaml`
- point `RETAIL_CATALOG_PERSISTENCE_ENDPOINT` to `<external-service-name>:3306`

## Deploy

```bash
helm upgrade --install catalog ../../charts/microservice-base \
  -f values-common.yaml \
  -f values-dev.yaml \
  --namespace default \
  --create-namespace
```

## Validate

```bash
kubectl get deploy,pod,svc | grep catalog
kubectl get secretproviderclass catalog-aws-secrets
kubectl describe pod -l app.kubernetes.io/instance=catalog
kubectl logs deploy/catalog --tail=100
```
