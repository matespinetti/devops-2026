# 14_02: Deploy Retail Store Microservices with AWS Dataplane
## Step-01: Introduction
In this section, we will **connect all Retail Store microservices** — Catalog, Cart, Checkout, and Orders — to their equivalent **AWS Data Plane components**.

The goal is to replace local in-cluster databases with **fully managed AWS services** for a production-grade architecture.

| **Microservice** | **AWS Data Plane Service** | **Purpose** |
|------------------|----------------------------|--------------|
| **Catalog** | **Amazon RDS MySQL** | Stores product catalog data |
| **Cart** | **Amazon DynamoDB** | Manages user shopping cart data |
| **Checkout** | **Amazon ElastiCache (Redis)** | Caches shipping rates and checkout data |
| **Orders** | **Amazon RDS PostgreSQL + Amazon SQS** | Stores order data and handles order messaging events |

Each microservice will be configured to use its respective AWS service endpoint — either via **ConfigMap**, **ExternalName Service**, or **Secrets Store CSI** for credentials.

### Retailstore Application with Persistent Dataplane running on Kubernetes Cluster
![Retailstore Application with Persistent Dataplane running on Kubernetes Cluster](../../images/14_01_Dataplane_k8s_cluster.png)

### Retailstore Application with Persistent Dataplane running on AWS Cloud
![Retailstore Application with Persistent Dataplane running on AWS Cloud](../../images/14_02_Dataplane_AWS_Cloud.png)

### Persistent Dataplane running on AWS Cloud - Automated using Terraform
![Persistent Dataplane running on AWS Cloud - Automated using Terraform](../../images/14_03_Dataplane_AWS_Cloud_Automated_Terraform.png)



## Folder Structure

```
14_02_Microservices_with_AWS_Data_Plane/
├── README.md                                                      # Project overview and setup instructions
└── RetailStore_k8s_manifests_with_Data_Plane/
    │
    ├── 01_secretproviderclass/                                    # AWS Secrets Manager integration configs
    │   ├── 01_catalog_db_secretproviderclass.yaml                # Syncs catalog MySQL credentials from AWS Secrets Manager
    │   └── 02_orders_db_secretproviderclass.yaml                 # Syncs orders PostgreSQL credentials from AWS Secrets Manager
    │
    ├── 02_RetailStore_Microservices/                              # Core microservices deployments
    │   │
    │   ├── 01_catalog/                                            # Product catalog service (MySQL backend)
    │   │   ├── 01_catalog_service_account.yaml                   # ServiceAccount with EKS Pod Identity for AWS Secrets Manager access
    │   │   ├── 02_catalog_configmap.yaml                         # Database connection configs (host, port, db name)
    │   │   ├── 03_catalog_deployment.yaml                        # Deployment with CSI secrets mount for secret readiness
    │   │   ├── 04_catalog_clusterip_service.yaml                 # Internal service for catalog API (port 80)
    │   │   └── 05_catalog_mysql_externalname_service.yaml        # ExternalName service pointing to RDS MySQL endpoint
    │   │
    │   ├── 02_cart/                                               # Shopping cart service (DynamoDB backend)
    │   │   ├── 01_cart_service_account.yaml                      # ServiceAccount with EKS Pod Identity for DynamoDB access
    │   │   ├── 02_cart_configmap.yaml                            # DynamoDB table name and region configs
    │   │   ├── 03_cart_deployment.yaml                           # Stateless deployment for cart operations
    │   │   └── 04_cart_clusterip_service.yaml                    # Internal service for cart API
    │   │
    │   ├── 03_checkout/                                           # Checkout service (ElastiCache Redis backend)
    │   │   ├── 01_checkout_service_account.yaml                  # ServiceAccount with EKS Pod Identity for ElastiCache access
    │   │   ├── 02_checkout_configmap.yaml                        # Redis endpoint and configuration
    │   │   ├── 03_checkout_deployment.yaml                       # Handles order processing and payment workflows
    │   │   └── 04_checkout_clusterip_service.yaml                # Internal service for checkout API
    │   │
    │   ├── 04_orders/                                             # Order management service (PostgreSQL + SQS backend)
    │   │   ├── 01_orders_service_account.yaml                    # ServiceAccount with EKS Pod Identity for AWS Secrets Manager + SQS access
    │   │   ├── 02_orders_configmap.yaml                          # PostgreSQL connection and SQS queue configs
    │   │   ├── 03_orders_deployment.yaml                         # Deployment with CSI secrets mount + init container for secret readiness
    │   │   └── 04_orders_clusterip_service.yaml                  # Internal service for orders API
    │   │
    │   └── 05_ui/                                                 # Frontend web application
    │       ├── 01_ui_service_account.yaml                        # ServiceAccount for UI pods
    │       ├── 02_ui_configmap.yaml                              # Backend service endpoints configuration
    │       ├── 03_ui_deployment.yaml                             # Frontend deployment
    │       └── 04_ui_clusterip_service.yaml                      # Internal service for UI (exposed via Ingress)
    │
    ├── 03_ingress/                                                # External access configuration
    │   └── 01_ingress_http_ip_mode.yaml                          # AWS Load Balancer Controller Ingress (HTTP, IP mode for routing to UI)
    │
    ├── 04_Verification_Pods/                                      # Troubleshooting and debugging pods
    │   ├── 01_catalog_mysql_client_pod.yaml                      # MySQL client pod to test catalog database connectivity
    │   ├── 02_cart_dynamodb_awscli_pod.yaml                      # AWS CLI pod to test DynamoDB table access
    │   ├── 03_checkout_elasticache_redis_client_pod.yaml         # Redis CLI pod to test ElastiCache connectivity
    │   ├── 04_orders_postgresql_client_pod.yaml                  # PostgreSQL client pod to test orders database connectivity
    │   ├── 05_orders_sqs_awscli_pod.yaml                         # AWS CLI pod to test SQS queue access
    │   └── Verification-Pods.md                                   # Instructions for using verification pods
    │
    └── Verification-Pods.md                                       # Top-level verification guide

```

