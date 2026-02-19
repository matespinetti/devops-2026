# Helm Deployment Structure

This directory contains the Helm deployment model for app-plane workloads.

## Layout

- `charts/microservice-base`: reusable chart used by all services
- `releases/<service>`: service-level values and deployment scripts
- `environments/<env>`: optional shared env overlays

## Ownership Model

- Terraform (`terraform_src`): VPC, EKS, IAM/Pod Identity, RDS, ElastiCache, DynamoDB, SQS, secrets
- Helm (`deploy/helm`): Deployments, Services, HPA, PDB, Ingress, NetworkPolicy, SecretProviderClass

## First Implemented Release

- `catalog` release in `deploy/helm/releases/catalog`

## Next Services

Apply same pattern for:
- `cart`
- `checkout`
- `orders`
- `ui`
