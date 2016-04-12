resource "aws_security_group" "gocd_elb" {
    name = "gocd-agent-ui-elb-sg"
    description = "Security group for the gocd UI ELBs"
    vpc_id = "${var.vpc_id}"

    tags {
        Name = "gocd (ELB)"
    }

    # HTTP
    ingress {
        from_port = 8085
        to_port = 8085
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

resource "aws_security_group" "gocd_agent" {
    name = "gocd-agent-sg"
    description = "Security group for gocd agent instances"
    vpc_id = "${var.vpc_id}"

    tags {
        Name = "gocd Agent (Instance)"
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
        from_port = 8085
        to_port = 8085
        protocol = "tcp"
        security_groups = ["${aws_security_group.gocd_elb.id}"]
    }

    # HTTP
    ingress {
        from_port = 8085
        to_port = 8085
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


resource "aws_iam_role" "gocd_agent" {
    name = "gocdAgent"
    assume_role_policy = "${file("${path.module}/policies/assume-role-policy.json")}"
}

resource "aws_iam_role_policy" "gocd_agent" {
    name = "gocdAgent"
    role = "${aws_iam_role.gocd_agent.id}"
    policy = "${file("${path.module}/policies/gocd-agent-policy.json")}"
}

resource "aws_iam_instance_profile" "gocd_agent" {
    name = "gocdAgent"
    roles = ["${aws_iam_role.gocd_agent.name}"]
}

resource "template_file" "init" {
    template = "${file("${path.module}/user_data.sh")}"
    vars {
        gocd_server = "${var.server_dns}"
    }
}


resource "aws_launch_configuration" "gocd_agent" {
    image_id = "${var.ami}"
    instance_type = "${var.instance_type}"
    security_groups = ["${aws_security_group.gocd_agent.id}"]
    associate_public_ip_address = false
    ebs_optimized = false
    key_name = "${var.key_name}"
    iam_instance_profile = "${aws_iam_instance_profile.gocd_agent.id}"
    lifecycle {create_before_destroy = true}
    user_data = "${template_file.init.rendered}"
}

resource "aws_elb" "gocd_elb" {
  name = "gocd-agent-elb"
  subnets = ["${split(",", var.public_subnets)}"]
  security_groups = ["${aws_security_group.gocd_elb.id}"]
  cross_zone_load_balancing = true
  connection_draining = true
  #internal = true

  listener {
    instance_port      = 8085
    instance_protocol  = "tcp"
    lb_port            = 8085
    lb_protocol        = "tcp"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
    target              = "TCP:8085"
    timeout             = 5
  }
}

resource "aws_autoscaling_group" "gocd_agent" {
    launch_configuration = "${aws_launch_configuration.gocd_agent.id}"
    vpc_zone_identifier = ["${split(",", var.private_subnets)}"]
    health_check_grace_period = "900"
    health_check_type = "EC2"
    load_balancers = ["${aws_elb.gocd_elb.name}"]

    name = "gocd-agent-autoscaling-group"

    max_size = 4
    min_size = 2
    desired_capacity = 3
    default_cooldown = 30
    force_delete = true

    tag {
        key = "Name"
        value = "gocd-agent"
        propagate_at_launch = true
    }

    tag {
        key = "role"
        value = "gocd-agent"
        propagate_at_launch = true
    }
}
