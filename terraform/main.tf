terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.16.2"
    }
    confluent = {
      source  = "confluentinc/confluent"
      version = "1.51.0"
    }
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = "0.68.0"
    }
  }
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

provider "confluent" {
  # https://developer.hashicorp.com/terraform/language/providers/configuration#alias-multiple-provider-configurations
  alias = "kafka"

  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret

  #   kafka_id            = confluent_kafka_cluster.standard.id
  kafka_rest_endpoint = confluent_kafka_cluster.standard.rest_endpoint
  kafka_api_key       = confluent_api_key.app-manager-kafka-api-key.id
  kafka_api_secret    = confluent_api_key.app-manager-kafka-api-key.secret
}

provider "aws" {
  region = var.region
}

provider "snowflake" {
  alias = "sys_admin"
  role  = "SYSADMIN"
}

provider "snowflake" {
  alias = "security_admin"
  role  = "SECURITYADMIN"
}

######################################
# ### Confluent Cloud
######################################
resource "confluent_environment" "demo" {
  display_name = "Demo_Change_Data_Capture"
}

data "confluent_schema_registry_region" "sg_package" {
  cloud   = "AWS"
  region  = "us-east-2"
  package = var.sg_package
}

resource "confluent_schema_registry_cluster" "sr_package" {
  package = data.confluent_schema_registry_region.sg_package.package

  environment {
    id = confluent_environment.demo.id
  }

  region {
    # See https://docs.confluent.io/cloud/current/stream-governance/packages.html#stream-governance-regions
    id = data.confluent_schema_registry_region.sg_package.id
  }
}

resource "confluent_kafka_cluster" "standard" {
  display_name = "demo_kafka_cluster"
  availability = "SINGLE_ZONE"
  cloud        = "AWS"
  region       = "us-west-2"
  standard {}

  environment {
    id = confluent_environment.demo.id
  }
}

# 'app-manager' service account is required in this configuration to create 'rabbitmq_transactions' topic and grant ACLs
# to 'app-producer' and 'app-consumer' service accounts.
resource "confluent_service_account" "app-manager" {
  display_name = "app-manager"
  description  = "Service account to manage 'demo' Kafka cluster"
}

resource "confluent_role_binding" "app-manager-kafka-cluster-admin" {
  principal   = "User:${confluent_service_account.app-manager.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.standard.rbac_crn
}

resource "confluent_api_key" "app-manager-kafka-api-key" {
  display_name = "app-manager-kafka-api-key"
  description  = "Kafka API Key that is owned by 'app-manager' service account"
  owner {
    id          = confluent_service_account.app-manager.id
    api_version = confluent_service_account.app-manager.api_version
    kind        = confluent_service_account.app-manager.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.standard.id
    api_version = confluent_kafka_cluster.standard.api_version
    kind        = confluent_kafka_cluster.standard.kind

    environment {
      id = confluent_environment.demo.id
    }
  }

  # The goal is to ensure that confluent_role_binding.app-manager-kafka-cluster-admin is created before
  # confluent_api_key.app-manager-kafka-api-key is used to create instances of
  # confluent_kafka_topic, confluent_kafka_acl resources.

  # 'depends_on' meta-argument is specified in confluent_api_key.app-manager-kafka-api-key to avoid having
  # multiple copies of this definition in the configuration which would happen if we specify it in
  # confluent_kafka_topic, confluent_kafka_acl resources instead.
  depends_on = [
    confluent_role_binding.app-manager-kafka-cluster-admin
  ]
}


# Create Oracle redo log topic 
resource "confluent_kafka_topic" "oracle_redo_log" {
  kafka_cluster {
    id = confluent_kafka_cluster.standard.id
  }

  topic_name       = "OracleCdcSourceConnector-demo-redo-log"
  rest_endpoint    = confluent_kafka_cluster.standard.rest_endpoint
  partitions_count = 1
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}


# Create postgres.products.products topic 
resource "confluent_kafka_topic" "postgres_products_products" {
  kafka_cluster {
    id = confluent_kafka_cluster.standard.id
  }

  topic_name       = "postgres.products.products"
  rest_endpoint    = confluent_kafka_cluster.standard.rest_endpoint
  partitions_count = 1
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}

