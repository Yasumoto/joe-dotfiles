module "kube" {
    source = "./modules/eks"

    project = "cluster"
    subnet_ids = [aws_subnet.main.id, aws_subnet.second.id]
    vpc_id = aws_vpc.main.id

    #cluster_serrvice_ipv4_cidr = ""
}
