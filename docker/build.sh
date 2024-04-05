#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
mkdir ${SCRIPT_DIR}/tasky
git clone https://github.com/jeffthorne/tasky ./tasky
cp ${SCRIPT_DIR}/Dockerfile.chainguard-static ${SCRIPT_DIR}/tasky/
cp ${SCRIPT_DIR}/wizexercise.txt ${SCRIPT_DIR}/tasky/
docker build -t ppresto/tasky:1.3 -f ${SCRIPT_DIR}/tasky/Dockerfile.chainguard-static ${SCRIPT_DIR}/tasky/
#docker push ppresto/tasky:1.3