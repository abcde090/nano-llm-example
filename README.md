# nano-llm-example

Minimal AI infrastructure on GCP: Terraform builds a GKE Autopilot cluster in
its own VPC, and Kubernetes manifests deploy a **very tiny LLM** —
[Qwen2.5 0.5B](https://ollama.com/library/qwen2.5:0.5b) served by
[Ollama](https://ollama.com) — entirely on CPU, so no GPU quota is required.

Reference: [AI/ML orchestration on GKE](https://docs.cloud.google.com/kubernetes-engine/docs/integrations/ai-infra)

## Architecture

```
GCP project
└── VPC (nano-llm-vpc)
    ├── Subnet + secondary ranges (pods / services)
    ├── Cloud Router + Cloud NAT (private nodes pull images & models)
    └── GKE Autopilot cluster (private nodes, public endpoint)
        └── namespace: nano-llm
            ├── Deployment: ollama (Qwen2.5 0.5B, 2 vCPU / 4 GiB)
            ├── PVC: ollama-models (model cache survives restarts)
            └── Service: ClusterIP :11434
```

Why these choices:

- **Autopilot** — no node pools to size; you pay per pod request, which suits a
  single tiny model.
- **CPU inference** — a 0.5B-parameter model runs comfortably on 2 vCPUs; no
  GPU quota requests or driver DaemonSets needed.
- **Ollama** — one container serves the model with both its native API and an
  OpenAI-compatible `/v1/chat/completions` endpoint.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- `gcloud` CLI authenticated (`gcloud auth application-default login`)
- `kubectl` with the GKE auth plugin (`gcloud components install gke-gcloud-auth-plugin`)
- A GCP project with billing enabled

## 1. Provision infrastructure

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # set your project_id / region
terraform init
terraform apply
```

Takes ~10 minutes. Then configure kubectl:

```bash
$(terraform output -raw get_credentials_command)
```

## 2. Deploy the LLM

```bash
cd ..
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/ollama.yaml
kubectl -n nano-llm rollout status deployment/ollama --timeout=15m
```

The first rollout is slow: Autopilot provisions a node, then the pod pulls the
Qwen2.5 0.5B weights (~400 MB) into the PVC. Later restarts reuse the cache.

(Or just run `make apply creds deploy` from the repo root.)

## 3. Talk to it

```bash
kubectl -n nano-llm port-forward svc/ollama 11434:11434
```

Then in another terminal — OpenAI-compatible endpoint:

```bash
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5:0.5b",
    "messages": [{"role": "user", "content": "Say hello in five words."}]
  }'
```

Or Ollama's native API:

```bash
curl http://localhost:11434/api/generate \
  -d '{"model": "qwen2.5:0.5b", "prompt": "Why is the sky blue?", "stream": false}'
```

## Costs

Rough always-on cost: the pod's 2 vCPU / 4 GiB Autopilot request plus the
Autopilot cluster management fee, Cloud NAT, and a 10 GiB disk — on the order
of **US$100–150/month** depending on region. `terraform destroy` (after
`make clean-k8s` to release the load balancer/PVC) tears everything down.

## Variations

- **Expose it externally**: change the Service type in `k8s/ollama.yaml` to
  `LoadBalancer`. Put auth in front (e.g. IAP or an API gateway) before doing
  this with anything non-toy.
- **Bigger model**: bump `resources` and swap the model tag, e.g.
  `qwen2.5:1.5b` or `llama3.2:1b` at ~4 vCPU / 8 GiB.
- **GPU inference**: on Autopilot, add a `nodeSelector` for
  `cloud.google.com/gke-accelerator: nvidia-l4` plus a
  `nvidia.com/gpu: "1"` resource limit to the container — Autopilot
  provisions the GPU node automatically (subject to GPU quota in your region).
- **Scale out**: the PVC is ReadWriteOnce, so for >1 replica switch the model
  cache to an emptyDir (each pod pulls its own copy) and raise `replicas`.

## Repository layout

```
terraform/          # GCP infra: APIs, VPC, NAT, GKE Autopilot
k8s/                # Kubernetes manifests: namespace, Ollama deployment
Makefile            # init / plan / apply / creds / deploy / chat shortcuts
```
