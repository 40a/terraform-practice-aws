variable "vpc_id" {}
variable "public_subnets" {}
variable "private_subnets" {}
variable "ingress_cidr_blocks" {}
variable "key_name" {}
variable "ami" {}
variable "instance_type" {}

resource "aws_security_group" "gocd_elb" {
    name = "gocd-ui-elb-sg"
    description = "Security group for the gocd UI ELBs"
    vpc_id = "${var.vpc_id}"

    tags {
        Name = "gocd (ELB)"
    }

    # HTTP
    ingress {
        from_port = 8153
        to_port = 8153
        protocol = "tcp"
        cidr_blocks = ["${var.ingress_cidr_blocks}"]
    }

    # TCP All outbound traffic
    egress {
        from_port = 0
        to_port = 65535
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "gocd_server" {
    name = "gocd-server-sg"
    description = "Security group for gocd Server instances"
    vpc_id = "${var.vpc_id}"

    tags {
        Name = "gocd Server (Instance)"
    }

    # SSH
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["${var.ingress_cidr_blocks}"]
    }

    # HTTP from ELB
    ingress {
        from_port = 8153
        to_port = 8153
        protocol = "tcp"
        security_groups = ["${aws_security_group.gocd_elb.id}"]
    }

    # HTTP
    ingress {
        from_port = 8153
        to_port = 8153
        protocol = "tcp"
        cidr_blocks = ["${var.ingress_cidr_blocks}"]
    }

    # TCP All outbound traffic
    egress {
        from_port = 0
        to_port = 65535
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # UDP All outbound traffic
    egress {
        from_port = 0
        to_port = 65535
        protocol = "udp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}


resource "aws_iam_role" "gocd_server" {
    name = "gocdServer"
    assume_role_policy = "${file("${path.module}/policies/assume-role-policy.json")}"
}

resource "aws_iam_role_policy" "gocd_server" {
    name = "gocdServer"
    role = "${aws_iam_role.gocd_server.id}"
    policy = "${file("${path.module}/policies/gocd-server-policy.json")}"
}

resource "aws_iam_instance_profile" "gocd_server" {
    name = "gocdServer"
    roles = ["${aws_iam_role.gocd_server.name}"]
}

resource "aws_launch_configuration" "gocd_server" {
    image_id = "${var.ami}"
    instance_type = "${var.instance_type}"
    security_groups = ["${aws_security_group.gocd_server.id}"]
    associate_public_ip_address = false
    ebs_optimized = false
    key_name = "${var.key_name}"
    iam_instance_profile = "${aws_iam_instance_profile.gocd_server.id}"
    lifecycle {create_before_destroy = true}
}

resource "aws_elb" "gocd_elb" {
  name = "gocd-elb"
  subnets = ["${split(",", var.public_subnets)}"]
  security_groups = ["${aws_security_group.gocd_elb.id}"]
  cross_zone_load_balancing = true
  connection_draining = true
  internal = true

  listener {
    instance_port      = 8153
    instance_protocol  = "tcp"
    lb_port            = 8153
    lb_protocol        = "tcp"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
    target              = "TCP:8153"
    timeout             = 5
  }
}

resource "aws_autoscaling_group" "gocd_server" {
    launch_configuration = "${aws_launch_configuration.gocd_server.id}"
    vpc_zone_identifier = ["${split(",", var.private_subnets)}"]
    health_check_grace_period = "900"
    health_check_type = "EC2"
    load_balancers = ["${aws_elb.gocd_elb.name}"]

    name = "gocd-server-autoscaling-group"

    max_size = 2
    min_size = 1
    desired_capacity = 1
    default_cooldown = 30
    force_delete = true
    
    tag {
        key = "Name"
        value = "gocd-server"
        propagate_at_launch = true
    }

    tag {
        key = "role"
        value = "gocd-server"
        propagate_at_launch = true
    }
}

output "elb_address" {
    value = "${aws_elb.gocd_elb.dns_name}"
}
