function bouncer
    set BOUNCER_IP (aws ec2 describe-instances --filters Name=tag-key,Values=Name Name=tag-value,Values=bouncer | jq -r .Reservations[].Instances[].NetworkInterfaces[].Association.PublicIp)
    echo "$BOUNCER_IP"
end
