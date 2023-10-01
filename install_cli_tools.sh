#!/bin/sh

set -eux

if [ ! -d "$HOME/.config/home-manager" ]; then
  mkdir -p "$HOME/.config/home-manager"

  nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager

  nix-channel --update
  nix-shell '<home-manager>' -A install
fi

if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
  #TODO(joe): Why the heck did you need to source this?
  #. $HOME/.nix-profile/etc/profile.d/hm-session-vars.sh
  echo "Not sourcing hm-session-vars.sh for now"
fi

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

CATP_VERSION=0.2.0 # https://github.com/rapiz1/catp

install_tool catp "catp" \
    "https://github.com/rapiz1/catp/releases/download/v${CATP_VERSION}/catp-x86_64-unknown-linux-gnu.zip" \
    "catp-x86_64-unknown-linux-gnu.zip" \
    unzip


#install_tool kubectx 🛹️ \
#    "https://github.com/ahmetb/kubectx/releases/download/v${KUBECTX_VERSION}/kubectx_v${KUBECTX_VERSION}_linux_x86_64.tar.gz" \
#    "./kubectx_v${KUBECTX_VERSION}_linux_x86_64.tar.gz" \
#    "tar -xzvf"
#
#if [ ! -f "${HOME}/.config/fish/completions/kubectx.fish" ]; then
#    curl -L -o "${HOME}/.config/fish/completions/kubectx.fish" "https://raw.githubusercontent.com/ahmetb/kubectx/v${KUBECTX_VERSION}/completion/kubectx.fish"
#fi
#
#install_tool kubens 🍀️ \
#    "https://github.com/ahmetb/kubectx/releases/download/v${KUBECTX_VERSION}/kubens_v${KUBECTX_VERSION}_linux_x86_64.tar.gz" \
#    "./kubens_v${KUBECTX_VERSION}_linux_x86_64.tar.gz" \
#    "tar -xzvf"
#
#if [ ! -f "${HOME}/.config/fish/completions/kubens.fish" ]; then
#    curl -L -o "${HOME}/.config/fish/completions/kubens.fish" "https://raw.githubusercontent.com/ahmetb/kubectx/v${KUBECTX_VERSION}/completion/kubens.fish"
#fi
#


#install_tool aws-vault 🔐️ \
#    "https://github.com/99designs/aws-vault/releases/download/v${AWS_VAULT_VERSION}/aws-vault-linux-amd64" \
#    "aws-vault-linux-amd64"


#install_tool tfswitch X \
#    "https://github.com/warrensbox/terraform-switcher/releases/download/${TFSWITCH_VERSION}/terraform-switcher_${TFSWITCH_VERSION}_linux_amd64.tar.gz" \
#    "terraform-switcher_${TFSWITCH_VERSION}_linux_amd64.tar.gz" \
#    "tar -xzvf" \
#    "tfswitch"

#install_tool cheat X \
#    "https://github.com/cheat/cheat/releases/download/${CHEAT_VERSION}/cheat-linux-amd64.gz" \
#    "cheat-linux-amd64.gz" \
#    gunzip
#if [ ! -d "${HOME}/.config/cheat" ]; then
#  mkdir -p "${HOME}/.config/cheat" && cheat --init > "${HOME}/.config/cheat/conf.yml"
#fi

