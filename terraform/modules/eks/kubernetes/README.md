# Kubernetes Jobs

We're bringing up some of the basic helper jobs on our cluster, based on the [hashicorp docs](https://learn.hashicorp.com/tutorials/terraform/eks#deploy-and-access-kubernetes-dashboard)

1. [Metrics Server](https://github.com/kubernetes-sigs/metrics-server/releases/tag/v0.5.0)
2. [Dashboard](https://github.com/kubernetes/dashboard/releases/tag/v2.3.1)

To launch these, just run:

```sh
kubectl apply -f $FILENAME
```

To view the dashboard, look up the [instructions above](../README#Viewing-the-Dashboard).

## TODO

Setup read-only access by default to the dashboard so we can open it up to our internal network