---

## Step-02: 01_secretproviderclass

We already configured the **AWS Secrets Manager CSI Driver** and **Pod Identity Agent** in earlier steps.

Now, we’ll deploy the **SecretProviderClass** manifest that syncs secrets from AWS Secrets Manager into native Kubernetes secrets for **Orders** and **Catalog** microservices.

This allows the application pods to securely retrieve database credentials at runtime.

Run the below command to deploy the SecretProviderClass manifest:

```bash
# Folder Structure
01_secretproviderclass/
├── 01_catalog_db_secretproviderclass.yaml
└── 02_orders_db_secretproviderclass.yaml

# Change Directory 
cd RetailStore_k8s_manifests_with_Data_Plane

# Deploy
kubectl apply -f 01_secretproviderclass/
```

This manifest ensures that:

* The Secrets Store CSI driver fetches credentials from AWS Secrets Manager.
* They are automatically synced to a native Kubernetes Secret (`orders-db`, `catalog-db`).
* Pods mount these secrets directly as environment variables.

---

## Step-03: Deploy UI and Ingress (Base Setup)

Before integrating backends, we’ll first deploy the **UI** and **Ingress** components.
This helps us verify the frontend accessibility via a Load Balancer before wiring up backend services.

### Files Used

```
02_RetailStore_Microservices/05_ui/
03_ingress/01_ingress_http_ip_mode.yaml
```

### Deploy Commands

```bash
# Deploy
kubectl apply -f 02_RetailStore_Microservices/05_ui/
kubectl apply -f 03_ingress/

# Access Application
http://ALB-DNS-NAME
http://ALB-DNS-NAME/topology
```

> The `/topology` endpoint displays internal microservice wiring — useful for verifying which services are up.

---

## Step-04: Deploy Catalog → AWS RDS MySQL

### Files

```
# Folder Structure
02_RetailStore_Microservices/01_catalog/
  ├── 01_catalog_service_account.yaml
  ├── 02_catalog_configmap.yaml
  ├── 03_catalog_deployment.yaml
  ├── 04_catalog_clusterip_service.yaml
  └── 05_catalog_mysql_externalname_service.yaml
```

### Key Configuration

We’ll point the Catalog service to the **RDS MySQL endpoint** using an **ExternalName Service** (`05_catalog_mysql_externalname_service.yaml`).

This ExternalName service acts as a **DNS alias** inside the cluster, mapping to the RDS endpoint (e.g., `mydb3.cxojydmxwly6.us-east-1.rds.amazonaws.com`).

### Why ExternalName Service?

