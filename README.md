# Project 3: EC2 State Monitoring with CloudWatch Alarm

An independent Terraform project that deploys one Amazon Linux 2023 EC2 instance, enables one-minute detailed monitoring, and creates a CloudWatch alarm for high CPU. A small Python CPU-load script is installed on the instance. Optional SNS email notifications can be enabled with `alert_email`.

## Architecture

Terraform -> EC2 (t3.micro by default) -> EC2 `CPUUtilization` metric -> CloudWatch alarm (>70% for 2 consecutive 1-minute periods) -> optional SNS email.

## Prerequisites

- AWS account and credentials configured locally/Codespaces (`aws configure` or environment credentials).
- AWS CLI, Terraform >= 1.5, and SSH client.
- An existing EC2 key pair in the AWS region selected below. Keep its `.pem` file private.
- The default VPC must exist in that region.

## 1. Configure

```bash
aws sts get-caller-identity
aws configure get region
terraform -version
```

If using AWS CLI credentials, set the region to `ap-south-1` or use the region you prefer:

```bash
aws configure set region ap-south-1
```

Create an EC2 key pair if you do not already have one in that region:

```bash
aws ec2 create-key-pair --key-name ec2-cw-demo-key --query KeyMaterial --output text > ec2-cw-demo-key.pem
chmod 400 ec2-cw-demo-key.pem
```

If the key pair already exists, use its name and the matching private key file instead. Get your current public IPv4 address from a trusted IP-check website, then use it with `/32` (example format: `198.51.100.25/32`). Do not use `0.0.0.0/0` for SSH.

Create the variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set `key_name` and `ssh_cidr`. Optionally set `alert_email` to an address you control. If email is set, confirm the AWS SNS subscription email after deployment.

## 2. Deploy

Run from this project directory:

```bash
./scripts/deploy.sh
```

The script initializes Terraform, formats and validates the configuration, shows a plan, and asks for confirmation before creating resources. Note the `instance_id`, `public_ip`, and `alarm_name` outputs.

## 3. Generate CPU load

Wait 2-3 minutes after deployment for user data to finish. Connect using the private key matching `key_name`:

```bash
ssh -i ec2-cw-demo-key.pem ec2-user@<PUBLIC_IP>
```

On the EC2 instance, run the included 5-minute load generator:

```bash
python3 /home/ec2-user/cpu_load.py
```

It starts one worker per vCPU. Leave it running for five minutes. Exit SSH when finished.

## 4. Verify the CloudWatch alarm

In AWS Console, select the same region as Terraform, then open **CloudWatch -> Alarms -> All alarms** and open `ec2-cw-state-monitor-high-cpu` (or the name shown by Terraform). The alarm should transition from `OK` to `ALARM` after CPU exceeds the configured threshold for two consecutive one-minute periods. It can take a few minutes for metrics and alarm state to update.

CLI checks:

```bash
aws cloudwatch describe-alarms --alarm-names ec2-cw-state-monitor-high-cpu
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=<INSTANCE_ID> \
  --start-time "$(date -u -d '20 minutes ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --period 60 --statistics Average
```

For a screenshot deliverable, capture the CloudWatch alarm details showing the alarm name, `ALARM` state, threshold, and metric/instance dimension. If it remains `OK`, verify the load script is running and wait for additional one-minute datapoints.

## 5. GitHub repository deliverable

```bash
git init
git add .
git commit -m "Build EC2 CPU monitoring with Terraform and CloudWatch"
git branch -M main
```

Create an empty GitHub repository, then use the repository URL GitHub provides:

```bash
git remote add origin <YOUR_GITHUB_REPOSITORY_URL>
git push -u origin main
```

Do not commit `terraform.tfvars`, state files, private keys, or AWS credentials. `.gitignore` excludes the common sensitive/local files.

## 6. IMPORTANT: avoid ongoing AWS charges

When screenshots and repository are complete, return to this directory and run:

```bash
./scripts/destroy.sh
```

Type `yes` when Terraform asks. Confirm the EC2 instance, security group, CloudWatch alarm, and optional SNS topic are removed. Delete the locally-created key pair file when no longer needed; the EC2 key-pair registration can be removed separately if desired:

```bash
aws ec2 delete-key-pair --key-name ec2-cw-demo-key
```

Only run that last command if you created that key pair for this project and no longer need it.

## Troubleshooting

- **InvalidKeyPair.NotFound**: key pair name does not exist in the selected region; create/select one in the same region.
- **No default VPC**: create/select a default VPC and subnet, or adapt the Terraform to an existing VPC.
- **SSH timeout**: check `ssh_cidr` matches your current public IP, the instance has a public IP, and the key file is correct.
- **Alarm does not trigger**: confirm detailed monitoring is enabled, the CPU script is running, and you are viewing CloudWatch in the deployment region. Allow several minutes for datapoints/state evaluation.
- **Email not received**: check spam and confirm the SNS subscription from the AWS email.
