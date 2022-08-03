data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = [ "sts:AssumeRole" ]
    effect = "Allow"
    principals {
      identifiers = [ "ecs-tasks.amazonaws.com" ]
      type = "Service"
    }
  }
}

data "aws_iam_policy_document" "ecs_agent" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_ami" "ec2_ami" {
  most_recent = true
  owners      = [ "amazon" ]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-*"]
  }
  
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}