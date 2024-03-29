.PHONY: fmt clean infra all

all: infra
	@echo ""
	@echo "Tasky URL - http://`kubectl -n tasky get ingress -o json | jq -r '.items[].status.loadBalancer.ingress[].hostname'`"
infra: fmt
	@terraform init
	@-terraform apply -auto-approve
fmt:
	@terraform fmt -recursive

clean:
	@-terraform destroy -auto-approve