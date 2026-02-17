# 08-05: Kubernetes StatefulSet – MySQL for Catalog Service

In this demo, we’ll deploy a **MySQL database using Kubernetes StatefulSet** for our **Catalog microservice**.
We’ll explore StatefulSet behavior, Headless Service DNS, Pod identity, scaling order, and connect to MySQL directly from inside the cluster.

---

## Learning Objectives

- ✅ Understand StatefulSet basics
- ✅ Deploy MySQL with a Headless Service
- ✅ Observe ordered Pod creation and deletion
- ✅ Test DNS resolution for StatefulSet Pods
- ✅ Connect to MySQL using a client Pod
- ✅ Verify data in the Catalog database
- ✅ Understand limitations (no replication yet)

---

## Step-01: Update ConfigMap for MySQL Connection

Update the existing Catalog ConfigMap to point to the new MySQL StatefulSet.

**Manifest:** `03_catalog_configmap.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: catalog
data:
  RETAIL_CATALOG_PERSISTENCE_PROVIDER: "mysql"
  RETAIL_CATALOG_PERSISTENCE_ENDPOINT: "catalog-mysql:3306"
  RETAIL_CATALOG_PERSISTENCE_DB_NAME: "catalogdb"
  RETAIL_CATALOG_PERSISTENCE_USER: "catalog_user"
  RETAIL_CATALOG_PERSISTENCE_PASSWORD: "kalyandb101"
  RETAIL_CATALOG_PERSISTENCE_CONNECT_TIMEOUT: "5"
```

> **Note:**
> Even with a Headless Service (`clusterIP: None`), `catalog-mysql:3306` works 
> Kubernetes DNS resolves the Pod IP directly.

---

## Step-02: Create Headless Service

**Manifest:** `05_catalog_mysql_headless_service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: catalog-mysql
  labels:
    app.kubernetes.io/name: catalog
    app.kubernetes.io/instance: catalog
    app.kubernetes.io/component: mysql
    app.kubernetes.io/owner: retail-store-sample
spec:
  clusterIP: None
  ports:
    - port: 3306
      targetPort: mysql
      name: mysql
  selector:
    app.kubernetes.io/name: catalog
    app.kubernetes.io/instance: catalog
    app.kubernetes.io/component: mysql
    app.kubernetes.io/owner: retail-store-sample
```

Headless Service enables **stable DNS** names like
`catalog-mysql-0.catalog-mysql.default.svc.cluster.local`.

---

## Step-03: Deploy MySQL StatefulSet

**Manifest:** `04_catalog_statefulset.yaml`

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: catalog-mysql
  labels:
    app.kubernetes.io/name: catalog
    app.kubernetes.io/instance: catalog
    app.kubernetes.io/component: mysql
    app.kubernetes.io/owner: retail-store-sample
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: catalog
      app.kubernetes.io/instance: catalog
      app.kubernetes.io/component: mysql
      app.kubernetes.io/owner: retail-store-sample
  template:
    metadata:
      labels:
        app.kubernetes.io/name: catalog
        app.kubernetes.io/instance: catalog
        app.kubernetes.io/component: mysql
        app.kubernetes.io/owner: retail-store-sample
    spec:
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
              value: catalog_user
            - name: MYSQL_PASSWORD
              value: kalyandb101
          ports:
            - name: mysql
              containerPort: 3306
              protocol: TCP
          volumeMounts:
            - name: data
              mountPath: /var/lib/mysql
      volumes:
        - name: data
          emptyDir: {}
```

---

## Step-04: Apply All Manifests

```bash
kubectl apply -f catalog_k8s_manifests
```

Verify resources:

```bash
kubectl get statefulsets
kubectl get pods -o wide
kubectl get svc
```

---

### **Step-04-01: Verify Catalog App Logs – Ensure It Connects to MySQL Database**

```bash
# View logs of the Catalog application (only one Pod under the Deployment)
kubectl logs -f deploy/catalog
```

#### **Sample Output**

```bash
Kalyan-mac-mini4:08_05_Kubernetes_StatefulSet kalyan$ kubectl logs -f deploy/catalog
Found 2 pods, using pod/catalog-mysql-0
2025-10-06 05:40:03+00:00 [Note] [Entrypoint]: Entrypoint script for MySQL Server 8.0.43-1.el9 started.
2025-10-06 05:40:04+00:00 [Note] [Entrypoint]: Switching to dedicated user 'mysql'
2025-10-06 05:40:04+00:00 [Note] [Entrypoint]: Entrypoint script for MySQL Server 8.0.43-1.el9 started.
```

### **Observation**

If you see MySQL startup logs like the above,
it confirms that the **Catalog microservice** is successfully pointing to the **MySQL database Pod** (`catalog-mysql-0`) through the **Kubernetes Service `catalog-mysql`**.


---

## Step-05: Test DNS Resolution

```bash
kubectl run dns-test --image=busybox:1.28 -it --rm
```

Inside the pod:

```bash
nslookup catalog-mysql
nslookup catalog-mysql-0.catalog-mysql
```

✅ You should see Pod IPs directly (no ClusterIP).

---

## Step-06: Scale Up – Ordered Pod Creation

```bash
kubectl scale statefulset catalog-mysql --replicas=3
kubectl get pods -w
```

Observe that Pods start **sequentially**:

```
catalog-mysql-0 → catalog-mysql-1 → catalog-mysql-2
```

---

## Step-07: Scale Down – Reverse Order Deletion

```bash
kubectl scale statefulset catalog-mysql --replicas=1
kubectl get pods -w
```

Observe reverse deletion:

```
catalog-mysql-2 → catalog-mysql-1 → catalog-mysql-0
```

---

## **Step-08: Delete Pod and Verify Identity**

```bash
kubectl delete pod catalog-mysql-0
kubectl get pods

