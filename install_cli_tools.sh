#!/bin/sh

set -eux

AWS_CLI_VERSION="2.2.16"

TERRAFORM_VERSION="1.0.1"
TERRAFORM_ZIPFILE="terraform_${TERRAFORM_VERSION}_linux_amd64.zip"

K9S_VERSION="0.24.13"

mkdir -p ~/workspace/bin
cd "${HOME}" || exit

if [ "$(which aws)"  = "" ]; then
    echo "☁️ Installing aws-cli"
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install --install-dir "${HOME}"/workspace/aws-cli --bin-dir "${HOME}"/workspace/bin
    rm ./awscliv2.zip
    rm -rf ./aws
fi

if [ "$(which terraform)" = "" ]; then
    echo "🏗️ Installing terraform"
    curl -O "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${TERRAFORM_ZIPFILE}"
    unzip "${TERRAFORM_ZIPFILE}"
    mv ./terraform "${HOME}/workspace/bin"
    rm "${TERRAFORM_ZIPFILE}"
fi

if [ "$(which kubectl)" = "" ]; then
    echo "☸️ Installing kubectl"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x ./kubectl
    mv ./kubectl "${HOME}/workspace/bin"
    kubectl version --client
fi

if [ "$(which docker)" = "" ]; then
    echo "🐳️ Installing Docker"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install docker-ce docker-ce-cli containerd.io
fi

if [ "$(which k9s)" = "" ]; then
    echo "🐶️ Installing k9s"
    curl -LO "https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_Linux_x86_64.tar.gz"
    tar -xzvf ./k9s_Linux_x86_64.tar.gz k9s
    rm ./k9s_Linux_x86_64.tar.gz
    mv ./k9s "${HOME}/workspace/bin"
fi

echo "🐧️ Happy hacking!"
