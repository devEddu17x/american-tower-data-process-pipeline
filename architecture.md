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
- `enable_emr` toggle preserves all S3 Data Lake buckets while destroying EC2 compute resources to eliminate idle costs.

- **Production Scaled Topology (11 Nodes / 44 vCPUs / 176 GB RAM):**
- 1 Master node (`m5.xlarge`, On-Demand): 4 vCPUs, 16 GB RAM (YARN coordinator, PySpark driver, Jupyter kernel).
- 2 Core nodes (`m5.xlarge`, On-Demand): 8 vCPUs, 32 GB RAM (HDFS distributed storage & execution).
- 8 Task nodes (`m5.xlarge`, Spot): 32 vCPUs, 128 GB RAM (pure Spark worker execution, bid price $0.192 USD/hr).
- Quota compliance: Exactly 12 / 16 Standard On-Demand vCPUs and 32 / 32 Standard Spot vCPUs. Zero quota violations.
- Service-linked role `AWSServiceRoleForEC2Spot` active in AWS account.

- **Ultra-Fast Bootstrap via S3 Virtualenv Cache:**
- Full analytical geospatial stack (`apache-sedona==1.7.2`, `geopandas==1.0.1`, `rasterio==1.3.11`, `shapely==2.0.6`, `pyproj==3.6.1`, `pyogrio==0.10.0`, `pyarrow==17.0.0`, `openpyxl==3.1.5`, `boto3==1.42.97`) is pre-compiled and cached in `s3://${artifacts_bucket}/envs/american-tower-venv.tar.gz` (174 MB).
- Nodes download and decompress the environment in ~3 seconds, bypassing pip compilation.
- System tool `bsdtar` is installed via `sudo dnf install -y bsdtar` during bootstrap.
- Jupyter kernel `American Tower - PySpark` is automatically registered for user `hadoop`.

### Data Lake Dedicated Buckets & Layout

| Bucket / Ruta | Contenido |
| --- | --- |
| `bronze` (`<fuente>/snapshot_id=<id>/`) | Archivos originales y metadatos de la versión incorporada. |
| `silver` (`<tabla>/version=<id>/`) | Datos normalizados por fuente. |
| `gold` (`<tabla>/version=<id>/`) | Tablas integradas y aprobadas para consumo. |
| `operations` (`quarantine/<fuente>/run_id=<id>/`) | Registros rechazados y motivos de rechazo. |
| `operations` (`evidence/run_id=<id>/`) | Manifiestos, calidad, métricas y reportes de ejecución. |
| `operations` (`benchmarks/escenario=<factor>/`) | Entradas y salidas exclusivas de las pruebas de rendimiento. |
| `artifacts` (`config/`) | Configuraciones y contratos de datos versionados. |
| `artifacts` (`models/`) | Modelos y transformaciones, cuando se desarrolle el punto 4. |
| `artifacts` (`logs/`) | Registros de ejecución y eventos de Spark y EMR. |
| `artifacts` (`scripts/`) | Scripts de bootstrap y dependencias del clúster. |

---

## 3. Repository Topology

```text
.
├── notebooks/
│   ├── 00_entorno_y_configuracion.ipynb  # Environment validation, S3 probe, dynamic EMR discovery
│   └── 01_ingesta_bronze.ipynb           # Distributed ingestion across 10 worker nodes
├── scripts/
│   ├── bootstrap.sh                      # EMR bootstrap action (S3 cache, bsdtar, PySpark venv)
│   └── connect_emr.sh                    # Automated SSH, SSM key fetch, tunnels & VS Code Remote
└── terraform/
    ├── bootstrap/                        # Remote state backend (S3 bucket with native locking)
    ├── envs/
    │   └── dev/                          # Root dev environment orchestration
    └── modules/
        ├── networking/                   # VPC, Subnet, IGW, S3 Gateway Endpoint, EMR Security Groups
        ├── iam/                          # EMR Service Role, EC2 Role with S3FullAccess, Instance Profile
        ├── integrations/iam_to_emr/      # IAM propagation safety sleep module
        ├── s3/                           # Data Lake 5-bucket architecture with force_destroy = false
        └── emr/                          # EMR Cluster (Master + Core) & Spot Task Instance Group
```

---

## 4. Cluster Architecture & Operational Interfaces

### Web Monitoring & Tunneling Strategy
Because AWS EMR enforces the strict account-level *Block Public Access* policy, web consoles cannot expose unauthenticated ports to the public internet (`0.0.0.0/0`). Connectivity is resolved via secure SSH port forwarding:

| Interface | Remote Port | Local URL | Description |
| :--- | :---: | :--- | :--- |
| **Spark History Server** | `18080` | `http://localhost:18080` | Official Spark Web UI with persistent event logs, Bootstrap styling, DAG visualization, and real-time Incomplete Applications view. |
| **YARN ResourceManager** | `8088` | `http://localhost:8088` | Cluster overview, live metrics, memory/vCPU allocation, and status of all 10 worker nodes. |
| **Spark Driver UI** | `4040` | `http://localhost:4040` | Dynamic ephemeral port active only while a SparkSession is running (wrapped in YARN AmIpFilter). |

*Note on LocalForward routing:* In Amazon EMR, YARN binds to the private VPC IP rather than loopback `127.0.0.1`. The SSH tunnels in `connect_emr.sh` and Terraform's `.ssh/config` forward directly to `${MASTER_DNS}` (which resolves internally to the private IP), preventing connection rejections.

---

## 5. Agent Operational Standards

- **Lifecycle Safety:** Never modify `core_instance_group` or `configurations_json` without checking `lifecycle { ignore_changes = [os_release_label, configurations_json] }` to avoid unwanted cluster destruction.
- **Quota Awareness:** Keep On-Demand vCPUs under 16 and Spot vCPUs under 32 in `us-east-1`.
- **Terraform Formatting & Validation:** Always validate HCL with `terraform fmt` and `terraform validate`.
- **No Hardcoded Credentials:** Never hardcode ARNs, IPs, or key pairs; use input variables, SSM Parameter Store, or dynamic instance metadata.
