# 12_04: Package & Publish Retail UI Helm Chart (ECR Private)

## Step-01: Introduction

In this demo, we will learn how to **package, publish, install, and verify** a Helm chart for the **Retail Store UI Application** using **Amazon ECR Private**.

**Key topics:**

* Update chart metadata (`Chart.yaml`)
* Package Helm chart (`.tgz`)
* Push to **Amazon ECR Private** (OCI registry)
* Install Helm chart directly from ECR
* Understand image tag fallback (`.Chart.Version`)
* New: Release Info ConfigMap

---

## Pre-requiste Item
```bash
# Create a workspace and enter it
mkdir -p charts && cd charts


# Pull the UI chart from ECR Public (OCI) and unpack it
helm pull oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart \
  --version 1.3.0 \
  --untar

# Inspect what got created
ls -la  

# Rename the long folder name to smaller folder name
mv retail-store-sample-ui-chart ui

# Optional: install 'tree' if not present
# Amazon Linux
sudo dnf install tree -y
# macOS
brew install tree

# If you have 'tree':
tree -a || true
```

## Step-02: Update Chart Metadata

Edit **`Chart.yaml`** inside your chart (`ui/`):

```yaml
apiVersion: v2
name: retail-store-sample-ui-chart
description: Retail Store UI Helm Chart
type: application
version: 1.3.1       # Chart version (bump from 1.3.0 to 1.3.1)
```

* Always bump `version` when releasing a new chart.

---

## Step-03: Add Release Info ConfigMap 
* Create a new template file: **`templates/release-info.yaml`**

```yaml
{{- if .Values.releaseInfo.enabled }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "ui.fullname" . }}-release-info
  labels:
    {{- include "ui.labels" . | nindent 4 }}
data:
  chartName: "{{ .Chart.Name }}"
  chartVersion: "{{ .Chart.Version }}"
  appVersion: "{{ .Chart.AppVersion }}"
  releaseName: "{{ .Release.Name }}"
  releaseNamespace: "{{ .Release.Namespace }}"
  releaseRevision: "{{ .Release.Revision }}"
  releaseTime: "{{ now | date "2006-01-02T15:04:05Z07:00" }}"
{{- end }}
```

### Add defaults in `ui/values.yaml`

```yaml
releaseInfo:
  enabled: false
```

### Add overrides in `retailstore-apps/values-ui.yaml`

```yaml
releaseInfo:
  enabled: true
```

---

## Step-04: End-to-End Workflow 
1. Create AWS ECR Private repository
2. helm package
3. helm push

```bash
# Set Variables
REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# Verify Variables
echo $REGION
echo $ACCOUNT_ID
echo $REGISTRY

# Login to ECR for Helm/OCI
aws ecr get-login-password --region "$REGION" \
| helm registry login -u AWS --password-stdin "$REGISTRY"

# Create flat repo (exactly chart name)
aws ecr create-repository \
  --repository-name retail-store-sample-ui-chart \
  --region "$REGION" || true

# Package chart (matches Chart.yaml)
cd charts
helm package ./ui   # -> retail-store-sample-ui-chart-1.3.1.tgz

# Push to ECR (OCI): IMPORTANT: push to registry root (no suffix) ---
helm push retail-store-sample-ui-chart-1.3.1.tgz oci://"$REGISTRY"

# Verify
aws ecr describe-images \
  --repository-name retail-store-sample-ui-chart \
  --region "$REGION" \
  --query 'imageDetails[].imageTags'
```

---

## Step-05: Install Chart from ECR Private

```bash
# helm install
helm install retail-ui \
  oci://"$REGISTRY"/retail-store-sample-ui-chart \
  --version 1.3.1 \
  -f ../retailstore-apps/values-ui.yaml
```

Or for upgrades:

```bash
# helm upgrade
helm upgrade --install retail-ui \
  oci://"$REGISTRY"/retail-store-sample-ui-chart \
  --version 1.2.5 \
  -f ../retailstore-apps/values-ui.yaml
```

---

## Step-06: Important Note on Deployment & Image Tags

The Deployment template defines the container image like this:

```yaml
image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.Version }}"
```

Meaning:

* If you **set** `image.tag`, that tag is used.
* If you **don’t set it**, Helm falls back to `.Chart.Version`.

**Best Practice:** Always set `image.repository` and `image.tag` explicitly.

Example (`values-ui.yaml`):

```yaml
# Add Image and Tag
image:
  repository: public.ecr.aws/aws-containers/retail-store-sample-ui
  pullPolicy: IfNotPresent
  tag: 1.3.0   
```

* [Docker Image: retail-store-sample-ui](https://gallery.ecr.aws/aws-containers/retail-store-sample-ui)

---

## Step-07: Verify Resources

```bash
# List Helm Releases
helm list

# List Kubernetes Resources
helm status retail-ui --show-resources 

# Verify pods & service
kubectl get pods,svc

# Verify Release Info ConfigMap
kubectl get cm 
kubectl get cm retail-ui-release-info -o yaml
kubectl describe cm retail-ui-release-info
```

---

## Step-08: Cleanup

```bash
helm uninstall retail-ui
```

---

## Step-09: Cleanup ECR Repository (Optional)
* To completely remove the chart repository from ECR:
```bash
# Delete AWS ECR Repository
aws ecr delete-repository \
  --repository-name retail-store-sample-ui-chart \
  --region "$REGION" \
  --force
```
>  Use `--force` to delete the repo along with all images (chart versions) inside it.

---
## Step-10: Summary

* Packaged **Retail UI Helm Chart v1.3.1**
* Published to **Amazon ECR Private**
* Installed directly from ECR
* Verified new **Release Info ConfigMap**
* Learned about **image tag fallback** (`.Chart.Version`)

**Note:** This completes the **real-world Helm packaging & publishing workflow** on AWS.

---

