# 17_02: Karpenter On-Demand Instances - Autoscaling Demo

## Step-01: Introduction

In this section, we will demonstrate **Karpenter's autoscaling capabilities** using **on-demand instances**.

We'll deploy a simple test application that triggers Karpenter to provision new nodes based on pod resource requirements, and then observe how Karpenter automatically **consolidates and removes nodes** when they're no longer needed.

### What You'll Learn

- How Karpenter provisions on-demand nodes based on pod requirements
- Observing node scaling up (from 5 to 10 replicas)
- Observing node scaling down (from 10 to 2 replicas)
- Understanding Karpenter's consolidation behavior
- Verifying NodeClaims and Node lifecycle

### Prerequisites

- Karpenter controller installed and running
- On-demand NodePool configured and applied
- EC2NodeClass configured

---

## Step-02: Review On-Demand Autoscaling Test Manifest

### File Structure

```
17_02_Karpenter_OnDemand_Instances/
├── README.md
└── kube-manifests-On-demand/
    └── On-demand_autoscaling_test.yaml
```

### Manifest Overview

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: karpenter-autoscale-demo-ondemand
  labels:
    demo: karpenter-ondemand
spec:
  replicas: 5  # Cost-effective demo - shows scaling without burning money
  selector:
    matchLabels:
      app: autoscale-demo
  template:
    metadata:
      labels:
        app: autoscale-demo
    spec:
      # Force pods to on-demand nodes
      nodeSelector:
        karpenter.sh/capacity-type: on-demand
      
      containers:
        - name: pause
          image: public.ecr.aws/eks-distro/kubernetes/pause:3.9
          resources:
            requests:
              cpu: "500m"
              memory: "256Mi"
            limits:
              cpu: "500m"
              memory: "256Mi"
```

**Key Configuration:**

- **5 replicas** - Cost-effective starting point (5 pods × 500m CPU = 2.5 vCPUs needed)
- **nodeSelector** - Ensures pods land only on on-demand nodes
- **Resource requests** - 500m CPU + 256Mi memory per pod
- **pause container** - Minimal overhead, perfect for demos

---

## Step-03: Deploy Application and Observe Initial Scaling

### Deploy the Application

```bash
# Change to the project directory
cd 17_02_Karpenter_OnDemand_Instances

# Deploy the autoscaling test deployment
kubectl apply -f kube-manifests-On-demand/On-demand_autoscaling_test.yaml

# Output
deployment.apps/karpenter-autoscale-demo-ondemand created
```

### Observe Pods in Pending State

Initially, pods will be in **Pending** state while Karpenter provisions new nodes:

```bash
# Check pod status
kubectl get pods

# Output
NAME                                                 READY   STATUS    RESTARTS   AGE
karpenter-autoscale-demo-ondemand-6bd55b7cdd-76xch   0/1     Pending   0          13s
karpenter-autoscale-demo-ondemand-6bd55b7cdd-bs5mr   0/1     Pending   0          13s
karpenter-autoscale-demo-ondemand-6bd55b7cdd-btkzz   0/1     Pending   0          13s
karpenter-autoscale-demo-ondemand-6bd55b7cdd-mcwkj   0/1     Pending   0          13s
karpenter-autoscale-demo-ondemand-6bd55b7cdd-vxmnl   0/1     Pending   0          14s
```

### Watch Karpenter Create NodeClaims

Karpenter will create **NodeClaims** to provision the required nodes:

```bash
# Check NodeClaims
kubectl get nodeclaims

# Output
NAME                      TYPE        CAPACITY    ZONE         NODE   READY     AGE
ondemand-nodepool-fqzc8   t3.small    on-demand   us-east-1b          Unknown   28s
ondemand-nodepool-w4dlq   t3a.small   on-demand   us-east-1c          Unknown   28s
```

**What's Happening:**

- Karpenter calculated: 5 pods × 500m CPU = 2.5 vCPUs needed
- Provisioned **2× t3.small** (2 vCPU each = 4 vCPUs total)
- Chose smallest instance types to fit workload efficiently

### Watch Nodes Become Ready

```bash
# Check nodes (initial state - NotReady)
kubectl get nodes

