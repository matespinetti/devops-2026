# 17_03: Karpenter Spot Instances - Basic Demo

## Step-01: Introduction

In this section, we will demonstrate **Karpenter with Spot instances** - AWS EC2 instances available at up to **90% discount** compared to On-Demand pricing.

Unlike the previous On-Demand demo where we explored scaling mechanics in detail, this demo focuses on **what makes Spot instances unique** and how to verify you're actually getting Spot capacity.

### What You'll Learn

- Understanding Spot instances and their cost benefits
- How to configure workloads to run on Spot nodes
- Verifying that Karpenter provisions actual Spot instances
- Observing Karpenter's instance diversity strategy for Spot
- When to use Spot vs On-Demand capacity

### Spot Instances - Key Concepts

**What are Spot Instances?**
- Spare AWS compute capacity available at steep discounts
- **50-90% cheaper** than On-Demand instances (typically 70% savings)
- Can be **interrupted by AWS with 2-minute warning** when capacity is needed elsewhere
- AWS reclaims Spot instances when On-Demand demand increases

**Cost Comparison Example:**
| Instance Type | On-Demand Price | Spot Price | Savings |
|---------------|-----------------|------------|---------|
| t3.medium     | $0.0416/hour    | ~$0.0125/hour | 70% |
| c5a.large     | $0.077/hour     | ~$0.023/hour  | 70% |
| t3a.small     | $0.0188/hour    | ~$0.0056/hour | 70% |

**Best Use Cases for Spot:**
- ✅ Stateless web applications (can handle pod restarts)
- ✅ Batch processing jobs (fault-tolerant workloads)
- ✅ CI/CD pipelines (temporary workloads)
- ✅ Development/test environments
- ✅ Microservices with multiple replicas
- ❌ **Avoid for:** Databases, stateful apps, single-replica critical services

**Spot Interruption Behavior:**
- AWS sends a **2-minute termination notice** before reclaiming capacity
- Karpenter/Kubernetes drains the node gracefully
- Pods are rescheduled to other available nodes
- *(We'll cover interruption handling in detail in 17_04)*

### Prerequisites

- Karpenter controller installed and running
- Spot NodePool configured and applied
- EC2NodeClass configured

---

## Step-02: Review Spot NodePool Configuration

Before deploying our test application, let's review the Spot NodePool we created earlier:

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: spot-nodepool
spec:
  template:
    spec:
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default-ec2nodeclass

      taints: []
      startupTaints: []

      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]

        - key: kubernetes.io/os
          operator: In
          values: ["linux"]

        # Spot capacity (50-90% cheaper than on-demand)
        # Note: Spot instances can be interrupted with 2-minute notice
        # Best for fault-tolerant, stateless workloads        
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]

        # Multiple instance families for better spot availability
        - key: karpenter.k8s.aws/instance-family
          operator: In
          values: ["t3", "t3a", "t2", "c5a", "c6a"]

        # Allow micro to large - flexibility helps find available spot capacity
        - key: karpenter.k8s.aws/instance-size
          operator: In
          values: ["micro", "small", "medium", "large"]

        # Must match the AZs where your EKS cluster has subnets configured
        # Karpenter can only launch nodes in AZs with configured VPC subnets
        - key: topology.kubernetes.io/zone
          operator: In
          values: ["us-east-1a", "us-east-1b", "us-east-1c"]

  limits:
    cpu: "50"

  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 30s

    # Add budgets to control disruption rate
    budgets:
      - nodes: "100%"  # Allow all nodes to be disrupted if needed
        reasons:
          - "Drifted"
          - "Underutilized"
          - "Empty"    
```

**Key Spot-Specific Configurations:**

1. **`capacity-type: spot`** - Tells Karpenter to use only Spot instances
2. **Multiple instance families** - `t3`, `t3a`, `t2`, `c5a`, `c6a` increases Spot availability
3. **Flexible instance sizes** - `micro` to `large` gives more Spot options

**Why Multiple Instance Types?**
Spot capacity varies by instance type and availability zone. By allowing multiple types, Karpenter can find available Spot capacity more easily, reducing the risk of "insufficient capacity" errors.

---

## Step-03: Review Spot Autoscaling Test Manifest

### File Structure

```
17_03_Karpenter_Spot_Instances/
├── README.md
└── kube-manifests-Spot/
    └── Spot_autoscaling_test.yaml
