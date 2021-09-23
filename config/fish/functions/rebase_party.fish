function rebase_party
    for filepath in (git status | grep -E 'both (added|modified)' | awk '{print $3}' )
	nvim $filepath
	git add $filepath
	git status
    end

    git status
    git rebase --continue
    git status
end
