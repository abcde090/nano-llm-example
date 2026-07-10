TF_DIR := terraform
TF_OUT := terraform -chdir=$(TF_DIR) output -raw

.PHONY: init plan apply destroy creds deploy deploy-gateway chat clean-k8s

init:
	terraform -chdir=$(TF_DIR) init

plan:
	terraform -chdir=$(TF_DIR) plan

apply:
	terraform -chdir=$(TF_DIR) apply

destroy:
	terraform -chdir=$(TF_DIR) destroy

# Configure kubectl against the freshly built cluster.
creds:
	$$($(TF_OUT) get_credentials_command)

# Core workload: namespace, model-seed Job, Ollama deployment + service.
# Manifests are templates; envsubst fills them from Terraform outputs
# (requires gettext's envsubst). The completed seed Job is deleted first —
# Job templates are immutable, so a changed template can't be re-applied.
deploy:
	kubectl apply -f k8s/namespace.yaml
	kubectl -n nano-llm delete job ollama-model-seed --ignore-not-found
	PROJECT_ID=$$($(TF_OUT) project_id) \
	REGION=$$($(TF_OUT) cluster_region) \
	MODELS_BUCKET=$$($(TF_OUT) models_bucket) \
	  envsubst '$$PROJECT_ID $$REGION $$MODELS_BUCKET' < k8s/seed-job.yaml | kubectl apply -f -
	PROJECT_ID=$$($(TF_OUT) project_id) \
	REGION=$$($(TF_OUT) cluster_region) \
	MODELS_BUCKET=$$($(TF_OUT) models_bucket) \
	  envsubst '$$PROJECT_ID $$REGION $$MODELS_BUCKET' < k8s/ollama.yaml | kubectl apply -f -
	kubectl apply -f k8s/webui.yaml
	kubectl -n nano-llm wait --for=condition=complete job/ollama-model-seed --timeout=20m
	kubectl -n nano-llm rollout status deployment/ollama --timeout=15m
	kubectl -n nano-llm rollout status deployment/open-webui --timeout=10m

# Public HTTPS edge: Gateway + HTTPRoute + health check + Cloud Armor/IAP
# backend policy. Requires terraform applied with var.domain set.
deploy-gateway:
	@test -n "$$($(TF_OUT) domain)" || { echo "Set var.domain in terraform first"; exit 1; }
	DOMAIN=$$($(TF_OUT) domain) \
	  envsubst '$$DOMAIN' < k8s/gateway.yaml | kubectl apply -f -
	@if [ "$$($(TF_OUT) iap_enabled)" = "true" ]; then \
	  gcloud secrets versions access latest --secret=nano-llm-iap-client-secret \
	    | kubectl -n nano-llm create secret generic iap-oauth \
	        --from-file=key=/dev/stdin --dry-run=client -o yaml \
	    | kubectl apply -f -; \
	  IAP_CLIENT_ID=$$($(TF_OUT) iap_client_id) \
	    envsubst '$$IAP_CLIENT_ID' < k8s/backend-policy-iap.yaml | kubectl apply -f -; \
	else \
	  kubectl apply -f k8s/backend-policy.yaml; \
	fi

# Port-forward for local access without the public edge.
chat:
	kubectl -n nano-llm port-forward svc/ollama 11434:11434

# Browser chat UI: open http://localhost:3000 while this runs.
webui:
	kubectl -n nano-llm port-forward svc/open-webui 3000:8080

clean-k8s:
	kubectl delete -f k8s/backend-policy.yaml --ignore-not-found
	kubectl delete gcpbackendpolicy ollama -n nano-llm --ignore-not-found
	kubectl delete -f k8s/gateway.yaml --ignore-not-found 2>/dev/null || true
	kubectl delete namespace nano-llm --ignore-not-found
