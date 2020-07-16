provider "aws" {
  region = "ap-northeast-2"
  profile = "riya"
}

resource "aws_vpc" "main" {
  cidr_block = "172.30.0.0/16"
}

resource "aws_subnet" "main1" {
  vpc_id            = aws_vpc.main.id
  availability_zone = "ap-south-1a"
  cidr_block        = "172.30.1.0/24"
}


resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "my_igw"
  }
}

resource "aws_route_table" "r" {
  vpc_id = aws_vpc.main.id


  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "my_routing_table"
  }
}


resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main1.id
  route_table_id = aws_route_table.r.id
}


resource "tls_private_key" "thiskey" {
  algorithm = "RSA"
}

module "key_pair" {
  source = "terraform-aws-modules/key-pair/aws"
  create_key_pair = true
  key_name   = "My_tera_key"
  public_key = tls_private_key.thiskey.public_key_openssh

}


resource "aws_security_group" "sg1" {
  name        = "my-sg"
  description = "Allow nfs,ssh and http  "
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "allow ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "allow nfs"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "allow http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nfs-sg"
  }
}



resource "aws_efs_file_system" "efs" {
  creation_token = "efs-1"

  tags = {
    Name = "my_efs"
  }
}

resource "aws_efs_mount_target" "alpha" {
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = aws_subnet.main1.id
  security_groups= [aws_security_group.sg1.id]
}


resource "aws_instance" "web" {
  depends_on=[aws_efs_mount_target.alpha]
  ami           = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  key_name = "My_tera_key"
  security_groups = [aws_security_group.sg1.id]
  subnet_id = aws_subnet.main1.id
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/HP/Desktop/tera-key.pem")
    host     = aws_instance.web.public_ip
  }
  provisioner "remote-exec" {
    inline = [
     "sudo yum install httpd php git -y",
     "sudo systemctl start httpd",
     "sudo systemctl enable httpd",
     "sudo rm -rf /var/www/html/*",
     "sudo yum install -y amazon-efs-utils",
     "sudo yum install -y nfs-utils",
     "sudo apt-get install nfs-common",
     "sudo mount -t nfs -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${aws_efs_mount_target.alpha.dns_name}:/ /var/www/html",
     "cd /var/www/html",
     "sudo rm -rf /var/www/html/*",
     "sudo yum install git -y",
     "sudo git clone https://github.com/aditi1819/terraform_test.git /var/www/html"
  }

  tags = {
    Name = "os-tf"
  }
}

resource "aws_s3_bucket" "b1" {
  bucket = "kjdclejnce"
  tags = {

    Name = "bucket-new"
   }
  region ="ap-south-1"
}

resource "aws_s3_bucket_object" "object" {
  bucket = "kjdclejnce"
  key    = "new_object"
  source = "C:/Users/HP/Desktop/tera/storage/git-test/myimg.jpg"
  acl = "public-read"
}


resource "aws_s3_bucket_public_access_block" "example1" {

  bucket = "${aws_s3_bucket.b1.id}"
  block_public_acls = false
  block_public_policy = false

}



resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.b1.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.b1.s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  
 default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.mybucket.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  
  restrictions {
        geo_restriction {
            
            restriction_type = "none"
        }
    }

   viewer_certificate {
        cloudfront_default_certificate = true
    }

  tags = {
    Name = "cf-tera"
  }
}
