if command -s rbenv > /dev/null
  status --is-interactive; and source (rbenv init -|psub)
end
