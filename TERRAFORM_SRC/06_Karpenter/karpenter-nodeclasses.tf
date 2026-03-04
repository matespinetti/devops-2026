resource "kubectl_manifest" "karpenter_nodeclass" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: default-ec2nodeclass
    spec:
      amiFamily: AL2023
      role: ${aws_iam_role.karpenter_node_role.name}
      amiSelectorTerms:
        - alias: al2023@latest
      subnetSelectorTerms:
        - tags:
            "kubernetes.io/cluster/${local.cluster_name}": "owned"
            "kubernetes.io/role/internal-elb": "1"
      securityGroupSelectorTerms:
        - tags:
            "kubernetes.io/cluster/${local.cluster_name}": "owned"
      tags:
        "karpenter.sh/discovery": "${local.cluster_name}"
      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeSize: 20Gi
            volumeType: gp3
            encrypted: true
            deleteOnTermination: true
      metadataOptions:
        httpTokens: required
        httpEndpoint: enabled
        httpPutResponseHopLimit: 2
  YAML

  # IMPORTANTE: Asegurate de descomentar y ajustar esto con el nombre 
  # exacto de tu helm_release para evitar el error del CRD no encontrado.
  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_ondemand_nodepool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: default-ondemand-nodepool
    spec:
      template:
        spec:
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default-ec2nodeclass
          taints: []
          startupTaints: []
          #Node selection logic 
          requirements:
            - key: "kubernetes.io/arch"
              operator: In
              values: ["amd64"]
            - key: "kubernetes.io/os"
              operator: In
              values: ["linux"]
            - key: "karpenter.sh/capacity-type"
              operator: In
              values: ["on-demand"]
            - key: "topology.kubernetes.io/zone"
              operator: In
              values: ["us-east-1a", "us-east-1b", "us-east-1c"]
            - key: "karpenter.k8s.aws/instance-family"
              operator: In
              values: ["t3", "t3a"]
            - key: "karpenter.k8s.aws/instance-size"
              operator: In
              values: ["micro", "small", "medium"]
      limits:
        cpu: "50"
      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 30s
  YAML

  depends_on = [
    kubectl_manifest.karpenter_nodeclass
  ]
}

resource "kubectl_manifest" "karpenter_spot_nodepool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: default-spot-nodepool
    spec:
      template:
        spec:
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default-ec2nodeclass
          taints: []
          startupTaints: []
          #Node selection logic 
          requirements:
            - key: "kubernetes.io/arch"
              operator: In
              values: ["amd64"]
            - key: "kubernetes.io/os"
              operator: In
              values: ["linux"]
            - key: "karpenter.sh/capacity-type"
              operator: In
              values: ["spot"]
            - key: "topology.kubernetes.io/zone"
              operator: In
              values: ["us-east-1a", "us-east-1b", "us-east-1c"]
            - key: "karpenter.k8s.aws/instance-family"
              operator: In
              values: ["t3", "t3a", "t2", "c5a", "c6a"]
            - key: "karpenter.k8s.aws/instance-size"
              operator: In
              values: ["medium", "large"]
      limits:
        cpu: "50"
      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 30s
        budgets:
          - nodes: "100%"
            reasons:
              - "Drifted"
              - "Underutilized"
              - "Empty"
  YAML

  depends_on = [
    kubectl_manifest.karpenter_nodeclass
  ]
}