| **Option**               | **Pros**                                       | **Cons**                                      |
| ------------------------ | ---------------------------------------------- | --------------------------------------------- |
| **ExternalName Service** | Simple DNS alias; no code or ConfigMap changes | No control over env variable injection        |
| **ConfigMap update**     | Explicit control; endpoint visible in YAML     | Manual update required on DB endpoint changes |

Here, we use **ExternalName** for **Catalog** just to demonstrate the approach.
For **Orders → PostgreSQL**, we’ll use **ConfigMap** updates instead, so students see both options in action.

### Deploy Commands

```bash
# Deploy
kubectl apply -f 02_RetailStore_Microservices/01_catalog/

# Access Application
http://ALB-DNS-NAME
http://ALB-DNS-NAME/topology
```

### Data Verification

Run the MySQL client pod to validate database connectivity and product data:

```bash
kubectl apply -f 04_Verification_Pods/01_catalog_mysql_client_pod.yaml
```

Then, follow verification instructions in:
📄 **[Verification-Pods.md → Step-01: Catalog → AWS RDS MySQL Database](./Verification-Pods.md)**

---

## Step-05: Deploy Cart → AWS DynamoDB

### Files

```
02_RetailStore_Microservices/02_cart/
  ├── 01_cart_service_account.yaml
  ├── 02_cart_configmap.yaml
  ├── 03_cart_deployment.yaml
  └── 04_cart_clusterip_service.yaml
```

The Cart microservice uses **Amazon DynamoDB** to persist shopping cart data.

We’ll update the **ConfigMap** to include:

* Real **AWS DynamoDB endpoint**
* Region (`us-west-2`)
* Table name and other parameters

### Deploy Commands

```bash
# Deploy
kubectl apply -f 02_RetailStore_Microservices/02_cart/

# Access Application
http://ALB-DNS-NAME
http://ALB-DNS-NAME/topology
```

### Verification

Access the Retail Store UI → Add an item to cart → Confirm that “Add to Cart” works without backend error.

Run the DynamoDB verification pod:

```bash
# Deploy
kubectl apply -f 04_Verification_Pods/02_cart_dynamodb_awscli_pod.yaml
```

Then follow verification steps in:
📄 **[Verification-Pods.md → Step-02: Carts → AWS DynamoDB](./Verification-Pods.md)**

### Note: Why `us-west-2` Region?

The **Cart** microservice code has the AWS region **hardcoded as `us-west-2`** in its DynamoDB client configuration.
To keep consistency with the application’s logic, we use the same region when creating and accessing the DynamoDB table.
(Developers can modify this in source later to use environment variables.)

---

## Step-06: Deploy Checkout → AWS ElastiCache (Redis)

### Files

```
02_RetailStore_Microservices/03_checkout/
  ├── 01_checkout_service_account.yaml
  ├── 02_checkout_configmap.yaml
  ├── 03_checkout_deployment.yaml
  └── 04_checkout_clusterip_service.yaml
```

The **Checkout** microservice uses **AWS ElastiCache (Redis)** for caching shipping rates and order checkout sessions.

We’ll update the **ConfigMap** to include:

* The **Redis endpoint** from ElastiCache (primary node endpoint)
  Example:

  ```
  RETAIL_CHECKOUT_PERSISTENCE_REDIS_HOST: retail-dev-checkout-redis.lwndbu.0001.use1.cache.amazonaws.com
  RETAIL_CHECKOUT_PERSISTENCE_REDIS_PORT: "6379"
  ```

### Deploy Commands

```bash
# Deploy
kubectl apply -f 02_RetailStore_Microservices/03_checkout/

# Access Application
http://ALB-DNS-NAME
http://ALB-DNS-NAME/topology
```

### Verification

Access the Retail Store UI → Add products → Proceed to checkout → Verify shipping rates and delivery options load correctly.

Run Redis client pod to validate data persistence:

```bash
# Deploy
kubectl apply -f 04_Verification_Pods/03_checkout_elasticache_redis_client_pod.yaml
```

Then follow verification steps in:
📄 **[Verification-Pods.md → Step-03: Checkout → AWS ElastiCache (Redis)](./Verification-Pods.md)**

---

## Step-07: Deploy Orders → AWS RDS PostgreSQL + SQS

### Files

```
02_RetailStore_Microservices/04_orders/
  ├── 01_orders_service_account.yaml
  ├── 02_orders_configmap.yaml
  ├── 03_orders_deployment.yaml
  └── 04_orders_clusterip_service.yaml
```

