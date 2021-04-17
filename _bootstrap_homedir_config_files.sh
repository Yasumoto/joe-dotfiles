#!/bin/sh

set -eu

git submodule update --init

SCRIPT_DIRECTORY=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

for target in bash_profile config git-completion.bash git-prompt.sh vim vimrc gitignore gitconfig; do
    original_source="${SCRIPT_DIRECTORY}/${target}"
    destination="${HOME}/.${target}"
    if [ -L "${destination}" ] && [ "$(readlink "${destination}")" = "${original_source}" ]; then
        echo "${destination} already a symlink, ignoring!"
    else
	echo "Fixing ${destination} to point to ${original_source}"
	rm -rf "${destination}"
        /bin/ln -s "${original_source}" "${destination}"
    fi
done
