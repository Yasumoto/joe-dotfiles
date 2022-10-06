#!/bin/sh

set -eux

AWS_CLI_VERSION="2.5.3"
AWS_EKSCTL_VERSION="0.55.0"

TERRAFORM_VERSION="1.1.9"
VAGRANT_VERSION="2.2.19"

TERRAFORM_DOCS_VERSION="0.16.0"
TERRAFORM_TFSEC_VERSION="1.18.0"
TERRAFORM_TFLINT_VERSION="0.35.0"
TERRAFORM_LS_VERSION="0.29.0"

K9S_VERSION="0.25.18"
MINIKUBE_VERSION="1.26.0"
DIVE_VERSION="0.10.0"
KUBESCAPE_VERSION="1.0.131"
STERN_VERSION=1.20.0
KUBECTX_VERSION=0.9.4
HELM_VERSION="3.7.1"
DOCKER_COMPOSE_VERSION="1.29.2"

BAT_VERSION="v0.21.0" # https://github.com/sharkdp/bat
DELTA_VERSION="0.13.0" # https://github.com/dandavison/delta
CTOP_VERSION="0.7.7"
EXA_VERSION="0.10.1" # https://github.com/ogham/exa
FD_VERSION="8.4.0" # https://github.com/sharkdp/fd
NAVI_VERSION="2.17.0"
FZF_VERSION=0.30.0 # https://github.com/junegunn/fzf
RIPGREP_VERSION=13.0.0 # https://github.com/BurntSushi/ripgrep
PROCS_VERSION=0.11.9
DOG_VERSION=0.1.0
GPING_VERSION=1.2.6
GLOW_VERSION=1.4.1 # https://github.com/charmbracelet/glow
AWS_VAULT_VERSION="6.6.0" # https://github.com/99designs/aws-vault
TASKWARRIOR_TUI_VERSION=0.23.4 # https://github.com/kdheepak/taskwarrior-tui
LAZYDOCKER_VERSION=0.18.1 # https://github.com/jesseduffield/lazydocker
TFSWITCH_VERSION=0.13.1288 # https://github.com/warrensbox/terraform-switcher
CHEAT_VERSION=4.2.5 # https://github.com/cheat/cheat
CATP_VERSION=0.2.0 # https://github.com/rapiz1/catp
VIDDY_VERSION=0.3.6 # https://github.com/sachaos/viddy

RUST_ANALYZER_VERSION="2022-05-23"

NEOVIM_VERSION="0.8.0"

EDEX_UI_VERSION="2.2.8"

mkdir -p ~/workspace/bin
TEMP_DIR="$(mktemp -d)"
cd "${TEMP_DIR}" || exit

ARCH="$(uname -m)"

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
	    # The tool is located in some subdirectory of the bundle
	    if [ -n "${ZIP_PATH}" ]; then
		# Includes some autocompletion helpers
		if [ -n "${AUTOCOMPLETE_PATH}" ]; then
		    ${UNZIP_TOOL} "${BUNDLE_NAME}" "${AUTOCOMPLETE_PATH}"
		    mv "${AUTOCOMPLETE_PATH}" "${HOME}/.config/fish/completions"
		fi

		${UNZIP_TOOL} "${BUNDLE_NAME}" "${ZIP_PATH}"
		chmod +x "./${ZIP_PATH}"
		mv "./${ZIP_PATH}" "${HOME}/workspace/bin/${TOOL_NAME}"
	    else
		if [ "${UNZIP_TOOL}" = gunzip ]; then
		    gunzip "${BUNDLE_NAME}"
		    EXTRACTED_NAME="$(echo "${BUNDLE_NAME}" | sed 's/.gz//')"
		    chmod +x ./"${EXTRACTED_NAME}"
		    mv ./"${EXTRACTED_NAME}" "${HOME}/workspace/bin/${TOOL_NAME}"
		else
		    # Tool is located at the top-level of the bundle
		    ${UNZIP_TOOL} "${BUNDLE_NAME}" "${TOOL_NAME}"
		    chmod +x "./${TOOL_NAME}"
		    mv "./${TOOL_NAME}" "${HOME}/workspace/bin"
		fi
	    fi
	else
	    chmod +x "./${BUNDLE_NAME}"
	    mv "${BUNDLE_NAME}" "${HOME}/workspace/bin/${TOOL_NAME}"
	fi
    fi
}


