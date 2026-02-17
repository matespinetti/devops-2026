# 08-04: Kubernetes ConfigMap – Catalog Microservice

In this demo, we’ll learn how to use a **Kubernetes ConfigMap** to externalize application configuration for our **Catalog microservice**.

- [Catalog Microservice - Documentation](https://github.com/stacksimplify/retail-store-sample-app-aws/tree/main/src/catalog)

---

## **Step-01: Create ConfigMap**

**Manifest:** `03_catalog_configmap.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: catalog
data:
  RETAIL_CATALOG_PERSISTENCE_PROVIDER: "in-memory"
  RETAIL_CATALOG_PERSISTENCE_ENDPOINT: ""
  RETAIL_CATALOG_PERSISTENCE_DB_NAME: "catalogdb"
  RETAIL_CATALOG_PERSISTENCE_USER: "catalog_user"
  RETAIL_CATALOG_PERSISTENCE_PASSWORD: ""
  RETAIL_CATALOG_PERSISTENCE_CONNECT_TIMEOUT: "5"
```

> 🔹 Even though the defaults are already set in the app, we explicitly define them in the ConfigMap.
> This demonstrates *Configuration as Code* — making all runtime configuration visible and manageable via Kubernetes manifests.

---

## **Step-02: Update Deployment to use ConfigMap**

**Manifest:** `01_catalog_deployment.yaml`

Under the container section, add:

```yaml
      containers:
        - name: catalog
          envFrom:
            - configMapRef:
                name: catalog
```

> This tells Kubernetes to load all key-value pairs from the ConfigMap as environment variables inside the container.

---

## **Step-03: Deploy and Verify**

```bash
kubectl apply -f catalog_k8s_manifests/
```

Once the pod is running, verify environment variables inside the container:

```bash
kubectl exec -it <catalog-pod-name> -- env
```

You should see all environment variables from the ConfigMap:

```
RETAIL_CATALOG_PERSISTENCE_PROVIDER=in-memory
RETAIL_CATALOG_PERSISTENCE_DB_NAME=catalogdb
RETAIL_CATALOG_PERSISTENCE_USER=catalog_user
RETAIL_CATALOG_PERSISTENCE_CONNECT_TIMEOUT=5
RETAIL_CATALOG_PERSISTENCE_ENDPOINT=
RETAIL_CATALOG_PERSISTENCE_PASSWORD=
```

---

## **Step-04: Clean-Up**

```bash
kubectl delete -f catalog_k8s_manifests/
```

This will delete all the resources (Deployment, Service, ConfigMap) created for this demo.

---

## ✅ **Summary**

* ConfigMaps help externalize configuration from the container image.
* We defined all environment variables explicitly, even defaults.
* Deployment consumed ConfigMap via `envFrom`.
* Verified that environment variables were successfully injected into the container.

---

