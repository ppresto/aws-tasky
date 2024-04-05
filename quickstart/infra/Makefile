.PHONY: fmt clean infra all

all: infra getIngress
getIngress:
	@. ../../scripts/kubectl_connect_eks.sh .
	@echo ""
	@echo "Tasky URL - http://`kubectl -n tasky get ingress -o json | jq -r '.items[].status.loadBalancer.ingress[].hostname'`"
infra: fmt
	@terraform init
	@-terraform apply -auto-approve
	@terraform apply -auto-approve
fmt:
	@../../scripts/tf_fmt.sh

clean:
	@-kubectl delete -f ../k8s-service
	@-helm uninstall -n kube-system aws-load-balancer-controller
	@-kubectl delete -n kube-system sa aws-load-balancer-controller
	@-terraform destroy -auto-approve