# nano-llm-example

Minimal but production-shaped AI infrastructure on GCP: Terraform builds the
platform, Kubernetes manifests deploy a **very tiny LLM** —
[Qwen2.5 0.5B](https://ollama.com/library/qwen2.5:0.5b) served by
[Ollama](https://ollama.com) — on CPU, so no GPU quota is required. The stack
leans on GCP **managed services** end to end.

Reference: [AI/ML orchestration on GKE](https://docs.cloud.google.com/kubernetes-engine/docs/integrations/ai-infra)

## Managed services used

| Concern | Managed service | Where |
|---|---|---|
| Compute / orchestration | GKE **Autopilot** (nodes managed by Google) | `terraform/gke.tf` |
| Egress for private nodes | Cloud **NAT** | `terraform/network.tf` |
| Image supply chain | **Artifact Registry** remote repo (Docker Hub proxy + scanning) | `terraform/registry.tf` |
| Model weight storage | **Cloud Storage** + GCS FUSE CSI driver | `terraform/storage.tf`, `k8s/ollama.yaml` |
| Bucket auth | **Workload Identity Federation** (no keys) | `terraform/storage.tf` |
| Public entry point | GKE **Gateway API** → global external Application **Load Balancer** | `k8s/gateway.yaml`, `terraform/edge.tf` |
| TLS | **Certificate Manager** (Google-managed cert, DNS auth) | `terraform/edge.tf` |
| WAF / rate limiting | **Cloud Armor** | `terraform/edge.tf`, `k8s/backend-policy.yaml` |
| Authentication | **Identity-Aware Proxy** (opt-in) | `terraform/edge.tf`, `k8s/backend-policy-iap.yaml` |
| Secrets | **Secret Manager** (IAP OAuth client secret) | `terraform/edge.tf` |
| Metrics / alerting | Cloud **Monitoring** + Managed Service for **Prometheus** (built into Autopilot) | `terraform/monitoring.tf` |
| Terraform state | **GCS** backend with versioning | `terraform/bootstrap/` |
| CI/CD | **Cloud Build** → **Cloud Deploy** → GKE | `cloudbuild.yaml`, `deploy/`, `terraform/cicd.tf` |

## Architecture

```
                        ┌────────────────────────────────────────────────┐
 client ── HTTPS ──►    │ Global external ALB (Gateway API)              │
                        │  · Certificate Manager TLS   · static IP       │
                        │  · Cloud Armor rate limit    · IAP (optional)  │
                        └───────────────────┬────────────────────────────┘
                                            │
 GCP project                                ▼
 └── VPC (nano-llm-vpc) + Cloud NAT ── GKE Autopilot (private nodes)
      └── namespace: nano-llm
          ├── Job: ollama-model-seed  ── pulls qwen2.5:0.5b ──► GCS bucket
          ├── Deployment: ollama (2 vCPU / 4 GiB, CPU-only)
          │     · image via Artifact Registry (Docker Hub proxy)
          │     · /models = GCS FUSE mount (Workload Identity, no keys)
          └── Service: ollama :11434  (OpenAI-compatible API)

 CI/CD: push to main ─► Cloud Build (validate + render) ─► Cloud Deploy ─► GKE
 Ops:   Cloud Monitoring alerts (restarts, memory) · Managed Prometheus
```

Why these choices:

- **Autopilot** — no node pools to size; you pay per pod request, which suits
  a single tiny model.
- **CPU inference** — a 0.5B-parameter model runs comfortably on 2 vCPUs; no
  GPU quota requests or driver DaemonSets needed.
- **GCS for weights instead of a PVC** — the model store is seeded once by a
  Job and shared read-mostly by every replica, so scaling out is just
  `replicas: N` (a ReadWriteOnce disk would pin you to one pod).
- **Ollama** — one container serves the model with both its native API and an
  OpenAI-compatible `/v1/chat/completions` endpoint.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- `gcloud` CLI authenticated (`gcloud auth application-default login`)
- `kubectl` + GKE auth plugin (`gcloud components install gke-gcloud-auth-plugin`)
- `envsubst` (package `gettext`) — the k8s manifests are small templates
- A GCP project with billing enabled

## 0. (Optional) Remote Terraform state

```bash
cd terraform/bootstrap
terraform init && terraform apply -var project_id=YOUR_PROJECT
cd ..
# uncomment the backend "gcs" block in versions.tf, then:
terraform init -migrate-state -backend-config="bucket=YOUR_PROJECT-nano-llm-tfstate"
```

(This leaves you in `terraform/` — skip the `cd terraform` at the start of
step 1.)

## 1. Provision infrastructure

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # set project_id / region (+ optional flags)
terraform init
terraform apply
```

Takes ~10 minutes. Commit the `.terraform.lock.hcl` that `init` generates so CI
resolves the same provider versions. Then configure kubectl and return to the
repo root (the Makefile lives there):

```bash
$(terraform output -raw get_credentials_command)
cd ..
```

## 2. Deploy the LLM

```bash
make deploy
```

This applies the namespace, runs the **model-seed Job** (`k8s/seed-job.yaml`,
pulls the ~400 MB Qwen2.5 0.5B weights into the GCS bucket once under a
write-capable identity), and rolls out the Ollama deployment, which mounts
those weights read-only via GCS FUSE. Pods only report Ready once the model is
actually servable (`ollama show` startup probe). First run is slow while
Autopilot provisions a node; later restarts reuse the bucket.

## 3. Talk to it

Private (no edge stack needed):

```bash
make chat          # port-forwards svc/ollama to localhost:11434
```

```bash
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5:0.5b",
    "messages": [{"role": "user", "content": "Say hello in five words."}]
  }'
```

## 4. (Optional) Public HTTPS endpoint

> **Warning:** without IAP (`enable_iap = false`, the default) the endpoint is
> **public and unauthenticated** — the Cloud Armor 60 req/min/IP throttle is
> abuse mitigation, not access control, and anyone can run inference on your
> bill. Enable IAP (org-owned projects) or put your own auth in front for
> anything beyond a short-lived demo. Only the OpenAI-compatible `/v1` paths
> are routed through the load balancer; Ollama's management API stays private.

Set in `terraform.tfvars`:

```hcl
domain     = "llm.example.com"

# Optional, org-owned projects only:
enable_iap        = true
iap_support_email = "you@example.com"
iap_members       = ["user:you@example.com"]

alert_email = "you@example.com"   # Cloud Monitoring notifications
```

Then:

```bash
make apply
# Create two DNS records at your provider:
#   1. terraform output dns_authorization_record   (CNAME, proves domain ownership)
#   2. an A record: llm.example.com -> $(terraform output -raw gateway_ip)
make deploy-gateway
```

`deploy-gateway` applies the Gateway, HTTPRoute and health-check policy, and
attaches Cloud Armor — plus IAP (client secret pulled from Secret Manager)
when `enable_iap = true`. Certificate issuance takes a few minutes after the
DNS records resolve.

## 5. (Optional) CI/CD

`terraform apply` always creates the Cloud Deploy pipeline (`nano-llm`) and
its execution service account. To trigger builds from GitHub pushes:

1. Create a Cloud Build **GitHub connection** once in the console
   (Cloud Build → Repositories → 2nd gen → Connect).
2. Set `cloudbuild_connection` in `terraform.tfvars` to its full resource name
   and re-apply.

Every push to `main` then runs `cloudbuild.yaml`: Terraform fmt/validate →
render manifests → `gcloud deploy releases create` → Cloud Deploy rolls out
to the cluster.

## Costs

Rough always-on cost for the core stack: the pod's 2 vCPU / 4 GiB Autopilot
request plus the cluster management fee, Cloud NAT, and GCS storage — on the
order of **US$100–150/month** depending on region. The edge stack adds the
load balancer (~US$20/month). `make clean-k8s` then `terraform destroy` tears
everything down.

## Variations

- **Bigger model**: bump `resources` and swap the model tag in
  `k8s/ollama.yaml`, e.g. `qwen2.5:1.5b` or `llama3.2:1b` at ~4 vCPU / 8 GiB.
- **GPU inference**: on Autopilot, add a `nodeSelector` for
  `cloud.google.com/gke-accelerator: nvidia-l4` plus a `nvidia.com/gpu: "1"`
  resource limit — Autopilot provisions the GPU node automatically (subject
  to GPU quota).
- **Scale out**: weights are shared via GCS, so raise `replicas` or add an
  HPA; the load balancer spreads traffic across pods.
- **Fully managed alternative**: if you want zero cluster ops, Vertex AI
  Model Garden / online prediction endpoints replace this whole stack — GKE
  is the right choice when you want control of the serving layer.

## Repository layout

```
terraform/            # GCP infra: APIs, VPC+NAT, GKE Autopilot, Artifact
│                     # Registry, GCS, Cloud Armor, Certificate Manager,
│                     # IAP, Secret Manager, Monitoring, Cloud Deploy
├── bootstrap/        # one-time GCS bucket for Terraform state
k8s/                  # manifest templates: Ollama, seed Job, Gateway, backend policies
deploy/skaffold.yaml  # Cloud Deploy render/apply config
cloudbuild.yaml       # CI pipeline (validate → render → release)
Makefile              # init/plan/apply · creds · deploy · deploy-gateway · chat
```
