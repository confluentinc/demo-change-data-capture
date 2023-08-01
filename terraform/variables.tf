variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API Key (also referred as Cloud API ID)"
  type        = string
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API Secret"
  type        = string
  sensitive   = true
}

variable "sg_package" {
  description = "Stream Governance Package: Advanced or Essentials"
  type        = string
  default     = "ESSENTIALS"
}

variable "snowflake_region" {
  description = "Snowflake region"
  type        = string
  default     = "us-west-2"
}

variable "snowflake_schema" {
  type    = string
  default = "PUBLIC"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "rds_instance_class" {
  description = "Amazon RDS (Oracle) instance size"
  type        = string
  default     = "db.m5.large"
}

variable "rds_instance_identifier" {
  description = "Amazon RDS (Oracle) instance identifier"
  type        = string
  default     = "demo-change-data-capture"
}

variable "rds_username" {
  description = "Amazon RDS (Oracle) master username"
  type        = string
  default     = "admin"
}

variable "rds_password" {
  description = "Amazon RDS (Oracle) database password. You can change it through command line"
  type        = string
  default     = "demo-cdc-c0nflu3nt!"
}


variable "redshift_cluster_identifier" {
  type        = string
  description = "Redshift Cluster Identifier"
  default     = "demo-cdc"
}

variable "redshift_database_name" {
  type        = string
  description = "Redshift Database Name"
  default     = "demo_confluent"
}

variable "redshift_admin_username" {
  type        = string
  description = "Redshift Admin Username"
  default     = "demo_user"
}

variable "redshift_admin_password" {
  type        = string
  description = "Redshift Admin Password"
  default     = "4Testing"
}

variable "redshift_node_type" {
  type        = string
  description = "Redshift Node Type"
  default     = "dc2.large"
}

variable "redshift_cluster_type" {
  type        = string
  description = "Redshift Cluster Type"
  default     = "single-node" // options are single-node or multi-node
}

variable "redshift_number_of_nodes" {
  type        = number
  description = "Redshift Number of Nodes in the Cluster"
  default     = 1
}

variable "redshift_vpc_cidr" {
  type        = string
  description = "VPC IPv4 CIDR"
  default     = "10.0.0.0/16"
  # default     = "10.1.0.0/16"
}

variable "redshift_subnet_1_cidr" {
  type        = string
  description = "IPv4 CIDR for Redshift subnet 1"
  default     = "10.0.1.0/24"
  # default     = "10.1.1.0/24"
}

variable "redshift_subnet_2_cidr" {
  type        = string
  description = "IPv4 CIDR for Redshift subnet 2"
  default     = "10.0.2.0/24"
  # default     = "10.1.2.0/24"
}

variable "redshift_schema" {
  type    = string
  default = "public"
}
