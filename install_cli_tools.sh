#!/bin/sh

set -eux

AWS_CLI_VERSION="2.2.16"

TERRAFORM_VERSION="1.0.1"
TERRAFORM_ZIPFILE="terraform_${TERRAFORM_VERSION}_linux_amd64.zip"

mkdir -p ~/workspace/bin
cd "${HOME}" || exit

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install --install-dir "${HOME}"/workspace/aws-cli --bin-dir "${HOME}"/workspace/bin
rm ./awscliv2.zip
rm -rf ./aws

curl -O "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${TERRAFORM_ZIPFILE}"
unzip "${TERRAFORM_ZIPFILE}"
mv ./terraform "${HOME}/workspace/bin"
rm "${TERRAFORM_ZIPFILE}"

echo "🐧️ Happy hacking!"
