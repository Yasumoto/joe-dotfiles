function vault_login
  set -e VAULT_TOKEN

  if [ -z (which vault) ]
    echo "No vault found"
    exit
  end

  vault login -non-interactive -method=userpass username=joe.smith \
      password=(keepassxc-cli show -s -a Password ~/Documents/joe.smith.kdbx Vault)
end
