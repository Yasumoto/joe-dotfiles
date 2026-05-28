.:53 {
    errors
    health :8080
    ready :8181
    hosts {
        ${forward_records}
    }
    forward . 8.8.8.8 1.1.1.1
    cache 30
    loop
    reload
    loadbalance
}

# Reverse DNS for your subnet
${reverse_zone}.in-addr.arpa {
    errors
    hosts {
        ${reverse_records}
    }
}