if [ "$(which terraform)" = "" ]; then
    if [ "$ARCH" = "x86_64" ]; then
        TERRAFORM_ARCH=amd64
    elif [ "$ARCH" = "aarch64" ]; then
	TERRAFORM_ARCH="arm64"
    else
        echo "Unsupported terraform architecture! Please review: ${ARCH}"
        exit 1
    fi
    TERRAFORM_ZIPFILE="terraform_${TERRAFORM_VERSION}_linux_${TERRAFORM_ARCH}.zip"
    echo "🏗️ Installing terraform"
    curl -L -O "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${TERRAFORM_ZIPFILE}"
    unzip "${TERRAFORM_ZIPFILE}"
    mv ./terraform "${HOME}/workspace/bin"
    rm "${TERRAFORM_ZIPFILE}"
fi

if [ "$(which bat)" = "" ]; then
    echo "🦇️ Installing bat"
    curl -L -O "https://github.com/sharkdp/bat/releases/download/${BAT_VERSION}/bat-${BAT_VERSION}-${ARCH}-unknown-linux-gnu.tar.gz"
    tar -xzvf ."/bat-${BAT_VERSION}-${ARCH}-unknown-linux-gnu.tar.gz" "bat-${BAT_VERSION}-${ARCH}-unknown-linux-gnu/bat"
    rm "./bat-${BAT_VERSION}-${ARCH}-unknown-linux-gnu.tar.gz"
    mv "./bat-${BAT_VERSION}-${ARCH}-unknown-linux-gnu/bat" "${HOME}/workspace/bin"
    rm -rf "./bat-${BAT_VERSION}-${ARCH}-unknown-linux-gnu"
fi

if [ "$(which delta)" = "" ]; then
    echo "🌊️ Installing delta"
    curl -L -O "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/delta-${DELTA_VERSION}-${ARCH}-unknown-linux-gnu.tar.gz"
    tar -xzvf "./delta-${DELTA_VERSION}-${ARCH}-unknown-linux-gnu.tar.gz" "delta-${DELTA_VERSION}-${ARCH}-unknown-linux-gnu/delta"
    rm "./delta-${DELTA_VERSION}-${ARCH}-unknown-linux-gnu.tar.gz"
    mv "./delta-${DELTA_VERSION}-${ARCH}-unknown-linux-gnu/delta" "${HOME}/workspace/bin"
    rm -rf "./delta-${DELTA_VERSION}-${ARCH}-unknown-linux-gnu"
fi

install_tool fd "🕵️" \
    "https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/fd-v${FD_VERSION}-${ARCH}-unknown-linux-gnu.tar.gz" \
    "./fd-v${FD_VERSION}-${ARCH}-unknown-linux-gnu.tar.gz" \
    "tar -xzvf" \
    "fd-v${FD_VERSION}-${ARCH}-unknown-linux-gnu/fd" \
    "fd-v${FD_VERSION}-${ARCH}-unknown-linux-gnu/autocomplete/fd.fish"

if [ "${ARCH}" = "x86_64" ]; then
    FZF_ARCH=amd64
elif [ "${ARCH}" = "aarch64" ]; then
    FZF_ARCH="arm64"
else
    echo "Unsupported terraform architecture! Please review: ${ARCH}"
    exit 1
fi
install_tool fzf 🧶️ \
    "https://github.com/junegunn/fzf/releases/download/${FZF_VERSION}/fzf-${FZF_VERSION}-linux_${FZF_ARCH}.tar.gz" \
    "./fzf-${FZF_VERSION}-linux_${FZF_ARCH}.tar.gz" \
    "tar -xzvf"


if [ "$ARCH" = aarch64 ]; then
  echo "!!!!!!!!!!!!!!!*******************!!!!!!!!!!!!"
  echo "Add more tools to be architecture-appropriate!"
  echo "!!!!!!!!!!!!!!!*******************!!!!!!!!!!!!"
  exit 1
fi

if [ "$(which nvim)" = "" ]; then
    echo "🌟️ Installing Neovim"
    curl -L -O "https://github.com/neovim/neovim/releases/download/v${NEOVIM_VERSION}/nvim.appimage"
    chmod +x ./nvim.appimage
    mv ./nvim.appimage "${HOME}/workspace/bin/nvim"
