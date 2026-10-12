output "vpc_id" {
  value = aws_vpc.lab.id
}

output "public_instance_public_ip" {
  value = aws_instance.public.public_ip
}

output "public_instance_private_ip" {
  value = aws_instance.public.private_ip
}

output "private_instance_private_ip" {
  value = aws_instance.private.private_ip
}

output "ssh_to_public" {
  value = "ssh -A ec2-user@${aws_instance.public.public_ip}"
}

output "ssh_to_private_from_public" {
  value = "ssh ec2-user@${aws_instance.private.private_ip}"
}
