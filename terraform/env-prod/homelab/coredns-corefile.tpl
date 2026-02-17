.:53 {
    errors
    health
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
      pods insecure
      fallthrough in-addr.arpa ip6.arpa
    }
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
