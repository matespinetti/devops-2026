data "aws_iam_policy_document" "node_assume_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "karpenter_node_role" {
  name               = "${local.name_prefix}-karpenter-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume_policy.json
}

resource "aws_iam_role_policy_attachment" "karpenter_node_role_policy_attachment" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ])
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = each.value
}

resource "aws_eks_access_entry" "karpenter_node_access_entry" {
  cluster_name  = local.cluster_name
  principal_arn = aws_iam_role.karpenter_node_role.arn
  type          = "EC2_LINUX"

}

