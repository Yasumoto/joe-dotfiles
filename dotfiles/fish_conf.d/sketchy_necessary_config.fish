function fish_greeting
    if command -v fortune > /dev/null
        echo
        fortune
    end
    echo
end
