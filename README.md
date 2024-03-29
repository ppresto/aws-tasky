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

#### VPC - public/private subnets
#### EC2
  * Route 53 Alias to EC2 IP
  * External SSH access to 0.0.0.0/0
  * IAM Profile - 
  * SG
  * S3 Bucket

#### EC2 - MongoDB
#### EKS Cluster and AWS Loadbalancer controller have been installed
The EKS 1.27 Cluster is running in the private subnet.  The AWS LB controller was installed to support internal NLB or ALBs to EKS services.  This repo is adding the required tags to public and private subnets in order for the LB to properly discover EKS services.  This repo installed the AWS LB Controller using the following steps:
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

## Tasky Container
* why does it have a shell and package manager?
* why does it have root permissions?
```
apk add tcpdump
```

## Next Steps
Once the EKS infrastructure is ready, and Consul is deployed it's time to build the service mesh.  A good starting place is to deploy the Consul API Gateway with fake-service.  This will create an ingress into the service mesh with a test service that is designed to validate service mesh traffic management use cases. Once this is setup validate the various use cases.
* [Deploy the Consul API Gateway and fake-service](https://github.com/ppresto/aws-consul-pd/blob/main/README_Consul_APIGW.md)
* [circuit breaking](https://github.com/ppresto/aws-consul-pd/blob/main/README_Consul_L7.md#circuit-breaking)
* [rate limiting](https://github.com/ppresto/aws-consul-pd/blob/main/README_Consul_L7.md#rate-limiting)
* [retries](https://github.com/ppresto/aws-consul-pd/blob/main/README_Consul_L7.md#retries)
* [timeouts](https://github.com/ppresto/aws-consul-pd/blob/main/README_Consul_L7.md#timeouts)
* [multi-region service failover](https://github.com/ppresto/aws-consul-pd/blob/main/README_Consul_Failover.md)

## References
Circuit Breaking
https://developer.hashicorp.com/consul/tutorials/developer-mesh/service-mesh-circuit-breaking#set-up-circuit-breaking

API GW Timeouts
https://developer.hashicorp.com/consul/docs/connect/gateways/api-gateway/configuration/routeretryfilter
https://developer.hashicorp.com/consul/docs/connect/gateways/api-gateway/configuration/routetimeoutfilter