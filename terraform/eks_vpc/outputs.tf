output "vpc_id" {
  value = aws_vpc.this.id
}

output "private_subnets" {
  value = join(",", aws_subnet.private.*.id)
}

output "public_subnets" {
  value = join(",", aws_subnet.public.*.id)
}

output "cluster_to_nodes_communication_security_group_id" {
  value = aws_security_group.cluster_to_nodes.id
}