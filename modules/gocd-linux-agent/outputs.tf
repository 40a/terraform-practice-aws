output "elb_address" {
    value = "${aws_elb.gocd_elb.dns_name}"
}
