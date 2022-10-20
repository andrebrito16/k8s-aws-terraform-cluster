variable "environment" {
  type = string
}

variable "ssk_key_pair_name" {
  type = string
}

variable "vpc_id" {
  type        = string
  description = "The vpc id"
}

variable "my_public_ip_cidr" {
  type        = string
  description = "My public ip CIDR"
}

variable "vpc_private_subnets" {
  type        = list(any)
  description = "The private vpc subnets ids"
}

variable "vpc_public_subnets" {
  type        = list(any)
  description = "The public vpc subnets ids"
}

variable "vpc_subnet_cidr" {
  type        = string
  description = "VPC subnet CIDR"
}

variable "common_prefix" {
  type        = string
  description = ""
  default     = "k8s"
}

variable "ec2_associate_public_ip_address" {
  type    = bool
  default = false
}

variable "ami" {
  type    = string
  default = "ami-0a2616929f1e63d91"
}

variable "default_instance_type" {
  type    = string
  default = "t3.large"
}

variable "instance_types" {
  description = "List of instance types to use"
  type        = map(string)
  default = {
    asg_instance_type_1 = "t3.large"
    asg_instance_type_2 = "t2.large"
    asg_instance_type_3 = "m4.large"
    asg_instance_type_4 = "t3a.large"
  }
}

variable "k8s_version" {
  type    = string
  default = "1.23.5"
}

variable "k8s_pod_subnet" {
  type    = string
  default = "10.244.0.0/16"
}

variable "k8s_service_subnet" {
  type    = string
  default = "10.96.0.0/12"
}

variable "k8s_dns_domain" {
  type    = string
  default = "cluster.local"
}

variable "kube_api_port" {
  type        = number
  default     = 6443
  description = "Kubeapi Port"
}

variable "k8s_server_desired_capacity" {
  type        = number
  default     = 3
  description = "k8s server ASG desired capacity"
}

variable "k8s_server_min_capacity" {
  type        = number
  default     = 3
  description = "k8s server ASG min capacity"
}

variable "k8s_server_max_capacity" {
  type        = number
  default     = 4
  description = "k8s server ASG max capacity"
}

variable "k8s_worker_desired_capacity" {
  type        = number
  default     = 3
  description = "k8s server ASG desired capacity"
}

variable "k8s_worker_min_capacity" {
  type        = number
  default     = 3
  description = "k8s server ASG min capacity"
}

variable "k8s_worker_max_capacity" {
  type        = number
  default     = 4
  description = "k8s server ASG max capacity"
}

variable "cluster_name" {
  type        = string
  default     = "k8s-cluster"
  description = "Cluster name"
}

variable "install_nginx_ingress" {
  type        = bool
  default     = false
  description = "Create external LB true/false"
}

variable "nginx_ingress_release" {
  type    = string
  default = "v1.3.1"
}

variable "create_extlb" {
  type        = bool
  default     = false
  description = "Create external LB true/false"
}

variable "extlb_listener_http_port" {
  type    = number
  default = 30080
}

variable "extlb_listener_https_port" {
  type    = number
  default = 30443
}

variable "extlb_http_port" {
  type    = number
  default = 80
}

variable "extlb_https_port" {
  type    = number
  default = 443
}