aws ec2 run-instances \
  --image-id ami-07fe743f8d6d95a40 \
  --instance-type t2.micro \
  --subnet-id subnet-0e9058bbe0ee3fea8 \
  --security-group-ids sg-01c640cca4b063fbd \
  --associate-public-ip-address \
  --key-name ppresto-ptfe-dev-key