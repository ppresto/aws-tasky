.PHONY: fmt clean infra all

all: infra getIngress

pre-scan:
	@trivy image --severity HIGH,CRITICAL ppresto/tasky:1.2
	@trivy fs --scanners vuln,secret,misconfig ../../ --skip-dirs ".terraform" --report summary
fmt:
	@../../scripts/tf_fmt.sh
infra: fmt
	@terraform init
	@-terraform apply -auto-approve
	@terraform apply -auto-approve
post-scan:
	@trivy aws --region us-west-2 --service s3 --arn arn:aws:s3:::ext-mongodb-s3-backup
	@trivy aws --region us-west-2 --service s3 --service eks --service ec2
	@trivy k8s --namespace=tasky --report=summary deploy
getIngress:
	@. ../../scripts/kubectl_connect_eks.sh .
	@echo ""
	@echo "Tasky URL - http://`kubectl -n tasky get ingress -o json | jq -r '.items[].status.loadBalancer.ingress[].hostname'`"
clean:
	@-kubectl delete -f ../k8s-service
	@-helm uninstall -n kube-system aws-load-balancer-controller
	@-kubectl delete -n kube-system sa aws-load-balancer-controller
	@-terraform destroy -auto-approve