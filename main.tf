terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "ec2_sg" {
  name_prefix = "${var.project_name}-sg-"
  description = "SSH access restricted to the configured client IP"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from the user's public IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-sg" }
}

resource "aws_instance" "monitoring" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true
  monitoring                  = true

  user_data = <<-USERDATA
    #!/bin/bash
    set -eux
    dnf update -y
    echo 'aW1wb3J0IG11bHRpcHJvY2Vzc2luZywgdGltZSwgb3MKCmRlZiBidXJuKCk6CiAgICBlbmQgPSB0aW1lLnRpbWUoKSArIDMwMAogICAgeCA9IDAKICAgIHdoaWxlIHRpbWUudGltZSgpIDwgZW5kOgogICAgICAgIHggPSAoeCAqIDMgKyAxKSAlIDEwMDAwMDMKCmlmIF9fbmFtZV9fID09ICdfX21haW5fXyc6CiAgICB3b3JrZXJzID0gbWF4KDEsIG9zLmNwdV9jb3VudCgpIG9yIDEpCiAgICBwcmludChmJ1N0YXJ0aW5nIENQVSBsb2FkIHdpdGgge3dvcmtlcnN9IHdvcmtlcnMgZm9yIDUgbWludXRlcycpCiAgICBqb2JzID0gW211bHRpcHJvY2Vzc2luZy5Qcm9jZXNzKHRhcmdldD1idXJuKSBmb3IgXyBpbiByYW5nZSh3b3JrZXJzKV0KICAgIGZvciBqb2IgaW4gam9iczogam9iLnN0YXJ0KCkKICAgIGZvciBqb2IgaW4gam9iczogam9iLmpvaW4oKQogICAgcHJpbnQoJ0NQVSBsb2FkIHRlc3QgZmluaXNoZWQnKQo=' | base64 -d > /home/ec2-user/cpu_load.py
    chown ec2-user:ec2-user /home/ec2-user/cpu_load.py
  USERDATA

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name        = "${var.project_name}-ec2"
    Project     = var.project_name
    Environment = "demo"
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-high-cpu"
  alarm_description   = "Triggers when EC2 average CPU utilization exceeds ${var.cpu_threshold}% for two consecutive one-minute periods."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.monitoring.id
  }

  alarm_actions = var.alert_email == "" ? [] : [aws_sns_topic.alerts[0].arn]
  ok_actions    = var.alert_email == "" ? [] : [aws_sns_topic.alerts[0].arn]
}

resource "aws_sns_topic" "alerts" {
  count = var.alert_email == "" ? 0 : 1
  name  = "${var.project_name}-cpu-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}
