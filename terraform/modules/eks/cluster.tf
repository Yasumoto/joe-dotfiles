data "aws_eks_cluster" "cluster" {
  name = module.cluster.cluster_id
}

data "aws_eks_cluster_auth" "auth" {
  name = module.cluster.cluster_id
}

# While providers typically live at the top-level, this is used
# by the EKS module to continue configuring the Kubernetes cluster
# we're creating here
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.auth.token
}

module "cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "17.1.0"

  cluster_name    = "${var.environment}-${var.region}-${var.project}"
  cluster_version = "1.20"

  # https://aws.amazon.com/blogs/containers/de-mystifying-cluster-networking-for-amazon-eks-worker-nodes/
  subnets = var.subnet_ids
  vpc_id  = var.vpc_id

  # Enable when ready
  #cluster_service_ipv4_cidr = var.cluster_service_ipv4_cidr

  # https://docs.aws.amazon.com/eks/latest/userguide/fargate-profile.html
  fargate_profiles = {
    default = {
      name = "default"
      selectors = [
        {
          namespace = "kube-system"
        },
        {
          namespace = "kubernetes-dashboard"
        },
        {
          namespace = "default"
        }
      ]
      tags = local.tags
    }
  }

  map_users = [
    {
      userarn  = "arn:aws:iam::805452399422:user/terraform"
      username = "terraform"
      groups   = ["system:masters"]
    },
  ]

  tags = local.tags
}