# Create postgres.products.orders topic 
resource "confluent_kafka_topic" "postgres_products_orders" {
  kafka_cluster {
    id = confluent_kafka_cluster.standard.id
  }

  topic_name       = "postgres.products.orders"
  rest_endpoint    = confluent_kafka_cluster.standard.rest_endpoint
  partitions_count = 1
  credentials {
    key    = confluent_api_key.app-manager-kafka-api-key.id
    secret = confluent_api_key.app-manager-kafka-api-key.secret
  }
}


# Create a service account for ksqlDB 
resource "confluent_service_account" "app-ksql" {
  display_name = "app-ksql"
  description  = "Service account to manage 'demo-ksql' ksqlDB cluster"
}

resource "confluent_role_binding" "app-ksql-kafka-cluster-admin" {
  principal   = "User:${confluent_service_account.app-ksql.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.standard.rbac_crn
}

resource "confluent_role_binding" "app-ksql-schema-registry-resource-owner" {
  principal   = "User:${confluent_service_account.app-ksql.id}"
  role_name   = "ResourceOwner"
  crn_pattern = format("%s/%s", confluent_schema_registry_cluster.sr_package.resource_name, "subject=*")

  lifecycle {
    prevent_destroy = false
  }
}

# Create ksqlDB cluster  
resource "confluent_ksql_cluster" "demo-ksql" {
  display_name = "demo-ksql"
  csu          = 1
  kafka_cluster {
    id = confluent_kafka_cluster.standard.id
  }
  credential_identity {
    id = confluent_service_account.app-ksql.id
  }
  environment {
    id = confluent_environment.demo.id
  }
  depends_on = [
    confluent_role_binding.app-ksql-kafka-cluster-admin,
    confluent_role_binding.app-ksql-schema-registry-resource-owner,
    confluent_schema_registry_cluster.sr_package
  ]
}

#####################################
# ### Amazon RDS (Oracle)
#####################################

# Create the VPC
resource "aws_vpc" "rds-vpc" {
  cidr_block           = var.rds_vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name       = "demo-cdc-rds-vpc"
    created_by = "terraform"
  }
}

# Create the RDS Oracle Subnet AZ1
resource "aws_subnet" "rds-subnet-az1" {
  vpc_id            = aws_vpc.rds-vpc.id
  cidr_block        = var.rds_subnet_1_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name       = "demo-cdc-rds-subnet-az1"
    created_by = "terraform"
  }
}

# Create the RDS Oracle Subnet AZ2
resource "aws_subnet" "rds-subnet-az2" {
  vpc_id            = aws_vpc.rds-vpc.id
  cidr_block        = var.rds_subnet_2_cidr
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name       = "demo-cdc-rds-subnet-az2"
    created_by = "terraform"
  }
}

