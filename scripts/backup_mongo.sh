#!/bin/bash

# Your MongoDB's connection string
URI="mongodb://localhost:27017"

# The MongoDB database to be backed up
DBNAME=admin

# AWS Bucket Name
BUCKET=pp-s3-backup

# Current time and date
#TIME=`/bin/date +%d-%m-%Y-%T`
TIME=`/bin/date +%Y-%m-%d-%H%M`

# Directory you'd like the MongoDB backup file to be saved to
DEST=/opt/mongodb-backups/tmp

# Command to create a .tar file of the MongoDB backup files
TAR=${DEST}/${TIME}.tar.gz

# Command to create the backup directory (-p to avoid warning if the directory already exists)
/bin/mkdir -p ${DEST}

# Echo for logging purposes
echo "Backing up ${URI}/${DBNAME} to ${BUCKET} on ${TIME}";
echo "mongodump --uri ${URI} --authenticationDatabase admin -u admin -p D0ntHackMePls!  --db ${DBNAME} --out ${DEST}";
echo
# Command to run the mongodump command that dumps all data for the specified database to the backup directory
/usr/bin/mongodump --uri ${URI} --authenticationDatabase "admin" -u "admin" -p D0ntHackMePls!  --db ${DBNAME} --out ${DEST}
# Create the .tar file of backup directory
echo "/bin/tar czvf ${TAR} -C ${DEST} ."
/bin/tar czvf ${TAR} -C ${DEST} .

# Upload the .tar to S3
aws s3 cp ${TAR} s3://${BUCKET}/

# Log the end of the script
echo "Backup of MongoDB databases to S3 bucket ${BUCKET} completed successfully."