```

### Manifest Overview

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: karpenter-autoscale-demo-spot
  labels:
    demo: karpenter-spot
spec:
  replicas: 5  # 5 pods = ~2.5 vCPUs needed
  selector:
    matchLabels:
      app: autoscale-demo-spot
  template:
    metadata:
      labels:
        app: autoscale-demo-spot
    spec:
      # THIS IS CRITICAL - Forces pods to run ONLY on Spot nodes
      nodeSelector:
        karpenter.sh/capacity-type: spot
      
      containers:
        - name: pause
          image: public.ecr.aws/eks-distro/kubernetes/pause:3.9
          resources:
            requests:
              cpu: "500m"      # 0.5 vCPU per pod
              memory: "256Mi"  # 256MB per pod
            limits:
              cpu: "500m"
              memory: "256Mi"
```

**Key Configuration:**

- **`nodeSelector: spot`** - Ensures pods **only** schedule on Spot nodes (won't fallback to On-Demand)
- **5 replicas** - 5 pods × 500m CPU = 2.5 vCPUs required
- **pause container** - Minimal resource usage, perfect for demos

**What Karpenter Will Do:**
With 2.5 vCPUs required, Karpenter will likely provision:
- **2× t3.small instances** (2 vCPU each = 4 vCPUs total) OR
- **2× t3a.small** (cheaper AMD-based alternative) OR
- **Mix of instance types** based on Spot availability

---

## Step-04: Deploy Application and Verify Spot Nodes

### Deploy the Spot Application

```bash
# Change to the project directory
cd 17_03_Karpenter_Spot_Instances

# Deploy the Spot autoscaling test deployment
kubectl apply -f kube-manifests-Spot/Spot_autoscaling_test.yaml

# Output
deployment.apps/karpenter-autoscale-demo-spot created
```

### Observe Pods in Pending State

Initially, pods will be **Pending** while Karpenter provisions Spot nodes:

```bash
# Check pod status
kubectl get pods

# Output
NAME                                             READY   STATUS    RESTARTS   AGE
karpenter-autoscale-demo-spot-7c8d9f6b5d-2xqhl   0/1     Pending   0          8s
karpenter-autoscale-demo-spot-7c8d9f6b5d-4vnpr   0/1     Pending   0          8s
karpenter-autoscale-demo-spot-7c8d9f6b5d-7kmwx   0/1     Pending   0          8s
karpenter-autoscale-demo-spot-7c8d9f6b5d-n8qzc   0/1     Pending   0          8s
karpenter-autoscale-demo-spot-7c8d9f6b5d-xhj2m   0/1     Pending   0          8s
```

### Watch Karpenter Create Spot NodeClaims

```bash
# Watch NodeClaims being created
kubectl get nodeclaims -w

# Output
NAME                   TYPE       CAPACITY   ZONE         NODE   READY     AGE
spot-nodepool-abc123   t3.small   spot       us-east-1a          Unknown   15s
spot-nodepool-xyz789   t3a.small  spot       us-east-1b          Unknown   15s
```

**Important:** Notice the **CAPACITY** column shows `spot` - this confirms Karpenter is creating Spot instances!

### Watch Nodes Become Ready

```bash
# Check nodes (wait ~30-60 seconds)
kubectl get nodes

# Initial state - NotReady
NAME                          STATUS     ROLES    AGE   VERSION
ip-10-0-10-57.ec2.internal    Ready      <none>   45m   v1.34.1-eks-c39b1d0
ip-10-0-11-72.ec2.internal    Ready      <none>   45m   v1.34.1-eks-c39b1d0
ip-10-0-12-145.ec2.internal   NotReady   <none>   12s   v1.34.1-eks-c39b1d0
ip-10-0-12-232.ec2.internal   Ready      <none>   45m   v1.34.1-eks-c39b1d0
ip-10-0-12-87.ec2.internal    NotReady   <none>   9s    v1.34.1-eks-c39b1d0
```

After ~30 seconds, nodes become **Ready**:

```bash
# Check nodes again
kubectl get nodes

# Output
NAME                          STATUS   ROLES    AGE   VERSION
ip-10-0-10-57.ec2.internal    Ready    <none>   45m   v1.34.1-eks-c39b1d0
ip-10-0-11-72.ec2.internal    Ready    <none>   45m   v1.34.1-eks-c39b1d0
ip-10-0-12-145.ec2.internal   Ready    <none>   35s   v1.34.1-eks-c39b1d0
ip-10-0-12-232.ec2.internal   Ready    <none>   45m   v1.34.1-eks-c39b1d0
ip-10-0-12-87.ec2.internal    Ready    <none>   32s   v1.34.1-eks-c39b1d0
```

---

## Step-05: Verify Spot Instances (Critical Verification Step!)

This is the most important part - **let's prove these are actually Spot instances!**

### Method 1: Check Capacity Type Label

Every node provisioned by Karpenter gets labeled with its capacity type:

```bash
# Filter nodes by capacity-type=spot
kubectl get nodes --selector=karpenter.sh/capacity-type=spot

# Output
NAME                          STATUS   ROLES    AGE   VERSION
ip-10-0-12-145.ec2.internal   Ready    <none>   45s   v1.34.1-eks-c39b1d0
ip-10-0-12-87.ec2.internal    Ready    <none>   42s   v1.34.1-eks-c39b1d0
```

✅ **Confirmed:** These nodes have the `karpenter.sh/capacity-type=spot` label!

### Method 2: Check Node Labels for Instance Details

```bash
# Get detailed labels from one Spot node
kubectl get node ip-10-0-12-145.ec2.internal -o json | jq '.metadata.labels'

# Output (relevant labels)
{
  "karpenter.sh/capacity-type": "spot",
  "node.kubernetes.io/instance-type": "t3a.small",
  "karpenter.k8s.aws/instance-family": "t3a",
  "karpenter.k8s.aws/instance-size": "small",
  "topology.kubernetes.io/zone": "us-east-1a"
}
```

**What This Tells Us:**
- ✅ `capacity-type: spot` - Confirmed Spot instance
- ✅ `instance-type: t3a.small` - AMD-based instance (typically cheaper)
- ✅ `zone: us-east-1a` - Availability zone placement

### Method 3: Verify Instance Diversity

One key advantage of Spot with Karpenter is **instance diversity** - mixing different instance types improves availability:

```bash
# Check instance types of all Spot nodes
kubectl get nodes -l karpenter.sh/capacity-type=spot \
  -o custom-columns=NAME:.metadata.name,INSTANCE-TYPE:.metadata.labels."node\.kubernetes\.io/instance-type"

# Output (example showing diversity)
NAME                          INSTANCE-TYPE
ip-10-0-12-145.ec2.internal   t3a.small
ip-10-0-12-87.ec2.internal    t3.small
```

**Why Different Types?**
- `t3a.small` - AMD-based, slightly cheaper
- `t3.small` - Intel-based, more available
- Karpenter picks whatever Spot capacity is available at the best price

### Method 4: Check EC2 Console (Optional)

If you want to verify in AWS Console:

```bash
# Get instance IDs
kubectl get nodes -l karpenter.sh/capacity-type=spot \
  -o custom-columns=NAME:.metadata.name,INSTANCE-ID:.spec.providerID | grep aws

# Output
NAME                          INSTANCE-ID
ip-10-0-12-145.ec2.internal   aws:///us-east-1a/i-0a1b2c3d4e5f67890
ip-10-0-12-87.ec2.internal    aws:///us-east-1b/i-0f9e8d7c6b5a43210
```

Then check EC2 Console → Instances → Filter by instance ID → Lifecycle should show **spot**.

---

## Step-06: Verify Pods Running on Spot Nodes

Now let's confirm our application pods are actually running on the Spot nodes:

```bash
# Check pod placement with node names
kubectl get pods -o wide

# Output
NAME                                             READY   STATUS    RESTARTS   NODE
karpenter-autoscale-demo-spot-7c8d9f6b5d-2xqhl   1/1     Running   0          ip-10-0-12-145.ec2.internal
karpenter-autoscale-demo-spot-7c8d9f6b5d-4vnpr   1/1     Running   0          ip-10-0-12-87.ec2.internal
karpenter-autoscale-demo-spot-7c8d9f6b5d-7kmwx   1/1     Running   0          ip-10-0-12-145.ec2.internal
karpenter-autoscale-demo-spot-7c8d9f6b5d-n8qzc   1/1     Running   0          ip-10-0-12-87.ec2.internal
karpenter-autoscale-demo-spot-7c8d9f6b5d-xhj2m   1/1     Running   0          ip-10-0-12-145.ec2.internal
```

**Perfect!** All 5 pods are running on the two Spot nodes we identified earlier.

### Verify Pod Distribution

```bash
# Count pods per node
kubectl get pods -o wide | grep karpenter-autoscale-demo-spot | awk '{print $7}' | sort | uniq -c

# Output
      3 ip-10-0-12-145.ec2.internal
      2 ip-10-0-12-87.ec2.internal
```

Karpenter distributed pods across both Spot nodes for better availability.

---

## Step-07: Clean Up and Observe Node Removal

Let's delete the deployment and watch Karpenter automatically clean up the Spot nodes:

```bash
# Delete the deployment
kubectl delete -f kube-manifests-Spot/Spot_autoscaling_test.yaml

# Output
deployment.apps "karpenter-autoscale-demo-spot" deleted
```

### Watch Pods Terminate

```bash
# Check pods (should show Terminating)
kubectl get pods

# Output
NAME                                             READY   STATUS        RESTARTS   AGE
karpenter-autoscale-demo-spot-7c8d9f6b5d-2xqhl   1/1     Terminating   0          3m45s
karpenter-autoscale-demo-spot-7c8d9f6b5d-4vnpr   1/1     Terminating   0          3m45s
```

### Watch Nodes Get Drained

After the `consolidateAfter: 30s` wait period:

```bash
# Check nodes
kubectl get nodes

# Output (Spot nodes will show NotReady during drain)
NAME                          STATUS     ROLES    AGE     VERSION
ip-10-0-10-57.ec2.internal    Ready      <none>   50m     v1.34.1-eks-c39b1d0
ip-10-0-11-72.ec2.internal    Ready      <none>   50m     v1.34.1-eks-c39b1d0
ip-10-0-12-145.ec2.internal   NotReady   <none>   4m20s   v1.34.1-eks-c39b1d0
ip-10-0-12-232.ec2.internal   Ready      <none>   50m     v1.34.1-eks-c39b1d0
ip-10-0-12-87.ec2.internal    NotReady   <none>   4m17s   v1.34.1-eks-c39b1d0
```

### Watch NodeClaims Get Removed

```bash
# Check NodeClaims
kubectl get nodeclaims

# Output (initially still present)
NAME                   TYPE       CAPACITY   ZONE         NODE                          READY   AGE
spot-nodepool-abc123   t3.small   spot       us-east-1a   ip-10-0-12-145.ec2.internal   False   4m35s
spot-nodepool-xyz789   t3a.small  spot       us-east-1b   ip-10-0-12-87.ec2.internal    False   4m35s
```

After ~1-2 minutes:

```bash
# Check NodeClaims again
kubectl get nodeclaims

# Output
No resources found
```

### Verify Final State

```bash
# Check nodes - only original EKS managed nodes remain
kubectl get nodes

# Output
NAME                          STATUS   ROLES    AGE   VERSION
ip-10-0-10-57.ec2.internal    Ready    <none>   55m   v1.34.1-eks-c39b1d0
ip-10-0-11-72.ec2.internal    Ready    <none>   55m   v1.34.1-eks-c39b1d0
ip-10-0-12-232.ec2.internal   Ready    <none>   55m   v1.34.1-eks-c39b1d0
```

✅ **Perfect cleanup!** All Spot nodes removed, cluster back to baseline.

---

## Step-08: Spot vs On-Demand - Key Differences

Now that you've seen both On-Demand (17_02) and Spot (17_03) in action, let's compare:

### Cost Comparison

**Demo Cost Breakdown (10 minutes of testing):**

| Configuration | Instance Type | Price/Hour | Total Cost |
|---------------|---------------|------------|------------|
| On-Demand (17_02) | 2× t3.small | $0.0208/hr each | ~$0.007 |
| Spot (17_03) | 2× t3a.small | ~$0.0062/hr each | ~$0.002 |
| **Savings** | - | - | **70%** |

For a production workload running 24/7:
- **On-Demand:** 2× t3.small = $30/month
- **Spot:** 2× t3a.small = ~$9/month
- **Annual savings:** ~$252 per node pair!

### Instance Diversity

**On-Demand NodePool:**
```yaml
instance-family: ["t3", "t3a"]  # Limited variety
```

**Spot NodePool:**
```yaml
instance-family: ["t3", "t3a", "t2", "c5a", "c6a"]  # Wide variety!
```

**Why More Variety for Spot?**
- Spot capacity fluctuates by instance type
- More options = better availability
- Reduces "InsufficientInstanceCapacity" errors

### When to Use Each

| Use Case | On-Demand | Spot | Why? |
|----------|-----------|------|------|
| Production databases | ✅ | ❌ | Stateful, can't handle interruptions |
| Web application (3+ replicas) | ⚠️ | ✅ | Fault-tolerant, cost-effective |
| Single-replica critical service | ✅ | ❌ | No redundancy to handle interruptions |
| CI/CD pipelines | ⚠️ | ✅ | Temporary jobs, cost matters |
| Batch processing | ⚠️ | ✅ | Fault-tolerant, elastic workloads |
| Development/test | ⚠️ | ✅ | Non-critical, maximize savings |

**Best Practice:** Use **mixed capacity** - critical pods on On-Demand, scalable/stateless workloads on Spot.

---

## Step-09: Key Observations and Best Practices

### What We Learned

✅ **Spot Provisioning:**
- Karpenter provisions Spot instances just as fast as On-Demand (~30-60 seconds)
- Uses multiple instance types to maximize availability
- Automatically labels nodes with `capacity-type: spot`

✅ **Cost Savings:**
- 70% typical savings compared to On-Demand
- Same functionality, just interruptible capacity

✅ **Consolidation:**
- Works identically to On-Demand
- 30-second grace period before cleanup
- Automatic node termination when empty

### Spot Best Practices

**1. Always Use Multiple Replicas**
```yaml
spec:
  replicas: 3  # Minimum - survives 1-2 interruptions
```

**2. Set PodDisruptionBudgets (PDB)**
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
spec:
  minAvailable: 2  # Keep at least 2 pods running
  selector:
    matchLabels:
      app: your-app
```

**3. Use Diverse Instance Types**
```yaml
# Good - wide variety
instance-family: ["t3", "t3a", "t2", "c5a", "c6a"]

# Bad - too restrictive
instance-family: ["t3"]  # May struggle to find capacity
```

**4. Implement Health Checks**
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
```

**5. Handle Graceful Shutdown**
```yaml
lifecycle:
  preStop:
    exec:
      command: ["/bin/sh", "-c", "sleep 15"]  # Allow time for connections to drain
```

---

## Step-10: What's Next?

You've now mastered basic Spot usage with Karpenter! But what about **interruptions**?

### Coming Up in 17_04: Spot Interruption Handling

In the next demo, we'll cover:
- How AWS sends 2-minute interruption warnings
- Graceful pod eviction and rescheduling
- AWS Node Termination Handler (optional)
- Monitoring interruption events
- Advanced resilience patterns

**Spot interruptions are not scary when handled properly!** 🚀

---

## Step-11: Troubleshooting

### Issue: Pods Stuck in Pending

**Symptoms:**
```bash
kubectl get pods
# All pods show "Pending" for > 2 minutes
```

**Possible Causes:**
1. **No Spot capacity available** in selected instance types/zones
2. Spot NodePool not applied correctly
3. `nodeSelector` typo

**Solution:**
```bash
# Check Karpenter logs for capacity errors
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=50

# Look for errors like:
# "InsufficientInstanceCapacity: no spot capacity available"

# Solution: Widen instance type selection in NodePool
```

### Issue: Nodes Using On-Demand Instead of Spot

**Symptoms:**
```bash
kubectl get nodes -l karpenter.sh/capacity-type=spot
# Returns no nodes, but pods are running
```

**Possible Causes:**
- Spot NodePool not applied
- `nodeSelector` not specified in deployment

**Solution:**
```bash
# Verify NodePool exists
kubectl get nodepool spot-nodepool

# Verify deployment has nodeSelector
kubectl get deploy karpenter-autoscale-demo-spot -o yaml | grep -A2 nodeSelector
```

### Issue: Frequent "InsufficientInstanceCapacity" Errors

**Solution:**
Expand instance type diversity in your Spot NodePool:

```yaml
requirements:
  - key: karpenter.k8s.aws/instance-family
    operator: In
    values: ["t3", "t3a", "t2", "c5", "c5a", "c6a", "c6i"]  # More options!
  
  - key: karpenter.k8s.aws/instance-size
    operator: In
    values: ["micro", "small", "medium", "large", "xlarge"]  # Wider range
```

---

## Summary

In this simplified demo, you successfully:

✅ Deployed a Spot-based application with Karpenter  
✅ **Verified actual Spot instances** using multiple methods  
✅ Observed Karpenter's instance diversity strategy  
✅ Cleaned up and watched automatic node removal  
✅ Learned when to use Spot vs On-Demand  
✅ Discovered 70% cost savings potential  

**Key Takeaway:** Spot instances with Karpenter are **simple to use** and **incredibly cost-effective** for the right workloads!

**Next:** 17_04 - Spot Interruption Handling (the advanced stuff!) 🚀

---