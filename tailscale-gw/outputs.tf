output "instance_id" {
  description = "EC2 instance ID of the Tailscale subnet router"
  value       = aws_instance.tailscale_gw.id
}

output "private_ip" {
  description = "Private IP of the subnet router inside the hybrid VPC"
  value       = aws_network_interface.tailscale_gw.private_ip
}

output "eni_id" {
  description = "ENI ID of the subnet router (target of route table entries for CGNAT)"
  value       = aws_network_interface.tailscale_gw.id
}

output "route_table_ids_updated" {
  description = "Route tables that received the 100.64.0.0/10 → subnet router route"
  value       = data.aws_route_tables.hybrid_private.ids
}

output "vpc_id" {
  description = "ID of the hybrid VPC (looked up by CIDR)"
  value       = data.aws_vpc.hybrid.id
}