fi

install_tool exa "📂️" \
    "https://github.com/ogham/exa/releases/download/v${EXA_VERSION}/exa-linux-x86_64-v${EXA_VERSION}.zip" \
    "./exa-linux-x86_64-v${EXA_VERSION}.zip" \
    "unzip" \
    bin/exa

install_tool rg ✂️  \
    "https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/ripgrep-${RIPGREP_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    "./ripgrep-${RIPGREP_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    "tar -xzvf" \
    "ripgrep-${RIPGREP_VERSION}-x86_64-unknown-linux-musl/rg" \
    "ripgrep-${RIPGREP_VERSION}-x86_64-unknown-linux-musl/complete/rg.fish"

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

install_tool vagrant ✌️ \
    "https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}_linux_amd64.zip" \
    "./vagrant_${VAGRANT_VERSION}_linux_amd64.zip" \
    "unzip"

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

install_tool terraform-ls 📚️ \
    "https://github.com/hashicorp/terraform-ls/releases/download/v${TERRAFORM_LS_VERSION}/terraform-ls_${TERRAFORM_LS_VERSION}_linux_amd64.zip" \
    "terraform-ls_${TERRAFORM_LS_VERSION}_linux_amd64.zip" \
    "unzip"

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

if [ "$(which rust-analyzer)" = "" ]; then
    echo "🦀️ Installing rust-analyzer"
    curl -L -O "https://github.com/rust-analyzer/rust-analyzer/releases/download/${RUST_ANALYZER_VERSION}/rust-analyzer-x86_64-unknown-linux-gnu.gz"
    gunzip rust-analyzer-x86_64-unknown-linux-gnu.gz
    chmod +x ./rust-analyzer-x86_64-unknown-linux-gnu
    mv ./rust-analyzer-x86_64-unknown-linux-gnu "${HOME}/workspace/bin/rust-analyzer"
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

install_tool ctop "📊️" \
    "https://github.com/bcicen/ctop/releases/download/${CTOP_VERSION}/ctop-${CTOP_VERSION}-linux-amd64" \
    "./ctop-${CTOP_VERSION}-linux-amd64"

install_tool edex-ui "🌐️" \
    "https://github.com/GitSquared/edex-ui/releases/download/v${EDEX_UI_VERSION}/eDEX-UI-Linux-x86_64.AppImage" \
    eDEX-UI-Linux-x86_64.AppImage

install_tool dive "🧜️" \
    "https://github.com/wagoodman/dive/releases/download/v${DIVE_VERSION}/dive_${DIVE_VERSION}_linux_amd64.tar.gz" \
    "./dive_${DIVE_VERSION}_linux_amd64.tar.gz" \
    "tar -xzvf"

install_tool navi 🧚️ \
    "https://github.com/denisidoro/navi/releases/download/v${NAVI_VERSION}/navi-v${NAVI_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    "./navi-v${NAVI_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    "tar -xzvf"

install_tool kubescape 🔒️ \
    "https://github.com/armosec/kubescape/releases/download/v${KUBESCAPE_VERSION}/kubescape-ubuntu-latest" \
    kubescape-ubuntu-latest

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

install_tool kubectx 🛹️ \
    "https://github.com/ahmetb/kubectx/releases/download/v${KUBECTX_VERSION}/kubectx_v${KUBECTX_VERSION}_linux_x86_64.tar.gz" \
    "./kubectx_v${KUBECTX_VERSION}_linux_x86_64.tar.gz" \
    "tar -xzvf"

if [ ! -f "${HOME}/.config/fish/completions/kubectx.fish" ]; then
    curl -L -o "${HOME}/.config/fish/completions/kubectx.fish" "https://raw.githubusercontent.com/ahmetb/kubectx/v${KUBECTX_VERSION}/completion/kubectx.fish"
fi

install_tool kubens 🍀️ \
    "https://github.com/ahmetb/kubectx/releases/download/v${KUBECTX_VERSION}/kubens_v${KUBECTX_VERSION}_linux_x86_64.tar.gz" \
    "./kubens_v${KUBECTX_VERSION}_linux_x86_64.tar.gz" \
    "tar -xzvf"

if [ ! -f "${HOME}/.config/fish/completions/kubens.fish" ]; then
    curl -L -o "${HOME}/.config/fish/completions/kubens.fish" "https://raw.githubusercontent.com/ahmetb/kubectx/v${KUBECTX_VERSION}/completion/kubens.fish"
fi

install_tool helm ☸️ \
    "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
    "./helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
    "tar -xzvf" \
    "linux-amd64/helm"

install_tool docker-compose 🐳️ \
    "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
    "docker-compose-$(uname -s)-$(uname -m)"

install_tool glow 💅️ \
    "https://github.com/charmbracelet/glow/releases/download/v${GLOW_VERSION}/glow_${GLOW_VERSION}_linux_x86_64.tar.gz" \
    "glow_${GLOW_VERSION}_linux_x86_64.tar.gz" \
    "tar -xzvf"

install_tool aws-vault 🔐️ \
    "https://github.com/99designs/aws-vault/releases/download/v${AWS_VAULT_VERSION}/aws-vault-linux-amd64" \
    "aws-vault-linux-amd64"

install_tool taskwarrior-tui 🛡️  \
    "https://github.com/kdheepak/taskwarrior-tui/releases/download/v${TASKWARRIOR_TUI_VERSION}/taskwarrior-tui-x86_64-unknown-linux-gnu.tar.gz" \
    "taskwarrior-tui-x86_64-unknown-linux-gnu.tar.gz" \
    "tar -xzvf" \
    "taskwarrior-tui"

install_tool lazydocker X \
    "https://github.com/jesseduffield/lazydocker/releases/download/v${LAZYDOCKER_VERSION}/lazydocker_${LAZYDOCKER_VERSION}_Linux_x86_64.tar.gz" \
    "lazydocker_${LAZYDOCKER_VERSION}_Linux_x86_64.tar.gz" \
    "tar -xzvf" \
    "lazydocker"

install_tool tfswitch X \
    "https://github.com/warrensbox/terraform-switcher/releases/download/${TFSWITCH_VERSION}/terraform-switcher_${TFSWITCH_VERSION}_linux_amd64.tar.gz" \
    "terraform-switcher_${TFSWITCH_VERSION}_linux_amd64.tar.gz" \
    "tar -xzvf" \
    "tfswitch"

install_tool viddy X \
    "https://github.com/sachaos/viddy/releases/download/v${VIDDY_VERSION}/viddy_${VIDDY_VERSION}_Linux_x86_64.tar.gz" \
    "viddy_${VIDDY_VERSION}_Linux_x86_64.tar.gz" \
    "tar -xzvf" \
    "viddy"

install_tool cheat X \
    "https://github.com/cheat/cheat/releases/download/${CHEAT_VERSION}/cheat-linux-amd64.gz" \
    "cheat-linux-amd64.gz" \
    gunzip
if [ ! -d "${HOME}/.config/cheat" ]; then
  mkdir -p "${HOME}/.config/cheat" && cheat --init > "${HOME}/.config/cheat/conf.yml"
fi

install_tool catp "cat" \
    "https://github.com/rapiz1/catp/releases/download/v${CATP_VERSION}/catp-x86_64-unknown-linux-gnu.zip" \
    "catp-x86_64-unknown-linux-gnu.zip" \
    unzip

if [ "$(which gopls)" = "" ]; then
  go install golang.org/x/tools/gopls@latest
fi

# https://github.com/mklement0/n-install
if [ "$(which n)" = "" ]; then
  curl -L https://git.io/n-install | bash
  export PATH="${HOME}/n/bin:${PATH}"
fi
# https://github.com/Microsoft/pyright#command-line
if [ "$(which pyright)" = "" ]; then
  npm -g install pyright
fi
# https://github.com/bash-lsp/bash-language-server#installation
if [ "$(which bash-language-server)" = "" ]; then
  npm -g install bash-language-server
fi
if [ "$(which docker-langserver)" = "" ]; then
  npm -g install dockerfile-language-server-nodejs
fi

if [ "$(which typescript-language-server)" = "" ]; then
  npm install -g typescript-language-server typescript
fi

npm -g update

if [ "$(which cargo)" = "" ]; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
fi
if [ "$(which topgrade)" = "" ]; then
  cargo install topgrade
fi
if [ "$(which cargo-update)" = "" ]; then
  cargo install cargo-update
fi
cargo install-update --all
#if [ "$(which alacritty)" = "" ]; then
#  cargo install alacritty
#fi

