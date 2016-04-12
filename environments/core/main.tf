module "vpc" {
    source = "../../modules/vpc"
    name = "${var.environment_name}"
    cidr = "10.0.0.0/16"
    private_subnets = "10.0.0.0/21,10.0.64.0/21,10.0.128.0/21"
    public_subnets = "10.0.32.0/22,10.0.96.0/22,10.0.160.0/22"
    availability_zones = "us-west-2a,us-west-2b,us-west-2c"
}

module "gocd-server" {
    source = "../../modules/gocd-server"
    ami = "${var.gocd_server_ami}"
    vpc_id = "${module.vpc.vpc_id}"
    public_subnets = "${module.vpc.public_subnets}"
    private_subnets = "${module.vpc.private_subnets}"
    ingress_cidr_blocks = "0.0.0.0/0"
    key_name = "${var.key_name}"
    instance_type = "t2.micro"
}

module "gocd-linux-agent" {
    source = "../../modules/gocd-linux-agent"
    ami = "${var.gocd_linux_agent_ami}"
    vpc_id = "${module.vpc.vpc_id}"
    public_subnets = "${module.vpc.public_subnets}"
    private_subnets = "${module.vpc.private_subnets}"
    ingress_cidr_blocks = "0.0.0.0/0"
    key_name = "${var.key_name}"
    instance_type = "t2.micro"
    server_dns = "${module.gocd-server.elb_address}"
}
