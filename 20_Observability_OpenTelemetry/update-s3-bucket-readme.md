# Update S3 Bucket Name for Terraform State

This guide helps you update the S3 bucket name in all Terraform files for the OpenTelemetry section.

---

## Step 1: Create Your S3 Bucket if not created already
S3 bucket is needed for storing Terraform state
S3 bucket names are **globally unique** across AWS. Create your own bucket first if not created:

```bash
# Create bucket (replace YOUR-UNIQUE-ID with something unique, e.g., your initials + random numbers)
aws s3 mb s3://tfstate-dev-us-east-1-YOUR-UNIQUE-ID --region us-east-1

# Enable versioning (recommended for Terraform state)
aws s3api put-bucket-versioning \
  --bucket tfstate-dev-us-east-1-YOUR-UNIQUE-ID \
  --versioning-configuration Status=Enabled

# Verify bucket was created
aws s3 ls | grep tfstate-dev-us-east-1-YOUR-UNIQUE-ID
```

---

## Step 2: Run the Update Script

Once your bucket is created, run the script to update all Terraform files:

```bash
# Navigate to the OpenTelemetry folder
cd 20_Observability_OpenTelemetry

# Make script executable
chmod +x update-s3-bucket.sh

# Run script with YOUR bucket name
./update-s3-bucket.sh tfstate-dev-us-east-1-YOUR-UNIQUE-ID
```

The script will:
- ✅ Verify your bucket exists
- ✅ Find all Terraform files with old bucket name
- ✅ Update them with your bucket name
- ✅ Verify all changes

---

## Step 3: Run Cluster Creation Script

After successful update, create your cluster:

```bash
cd 01_EKS_Cluster_Environment
./create-cluster-with-karpenter-and-opentelemetry.sh
```

---

## 💡 Recommendation

If you follow the course **section by section from the beginning**, all this S3 bucket and Terraform state setup is explained in detail. 

---

**Happy Learning! **