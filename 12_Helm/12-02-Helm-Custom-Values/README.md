# 12_02 Helm Custom Values - Retail Store UI with Ingress (HTTP)

## Step-01: Introduction
In this demo, we extend our Helm knowledge by deploying the **Retail Store UI** with a **custom `values-ui.yaml`** file.  
- Enable **Ingress** with AWS Load Balancer Controller (ALB)  
- Set **App theme** to **green**  

---

## Step-02: Helm Values — What, Why, and How (Deep Dive)
**Where do values come from?**
- **Chart defaults**: `values.yaml` inside the chart (what the author ships)
- **Your overrides**: `-f <file.yaml>` (recommended) and/or `--set key=value` (quick tweaks)

**Precedence (highest → lowest):**
1. `--set` (and `--set-string`)
2. Multiple `-f` files **in order** (the last file wins for the same key)
3. Chart’s default `values.yaml`

**Best practices:**
- Prefer **`-f values-<env>.yaml`** for most overrides; use `--set` for **small, one-off** changes.
- Keep **environment files** (`values-dev.yaml`, `values-stg.yaml`, `values-prod.yaml`) to avoid accidental drift.
- Avoid putting **secrets** in values files. Use External Secrets or Kubernetes Secrets + IRSA.


**Inspect & preview:**
```bash
# See chart default values (great for discovering knobs)
helm show values oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart --version 1.3.0

# Dry-run to preview what will be applied
cd retailstore-apps
helm install ui oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart --version 1.3.0 -f values-ui.yaml --dry-run --debug | less
```

**Upgrades & reuse:**

* `helm upgrade ui ... -f values-ui.yaml` applies changes from your file.
* `--reuse-values` merges prior overrides with new ones (handy, but can carry stale flags—use thoughtfully).

**Kubernetes rollout nuance:**

* If a value only changes a **ConfigMap/env**, pods might **not** auto‑restart.

  * Use: `kubectl rollout restart deployment/ui` to pick up changes.

**ALB Ingress prerequisites (recap):**

* AWS Load Balancer Controller (installed & IAM/IRSA configured)
* Subnets tagged for ALB (usually already done in cluster networking)
* An **IngressClass** in the cluster (default or explicitly referenced via `className`)

---

## Step-03: UI App — Review Custom Values File

Create **`values-ui.yaml`** with the following content (HTTP‑only Ingress):

```yaml
# Application Settings
app:
  theme: teal # Other options: orange, default, teal, green


# Ingress for load balancer
ingress:
  enabled: true
  className: alb
  annotations: 
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /actuator/health/liveness
  tls: []
  hosts: [] 
```

---

## Step-04: Install Helm Release with Custom Values

```bash
# Verify if AWS Load Balancer Controller installed
kubectl get deploy  -n kube-system aws-load-balancer-controller
kubectl get pods -n kube-system

# Verify Default Ingressclass configured
kubectl get ingressclass
Observation: "alb" should be default ingressclass

# Change Directory (adjust to your repo layout)
cd 12-02-Helm-Custom-Values/retailstore-apps

# Helm Install
cd retailstore-apps
helm install ui oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart \
  --version 1.3.0 \
  -f values-ui.yaml
```

---

## Step-05: Verify Ingress and ALB

```bash
# List Helm Release
helm list

# This gives a nice summary of resources created by the release.
helm status ui --show-resources

# After install/upgrade, see effective values
helm get values ui --all

# Shows all Kubernetes manifests (raw YAML) rendered and applied by Helm:
helm get manifest ui

# Pods created by the release
kubectl get pods

# Services (expect ClusterIP for internal communication)
kubectl get svc

# Ingress (ALB will be created by the controller)
kubectl get ingress

# Describe the Ingress to view ALB details and events
kubectl describe ingress ui
```

**Observation:**

* AWS Load Balancer Controller provisions an **internet‑facing ALB**
* The app is accessible over **HTTP (port 80)** using the ALB’s DNS name

---

## Step-06: Access Application

```bash
# Get the ALB DNS name
kubectl get ingress ui 
```

Open in your browser:

```
# Access Application
http://<ALB-DNS-NAME>
http://<ALB-DNS-NAME>/topology
```

---

## Step-07: Uninstall Helm Release

```bash
# Uninstall Helm Release
helm uninstall ui
```

---

## Helm Chart Reference
- [Retail Store Helm Chart - UI App](https://gallery.ecr.aws/aws-containers/retail-store-sample-ui-chart)

---