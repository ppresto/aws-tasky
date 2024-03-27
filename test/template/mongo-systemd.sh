#!/bin/bash
# CloudInit
# stored in: /var/lib/cloud/instances/instance-id/user-data.txt
# logged at: /var/log/cloud-init-output.log
local_ip=`ip -o route get to 169.254.169.254 | sed -n 's/.*src \([0-9.]\+\).*/\1/p'`

# mongodb - /etc/mongod.conf
# log     - /var/log/mongodb/mongod.log
# data    - /var/lib/mongodb

curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg \
   --dearmor

#echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt-get update
sudo apt-get install -y mongodb-org unzip
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
# # S3 command
# wget -O- -q http://s3tools.org/repo/deb-all/stable/s3tools.key | sudo apt-key add -
# sudo wget -O/etc/apt/sources.list.d/s3tools.list http://s3tools.org/repo/deb-all/stable/s3tools.list
# sudo apt-get install -y s3cmd
# sudo systemctl daemon-reload
sudo systemctl start mongod
sudo systemctl enable mongod
sleep 5
/usr/bin/mongosh <<- EOF
use admin
db.createUser(
  {
    user: "admin",
    pwd: "D0ntHackMePls!",
    roles: [
      { role: "userAdminAnyDatabase", db: "admin" },
      { role: "readWriteAnyDatabase", db: "admin" }
    ]
  }
)

db.createUser(
  {
    user: "backup",
    pwd: "D0ntR3adThis!",
    roles: [
      { role: "read", db: "admin" },
      { role: "backup", db: "admin"}
    ]
  }
)

db.adminCommand( { shutdown: 1 } )
EOF


# Add Security Auth and bind to all interfaces
cat > /etc/mongod.conf <<- EOF
# mongod.conf

# for documentation of all options, see:
#   http://docs.mongodb.org/manual/reference/configuration-options/

# Where and how to store data.
storage:
  dbPath: /var/lib/mongodb
#  engine:
#  wiredTiger:

# where to write logging data.
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

# network interfaces
net:
  port: 27017
  bindIp: 0.0.0.0

# how the process runs
processManagement:
  timeZoneInfo: /usr/share/zoneinfo

#security:
security:
  authorization: enabled

#operationProfiling:

#replication:

#sharding:

## Enterprise-Only Options:

#auditLog:
EOF

sudo systemctl restart mongod

# Create directory for mongodb backups.
mkdir -p /opt/mongodb-backups
cat > /opt/mongodb-backups/env.sh <<- EOF
#!/bin/bash

# Your MongoDB's connection string
URI="mongodb://localhost:27017"

# The MongoDB database to be backed up
DBNAME=admin

# AWS Bucket Name
BUCKET=${BUCKET_NAME}

# Current time and date
TIME=`/bin/date +%Y-%m-%d-%H%M`

# Directory you'd like the MongoDB backup file to be saved to
DEST=/opt/mongodb-backups/tmp
EOF

cat > /opt/mongodb-backups/backup.sh <<- 'EOF'
#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "$${BASH_SOURCE[0]}") && pwd)
source $${SCRIPT_DIR}/env.sh

# Command to create a .tar file of the MongoDB backup files
TAR=$${DEST}/$${TIME}.tar.gz

# Command to create the backup directory (-p to avoid warning if the directory already exists)
/bin/mkdir -p $${DEST}

# Echo for logging purposes
echo "Backing up $${URI}/$${DBNAME} to $${BUCKET} on $${TIME}";

# Command to run the mongodump command that dumps all data for the specified database to the backup directory
/usr/bin/mongodump --uri $${URI} --authenticationDatabase "admin" -u "admin" -p D0ntHackMePls!  --db $${DBNAME} --out $${DEST}

# Create the .tar file of backup directory
echo "/bin/tar czvf $${TAR} -C $${DEST} ."
/bin/tar czvf $${TAR} -C $${DEST} .

# Upload the .tar to S3
aws s3 cp $${TAR} s3://$${BUCKET}/

# Clean up
rm -rm $${DEST}/$${DBNAME}
#rm -rm $${DEST}/$${TIME}.tar.gz

# Log the end of the script
echo "Backup of MongoDB databases to S3 bucket $${BUCKET} completed successfully."
EOF
chown -R mongodb:mongodb /opt/mongodb-backups
chmod 744 /opt/mongodb-backups/env.sh
chmod 750 /opt/mongodb-backups/backup.sh

# Examples:
# mongosh  --authenticationDatabase "admin" -u "admin" -p D0ntHackMePls!
#
# use admin 
# db.auth("myUserAdmin", "D0ntHackMePls!")
#
# sudo mongodump --uri mongodb://localhost:27017 --authenticationDatabase "admin" -u "admin" -p D0ntHackMePls!  --db admin --out /opt/mongodb-backups/tmp
# aws s3 cp /opt/mongodb-backups/tmp/admin s3://pp-s3-backup/ --recursive