The **Orders** microservice connects to:

* **Amazon RDS PostgreSQL** for order data persistence
* **Amazon SQS** for order event messaging

### Configuration Highlights

**ConfigMap** (`02_orders_configmap.yaml`) includes:

```yaml
RETAIL_ORDERS_PERSISTENCE_PROVIDER: postgres
RETAIL_ORDERS_PERSISTENCE_ENDPOINT: orders-postgres-db.cxojydmxwly6.us-east-1.rds.amazonaws.com:5432
RETAIL_ORDERS_PERSISTENCE_NAME: ordersdb
RETAIL_ORDERS_MESSAGING_PROVIDER: sqs
RETAIL_ORDERS_MESSAGING_SQS_TOPIC: retail-dev-orders-queue
```

We are using **ConfigMap** here instead of **ExternalName**, to show variety and because the Orders microservice needs both RDS and SQS configuration keys in environment variables.

### Deploy Commands

```bash
# Deploy
kubectl apply -f 02_RetailStore_Microservices/04_orders/

# Access Application
http://ALB-DNS-NAME
http://ALB-DNS-NAME/topology
```

### Verification

#### ✅ Database Connectivity

Deploy PostgreSQL client pod and connect to RDS PostgreSQL:

```bash
# Deploy
kubectl apply -f 04_Verification_Pods/04_orders_postgresql_client_pod.yaml
```

#### ✅ SQS Queue Validation

Deploy AWS CLI pod for SQS testing:

```bash
# Deploy
kubectl apply -f 04_Verification_Pods/05_orders_sqs_awscli_pod.yaml
```

Then follow verification steps in:
📄 **[Verification-Pods.md → Step-04 & Step-05: Orders → RDS PostgreSQL & SQS](./Verification-Pods.md)**

You can also verify messages in SQS queue:

```bash
aws sqs receive-message \
  --queue-url https://sqs.us-east-1.amazonaws.com/<account-id>/retail-dev-orders-queue \
  --max-number-of-messages 5 \
  --output json | jq -r '.Messages[].Body' | jq
```

---

## Step-08: Final End-to-End Verification

Now that all microservices are integrated with AWS data plane services, open the Ingress URL and walk through the complete user flow:

1. Access the Retail Store via Ingress URL.
2. Perform full flow:
   * Browse products (Catalog → MySQL)
   * Add items to cart (Cart → DynamoDB)
   * Checkout (Checkout → Redis)
   * Place Order (Orders → PostgreSQL + SQS)
3. Observe logs and confirm successful transactions across all backends.

If everything works, the app should now represent a **fully cloud-native architecture** using AWS managed services for persistence, caching, and messaging.

---

## Step-09: Clean-up (Optional)

To remove all deployed Kubernetes resources:

```bash
# Delete Kubernetes Resources
kubectl delete -f 02_RetailStore_Microservices/04_orders/
kubectl delete -f 02_RetailStore_Microservices/03_checkout/
kubectl delete -f 02_RetailStore_Microservices/02_cart/
kubectl delete -f 02_RetailStore_Microservices/01_catalog/
kubectl delete -f 02_RetailStore_Microservices/05_ui/
kubectl delete -f 03_ingress/
kubectl delete -f 01_secretproviderclass/
```
> ⚠️ Always destroy the AWS data plane resources after verifying the demo to avoid unwanted charges.

To remove AWS data plane resources (when demo is done):

```bash
# Delete AWS Dataplane
cd ../../14_01_All_Microservices_Persistent_Endpoints/
terraform destroy -auto-approve
```

---

## Folder Structure - High Level

```
14_02_Microservices_with_AWS_Data_Plane/
├── README.md
├── Verification-Pods.md
└── RetailStore_k8s_manifests_with_Data_Plane
    ├── 01_secretproviderclass/
    ├── 02_RetailStore_Microservices/
    ├── 03_ingress/
    └── 04_Verification_Pods/
```

---

✅ **Summary**

In this section, we:

* Synced AWS Secrets with Kubernetes (SecretProviderClass)
* Deployed UI and Ingress
* Integrated each backend microservice with AWS:
  * Catalog → RDS MySQL
  * Cart → AWS DynamoDB
  * Checkout → ElastiCache (Redis)
  * Orders → PostgreSQL + SQS
* Verified data and message flow end-to-end
* Prepared a clean, production-ready cloud-native deployment on AWS


---
