#module "kube" {
#  source = "./modules/eks"
#
#  project = "cluster"
#  subnet_ids = [
#    aws_subnet.main.id,
#    aws_subnet.second.id,
#    aws_subnet.public_main.id,
#    aws_subnet.public_second.id
#  ]
#  vpc_id = aws_vpc.main.id
#
#  #TODO(joe): Fix this up when the config map isn't a race condition
#  # when trying to create/update the cluster! Set to false to try
#  # to be free (you may also need to run this first:
#  # terraform state rm module.main.kubernetes_config_map.aws_auth[0]
#  manage_aws_auth = false
#
#  #cluster_serrvice_ipv4_cidr = ""
#}