# Output
NAME                          STATUS     ROLES    AGE   VERSION
ip-10-0-10-57.ec2.internal    Ready      <none>   38m   v1.34.1-eks-c39b1d0
ip-10-0-11-119.ec2.internal   NotReady   <none>   10s   v1.34.1-eks-c39b1d0
ip-10-0-11-72.ec2.internal    Ready      <none>   38m   v1.34.1-eks-c39b1d0
ip-10-0-12-232.ec2.internal   Ready      <none>   38m   v1.34.1-eks-c39b1d0
ip-10-0-12-93.ec2.internal    NotReady   <none>   5s    v1.34.1-eks-c39b1d0
```

After ~20-30 seconds, nodes become **Ready**:

```bash
# Check nodes again
kubectl get nodes

# Output
NAME                          STATUS   ROLES    AGE   VERSION
ip-10-0-10-57.ec2.internal    Ready    <none>   38m   v1.34.1-eks-c39b1d0
ip-10-0-11-119.ec2.internal   Ready    <none>   23s   v1.34.1-eks-c39b1d0
ip-10-0-11-72.ec2.internal    Ready    <none>   38m   v1.34.1-eks-c39b1d0
ip-10-0-12-232.ec2.internal   Ready    <none>   38m   v1.34.1-eks-c39b1d0
ip-10-0-12-93.ec2.internal    Ready    <none>   18s   v1.34.1-eks-c39b1d0
```

### Verify Pods Running

```bash
# Check pod status
kubectl get pods

# Output
NAME                                                 READY   STATUS    RESTARTS   AGE
karpenter-autoscale-demo-ondemand-6bd55b7cdd-76xch   1/1     Running   0          57s
karpenter-autoscale-demo-ondemand-6bd55b7cdd-bs5mr   1/1     Running   0          57s
karpenter-autoscale-demo-ondemand-6bd55b7cdd-btkzz   1/1     Running   0          57s
karpenter-autoscale-demo-ondemand-6bd55b7cdd-mcwkj   1/1     Running   0          57s
karpenter-autoscale-demo-ondemand-6bd55b7cdd-vxmnl   1/1     Running   0          58s
```

---

## Step-04: Scale Up to 10 Replicas

Now let's scale up to **10 replicas** and observe Karpenter provision additional nodes:

```bash
# Scale deployment to 10 replicas
kubectl scale deploy/karpenter-autoscale-demo-ondemand --replicas=10

# Output
deployment.apps/karpenter-autoscale-demo-ondemand scaled
```

### Observe New Pods in Pending State

```bash
# Check pods
kubectl get pods

# Output
NAME                                                 READY   STATUS    RESTARTS   AGE
karpenter-autoscale-demo-ondemand-6bd55b7cdd-76xch   1/1     Running   0          104s
karpenter-autoscale-demo-ondemand-6bd55b7cdd-7qqh4   0/1     Pending   0          5s
karpenter-autoscale-demo-ondemand-6bd55b7cdd-bs5mr   1/1     Running   0          104s
karpenter-autoscale-demo-ondemand-6bd55b7cdd-btkzz   1/1     Running   0          104s
karpenter-autoscale-demo-ondemand-6bd55b7cdd-mcwkj   1/1     Running   0          104s
karpenter-autoscale-demo-ondemand-6bd55b7cdd-nv2d6   0/1     Pending   0          5s
karpenter-autoscale-demo-ondemand-6bd55b7cdd-p6xrb   0/1     Pending   0          5s
karpenter-autoscale-demo-ondemand-6bd55b7cdd-tghfb   0/1     Pending   0          5s
karpenter-autoscale-demo-ondemand-6bd55b7cdd-tm5zl   0/1     Pending   0          5s
karpenter-autoscale-demo-ondemand-6bd55b7cdd-vxmnl   1/1     Running   0          105s
```

### Watch Karpenter Create Additional NodeClaims

```bash
# Check NodeClaims
kubectl get nodeclaims

# Output
NAME                      TYPE        CAPACITY    ZONE         NODE                          READY     AGE
ondemand-nodepool-fqzc8   t3.small    on-demand   us-east-1b   ip-10-0-11-119.ec2.internal   True      116s
ondemand-nodepool-w4dlq   t3a.small   on-demand   us-east-1c   ip-10-0-12-93.ec2.internal    True      116s
ondemand-nodepool-wpw4p   t3.small    on-demand   us-east-1b                                 Unknown   17s
ondemand-nodepool-zqzd2   t3a.small   on-demand   us-east-1b                                 Unknown   17s
```

**What's Happening:**

- 5 additional pods × 500m CPU = 2.5 vCPUs needed
- Karpenter provisioned **2 more t3.small** nodes
- Total: **4 nodes** to handle 10 pods (5 vCPUs total requirement)

### Verify All Nodes Ready

```bash
# Check nodes
kubectl get nodes

