# Section 08-01: Kubernetes Pod Basics – Catalog Microservice

In this first Kubernetes demo, we’ll deploy a **single Pod** for the **Catalog microservice** from the AWS Retail Store Sample App.
This marks the beginning of our Kubernetes journey — starting simple, focusing on fundamentals, and understanding how Pods work at the most basic level.

---

## Learning Objectives

* Understand what a **Pod** is in Kubernetes.
* Deploy your first **Pod manifest**.
* Inspect Pod details and status.
* View **application logs** directly from the Pod.
* Access the Pod application using **port-forward**.
* Connect **inside the Pod** container using `kubectl exec`.
* Additional Concepts
  * Readiness Probe
  * Resources: Requests and Limits

---

## Step-01: Review the Pod Manifest

**File:** `01_catalog_pod.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: catalog-pod
  labels:
    app: catalog
spec:
  containers:
    - name: catalog
      image: "public.ecr.aws/aws-containers/retail-store-sample-catalog:1.3.0"
      ports:
        - name: http
          containerPort: 8080
          protocol: TCP
      resources:
        requests: 
          cpu: "100m"
          memory: "128Mi" 
        limits:   
          cpu: "250m"
          memory: "256Mi"
      readinessProbe:
        httpGet:
          path: /health
          port: 8080
```

---

## Step-02: Deploy the Pod

```bash
kubectl apply -f 01_catalog_pod.yaml
```

✅ Expected output:

```
pod/catalog-pod created
```

---

## Step-03: Verify Pod Status

```bash
kubectl get pods
```

Example output:

```
NAME           READY   STATUS    RESTARTS   AGE
catalog-pod    1/1     Running   0          25s
```

---

## Step-04: Describe the Pod

```bash
kubectl describe pod catalog-pod
```

This command shows detailed Pod info like:

* Image used
* Events
* Probes
* Resource requests/limits

---

## Step-05: View Pod Logs

```bash
kubectl logs -f catalog-pod
```

Example logs:

```
Using in-memory database
Running database migration...
Database migration complete
[GIN] 2025/10/06 - 02:12:15 | 200 | 62.471µs | 10.0.11.241 | GET "/health"
[GIN] 2025/10/06 - 02:12:25 | 200 | 65.235µs | 10.0.11.241 | GET "/health"
[GIN] 2025/10/06 - 02:12:35 | 200 | 43.681µs | 10.0.11.241 | GET "/health"
```

These logs confirm that:

* The application started successfully.
* Readiness probe `/health` is being called periodically by Kubernetes.

---

## Step-06: Access the Application via Port Forwarding
```
# Expose the Pod locally using:
kubectl port-forward pod/catalog-pod 7080:8080

# Topology Endpoint
http://localhost:7080/topology

# Health Endpoint
http://localhost:7080/health

# Catalog - Get Products
http://localhost:7080/catalog/products

# Catalog - Get Products By ID
http://localhost:7080/catalog/products/d77f9ae6-e9a8-4a3e-86bd-b72af75cbc49

# Catalog - Get Size
http://localhost:7080/catalog/size

# Catalog - Get Tags
http://localhost:7080/catalog/tags
```

---

## Step-07: Connect Inside the Pod

Use `kubectl exec` to open a shell inside the container:

```bash
kubectl exec -it catalog-pod -- sh
```

Example:

```
kalyan-mac-mini4:catalog_k8s_manifests kalyan$ kubectl exec -it catalog-pod -- sh
sh-5.2$ id
uid=1000(appuser) gid=1000(appuser) groups=1000(appuser)
sh-5.2$ ls
LICENSES.md  main
sh-5.2$ 

```

Use `exit` to leave the container shell.

---

## Step-08: Clean Up

```bash
kubectl delete pod catalog-pod
```

✅ Output:

```
pod "catalog-pod" deleted
```

---

## 🧠 Recap

* Pods are **the smallest deployable unit** in Kubernetes.
* Each Pod wraps **one or more containers** that share:

  * Network (same IP)
  * Storage (shared volumes)
  * Lifecycle (scheduled together)
* This demo introduced:

  * Pod manifest structure
  * Resource requests/limits
  * Readiness probes
  * Port-forwarding and exec commands

---

### Next: Deployments, Probes, ConfigMaps & ServiceAccounts

In the next section, we’ll evolve this single Pod into a **Deployment**,
and then add **readiness + liveness probes**, **ConfigMaps**, and **ServiceAccounts** to simulate a more production-like setup.

---

