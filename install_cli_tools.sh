#!/bin/sh

set -eux

AWS_CLI_VERSION="2.2.16"
AWS_EKSCTL_VERSION="0.55.0"

TERRAFORM_VERSION="1.0.1"

TERRAFORM_DOCS_VERSION="0.14.1"
TERRAFORM_TFSEC_VERSION="0.42.0"
TERRAFORM_TFLINT_VERSION="0.30.0"

K9S_VERSION="0.24.15"
MINIKUBE_VERSION="1.22.0"

BAT_VERSION="v0.18.2"
DELTA_VERSION="0.8.3"

NEOVIM_VERSION="0.5.0"

mkdir -p ~/workspace/bin
cd "${HOME}" || exit

if [ "$(which aws)"  = "" ]; then
    echo "☁️ Installing aws-cli"
    curl -L "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install --install-dir "${HOME}"/workspace/aws-cli --bin-dir "${HOME}"/workspace/bin
    rm ./awscliv2.zip
    rm -rf ./aws
fi

if [ "$(which eksctl)" = "" ]; then
    echo "🎛️ Installing eksctl"
    curl -L -O "https://github.com/weaveworks/eksctl/releases/download/${AWS_EKSCTL_VERSION}/eksctl_Linux_amd64.tar.gz"
    tar -xzvf ./eksctl_Linux_amd64.tar.gz eksctl
    mv ./eksctl "${HOME}/workspace/bin"
    rm -f ./eksctl_Linux_amd64.tar.gz
fi

if [ "$(which terraform)" = "" ]; then
    TERRAFORM_ZIPFILE="terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
    echo "🏗️ Installing terraform"
    curl -L -O "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${TERRAFORM_ZIPFILE}"
    unzip "${TERRAFORM_ZIPFILE}"
    mv ./terraform "${HOME}/workspace/bin"
    rm "${TERRAFORM_ZIPFILE}"
fi

if [ "$(which terraform-docs)" = "" ]; then
    echo "📖️ Installing terraform-docs"
    curl -L -O "https://github.com/terraform-docs/terraform-docs/releases/download/v${TERRAFORM_DOCS_VERSION}/terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-amd64.tar.gz"
    tar -xzvf "./terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-amd64.tar.gz" terraform-docs
    mv ./terraform-docs "${HOME}/workspace/bin"
    rm -f "./terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-amd64.tar.gz"
fi

if [ "$(which tfsec)" = "" ]; then
    echo "🔒️ Installing tfsec"
    curl -L -O "https://github.com/tfsec/tfsec/releases/download/v${TERRAFORM_TFSEC_VERSION}/tfsec-linux-amd64"
    mv ./tfsec-linux-amd64 "${HOME}/workspace/bin/tfsec"
    chmod +x "${HOME}/workspace/bin/tfsec"
fi

if [ "$(which tflint)" = "" ]; then
    curl -L -O "https://github.com/terraform-linters/tflint/releases/download/v${TERRAFORM_TFLINT_VERSION}/tflint_linux_amd64.zip"
    unzip ./tflint_linux_amd64.zip tflint
    mv ./tflint "${HOME}/workspace/bin"
    rm ./tflint_linux_amd64.zip
fi

if [ "$(which kubectl)" = "" ]; then
    echo "☸️ Installing kubectl"
    curl -L -O "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x ./kubectl
    mv ./kubectl "${HOME}/workspace/bin"
    kubectl version --client
fi

if [ "$(which k9s)" = "" ]; then
    echo "🐶️ Installing k9s"
    curl -L -O "https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_Linux_x86_64.tar.gz"
    tar -xzvf ./k9s_Linux_x86_64.tar.gz k9s
    rm ./k9s_Linux_x86_64.tar.gz
    mv ./k9s "${HOME}/workspace/bin"
fi

if [ "$(which minikube)" = "" ]; then
    curl -L "https://storage.googleapis.com/minikube/releases/v${MINIKUBE_VERSION}/minikube-linux-amd64" -o "${HOME}/workspace/bin/minikube"
    chmod +x "${HOME}/workspace/bin/minikube"
fi

if [ "$(which cbonsai)" = "" ]; then
    echo "🌳 Installing cbonsai"
    mkdir -p "${HOME}/workspace/gitlab.com/jallbrit"
    git clone git@gitlab.com:jallbrit/cbonsai.git "${HOME}/workspace/gitlab.com/jallbrit/cbonsai"
    make -C "${HOME}/workspace/gitlab.com/jallbrit/cbonsai" install PREFIX="${HOME}/workspace"
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

if [ "$(which gh)" = "" ]; then
    echo "🐙️ Installing gh"
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update
    sudo apt install gh
fi

if [ "$(which bat)" = "" ]; then
    echo "🦇️ Installing bat"
    curl -L -O "https://github.com/sharkdp/bat/releases/download/${BAT_VERSION}/bat-${BAT_VERSION}-x86_64-unknown-linux-gnu.tar.gz"
    tar -xzvf ./bat-${BAT_VERSION}-x86_64-unknown-linux-gnu.tar.gz bat-${BAT_VERSION}-x86_64-unknown-linux-gnu/bat
    rm ./bat-${BAT_VERSION}-x86_64-unknown-linux-gnu.tar.gz
    mv ./bat-${BAT_VERSION}-x86_64-unknown-linux-gnu/bat "${HOME}/workspace/bin"
    rm -rf ./bat-${BAT_VERSION}-x86_64-unknown-linux-gnu
fi

if [ "$(which delta)" = "" ]; then
    echo "🌊️ Installing delta"
    curl -L -O "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/delta-${DELTA_VERSION}-x86_64-unknown-linux-gnu.tar.gz"
    tar -xzvf ./delta-${DELTA_VERSION}-x86_64-unknown-linux-gnu.tar.gz delta-${DELTA_VERSION}-x86_64-unknown-linux-gnu/delta
    rm ./delta-${DELTA_VERSION}-x86_64-unknown-linux-gnu.tar.gz
    mv ./delta-${DELTA_VERSION}-x86_64-unknown-linux-gnu/delta "${HOME}/workspace/bin"
    rm -rf ./delta-${DELTA_VERSION}-x86_64-unknown-linux-gnu
fi

if [ "$(which nvim)" = "" ]; then
    echo "🌟️ Installing Neovim"
    curl -L -O "https://github.com/neovim/neovim/releases/download/v${NEOVIM_VERSION}/nvim.appimage"
    chmod +x ./nvim.appimage
    mv ./nvim.appimage "${HOME}/workspace/bin/nvim"
fi

echo "🐧️ Happy hacking!"