# Output
NAME                          STATUS   ROLES    AGE    VERSION
ip-10-0-10-57.ec2.internal    Ready    <none>   40m    v1.34.1-eks-c39b1d0
ip-10-0-11-119.ec2.internal   Ready    <none>   2m5s   v1.34.1-eks-c39b1d0
ip-10-0-11-70.ec2.internal    Ready    <none>   27s    v1.34.1-eks-c39b1d0
ip-10-0-11-72.ec2.internal    Ready    <none>   40m    v1.34.1-eks-c39b1d0
ip-10-0-11-90.ec2.internal    Ready    <none>   29s    v1.34.1-eks-c39b1d0
ip-10-0-12-232.ec2.internal   Ready    <none>   40m    v1.34.1-eks-c39b1d0
ip-10-0-12-93.ec2.internal    Ready    <none>   2m     v1.34.1-eks-c39b1d0
```

### Verify All Pods Running

```bash
# Check pods
kubectl get pods

# Output
NAME                                                 READY   STATUS    RESTARTS   AGE
karpenter-autoscale-demo-ondemand-6bd55b7cdd-76xch   1/1     Running   0          2m39s
karpenter-autoscale-demo-ondemand-6bd55b7cdd-7qqh4   1/1     Running   0          60s
karpenter-autoscale-demo-ondemand-6bd55b7cdd-bs5mr   1/1     Running   0          2m39s
karpenter-autoscale-demo-ondemand-6bd55b7cdd-btkzz   1/1     Running   0          2m39s
karpenter-autoscale-demo-ondemand-6bd55b7cdd-mcwkj   1/1     Running   0          2m39s
karpenter-autoscale-demo-ondemand-6bd55b7cdd-nv2d6   1/1     Running   0          60s
karpenter-autoscale-demo-ondemand-6bd55b7cdd-p6xrb   1/1     Running   0          60s
karpenter-autoscale-demo-ondemand-6bd55b7cdd-tghfb   1/1     Running   0          60s
karpenter-autoscale-demo-ondemand-6bd55b7cdd-tm5zl   1/1     Running   0          60s
karpenter-autoscale-demo-ondemand-6bd55b7cdd-vxmnl   1/1     Running   0          2m40s
```

---

## Step-05: Scale Down to 2 Replicas and Observe Consolidation

Now let's scale down to **2 replicas** and watch Karpenter **consolidate and terminate** underutilized nodes:

```bash
# Scale down to 2 replicas
kubectl scale deploy/karpenter-autoscale-demo-ondemand --replicas=2

# Output
deployment.apps/karpenter-autoscale-demo-ondemand scaled
```

### Observe Pod Termination

```bash
# Check pods
kubectl get pods

# Output
NAME                                                 READY   STATUS    RESTARTS   AGE
karpenter-autoscale-demo-ondemand-6bd55b7cdd-76xch   1/1     Running   0          3m18s
karpenter-autoscale-demo-ondemand-6bd55b7cdd-bs5mr   1/1     Running   0          3m18s
```

**Note:** Only 2 pods remain running. The other 8 pods have been terminated.

### Watch Karpenter Consolidate Nodes

Karpenter's **consolidation policy** (`WhenEmptyOrUnderutilized`) kicks in after **30 seconds** (as configured in the NodePool):

```bash
# Check NodeClaims immediately after scaling down
kubectl get nodeclaims

# Output (nodes still present, but being evaluated)
NAME                      TYPE        CAPACITY    ZONE         NODE                          READY   AGE
ondemand-nodepool-fqzc8   t3.small    on-demand   us-east-1b   ip-10-0-11-119.ec2.internal   True    3m6s
ondemand-nodepool-qw9cb   t3a.small   on-demand   us-east-1a                                 Unknown 25s
ondemand-nodepool-w4dlq   t3a.small   on-demand   us-east-1c   ip-10-0-12-93.ec2.internal    True    3m6s
ondemand-nodepool-wpw4p   t3.small    on-demand   us-east-1b   ip-10-0-11-90.ec2.internal    True    87s
ondemand-nodepool-zqzd2   t3a.small   on-demand   us-east-1b   ip-10-0-11-70.ec2.internal    True    87s
```

**What's Happening:**

- Karpenter detects underutilized nodes
- After 30s (`consolidateAfter: 30s`), it begins draining and terminating nodes
- A new, smaller node may be created to consolidate remaining workload

### Observe Node Draining

```bash
# Check nodes - some will show NotReady status during draining
kubectl get nodes