# Restart Catalog App
kubectl rollout restart deploy/catalog
```

---

### **Observation Note: VERY IMPORTANT**

Since the MySQL database Pod uses an **`emptyDir` volume**,
the data stored inside the Pod is **ephemeral** — it exists only for the Pod’s lifetime.

👉 When you **delete and recreate the Pod**, the **entire database is reinitialized**, and any **previously created data** (for example, products, tags, etc.) is **lost**.

This clearly demonstrates **why we need persistent storage** —
which we’ll address later using **EBS CSI Driver and PersistentVolumeClaims**.


✅ Pod will recreate with **same name** (`catalog-mysql-0`).

---

## Instructor Note: StatefulSet Scaling ≠ MySQL Replication

> Scaling MySQL StatefulSet to multiple replicas only creates **independent MySQL servers**.
> Kubernetes does **not** configure replication automatically.
>
> To build master–replica replication, you’d need:
>
> * Custom **init scripts** or **sidecar containers**
> * Commands like `CHANGE MASTER TO` and `START SLAVE;`
> * Or use **Bitnami MySQL Helm Chart**, which sets up replication automatically.
>
> **StatefulSet gives identity and stability; replication logic must be handled separately.**

---

## Step-09: Verify Database Connection Inside Cluster

### Step-09-01: Connect Using MySQL Client Pod

```bash
kubectl run mysql-client --rm -it \
  --image=mysql:8.0 \
  --restart=Never \
  -- mysql -h catalog-mysql -u catalog_user -p
```

When prompted for password, enter:

```
kalyandb101
```

### Step-09-02: Run SQL Commands

```sql
SHOW DATABASES;
USE catalogdb;
SHOW TABLES;
SELECT * FROM products;
SELECT * FROM tags;
SELECT * FROM product_tags;
EXIT;
```

✅ You can now explore your database directly inside the cluster —
no need for a local MySQL client.

---

## Step-10: Access Catalog Application via Port Forwarding

After MySQL StatefulSet is up, we can test our Catalog app which now connects to the MySQL database.

```bash
# Port-forward to Catalog Service
kubectl port-forward svc/catalog-service 7080:8080

# When you access topoligy endpoint expected output
http://localhost:7080/topology

## Sample output - topology endpoint
{
  "databaseEndpoint": "catalog-mysql:3306",
  "persistenceProvider": "mysql"
}
```

### Test Endpoints

| Endpoint                                                                                                                                                   | Description           |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------- |
| [http://localhost:7080/topology](http://localhost:7080/topology)                                                                                           | View service topology |
| [http://localhost:7080/health](http://localhost:7080/health)                                                                                               | Health check          |
| [http://localhost:7080/catalog/products](http://localhost:7080/catalog/products)                                                                           | Get all products      |
| [http://localhost:7080/catalog/products/d77f9ae6-e9a8-4a3e-86bd-b72af75cbc49](http://localhost:7080/catalog/products/d77f9ae6-e9a8-4a3e-86bd-b72af75cbc49) | Get product by ID     |
| [http://localhost:7080/catalog/size](http://localhost:7080/catalog/size)                                                                                   | Get catalog size      |
| [http://localhost:7080/catalog/tags](http://localhost:7080/catalog/tags)                                                                                   | Get tags              |

---

## Step-11: Cleanup (Optional)

```bash
kubectl delete catalog_k8s_manifests
```

---

## Summary

| Concept          | What We Learned                                                  |
| ---------------- | ---------------------------------------------------------------- |
| StatefulSet      | Manages stateful workloads with stable Pod identity              |
| Headless Service | Enables predictable DNS per Pod                                  |
| Scaling          | Pods scale **in order** and terminate **in reverse**             |
| Pod Identity     | Pods retain same names on recreation                             |
| DNS Resolution   | Verified with `nslookup` for Stateful Pods                       |
| Persistence      | Using `emptyDir` now — will move to **EBS volumes** in **08-08** |
| Credentials      | Hardcoded now — will move to **Kubernetes Secrets** in **08-06** |
| Database Access  | Verified inside cluster using temporary `mysql-client` Pod       |

---
