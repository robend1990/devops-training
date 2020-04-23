output "vpc_id" {
  value = module.eks_vpc.vpc_id
}

output "private_subnets" {
  value = module.eks_vpc.private_subnets
}

output "public_subnets" {
  value = module.eks_vpc.public_subnets
}

output "cluster_to_nodes_communication_security_group_id" {
  value = module.eks_vpc.cluster_to_nodes_communication_security_group_id
}

output "node_group_role_arn" {
  value = aws_iam_role.node_group_role.arn
}

output "ingress_controller_role_arn" {
  value = aws_iam_role.ingress_controller_role.arn
}