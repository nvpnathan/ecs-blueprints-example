provider "aws" {
  region = local.region
}

data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}

locals {
  name   = basename(path.cwd)
  region = "us-west-2"

  app_server_port = 3001

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/ecs-client-backend"
  }
}

################################################################################
# ECS Blueprint
################################################################################

module "server_alb_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${local.name}-server"
  description = "Security group for server application"
  vpc_id      = var.vpc_id

  ingress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = var.client_security_group
    },
  ]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = var.private_subnets_cidr_blocks

  tags = local.tags
}

module "server_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 7.0"

  name = "${local.name}-server"

  load_balancer_type = "application"
  internal           = true

  vpc_id          = var.vpc_id
  subnets         = var.private_subnets
  security_groups = [module.server_alb_security_group.security_group_id]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    },
  ]

  target_groups = [
    {
      name             = "server"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "ip"
      health_check = {
        path    = "/status"
        port    = local.app_server_port
        matcher = "200-299"
      }
    },
  ]

  tags = local.tags
}

module "app_ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 1.0"

  repository_name = "${local.name}-server"

  create_lifecycle_policy           = false
  repository_read_access_arns       = [var.ecs_task_execution_role_arn]
  repository_read_write_access_arns = [module.devops_role.devops_role_arn]

  tags = local.tags
}

data "aws_iam_policy_document" "task_role" {
  statement {
    sid = "S3Read"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      module.assets_s3_bucket.s3_bucket_arn,
      "${module.assets_s3_bucket.s3_bucket_arn}/*",
    ]
  }

  statement {
    sid       = "IAMPassRole"
    actions   = ["iam:PassRole"]
    resources = ["*"]
  }

  statement {
    sid = "DynamoDBReadWrite"
    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:Describe*",
      "dynamodb:List*",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
    ]
    resources = [module.assets_dynamodb_table.dynamodb_table_arn]
  }
}

module "server_task_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${local.name}-server-task"
  description = "Security group for server task"
  vpc_id      = var.vpc_id

  ingress_with_source_security_group_id = [
    {
      from_port                = local.app_server_port
      to_port                  = local.app_server_port
      protocol                 = "tcp"
      source_security_group_id = module.server_alb_security_group.security_group_id
    },
  ]

  egress_rules = ["all-all"]

  tags = local.tags
}

module "ecs_service_app" {
  source = "../modules/ecs-service"
  
  ecs_task_execution_role_arn = var.ecs_task_execution_role_arn
  attach_task_role_policy = true

  name           = "${local.name}"
  desired_count  = 1
  ecs_cluster_id = var.ecs_cluster_id

  security_groups = [module.server_task_security_group.security_group_id]
  subnets         = var.private_subnets

  load_balancers = [{
    target_group_arn = element(module.server_alb.target_group_arns, 0)
  }]
  deployment_controller = "ECS"

  # Task Definition
  container_name   = "${local.name}"
  container_port   = local.app_server_port
  cpu              = 256
  memory           = 512
  image            = module.app_ecr.repository_url
  task_role_policy = data.aws_iam_policy_document.task_role.json

  tags = local.tags
}

module "ecs_autoscaling_server" {
  source = "../modules/ecs-autoscaling"

  cluster_name     = var.ecs_cluster_name
  service_name     = module.ecs_service_app.name
  min_capacity     = 1
  max_capacity     = 5
  cpu_threshold    = 75
  memory_threshold = 75
}

################################################################################
# CodePipeline
################################################################################

module "codepipeline_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket = "codepipeline-${local.region}-${random_id.this.hex}"
  acl    = "private"

  # For example only - please re-evaluate for your environment
  force_destroy = true

  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = local.tags
}

resource "aws_sns_topic" "codestar_notification" {
  name = local.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "WriteAccess"
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = "arn:aws:sns:${local.region}:${data.aws_caller_identity.current.account_id}:${local.name}"
        Principal = {
          Service = "codestar-notifications.amazonaws.com"
        }
      },
    ]
  })

  tags = local.tags
}

module "devops_role" {
  source = "../modules/iam"

  create_devops_role = true

  name                = "${local.name}-devops"
  ecr_repositories    = [module.app_ecr.repository_arn]
  code_build_projects = [module.codebuild_app.project_arn]

  tags = local.tags
}

module "codebuild_app" {
  source = "../modules/codebuild"

  name                   = "codebuild-${local.name}-server"
  iam_role               = module.devops_role.devops_role_arn
  ecr_repo_url           = module.app_ecr.repository_url
  folder_path            = var.folder_path_app
  buildspec_path         = var.buildspec_path
  task_definition_family = module.ecs_service_app.task_definition_family
  container_name         = module.ecs_service_app.container_name
  service_port           = local.app_server_port
  ecs_role               = "${local.name}-ecs"
  ecs_task_role          = module.ecs_service_app.task_role_arn
  dynamodb_table_name    = module.assets_dynamodb_table.dynamodb_table_id

  tags = local.tags
}

module "codepipeline" {
  source = "../modules/codepipeline"

  name                     = "pipeline-${local.name}"
  pipe_role                = module.devops_role.devops_role_arn
  s3_bucket                = module.codepipeline_s3_bucket.s3_bucket_id
  github_token             = var.github_token
  app_repo_owner           = var.app_repository_owner
  app_repo_name            = var.app_repository_name
  app_branch               = var.app_repository_branch
  env_repo_owner           = var.env_repository_owner
  env_repo_name            = var.env_repository_name
  env_branch               = var.env_repository_branch
  codebuild_project_app    = module.codebuild_app.project_id
  sns_topic                = aws_sns_topic.codestar_notification.arn

  app_deploy_configuration = {
    ClusterName = var.ecs_cluster_name
    ServiceName = module.ecs_service_app.name
    FileName    = "imagedefinition.json"
  }

  tags = local.tags
}

################################################################################
# Assets
################################################################################

module "assets_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket = "assets-${local.region}-${random_id.this.hex}"
  acl    = "private"

  # For example only - please evaluate for your environment
  force_destroy = true

  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = local.tags
}

module "assets_dynamodb_table" {
  source  = "terraform-aws-modules/dynamodb-table/aws"
  version = "~> 2.0"

  name     = "${local.name}-assets"
  hash_key = "id"

  attributes = [
    {
      name = "id"
      type = "N"
    }
  ]

  tags = local.tags
}

resource "random_id" "this" {
  byte_length = "2"
}