# Create the RDS Oracle Subnet Group
resource "aws_db_subnet_group" "rds-subnet-group" {
  depends_on = [
    aws_subnet.rds-subnet-az1,
    aws_subnet.rds-subnet-az2,
  ]

  name       = "demo-cdc-rds-subnet-group"
  subnet_ids = [aws_subnet.rds-subnet-az1.id, aws_subnet.rds-subnet-az2.id]

  tags = {
    Name       = "demo-cdc-rds-subnet-group"
    created_by = "terraform"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "rds-igw" {
  vpc_id = aws_vpc.rds-vpc.id

  tags = {
    Name       = "demo-cdc-rds-igw"
    created_by = "terraform"
  }
}

# Define the RDS Oracle route table to Internet Gateway
resource "aws_route_table" "rds-rt-igw" {
  vpc_id = aws_vpc.rds-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.rds-igw.id
  }

  tags = {
    Name       = "demo-cdc-rds-public-route-igw"
    created_by = "terraform"
  }
}

# Assign the Oracle RDS route table to the RDS Subnet az1 for IGW 
resource "aws_route_table_association" "rds-subnet-rt-association-igw-az1" {
  subnet_id      = aws_subnet.rds-subnet-az1.id
  route_table_id = aws_route_table.rds-rt-igw.id
}

# Assign the public route table to the RDS Subnet az2 for IGW 
resource "aws_route_table_association" "rds-subnet-rt-association-igw-az2" {
  subnet_id      = aws_subnet.rds-subnet-az2.id
  route_table_id = aws_route_table.rds-rt-igw.id
}

resource "aws_security_group" "rds_security_group" {
  name        = "demo_cdc_rds_security_group_${split("-", uuid())[0]}"
  description = "Security Group for RDS Oracle instance. Used in Confluent Cloud Change Data Capture workshop."
  vpc_id      = aws_vpc.rds-vpc.id

  ingress {
    description = "RDS Oracle Port"
    from_port   = 1521
    to_port     = 1521
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Allow all outbound."
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name       = "demo-cdc-rds-security-group"
    created_by = "terraform"
  }
}

resource "aws_db_instance" "demo-change-data-capture" {
  identifier             = var.rds_instance_identifier
  engine                 = "oracle-se2"
  engine_version         = "19"
  instance_class         = var.rds_instance_class
  username               = var.rds_username
  password               = var.rds_password
  port                   = 1521
  license_model          = "license-included"
  db_subnet_group_name   = aws_db_subnet_group.rds-subnet-group.name
  vpc_security_group_ids = [aws_security_group.rds_security_group.id]
  #   parameter_group_name = "default.oracle-se2-19.0"
  allocated_storage   = 20
  storage_encrypted   = false
  skip_final_snapshot = true
  publicly_accessible = true
  tags = {
    name       = "demo-change-data-capture"
    created_by = "terraform"
  }
}

######################################
# ### Postgres 
######################################
resource "aws_default_vpc" "default_vpc" {
  tags = {
    name = "Default VPC"
  }
}

resource "aws_security_group" "postgres_sg" {
  name        = "demo_cdc_postgres_security_group_${split("-", uuid())[0]}"
  description = "Security Group for Postgres EC2 instance. Used in Confluent Cloud Change Data Capture workshop."
  vpc_id      = aws_default_vpc.default_vpc.id
  egress {
    description = "Allow all outbound."
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Postgres"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Postgres"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name       = "demo-cdc-postgres-sg"
    created_by = "terraform"
  }
}

data "template_cloudinit_config" "pg_bootstrap_products" {
  base64_encode = true
  part {
    content_type = "text/x-shellscript"
    content      = file("scripts/pg_products_bootstrap.sh")
  }
}
resource "aws_instance" "postgres_products" {
  ami             = "ami-08546f4ffb2306647"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.postgres_sg.name]
  user_data       = data.template_cloudinit_config.pg_bootstrap_products.rendered
  tags = {
    Name       = "demo-cdc-postgres-products-instance"
    created_by = "terraform"
  }
}
resource "aws_eip" "postgres_products_ip" {
  # vpc      = true
  domain   = "vpc"
  instance = aws_instance.postgres_products.id
  tags = {
    Name       = "demo-cdc-postgres-products-eip"
    created_by = "terraform"
  }
}

######################################
# ### Snowflake
######################################
resource "snowflake_database" "db" {
  # provider = snowflake.security_admin 
  provider = snowflake.sys_admin
  name     = "TF_DEMO"
}

resource "snowflake_warehouse" "warehouse" {
  provider                            = snowflake.sys_admin
  name                                = "TF_DEMO"
  warehouse_size                      = "X-SMALL"
  query_acceleration_max_scale_factor = 0
  auto_suspend                        = 60
}

resource "snowflake_role" "role" {
  provider = snowflake.security_admin
  name     = "TF_DEMO_SVC_ROLE"
}

resource "snowflake_grant_privileges_to_role" "database_grant" {
  provider   = snowflake.security_admin
  privileges = ["USAGE"]
  role_name  = snowflake_role.role.name
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.db.name
  }
  # all_privileges    = true
  with_grant_option = true
}

resource "snowflake_grant_privileges_to_role" "schema_grant" {
  provider   = snowflake.security_admin
  privileges = ["USAGE", "CREATE TABLE", "CREATE STAGE", "CREATE PIPE"]
  role_name  = snowflake_role.role.name
  on_schema {
    schema_name = "\"${snowflake_database.db.name}\".\"${var.snowflake_schema}\"" # note this is a fully qualified name!
  }
  # all_privileges = true
}

# future schemas in database
resource "snowflake_grant_privileges_to_role" "g8" {
  provider   = snowflake.security_admin
  privileges = ["USAGE", "CREATE TABLE", "CREATE STAGE", "CREATE PIPE"]
  role_name  = snowflake_role.role.name
  on_schema {
    future_schemas_in_database = snowflake_database.db.name
  }
}

resource "snowflake_grant_privileges_to_role" "warehouse_grant" {
  provider   = snowflake.security_admin
  privileges = ["USAGE", "OPERATE"]
  role_name  = snowflake_role.role.name
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.warehouse.name
  }
}

