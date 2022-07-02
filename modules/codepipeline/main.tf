resource "aws_codepipeline" "aws_codepipeline" {
  name     = var.name
  role_arn = var.pipe_role

  artifact_store {
    location = var.s3_bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "App_Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["AppSourceArtifact"]

      configuration = {
        OAuthToken           = var.github_token
        Owner                = var.app_repo_owner
        Repo                 = var.app_repo_name
        Branch               = var.app_branch
        PollForSourceChanges = true
      }
    }

      action {
      name             = "Env_Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["EnvSourceArtifact"]

      configuration = {
        OAuthToken           = var.github_token
        Owner                = var.env_repo_owner
        Repo                 = var.env_repo_name
        Branch               = var.env_branch
        PollForSourceChanges = false
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build_client"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["AppSourceArtifact", "EnvSourceArtifact"]
      output_artifacts = ["BuildArtifact_client"]

      configuration = {
        ProjectName = var.codebuild_project_client
        PrimarySource = "EnvSourceArtifact"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy_client"
      category        = "Deploy"
      owner           = "AWS"
      provider        = var.deploy_provider
      input_artifacts = ["BuildArtifact_client"]
      version         = "1"

      configuration = var.client_deploy_configuration
    }
  }

  lifecycle {
    # prevents github OAuthToken from causing updates, since it's removed from state file
    ignore_changes = [stage[0].action[0].configuration]
  }

  tags = var.tags
}

resource "aws_codestarnotifications_notification_rule" "codepipeline" {
  name        = "pipeline_execution_status"
  detail_type = "FULL"

  event_type_ids = [
    "codepipeline-pipeline-action-execution-succeeded",
    "codepipeline-pipeline-action-execution-failed"
  ]
  resource = aws_codepipeline.aws_codepipeline.arn

  target {
    address = var.sns_topic
  }

  tags = var.tags
}
