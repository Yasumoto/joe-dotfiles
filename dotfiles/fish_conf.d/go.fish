if [ -d "$HOME/go" ]
  set -gx GOPATH "$HOME"/go
  set PATH "$GOPATH"/bin $PATH
  ulimit -n 1024
end
