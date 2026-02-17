# 08-03: Kubernetes Services

### **Step-01: Verify existing Deployment**

```bash
kubectl get deploy catalog
kubectl get pods -l app.kubernetes.io/name=catalog
```

Ensure 3 replicas are running.

---

### **Step-02: Create ClusterIP Service**

**File:** `02_catalog_clusterip_service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: catalog-service
  labels:
    app.kubernetes.io/name: catalog
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: catalog
  ports:
    - name: http
      port: 8080
      targetPort: 8080
      protocol: TCP
```

---

### **Step-03: Apply and verify**

```bash
kubectl apply -f 02_catalog_clusterip_service.yaml
kubectl get svc
kubectl describe svc catalog-service
```

Highlight output:

* **Type:** ClusterIP
* **ClusterIP:** 10.x.x.x
* **Ports:** 8080/TCP
* **Endpoints:** Pod IPs behind the service

---

### **Step-04: Inspect EndpointSlices and Pod Matching**

After creating the service, verify how Kubernetes automatically links **Pods to the Service** using **labels**.

```bash
kubectl get pods -o wide
kubectl get endpointslices -l kubernetes.io/service-name=catalog-service
```

You should see something like:

```
NAME                    ADDRESSTYPE   PORTS   ENDPOINTS
catalog-service-abcde   IPv4          8080    10.0.11.45,10.0.12.18,10.0.13.29
```

- ✅ **Key concept:**
Kubernetes **uses the selector labels** in the Service definition to automatically discover Pods that match those labels.
It then creates an **EndpointSlice** object listing the **Pod IPs** and **ports** that belong to that Service.

> Even if pods restart and get new IPs, the EndpointSlice automatically updates ensuring the Service always routes traffic to healthy, matching pods.

---

### **Step-05: Verify Service Connectivity (Internal Test)**

Run a test pod inside the same namespace:

```bash
kubectl run test --image=curlimages/curl -it --rm -- sh
```

Inside the pod:

```bash
curl http://catalog-service:8080/topology
```

Expected output:

```json
{"databaseEndpoint":"N/A","persistenceProvider":"in-memory"}
```

Then exit.

> “This proves that even though our pods have dynamic IPs, we can consistently reach the catalog application using the service name.”

---

### **Step-06: DNS Resolution Check**

```bash
kubectl run dns-test --image=busybox:1.28 -it --rm
```

Inside pod:

```bash
nslookup catalog-service
```

Explain how Kubernetes DNS automatically creates entries like:

```
catalog-service.default.svc.cluster.local
```

---

## Step-07: Clean Up 

```bash
# Delete k8s Resources
kubectl delete svc catalog-service
kubectl delete deploy catalog

### OR ###

# Delete using YAML files
kubectl delete -f catalog_k8s_manifests
```