# Output
NAME                          STATUS     ROLES    AGE     VERSION
ip-10-0-10-38.ec2.internal    Ready      <none>   19s     v1.34.1-eks-c39b1d0
ip-10-0-10-57.ec2.internal    Ready      <none>   41m     v1.34.1-eks-c39b1d0
ip-10-0-11-119.ec2.internal   NotReady   <none>   2m57s   v1.34.1-eks-c39b1d0
ip-10-0-11-70.ec2.internal    Ready      <none>   79s     v1.34.1-eks-c39b1d0
ip-10-0-11-72.ec2.internal    Ready      <none>   41m     v1.34.1-eks-c39b1d0
ip-10-0-11-90.ec2.internal    Ready      <none>   81s     v1.34.1-eks-c39b1d0
ip-10-0-12-232.ec2.internal   Ready      <none>   41m     v1.34.1-eks-c39b1d0
ip-10-0-12-93.ec2.internal    Ready      <none>   2m52s   v1.34.1-eks-c39b1d0
```

**Note:** `ip-10-0-11-119.ec2.internal` is in **NotReady** state as it's being drained.

### Final State - Consolidated NodeClaims

After a few minutes, only the necessary nodes remain:

```bash
# Check final NodeClaims state
kubectl get nodeclaims

# Output
NAME                      TYPE        CAPACITY    ZONE         NODE                         READY   AGE
ondemand-nodepool-qw9cb   t3a.small   on-demand   us-east-1a   ip-10-0-10-38.ec2.internal   True    2m48s
```

**Result:**

- Karpenter consolidated workload to a **single t3a.small** node
- 2 pods × 500m CPU = 1 vCPU (fits easily on one t3a.small with 2 vCPUs)
- All other nodes terminated automatically

---

## Step-06: Clean Up and Observe Final Consolidation

Let's delete the deployment entirely and watch Karpenter clean up all provisioned nodes:

```bash
# Delete the deployment
kubectl delete -f kube-manifests-On-demand/

# Output
deployment.apps "karpenter-autoscale-demo-ondemand" deleted
```

### Watch Nodes Get Drained

```bash
# Check nodes immediately after deletion
kubectl get nodes

# Output
NAME                          STATUS     ROLES    AGE     VERSION
ip-10-0-10-38.ec2.internal    Ready      <none>   2m14s   v1.34.1-eks-c39b1d0
ip-10-0-10-57.ec2.internal    Ready      <none>   42m     v1.34.1-eks-c39b1d0
ip-10-0-11-70.ec2.internal    NotReady   <none>   3m14s   v1.34.1-eks-c39b1d0
ip-10-0-11-72.ec2.internal    Ready      <none>   42m     v1.34.1-eks-c39b1d0
ip-10-0-12-232.ec2.internal   Ready      <none>   42m     v1.34.1-eks-c39b1d0
```

### Watch NodeClaims Get Removed

```bash
# Check NodeClaims
kubectl get nodeclaims

# Output (last remaining node being evaluated)
NAME                      TYPE        CAPACITY    ZONE         NODE                         READY   AGE
ondemand-nodepool-qw9cb   t3a.small   on-demand   us-east-1a   ip-10-0-10-38.ec2.internal   True    3m31s
```

After ~30 seconds (consolidation wait time):

```bash
# Check NodeClaims again
kubectl get nodeclaims

# Output
No resources found
```

### Verify All Karpenter-Managed Nodes Removed

```bash
# Check final node state
kubectl get nodes

