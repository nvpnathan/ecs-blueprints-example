# ------- IAM Roles -------
resource "aws_iam_role" "ecs_task_excecution_role" {
  name               = local.name
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
  tags = {
    Name = local.name
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_task_excecution_role.name

  lifecycle {
    create_before_destroy = true
  }
}
