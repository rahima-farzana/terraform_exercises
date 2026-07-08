# EKS Cluster Resources
#  * IAM Role to allow EKS service to manage other AWS services
#  * EC2 Security Group to allow networking traffic with EKS cluster
#  * EKS Cluster

locals {
   oidc_url = replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")
   oidc_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_url}"
}


resource "aws_iam_role" "demo-cluster" {
  name = "wezvatech-eks-demo-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "demo-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.demo-cluster.name
}

resource "aws_iam_role_policy_attachment" "demo-cluster-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.demo-cluster.name
}

resource "aws_security_group" "demo-cluster" {
  name        = "wezvatech-eks-cluster-sg"
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.demo.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-eks-demo"
  }
}


resource "aws_eks_cluster" "demo" {
  name     = var.cluster_name
  role_arn = aws_iam_role.demo-cluster.arn

  version = var.eksversion

  vpc_config {
    security_group_ids = [aws_security_group.demo-cluster.id]
    subnet_ids         = aws_subnet.demo[*].id
  }
# --- ADD THIS CONFIGURATION BLOCK ---
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }
  # ------------------------------------
  depends_on = [
    aws_iam_role_policy_attachment.demo-cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.demo-cluster-AmazonEKSVPCResourceController,
  ]
}


resource "aws_iam_policy" "cluster_autoscaler" {
  name = "ClusterAutoscalerPolicy"

 policy = jsonencode({
    Statement = [{
      Action = [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeTags",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "ec2:DescribeLaunchTemplateVersions",
                "ec2:DescribeImages",
                "ec2:DescribeInstanceTypes",
                "ec2:GetInstanceTypesFromInstanceRequirements",
                "eks:DescribeNodegroup"
            ]
      Effect   = "Allow"
      Resource = "*"
    }]
    Version = "2012-10-17"
  })
}


data "aws_eks_cluster" "eks" {
  name = var.cluster_name
  depends_on = [aws_eks_cluster.demo]
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da0d1e5a362"]
  url             = data.aws_eks_cluster.eks.identity[0].oidc[0].issuer
}


resource "aws_iam_role" "cluster_autoscaler" {
  name               = "eks-cluster-autoscaler"
  
 assume_role_policy = jsonencode({
  Version = "2012-10-17",
  Statement = [{
   Effect = "Allow",
   Principal = {
     Federated = local.oidc_arn
   },
   Action =  "sts:AssumeRoleWithWebIdentity",
   Condition = {
     StringEquals = {
       "${local.oidc_url}:sub" = "system:serviceaccount:kube-system:cluster-autoscaler"
     }
    }
  }]
 })

}

resource "aws_iam_role_policy_attachment" "ca_attach" {
  role       = aws_iam_role.cluster_autoscaler.name
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
}


# -- Download the kube config to run kubectl -- #
resource "null_resource" "cluster" {
  depends_on = [aws_eks_cluster.demo]

  provisioner "local-exec" {
     command = "aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.aws_region}"
  }
}

# -- Install cluster autoscaler & create serviceaccount needed -- #
resource "helm_release" "cluster_autoscaler" {
   name = "cluster-autoscaler"
   repository = "https://kubernetes.github.io/autoscaler"
   chart = "cluster-autoscaler"
   namespace = "kube-system"
   version = "9.54.0"
  
   set = [ 
   {
     name = "image.tag"
     value = var.caversion
   },
   {
     name = "autoDiscovery.clusterName"
     value = var.cluster_name
   },
   {
     name = "autoDiscovery.clusterName"
     value = var.cluster_name
   },
   {
     name = "awsRegion"
     value = var.aws_region
   },
   {
     name = "rbac.serviceAccount.create"
     value = "true"
   },
   {
     name = "rbac.serviceAccount.name"
     value = "cluster-autoscaler"
   },
   {
     name = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
     value = aws_iam_role.cluster_autoscaler.arn
   },
   {
     name = "extraArgs.balance-similar-node-groups"
     value = "true"
   },
   {
     name = "extraArgs.skip-nodes-with-system-pods"
     value = "false"
   }]

   depends_on = [
     aws_iam_role_policy_attachment.ca_attach
   ]

}