# Output (only original EKS managed nodes remain)
NAME                          STATUS   ROLES    AGE   VERSION
ip-10-0-10-57.ec2.internal    Ready    <none>   44m   v1.34.1-eks-c39b1d0
ip-10-0-11-72.ec2.internal    Ready    <none>   44m   v1.34.1-eks-c39b1d0
ip-10-0-12-232.ec2.internal   Ready    <none>   44m   v1.34.1-eks-c39b1d0
```

**Result:**

- All Karpenter-managed nodes terminated
- Only original EKS managed node group nodes remain
- Cluster back to baseline state

---

## Step-07: Key Observations and Learning Points

### What We Demonstrated

✅ **Autoscaling Up:**
- Karpenter provisions nodes **within 30-60 seconds** based on pod requirements
- Intelligently selects smallest instance types (t3.small, t3a.small)
- Creates NodeClaims → Launches EC2 instances → Nodes become Ready

✅ **Autoscaling Down:**
- Karpenter waits **30 seconds** (`consolidateAfter: 30s`) before consolidating
- Drains underutilized nodes gracefully
- Terminates unnecessary nodes to save costs

✅ **Cost Efficiency:**
- Entire demo cost: **~$0.02 for ~10 minutes** of testing
- Automatic cleanup prevents forgotten resources

### Karpenter vs Traditional Cluster Autoscaler

| **Feature** | **Karpenter** | **Cluster Autoscaler** |
|-------------|---------------|------------------------|
| **Provisioning Speed** | 30-60 seconds | 2-5 minutes |
| **Instance Selection** | Intelligent, considers multiple types | Limited to predefined node groups |
| **Consolidation** | Automatic, configurable | Manual or slow |
| **Cost Optimization** | Built-in, proactive | Reactive |

---

## Step-08: Troubleshooting Tips

### Issue: Pods Stuck in Pending

**Possible Causes:**
- NodePool not applied or misconfigured
- EC2NodeClass missing or incorrect
- Insufficient CPU limits in NodePool (`limits.cpu`)
- No matching instance types available in the region

**Solution:**
```bash
# Check NodePool status
kubectl get nodepool

# Check Karpenter controller logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -f
```

### Issue: Nodes Not Being Removed After Scale Down

**Possible Causes:**
- `consolidationPolicy` not set to `WhenEmptyOrUnderutilized`
- `consolidateAfter` duration too long
- Pods with PodDisruptionBudget blocking eviction

**Solution:**
```bash
# Verify NodePool disruption settings
kubectl get nodepool ondemand-nodepool -o yaml | grep -A5 disruption
```

---

## Summary

In this demo, you successfully:

✅ Deployed an autoscaling test application with on-demand instances  
✅ Observed Karpenter provision nodes based on pod requirements  
✅ Scaled up from 5 → 10 replicas and watched new nodes appear  
✅ Scaled down from 10 → 2 replicas and observed node consolidation  
✅ Cleaned up and verified automatic node termination  

**Next Steps:** Explore Karpenter with **Spot Instances** for even greater cost savings! 🚀

---

## 🔄 How Karpenter Works

### Provisioning Flow

```
1. Pod created with resource requests
   ↓
2. Kubernetes scheduler: No capacity available
   ↓
3. Pod marked as "Unschedulable"
   ↓
4. Karpenter detects unschedulable pod
   ↓
5. Karpenter analyzes pod requirements:
   - CPU, memory, GPU
   - Node selectors, affinity rules
   - Topology constraints
   ↓
6. Karpenter selects optimal instance type
   ↓
7. Karpenter launches EC2 instance
   ↓
8. Node joins cluster (30-60 seconds)
   ↓
9. Pod scheduled on new node
```

### Deprovisioning Flow

```
1. Node becomes underutilized (low CPU/memory)
   ↓
2. Karpenter waits consolidateAfter period (30s)
   ↓
3. Karpenter cordons node (mark unschedulable)
   ↓
4. Karpenter drains node (evicts pods gracefully)
   ↓
5. Pods rescheduled to other nodes
   ↓
6. Karpenter terminates EC2 instance
   ↓
7. Node removed from cluster
```

### Spot Interruption Handling

```
1. AWS sends spot interruption warning (2 min notice)
   ↓
2. EventBridge catches event → SQS
   ↓
3. Karpenter polls SQS (~20s interval)
   ↓
4. Karpenter receives interruption message
   ↓
5. Karpenter cordons node immediately
   ↓
6. Karpenter provisions replacement node
   ↓
7. Karpenter drains interrupted node
   ↓
8. Pods migrate to new node
   ↓
9. Interrupted node terminates gracefully
```

---
