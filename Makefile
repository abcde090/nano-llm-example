TF_DIR := terraform

.PHONY: init plan apply destroy creds deploy chat clean-k8s

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
	$$(terraform -chdir=$(TF_DIR) output -raw get_credentials_command)

deploy:
	kubectl apply -f k8s/namespace.yaml
	kubectl apply -f k8s/ollama.yaml
	kubectl -n nano-llm rollout status deployment/ollama --timeout=15m

# Port-forward and send a test prompt (run in two terminals, or background the first).
chat:
	kubectl -n nano-llm port-forward svc/ollama 11434:11434

clean-k8s:
	kubectl delete -f k8s/ollama.yaml --ignore-not-found
	kubectl delete -f k8s/namespace.yaml --ignore-not-found
