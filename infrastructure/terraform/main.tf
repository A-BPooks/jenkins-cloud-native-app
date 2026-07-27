provider "aws" {
  region = var.aws_region
}

# VPC Configuration
module "vpc" {
  source = "./modules/vpc"
  
  environment = var.environment
  cidr_block = var.vpc_cidr
  az_count   = var.az_count
  
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
}

# EKS Cluster
module "eks" {
  source = "./modules/eks"
  
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids
  
  node_groups = {
    general = {
      instance_types = ["m5.large", "m5.xlarge"]
      min_size       = 2
      max_size       = 10
      desired_size   = 2
      
      labels = {
        role = "general"
      }
      
      taints = []
    }
    
    performance = {
      instance_types = ["c5.large", "c5.xlarge"]
      min_size       = 1
      max_size       = 5
      desired_size   = 1
      
      labels = {
        role = "performance"
      }
      
      taints = [
        {
          key    = "dedicated"
          value  = "performance"
          effect = "NO_SCHEDULE"
        }
      ]
    }
  }
}

# RDS PostgreSQL
module "rds" {
  source = "./modules/rds"
  
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
  security_groups = [module.eks.cluster_security_group_id]
  
  instance_class = var.environment == "production" ? "db.r6g.large" : "db.t3.medium"
  storage_size   = var.environment == "production" ? 100 : 20
  engine_version = "15.3"
  
  database_name = var.db_name
  database_user = var.db_user
  database_password = var.db_password
}

# ElastiCache Redis
module "redis" {
  source = "./modules/redis"
  
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
  security_groups = [module.eks.cluster_security_group_id]
  
  node_type = var.environment == "production" ? "cache.r6g.large" : "cache.t3.micro"
  num_nodes = var.environment == "production" ? 3 : 1
}

# Outputs
output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "redis_endpoint" {
  value = module.redis.endpoint
}