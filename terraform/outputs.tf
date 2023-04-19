output "oracle_endpoint" {
  value     = aws_db_instance.demo-change-data-capture
  sensitive = true
}
output "postgres_instance_products_public_endpoint" {
  value = aws_eip.postgres_products_ip.public_ip
  sensitive = true
}
output "redshift_endpoint" {
  value     = aws_redshift_cluster.redshift_cluster.endpoint
  sensitive = true
}
output "snowflake_svc_public_key" {
  value = tls_private_key.svc_key.public_key_pem
}

output "snowflake_svc_private_key" {
  value     = tls_private_key.svc_key.private_key_pem
  sensitive = true
}