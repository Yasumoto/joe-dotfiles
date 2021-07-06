# Main Kubernetes Cluster

This cluster is configured with the [community-maintained `eks` module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/17.1.0). Rather than build out our own entirely from scratch, we leverage the best practices provided by the community to ensure everything is wired up appropriately.

Overall, this cluster is following [the suggested configs based off Hashicorp's tutorial](https://learn.hashicorp.com/tutorials/terraform/eks?in=terraform/kubernetes).

## Create your kubeconfig

```sh
aws eks --region $(terraform output -raw region) update-kubeconfig --name $(terraform output -raw cluster_name)
```

## Viewing the Dashboard

```sh
kubectl proxy

kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep service-controller-token | awk '{print $1}')
```

Then use the [local proxy to tunnel your browser traffic](http://127.0.0.1:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/) through, and paste the token.
