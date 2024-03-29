<!-- TOC -->

- [Troubleshooting](#troubleshooting)
  - [SSH - Bastion Host](#ssh---bastion-host)
    - [Manually create SSH Key, and AWS keypair](#manually-create-ssh-key-and-aws-keypair)
  - [AWS EC2 / VM](#aws-ec2--vm)
    - [AWS EC2 - Helpful Commands](#aws-ec2---helpful-commands)
    - [AWS EC2 - Review Cloud-init execution](#aws-ec2---review-cloud-init-execution)
    - [AWS EC2 - logs](#aws-ec2---logs)
    - [AWS EC2 - Test client connectivity with nc](#aws-ec2---test-client-connectivity-with-nc)
  - [EKS / Kubernetes](#eks--kubernetes)
    - [EKS - Login / Set Context](#eks---login--set-context)
    - [Attach debug container to pod to run additional commands (tcpdump, netstat, dig, curl, etc...)](#attach-debug-container-to-pod-to-run-additional-commands-tcpdump-netstat-dig-curl-etc)
    - [Get Security Context of all Pods in all namespaces](#get-security-context-of-all-pods-in-all-namespaces)

<!-- /TOC -->
# Troubleshooting

## SSH - Bastion Host
SSH to bastion host for access to internal networks.  The TF is leveraging your AWS Key Pair for the Bastion/EC2 and EKS nodes.  Use `Agent Forwarding` to ssh to your nodes.  Locally in your terminal find your key and setup ssh.
```
ssh-add -L  # Find SSH Keys added
ssh-add ${HOME}/.ssh/hcp-consul  # If you dont have any keys then add your key being used in TF.
ssh -A ubuntu@<BASTION_IP>  # pass your key in memory to the ubuntu Bastion Host you ssh to.
ssh -A ec2_user@<K8S_NODE_IP> # From bastion use your key to access a node in the private network.
ssh -A -J ubuntu@<PUBLIC_BASTION_IP> ubuntu@<PRIVATE_EC2_IP>
```

### Manually create SSH Key, and AWS keypair
```
ssh-keygen -t rsa -b 4096 -f /tmp/hcp-consul -N ''
publickeyfile="/tmp/tfc-hcpc-pipelines/hcp-consul.pub"
aws_keypair_name=my-aws-keypair-$(date +%Y%m%d)
echo aws ec2 import-key-pair \
    --region "$AWS_DEFAULT_REGION" \
    --key-name "$aws_keypair_name" \
    --public-key-material "fileb://$publickeyfile"
```

## AWS EC2 / VM

### AWS EC2 - Helpful Commands

SCP file through public bastion from K8s cluster to an internal VM.
```
scp -o 'ProxyCommand ssh ubuntu@54.202.45.196 -W %h:%p' ./ca.pem ubuntu@10.17.1.130:/tmp/ca.pem
```

Generate AWS kubeconfig file for VM (`cluster-name: presto-usw2-consul1`)
```
aws eks --region us-west-2 update-kubeconfig --name presto-usw2-consul1 --kubeconfig ./kubeconfig
```

### AWS EC2 - Review Cloud-init execution
When a user data script is processed, it is copied to and run from /var/lib/cloud/instances/instance-id/. The script is not deleted after it is run and can be found in this directory with the name user-data.txt.  
```
sudo cat /var/lib/cloud/instance/user-data.txt
```
The cloud-init log captures console output of the user-data script run.
```
sudo cat /var/log/cloud-init-output.log
```

### AWS EC2 - logs
To investigate systemd errors starting consul use `journalctl`.  
```
journalctl -u consul -xn | less
```
pipe to less to avoid line truncation in terminal

### AWS EC2 - Test client connectivity with nc
```
ping $ip
nc -zv $ip 8301   # TCP Test to remote port
nc -zvu $ip 8301  # UDP 8301
nc -zv $ip 8300   # TCP 8300
```

## EKS / Kubernetes

### EKS - Login / Set Context
Set default Namespace in current context
```
kubectl config set-context --current --namespace=consul
```

Label node
```
kubectl label nodes ip-10-16-1-177.us-west-2.compute.internal nodetype=consul
```

### Attach debug container to pod to run additional commands (tcpdump, netstat, dig, curl, etc...)
```
kubectl -n fortio-baseline debug -it $POD_NAME --image=nicolaka/netshoot
#kubectl -n fortio-baseline debug -q -i $POD_NAME --image=nicolaka/netshoot
kubectl -n web debug -it $POD_NAME --target consul-dataplane --image nicolaka/netshoot -- tcpdump -i eth0 dst port 20000 -A
```

### Get Security Context of all Pods in all namespaces
```
kubectl get pods --all-namespaces -o go-template \
    --template='{{range .items}}{{"pod: "}}{{.metadata.name}}
{{if .spec.securityContext}}
  PodSecurityContext:
    {{"runAsGroup: "}}{{.spec.securityContext.runAsGroup}}                               
    {{"runAsNonRoot: "}}{{.spec.securityContext.runAsNonRoot}}                           
    {{"runAsUser: "}}{{.spec.securityContext.runAsUser}}                                 {{if .spec.securityContext.seLinuxOptions}}
    {{"seLinuxOptions: "}}{{.spec.securityContext.seLinuxOptions}}                       {{end}}
{{else}}PodSecurity Context is not set
{{end}}{{range .spec.containers}}
{{"container name: "}}{{.name}}
{{"image: "}}{{.image}}{{if .securityContext}}                                      
    {{"allowPrivilegeEscalation: "}}{{.securityContext.allowPrivilegeEscalation}}   {{if .securityContext.capabilities}}
    {{"capabilities: "}}{{.securityContext.capabilities}}                           {{end}}
    {{"privileged: "}}{{.securityContext.privileged}}                               {{if .securityContext.procMount}}
    {{"procMount: "}}{{.securityContext.procMount}}                                 {{end}}
    {{"readOnlyRootFilesystem: "}}{{.securityContext.readOnlyRootFilesystem}}       
    {{"runAsGroup: "}}{{.securityContext.runAsGroup}}                               
    {{"runAsNonRoot: "}}{{.securityContext.runAsNonRoot}}                           
    {{"runAsUser: "}}{{.securityContext.runAsUser}}                                 {{if .securityContext.seLinuxOptions}}
    {{"seLinuxOptions: "}}{{.securityContext.seLinuxOptions}}                       {{end}}{{if .securityContext.windowsOptions}}
    {{"windowsOptions: "}}{{.securityContext.windowsOptions}}                       {{end}}
{{else}}
    SecurityContext is not set
{{end}}
{{end}}{{end}}'
```