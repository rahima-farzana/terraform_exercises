resource "aws_iam_role" "demo-node" {
  name = "wezvatech-eks-demo-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "demo-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.demo-node.name
}

resource "aws_iam_role_policy_attachment" "demo-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.demo-node.name
}

resource "aws_iam_role_policy_attachment" "demo-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.demo-node.name
}

# Node Group 1: General Microservices
resource "aws_eks_node_group" "system_apps" {
  cluster_name    = aws_eks_cluster.demo.name
  node_group_name = "system-apps-pool"
  node_role_arn   = aws_iam_role.demo-node.arn
  subnet_ids      = data.aws_subnets.default.ids

  instance_types = ["t3.medium"]

  scaling_config {
    desired_size = 1
    max_size     = 3
    min_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.demo-node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.demo-node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.demo-node-AmazonEC2ContainerRegistryReadOnly,
  ]
}

# Node Group 2: GPU Scaling Pool (KServe Engine)
resource "aws_eks_node_group" "ml_gpu" {
  cluster_name    = aws_eks_cluster.demo.name
  node_group_name = "ml-gpu-pool"
  node_role_arn   = aws_iam_role.demo-node.arn
  subnet_ids      = data.aws_subnets.default.ids

  instance_types = ["t2.medium"] # Lowest-cost entry GPU (NVIDIA L4)

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 0 # Can scale completely down to zero when idle
  }

  taint {
    key    = "dedicated"
    value  = "ml-inference"
    effect = "NO_SCHEDULE"
  }

  depends_on = [
    aws_iam_role_policy_attachment.demo-node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.demo-node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.demo-node-AmazonEC2ContainerRegistryReadOnly,
  ]
}

resource "null_resource" "update_kubeconfig" {
  # Explicitly wait until the cluster and nodes are fully online
  depends_on = [
    aws_eks_cluster.demo,
    aws_eks_node_group.system_apps
  ]

  provisioner "local-exec" {
    # Dynamically injects variables to build the localized configuration file
    command = "aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.aws_region}"
  }
}
