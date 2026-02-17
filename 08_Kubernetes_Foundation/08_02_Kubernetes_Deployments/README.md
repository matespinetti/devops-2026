# 08-02: Kubernetes Deployment – Rolling Updates, Readiness, Liveness, Scaling & Rollback

In this demo, we’ll create a **Kubernetes Deployment** for the **Catalog microservice**.
We’ll explore how Deployments manage Pods using ReplicaSets, perform **rolling updates** for zero downtime,
and how to **scale** the application up and down with simple commands.

---

## Learning Objectives

✅ Understand why we use a **Deployment** instead of standalone Pods
✅ Learn the relationship: **Deployment → ReplicaSet → Pod**
✅ Perform **scaling operations** (scale up / down)
✅ Test **rolling updates** and **rollbacks**
✅ Implement **readiness** and **liveness probes**
✅ Apply **security best practices** for production containers

---

## Why Deployment?

A **Deployment** in Kubernetes:

* Ensures the desired number of Pods are always running
* Automatically replaces unhealthy Pods via its ReplicaSet
* Supports **rolling updates** for version upgrades
* Allows **easy rollback** to previous versions
* Provides **horizontal scaling** with a single command

**Flow:**
`Deployment` → manages → `ReplicaSet` → creates → `Pods`

---

## YAML Manifest – `01_catalog_deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog
  labels:
    app.kubernetes.io/name: catalog
spec:
  replicas: 1
  strategy:
    rollingUpdate:
      maxUnavailable: 1
    type: RollingUpdate
  selector:
    matchLabels:
      app.kubernetes.io/name: catalog
  template:
    metadata:
      labels:
        app.kubernetes.io/name: catalog
    spec:
      securityContext:
        fsGroup: 1000
      containers:
        - name: catalog
          securityContext:
            capabilities:
              drop:
              - ALL
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 1000
          image: "public.ecr.aws/aws-containers/retail-store-sample-catalog:1.3.0"
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 8080
              protocol: TCP
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
          resources:
            limits:
              cpu: 200m
              memory: 256Mi
            requests:
              cpu: 100m
              memory: 256Mi
```

---

## Probes Explained

| Probe Type          | Purpose                                   | Example Path | Behavior                                                       |
| ------------------- | ----------------------------------------- | ------------ | -------------------------------------------------------------- |
| **Readiness Probe** | Checks if Pod is *ready* to serve traffic | `/health`    | If it fails, Pod is temporarily removed from Service endpoints |
| **Liveness Probe**  | Checks if container is *alive*            | `/health`    | If it fails repeatedly, kubelet restarts the container         |

> **Tip:** Liveness probes can detect deadlocks or hung processes.
> Use `initialDelaySeconds` or a `startupProbe` to delay early liveness checks.

---

## Rolling Update Strategy

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 1
```

* **RollingUpdate** → replaces Pods gradually without downtime
* **maxUnavailable: 1** → ensures at most one Pod is down during rollout

**Result:** Users experience **zero downtime** while updates roll out.

---

## Security Context Highlights

| Setting                        | Description                                                 |
| ------------------------------ | ----------------------------------------------------------- |
| `runAsNonRoot: true`           | Runs container as non-root user                             |
| `readOnlyRootFilesystem: true` | Prevents writes to filesystem                               |
| `capabilities.drop: [ALL]`     | Removes unnecessary Linux capabilities                      |
| `fsGroup: 1000`                | Ensures shared volume files are accessible to non-root user |

---

## Step-01: Deploy the Catalog Microservice

```bash
kubectl apply -f 01_catalog_deployment.yaml
```

---

## Step-02: Verify Deployment, ReplicaSet, and Pod

```bash
kubectl get deployment
kubectl get replicaset
kubectl get pods -o wide
```

Check rollout status:

```bash
kubectl rollout status deployment/catalog
```

Describe the Pod to view probes and security context:

```bash
kubectl describe pod <pod-name>
```

---

## Step-03: Access the Application via Port Forwarding
```
# Expose the Pod locally using:
kubectl port-forward deploy/catalog 7080:8080

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

## Step-04: Scaling the Deployment

### Scale Up (1 → 3 replicas)

```bash
kubectl scale deployment catalog --replicas=3
```

Check:

```bash
kubectl get pods -o wide
```

You should now see **3 running Pods**.

### Scale Down (3 → 1 replica)

```bash
kubectl scale deployment catalog --replicas=1
```

Check again:

```bash
kubectl get pods
```

Kubernetes terminates extra Pods gracefully.

---

## Step-05: Rolling Update (Upgrade App Version)

### Scale Up (1 → 3 replicas)
We’ll now simulate a **version upgrade** from `1.0.0` to `1.3.0`.

```bash
kubectl scale deployment catalog --replicas=3
```

### Update the Deployment image

```bash
# List Deployment Revisions
kubectl rollout history deployment/catalog

# Update the Deployment
kubectl set image deployment/catalog catalog=public.ecr.aws/aws-containers/retail-store-sample-catalog:1.3.0

# List Deployment Revisions
kubectl rollout history deployment/catalog
```

Verify rollout status:

```bash
kubectl rollout status deployment/catalog
```

You’ll see Pods being updated **one by one** (rolling update).

Confirm new version:

```bash
kubectl get pods -o wide
kubectl describe pod <pod-name> | grep Image
```
---

## Step-06: Rollback to Previous Version (1.0.0)

If something goes wrong, roll back easily:

```bash
# Rollback to previous version
kubectl rollout undo deployment/catalog

# List Deployment Revisions
kubectl rollout history deployment/catalog
```

or rollback to a specific revision:

```bash
# List Deployment Revisions
kubectl rollout history deployment/catalog

# rollback to a specific revision
kubectl rollout undo deployment/catalog --to-revision=<X>

# List Deployment Revisions
kubectl rollout history deployment/catalog
```

Check the version after rollback:

```bash
kubectl describe deployment catalog | grep Image
```

---

## Step-07: Cleanup

```bash
kubectl delete deployment catalog
```

---

## Summary

| Feature              | Description                                           |
| -------------------- | ----------------------------------------------------- |
| **Deployment**       | Manages Pods & ensures desired state                  |
| **ReplicaSet**       | Keeps specified number of Pods running                |
| **Rolling Update**   | Gradual version upgrade with zero downtime            |
| **Rollback**         | Instantly revert to previous working version          |
| **Scaling**          | Scale Pods up/down using a single command             |
| **Probes**           | Keep Pods healthy & automatically restarted if needed |
| **Security Context** | Enforces least privilege and non-root execution       |

---

