# Big Data & Analytics Infrastructure - Agent Context & Guidelines

## 1. Project Context & Objective

This repository provisions a reproducible, production-grade cloud environment for the **Big Data and Data Analytics** university curriculum (Hadoop, HDFS, Spark, MLlib, and Structured Streaming) on AWS using Infrastructure as Code (IaC) with Terraform.

The architectural pattern avoids legacy manual VM configurations, prioritizing a cloud-native **AWS EMR on EC2** deployment controlled remotely via **VS Code Remote-SSH**, leveraging S3 for storage decoupling, and enforcing strict cost governance through auto-termination policies.

---

## 2. Core Architectural Principles & Guardrails

- **Strict Cost Governance:**
- Never provision NAT Gateways. Outbound internet traffic uses an Internet Gateway in a public subnet; intra-AWS S3 traffic routes through a free S3 Gateway VPC Endpoint.
- Idle timeout auto-termination must be set on the EMR cluster (`idle_timeout = 3600` seconds).
- Default development topology is minimal: 1 Master node (m5.xlarge), 0 to 1 Core nodes. Core nodes should evaluate Spot instances where feasible.

- **Network & Security Boundaries:**
- Master Security Group accepts ingress SSH (port 22) **only** from `var.my_ip/32`.
- Slaves (Core/Task) Security Group accepts traffic exclusively from the Master SG and internally from itself. No direct internet ingress.
- Service Access SG governs internal AWS EMR control plane communication over port 9443.

- **Storage & Compute Decoupling:**
- Compute is ephemeral. The HDFS on EBS storage terminates with the cluster.
- Persistent scripts, artifacts, datasets, and bootstrap files reside in Amazon S3.

---

## 3. Repository Topology

```text
.
├── ansible/
├── docs/
├── scripts/
│   └── bootstrap.sh              # EMR bootstrap actions (pip dependencies, etc.)
└── terraform/
    ├── envs/
    │   └── dev/                  # Root orchestration (calls modules, defines tfvars/backend)
    ├── global/                   # Persistent foundational resources (S3 buckets, state)
    └── modules/
        ├── networking/           # VPC, Subnets, IGW, S3 Endpoint, 3x EMR Security Groups [DONE]
        ├── emr/                  # Target module: IAM roles, Instance Profile, EMR Cluster
        └── lambda/               # (Optional/Future: event triggers, Slack notifications)

```

---

## 4. Current Sprint: `terraform/modules/emr` Implementation

### Scope & Tasks

1. **IAM Identity Layer:**

- `aws_iam_role.emr_service_role`: Assumed by `elasticmapreduce.amazonaws.com`, managed policy `AmazonEMRServicePolicy_v2` or `service-role/AmazonEMRServicePolicy_v2`.
- `aws_iam_role.emr_ec2_role`: Assumed by `ec2.amazonaws.com`, policies for basic EMR job execution and S3 read/write (`AmazonS3FullAccess` or scoped bucket access).
- `aws_iam_instance_profile.emr_ec2_profile`: Wraps `emr_ec2_role`.

2. **Artifact Delivery (S3 / Bootstrap):**

- Upload `scripts/bootstrap.sh` to an S3 bucket via `aws_s3_object`.
- Bootstrap script installs runtime Python packages: `pandas`, `numpy`, `matplotlib`, `seaborn`, `pyarrow`.

3. **Cluster Engine (`aws_emr_cluster`):**

- Release: `emr-7.1.0` (or latest compatible 7.x).
- Applications: `["Hadoop", "Spark"]`.
- Bind `ec2_attributes` to inputs exported by `modules/networking`:
- `subnet_id = var.public_subnet_id`
- `emr_managed_master_security_group = var.emr_master_sg_id`
- `emr_managed_slave_security_group = var.emr_slave_sg_id`
- `service_access_security_group = var.emr_service_access_sg_id`
- `instance_profile = aws_iam_instance_profile.emr_ec2_profile.arn`
- `key_name = var.key_pair_name`

- Dynamic/configurable node topology:
- `master_instance_group`: count = 1, type = `var.master_instance_type`.
- `core_instance_group`: count = `var.core_instance_count`, type = `var.core_instance_type` (can be 0 or omitted when running single-node EDA).

- Configuration block:

```hcl
auto_termination_policy {
  idle_timeout = 3600
}

```

### Required Variables (`terraform/modules/emr/variables.tf`)

- `project_name`: String identifier.
- `environment`: String (e.g., `dev`).
- `public_subnet_id`: String.
- `emr_master_sg_id`: String.
- `emr_slave_sg_id`: String.
- `emr_service_access_sg_id`: String.
- `key_pair_name`: String.
- `bootstrap_bucket_id`: String (S3 bucket for bootstrapping).
- `master_instance_type`: String (default: `"m5.xlarge"`).
- `core_instance_type`: String (default: `"m5.xlarge"`).
- `core_instance_count`: Number (default: `1`).

### Required Outputs (`terraform/modules/emr/outputs.tf`)

- `cluster_id`: ID of the created EMR cluster.
- `master_public_dns`: Public DNS name of the Master node.
- `ssh_connection_string`: Computed string: `ssh -i <path-to-key> hadoop@<master_public_dns>`.

---

## 5. Agent Operational Standards

- **Terraform Formatting & Validation:** Always validate HCL with `terraform fmt -check` and `terraform validate`.
- **Explicit Resource Dependencies:** Use `depends_on` when IAM policies or S3 objects must exist before the cluster initializes.
- **No Hardcoded Credentials:** Never hardcode ARNs, IPs, or key pairs; use input variables or dynamic data sources.
- **Concise HCL:** Keep definitions modular, DRY, and well-tagged (`Project = "big-data"`, `ManagedBy = "Terraform"`).
