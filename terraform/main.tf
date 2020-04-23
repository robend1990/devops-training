# Creates VPC with private and public subnets.
# Creates IAM roles that should be used for eks cluster node group and for alb-ingress-controller-pod


provider "aws" {
  profile = "rdrewniak-pgs"
  region = "eu-west-1"
}

resource "aws_iam_role" "ingress_controller_role" {
  name = "${var.eks_cluster_name}-ingress-controller-role"
  assume_role_policy = data.aws_iam_policy_document.node_can_assume_this.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "ingress_policy" {
  name       = "${aws_iam_role.ingress_controller_role.name}-policy"
  role       = aws_iam_role.ingress_controller_role.id
  policy     = data.aws_iam_policy_document.aws_ingress_controller_policy.json
  depends_on = [aws_iam_role.ingress_controller_role]
}

resource "aws_iam_role" "node_group_role" {
  name = "${var.eks_cluster_name}-node-group-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.node_group_role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.node_group_role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.node_group_role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy" "node_group_can_assume_roles" {
  name = "AllowToAssumeRoles"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "sts:AssumeRole"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
}
EOF
  role = aws_iam_role.node_group_role.id
}

module "eks_vpc" {
  source = "eks_vpc/"
  vpc_cidr = "10.0.0.0/16"
  private_cidrs = ["10.0.23.0/24", "10.0.24.0/24"]
  public_cidrs = ["10.0.4.0/24", "10.0.5.0/24"]
  eks_cluster_name = var.eks_cluster_name
  tags = var.tags
}