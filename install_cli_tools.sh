#!/bin/sh

set -eux

AWS_CLI_VERSION="2.2.16"
AWS_EKSCTL_VERSION="0.55.0"

TERRAFORM_VERSION="1.0.6"

TERRAFORM_DOCS_VERSION="0.15.0"
TERRAFORM_TFSEC_VERSION="0.58.6"
TERRAFORM_TFLINT_VERSION="0.31.0"

K9S_VERSION="0.24.15"
MINIKUBE_VERSION="1.22.0"
DIVE_VERSION="0.10.0"
KUBESCAPE_VERSION=1.0.66
STERN_VERSION=1.20.0

BAT_VERSION="v0.18.3"
DELTA_VERSION="0.8.3"
CTOP_VERSION="0.7.6"
EXA_VERSION="0.10.1"
FD_VERSION="8.2.1"
NAVI_VERSION="2.17.0"
FZF_VERSION=0.27.2
RIPGREP_VERSION=13.0.0
PROCS_VERSION=0.11.9
DOG_VERSION=0.1.0
GPING_VERSION=1.2.3

NEOVIM_VERSION="0.5.0"

EDEX_UI_VERSION="2.2.7"

OPSTRACE_VERSION="2021.08.13"

mkdir -p ~/workspace/bin
TEMP_DIR="$(mktemp -d)"
cd "${TEMP_DIR}" || exit

install_tool() {
    # The eventual executable name
    TOOL_NAME="$1"

    # Fun matching glyph
    EMOJI="$2"

    # Download location
    RELEASE_URL="$3"

    # Either the zipfile, tarball, AppImage, etc we get from the remote
    BUNDLE_NAME="$4"

    # These are only optional
    set +u
    # Typically unzip or tar
    UNZIP_TOOL="${5}"

    # Path to the binary inside the zip/tarball (like bin/my_tool)
    ZIP_PATH="${6}"

    # Fish shell autocompletions
    AUTOCOMPLETE_PATH="${7}"
    set -u

    if [ "$(which "${TOOL_NAME}")" = "" ]; then
	echo "${EMOJI} Installing ${TOOL_NAME}"
	curl -L -O "${RELEASE_URL}"

	# If we're downloading a tarball/zip, we need to extract + remove
	if [ -n "${UNZIP_TOOL}" ]; then
	    if [ -n "${ZIP_PATH}" ]; then
		if [ -n "${AUTOCOMPLETE_PATH}" ]; then
		    ${UNZIP_TOOL} "${BUNDLE_NAME}" "${AUTOCOMPLETE_PATH}"
		    mv "${AUTOCOMPLETE_PATH}" "${HOME}/.config/fish/completions"
		fi

		${UNZIP_TOOL} "${BUNDLE_NAME}" "${ZIP_PATH}"
		chmod +x "./${ZIP_PATH}"
		mv "./${ZIP_PATH}" "${HOME}/workspace/bin/${TOOL_NAME}"
	    else
		${UNZIP_TOOL} "${BUNDLE_NAME}" "${TOOL_NAME}"
		chmod +x "./${TOOL_NAME}"
		mv "./${TOOL_NAME}" "${HOME}/workspace/bin"
	    fi
	else
	    chmod +x "./${BUNDLE_NAME}"
	    mv "${BUNDLE_NAME}" "${HOME}/workspace/bin/${TOOL_NAME}"
	fi
    fi
}

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
    echo "🧹️ Installing tflint"
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

if [ "$(which helm)" = "" ]; then
    sudo snap install helm --classic
fi

if [ "$(which minikube)" = "" ]; then
    curl -L "https://storage.googleapis.com/minikube/releases/v${MINIKUBE_VERSION}/minikube-linux-amd64" -o "${HOME}/workspace/bin/minikube"
    chmod +x "${HOME}/workspace/bin/minikube"
fi

if [ "$(which microk8s)" = "" ]; then
    echo "🔬️ Installing microk8s"
    sudo snap install microk8s --classic
    # https://github.com/ubuntu/microk8s#user-access-without-sudo
    sudo usermod -a -G microk8s "${USER}"
    sudo chown -f -R "${USER}" ~/.kube
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
    # https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user
    sudo usermod -aG docker "${USER}"
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


