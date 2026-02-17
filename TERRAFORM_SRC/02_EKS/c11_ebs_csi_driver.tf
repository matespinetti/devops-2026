# 1. The Trust Policy for the EBS CSI Driver Role
data "aws_iam_policy_document" "ebs_csi_driver_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }

}

# 2. The IAM Role for the EBS CSI Driver

resource "aws_iam_role" "ebs_csi_driver_role" {
  name               = "${local.eks_cluster_name}-ebs-csi-driver-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_driver_policy.json
}

# 3. Attach the AmazonEBSCSIDriverPolicy to the IAM Role
resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy_attachment" {
  role       = aws_iam_role.ebs_csi_driver_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# 4. The Pod Identity Association (Step 02-04)
# This links the IAM Role to the Service Account
resource "aws_eks_pod_identity_association" "ebs_csi_driver_pod_identity_association" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi_driver_role.arn
}

#5. The EKS Add-on
#Installs the actual driver software into the cluster
resource "aws_eks_addon" "ebs_csi_driver_addon" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "aws-ebs-csi-driver"
  service_account_role_arn    = aws_iam_role.ebs_csi_driver_role.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on = [
    aws_eks_pod_identity_association.ebs_csi_driver_pod_identity_association
  ]
}
