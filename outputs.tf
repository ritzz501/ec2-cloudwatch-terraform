output "instance_id" {
  value = aws_instance.monitoring.id
}

output "public_ip" {
  value = aws_instance.monitoring.public_ip
}
}

output "alarm_name" {
  value = aws_cloudwatch_metric_alarm.cpu_high.alarm_name
}

output "ssh_command" {
  value = "ssh -i <your-key-file.pem> ec2-user@${aws_instance.monitoring.public_ip}"
}
