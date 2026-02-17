# 09-01: Kubernetes Secrets – Secure MySQL Credentials

In this demo, we’ll learn how to use **Kubernetes Secrets** to store and manage **sensitive information** — such as **database usernames and passwords** — securely for our **Catalog microservice** and its **MySQL StatefulSet**.

---

## **Step-01: Create Secret for MySQL Credentials**

**Manifest:** `06_catalog_mysql_secrets.yaml`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: catalog-db
data:
  RETAIL_CATALOG_PERSISTENCE_USER: "Y2F0YWxvZ191c2Vy"
  RETAIL_CATALOG_PERSISTENCE_PASSWORD: "a2FseWFuZGIxMDE="
```

✅ **Explanation:**

* Secrets must store values **Base64-encoded**.
* The decoded values are:

  * `RETAIL_CATALOG_PERSISTENCE_USER` → `catalog_user`
  * `RETAIL_CATALOG_PERSISTENCE_PASSWORD` → `kalyandb101`

---

## **Step-02: Reference Secret in MySQL StatefulSet**

**File:** `04_catalog_statefulset.yaml`

Update container environment variables to read values from the Secret.

```yaml
      containers:
        - name: mysql
          image: "public.ecr.aws/docker/library/mysql:8.0"
          imagePullPolicy: IfNotPresent
          env:
            - name: MYSQL_ROOT_PASSWORD
              value: my-secret-pw
            - name: MYSQL_DATABASE
              value: catalogdb
            - name: MYSQL_USER
              valueFrom:
                secretKeyRef:
                  name: catalog-db
                  key: RETAIL_CATALOG_PERSISTENCE_USER
            - name: MYSQL_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: catalog-db
                  key: RETAIL_CATALOG_PERSISTENCE_PASSWORD
```

✅ **Explanation:**

* Secrets are injected directly as environment variables.
* This ensures credentials are **not exposed** in ConfigMaps or manifests.

---

## **Step-03: Update ConfigMap**

Comment out username and password from `03_catalog_configmap.yaml` — these are now managed securely via the Secret.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: catalog
data:
  RETAIL_CATALOG_PERSISTENCE_PROVIDER: "mysql"
  #RETAIL_CATALOG_PERSISTENCE_ENDPOINT: "catalog-mysql:3306"
  RETAIL_CATALOG_PERSISTENCE_ENDPOINT: "catalog-mysql-0.catalog-mysql.default.svc.cluster.local:3306"   
  RETAIL_CATALOG_PERSISTENCE_DB_NAME: "catalogdb"
  #RETAIL_CATALOG_PERSISTENCE_USER: "catalog_user"
  #RETAIL_CATALOG_PERSISTENCE_PASSWORD: "kalyandb101"
  RETAIL_CATALOG_PERSISTENCE_CONNECT_TIMEOUT: "5"
```

---

## **Step-04: Reference Secret in Deployment**

Update the **Catalog Deployment** to load both ConfigMap and Secret as environment sources.

**File:** `01_catalog_deployment.yaml`

```yaml
    spec:
      securityContext:
        fsGroup: 1000
      containers:
        - name: catalog
          envFrom:
            - configMapRef:
                name: catalog
            - secretRef:
                name: catalog-db
```

✅ **Explanation:**

* Application Pods can now securely read DB credentials via environment variables.
* `envFrom` merges both ConfigMap and Secret values inside the container.

---

## **Step-05: Apply Manifests and Verify**

```bash
kubectl apply -f catalog_k8s_manifests
```

Verify Secret:

```bash
kubectl get secrets
kubectl describe secret catalog-db
kubectl get secret catalog-db -o yaml
```

---

## **Step-06: Access the Application**

Expose the Catalog application locally for testing.

```bash
# Port-forward Catalog Pod
kubectl port-forward svc/catalog-service 7080:8080
```

**Test Endpoints:**

| Endpoint                                              | Description            |
| ----------------------------------------------------- | ---------------------- |
| `http://localhost:7080/topology`                      | Check service topology |
| `http://localhost:7080/health`                        | Health check           |
| `http://localhost:7080/catalog/products`              | List all products      |
| `http://localhost:7080/catalog/products/<product-id>` | Get product by ID      |
| `http://localhost:7080/catalog/size`                  | Product count          |
| `http://localhost:7080/catalog/tags`                  | List tags              |

---

## **Summary**

| Concept       | Description                                                      |
| ------------- | ---------------------------------------------------------------- |
| **ConfigMap** | Stores non-sensitive data (configurations).                      |
| **Secret**    | Stores sensitive data securely (credentials, tokens).            |
| **envFrom**   | Loads ConfigMap and Secret into Pod environment.                 |
| **Security**  | Base64 encoding + restricted visibility in `kubectl get` output. |

---