resource "tls_private_key" "svc_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "snowflake_user" "user" {
  provider          = snowflake.security_admin
  name              = "TF_DEMO_USER"
  default_warehouse = snowflake_warehouse.warehouse.name
  default_role      = snowflake_role.role.name
  rsa_public_key    = substr(tls_private_key.svc_key.public_key_pem, 27, 398)
}

resource "snowflake_role_grants" "grants" {
  provider  = snowflake.security_admin
  role_name = snowflake_role.role.name
  roles = [
    "SECURITYADMIN"
  ]
  users = [snowflake_user.user.name]
}

# ######################################
# ### AWS Redshift
# ######################################
# AWS Availability Zones data
data "aws_availability_zones" "available" {}

# Create the VPC
resource "aws_vpc" "redshift-vpc" {
  cidr_block           = var.redshift_vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name       = "demo-cdc-redshift-vpc"
    created_by = "terraform"
  }
}

# Create the Redshift Subnet AZ1
resource "aws_subnet" "redshift-subnet-az1" {
  vpc_id            = aws_vpc.redshift-vpc.id
  cidr_block        = var.redshift_subnet_1_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name       = "demo-cdc-redshift-subnet-az1"
    created_by = "terraform"
  }
}

# Create the Redshift Subnet AZ2
resource "aws_subnet" "redshift-subnet-az2" {
  vpc_id            = aws_vpc.redshift-vpc.id
  cidr_block        = var.redshift_subnet_2_cidr
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name       = "demo-cdc-redshift-subnet-az2"
    created_by = "terraform"
  }
}

# Create the Redshift Subnet Group
resource "aws_redshift_subnet_group" "redshift-subnet-group" {
  depends_on = [
    aws_subnet.redshift-subnet-az1,
    aws_subnet.redshift-subnet-az2,
  ]

  name       = "demo-cdc-redshift-subnet-group"
  subnet_ids = [aws_subnet.redshift-subnet-az1.id, aws_subnet.redshift-subnet-az2.id]

  tags = {
    Name       = "demo-cdc-redshift-subnet-group"
    created_by = "terraform"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "redshift-igw" {
  vpc_id = aws_vpc.redshift-vpc.id

  tags = {
    Name       = "demo-cdc-redshift-igw"
    created_by = "terraform"
  }
}

# Define the redshift route table to Internet Gateway
resource "aws_route_table" "redshift-rt-igw" {
  vpc_id = aws_vpc.redshift-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.redshift-igw.id
  }

  tags = {
    Name       = "demo-cdc-redshift-public-route-igw"
    created_by = "terraform"
  }
}

# Assign the redshift route table to the redshift Subnet az1 for IGW 
resource "aws_route_table_association" "redshift-subnet-rt-association-igw-az1" {
  subnet_id      = aws_subnet.redshift-subnet-az1.id
  route_table_id = aws_route_table.redshift-rt-igw.id
}

# Assign the public route table to the redshift Subnet az2 for IGW 
resource "aws_route_table_association" "redshift-subnet-rt-association-igw-az2" {
  subnet_id      = aws_subnet.redshift-subnet-az2.id
  route_table_id = aws_route_table.redshift-rt-igw.id
}

resource "aws_default_security_group" "redshift_security_group" {
  depends_on = [aws_vpc.redshift-vpc]

  vpc_id = aws_vpc.redshift-vpc.id

  ingress {
    description = "Redshift Port"
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name       = "demo-cdc-redshift-security-group"
    created_by = "terraform"
  }
}


# Create the Redshift Cluster
resource "aws_redshift_cluster" "redshift_cluster" {
  depends_on = [
    aws_vpc.redshift-vpc,
    aws_redshift_subnet_group.redshift-subnet-group
  ]

  cluster_identifier = var.redshift_cluster_identifier
  database_name      = var.redshift_database_name
  master_username    = var.redshift_admin_username
  master_password    = var.redshift_admin_password
  node_type          = var.redshift_node_type
  cluster_type       = var.redshift_cluster_type
  number_of_nodes    = var.redshift_number_of_nodes

  cluster_subnet_group_name = aws_redshift_subnet_group.redshift-subnet-group.id
  publicly_accessible       = true
  skip_final_snapshot       = true

  tags = {
    Name       = "demo-cdc-redshift-cluster"
    created_by = "terraform"
  }
}
