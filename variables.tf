variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Short name used in resource names"
  type        = string
  default     = "ec2-cw-state-monitor"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair in the selected region"
  type        = string
}

variable "ssh_cidr" {
  description = "Your public IPv4 CIDR, for example 203.0.113.10/32"
  type        = string
}

variable "cpu_threshold" {
  description = "CPU utilization alarm threshold percentage"
  type        = number
  default     = 70
}

variable "alert_email" {
  description = "Optional email for SNS alarm notifications; leave empty to disable email"
  type        = string
  default     = ""
}