install_tool ctop "📊️" \
    "https://github.com/bcicen/ctop/releases/download/${CTOP_VERSION}/ctop-${CTOP_VERSION}-linux-amd64" \
    "./ctop-${CTOP_VERSION}-linux-amd64"

install_tool edex-ui "🌐️" \
    "https://github.com/GitSquared/edex-ui/releases/download/v${EDEX_UI_VERSION}/eDEX-UI-Linux-x86_64.AppImage" \
    eDEX-UI-Linux-x86_64.AppImage

install_tool exa "📂️" \
    "https://github.com/ogham/exa/releases/download/v${EXA_VERSION}/exa-linux-x86_64-v${EXA_VERSION}.zip" \
    "./exa-linux-x86_64-v${EXA_VERSION}.zip" \
    "unzip" \
    bin/exa

install_tool opstrace "🦑️" \
    "https://github.com/opstrace/opstrace/releases/download/v${OPSTRACE_VERSION}/opstrace-cli-v${OPSTRACE_VERSION}-linux-amd64.tar.bz2" \
    "./opstrace-cli-v${OPSTRACE_VERSION}-linux-amd64.tar.bz2" \
    "tar -xjvf"

install_tool fd "🕵️" \
    "https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/fd-v${FD_VERSION}-x86_64-unknown-linux-gnu.tar.gz" \
    "./fd-v${FD_VERSION}-x86_64-unknown-linux-gnu.tar.gz" \
    "tar -xzvf" \
    "fd-v${FD_VERSION}-x86_64-unknown-linux-gnu/fd" \
    "fd-v${FD_VERSION}-x86_64-unknown-linux-gnu/autocomplete/fd.fish"

install_tool dive "🧜️" \
    "https://github.com/wagoodman/dive/releases/download/v${DIVE_VERSION}/dive_${DIVE_VERSION}_linux_amd64.tar.gz" \
    "./dive_${DIVE_VERSION}_linux_amd64.tar.gz" \
    "tar -xzvf"

install_tool navi 🧚️ \
    "https://github.com/denisidoro/navi/releases/download/v${NAVI_VERSION}/navi-v${NAVI_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    "./navi-v${NAVI_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    "tar -xzvf"

install_tool fzf 🧶️ \
    "https://github.com/junegunn/fzf/releases/download/${FZF_VERSION}/fzf-${FZF_VERSION}-linux_amd64.tar.gz" \
    "./fzf-${FZF_VERSION}-linux_amd64.tar.gz" \
    "tar -xzvf"

install_tool kubescape 🔒️ \
    "https://github.com/armosec/kubescape/releases/download/v${KUBESCAPE_VERSION}/kubescape-ubuntu-latest" \
    kubescape-ubuntu-latest

install_tool rg ✂️  \
    "https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/ripgrep-${RIPGREP_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    "./ripgrep-${RIPGREP_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    "tar -xzvf" \
    "ripgrep-${RIPGREP_VERSION}-x86_64-unknown-linux-musl/rg" \
    "ripgrep-${RIPGREP_VERSION}-x86_64-unknown-linux-musl/complete/rg.fish"

install_tool stern 📜️ \
    "https://github.com/stern/stern/releases/download/v${STERN_VERSION}/stern_${STERN_VERSION}_linux_amd64.tar.gz" \
    "./stern_${STERN_VERSION}_linux_amd64.tar.gz" \
    "tar -xzvf" \
    "stern_${STERN_VERSION}_linux_amd64/stern"

install_tool procs 💫️ \
    "https://github.com/dalance/procs/releases/download/v${PROCS_VERSION}/procs-v${PROCS_VERSION}-x86_64-lnx.zip" \
    "./procs-v${PROCS_VERSION}-x86_64-lnx.zip" \
    unzip

install_tool dog 🐕️ \
    "https://github.com/ogham/dog/releases/download/v${DOG_VERSION}/dog-v${DOG_VERSION}-x86_64-unknown-linux-gnu.zip" \
    "./dog-v${DOG_VERSION}-x86_64-unknown-linux-gnu.zip" \
    unzip \
    bin/dog \
    completions/dog.fish

install_tool gping 📈️ \
    "https://github.com/orf/gping/releases/download/gping-v${GPING_VERSION}/gping-Linux-x86_64.tar.gz" \
    ./gping-Linux-x86_64.tar.gz \
    "tar -xzvf"
