---
name: aws-iac
description: >-
  Use when working with AWS, Infrastructure as Code (CDK, SAM, Terraform), or
  container builds. Defines autonomous local and read-only checks versus
  explicit-approval infrastructure mutations.
---

# AWS & IaC Safety

- **Autonomous local/read-only checks:** Run `docker build`, `sam validate`, `cdk synth`, `cdk diff`, `terraform validate`, `terraform plan`, and read-only `aws` CLI inspection (`describe-*`, `list-*`, `get-*`, `sts get-caller-identity`) without waiting for approval.
- **Explicit approval required for mutations:** Never run `cdk deploy`, `cdk destroy`, `terraform apply`, `terraform destroy`, `sam deploy`, `sam delete`, or mutating `aws` CLI commands without explicit user confirmation.
- **Pre-approval summary:** Before asking for confirmation, state the target account, region, and stack (when known) and summarize the diff or plan output.
