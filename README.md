[![GitHub issues](https://img.shields.io/github/issues/garutilorenzo/k8s-aws-terraform-cluster)](https://github.com/garutilorenzo/k8s-aws-terraform-cluster/issues)
![GitHub](https://img.shields.io/github/license/garutilorenzo/k8s-aws-terraform-cluster)
[![GitHub forks](https://img.shields.io/github/forks/garutilorenzo/k8s-aws-terraform-cluster)](https://github.com/garutilorenzo/k8s-aws-terraform-cluster/network)
[![GitHub stars](https://img.shields.io/github/stars/garutilorenzo/k8s-aws-terraform-cluster)](https://github.com/garutilorenzo/k8s-aws-terraform-cluster/stargazers)

<p align="center">
  <img src="https://garutilorenzo.github.io/images/k8s-logo.png?" alt="k8s Logo"/>
</p>

# Deploy Kubernetes on Amazon AWS

Deploy in a few minutes an high available Kubernetes cluster on Amazon AWS using mixed on-demand and spot instances.

Please **note**, this is only an example on how to Deploy a Kubernetes cluster. For a production environment you should use [EKS](https://aws.amazon.com/eks/) or [ECS](https://aws.amazon.com/it/ecs/).

The scope of this repo is to show all the AWS components needed to deploy a high available K8s cluster.

# Table of Contents

- [Deploy Kubernetes on Amazon AWS](#deploy-kubernetes-on-amazon-aws)
- [Table of Contents](#table-of-contents)
  - [Requirements](#requirements)
  - [Before you start](#before-you-start)
  - [Project setup](#project-setup)
  - [AWS provider setup](#aws-provider-setup)
  - [Pre flight checklist](#pre-flight-checklist)
  - [Infrastructure overview](#infrastructure-overview)
  - [Kubernetes setup](#kubernetes-setup)
    - [Nginx ingress controller](#nginx-ingress-controller)
    - [Cert manager](#cert-manager)
  - [Deploy](#deploy)
    - [Public LB check](#public-lb-check)
  - [Deploy a sample stack](#deploy-a-sample-stack)
  - [Clean up](#clean-up)
  - [Todo](#todo)

## Requirements

* [Terraform](https://www.terraform.io/) - Terraform is an open-source infrastructure as code software tool that provides a consistent CLI workflow to manage hundreds of cloud services. Terraform codifies cloud APIs into declarative configuration files.
* [Amazon AWS Account](https://aws.amazon.com/it/console/) - Amazon AWS account with billing enabled
* [kubectl](https://kubernetes.io/docs/tasks/tools/) - The Kubernetes command-line tool (optional)
* [aws cli](https://aws.amazon.com/cli/) optional

You need also:

* one VPC with private and public subnets
* one ssh key already uploaded on your AWS account

For VPC you can refer to [this](https://github.com/garutilorenzo/aws-terraform-examples) repository.

## Before you start

Note that this tutorial uses AWS resources that are outside the AWS free tier, so be careful!

## Project setup

Clone this repo and go in the example/ directory:

```
git clone https://github.com/garutilorenzo/k8s-aws-terraform-cluster
cd k8s-aws-terraform-cluster/example/
```

Now you have to edit the `main.tf` file and you have to create the `terraform.tfvars` file. For more detail see [AWS provider setup](#aws-provider-setup) and [Pre flight checklist](#pre-flight-checklist).

Or if you prefer you can create an new empty directory in your workspace and create this three files:

* `terraform.tfvars`
* `main.tf`
* `provider.tf`

The main.tf file will look like:

```
variable "AWS_ACCESS_KEY" {

}

variable "AWS_SECRET_KEY" {

}

variable "environment" {
  default = "staging"
}

variable "AWS_REGION" {
  default = "<CHANGE_ME>"
}

variable "my_public_ip_cidr" {
  default = "<CHANGE_ME>"
}

variable "vpc_cidr_block" {
  default = "<CHANGE_ME>"
}

variable "certmanager_email_address" {
  default = "<CHANGE_ME>"
}

variable "ssk_key_pair_name" {
  default = "<CHANGE_ME>"
}

module "private-vpc" {
  region            = var.AWS_REGION
  my_public_ip_cidr = var.my_public_ip_cidr
  vpc_cidr_block    = var.vpc_cidr_block
  environment       = var.environment
  source            = "github.com/garutilorenzo/aws-terraform-examples/private-vpc"
}

output "private_subnets_ids" {
  value = module.private-vpc.private_subnet_ids
}

output "public_subnets_ids" {
  value = module.private-vpc.public_subnet_ids
}

output "vpc_id" {
  value = module.private-vpc.vpc_id
}

module "k8s-cluster" {
  ssk_key_pair_name         = var.ssk_key_pair_name
  environment               = var.environment
  vpc_id                    = module.private-vpc.vpc_id
  vpc_private_subnets       = module.private-vpc.private_subnet_ids
  vpc_public_subnets        = module.private-vpc.public_subnet_ids
  vpc_subnet_cidr           = var.vpc_cidr_block
  my_public_ip_cidr         = var.my_public_ip_cidr
  create_extlb              = true
  install_nginx_ingress     = true
  efs_persistent_storage    = true
  expose_kubeapi            = true
  install_certmanager       = true
  certmanager_email_address = var.certmanager_email_address
  source                    = "github.com/garutilorenzo/k8s-aws-terraform-cluster"
}

output "k8s_dns_name" {
  value = module.k8s-cluster.k8s_dns_name
}

output "k8s_server_private_ips" {
  value = module.k8s-cluster.k8s_server_private_ips
}

output "k8s_workers_private_ips" {
  value = module.k8s-cluster.k8s_workers_private_ips
}
```

For all the possible variables see [Pre flight checklist](#pre-flight-checklist)

The `provider.tf` will look like:

```
provider "aws" {
  region     = var.AWS_REGION
  access_key = var.AWS_ACCESS_KEY
  secret_key = var.AWS_SECRET_KEY
}
```

The `terraform.tfvars` will look like:

```
AWS_ACCESS_KEY = "xxxxxxxxxxxxxxxxx"
AWS_SECRET_KEY = "xxxxxxxxxxxxxxxxx"
```

Now we can init terraform with:

```
terraform init

Initializing modules...
- k8s-cluster in ..

Initializing the backend...

Initializing provider plugins...
- Finding latest version of hashicorp/template...
- Finding latest version of hashicorp/aws...
- Installing hashicorp/template v2.2.0...
- Installed hashicorp/template v2.2.0 (signed by HashiCorp)
- Installing hashicorp/aws v4.9.0...
- Installed hashicorp/aws v4.9.0 (signed by HashiCorp)

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

## AWS provider setup

Follow the prerequisites step on [this](https://learn.hashicorp.com/tutorials/terraform/aws-build?in=terraform/aws-get-started) link.
In your workspace folder or in the examples directory of this repo create a file named `terraform.tfvars`:

```
AWS_ACCESS_KEY = "xxxxxxxxxxxxxxxxx"
AWS_SECRET_KEY = "xxxxxxxxxxxxxxxxx"
```

## Pre flight checklist

Once you have created the `terraform.tfvars` file edit the `main.tf` file (always in the example/ directory) and set the following variables:

| Var   | Required | Desc |
| ------- | ------- | ----------- |
| `region`       | `yes`       | set the correct AWS region based on your needs  |
| `environment`  | `yes`  | Current work environment (Example: staging/dev/prod). This value is used for tag all the deployed resources |
| `ssk_key_pair_name`  | `yes`  | Name of the ssh key to use |
| `my_public_ip_cidr` | `yes`        |  your public ip in cidr format (Example: 195.102.xxx.xxx/32) |
| `vpc_id`  | `yes`  |  ID of the VPC to use. You can find your vpc_id in your AWS console (Example: vpc-xxxxx) |
| `vpc_private_subnets`  | `yes`  |  List of private subnets to use. This subnets are used for the public LB You can find the list of your vpc subnets in your AWS console (Example: subnet-xxxxxx) |
| `vpc_public_subnets`   | `yes`  |  List of public subnets to use. This subnets are used for the EC2 instances and the private LB. You can find the list of your vpc subnets in your AWS console (Example: subnet-xxxxxx) |
| `vpc_subnet_cidr`  | `yes`  |  Your subnet CIDR. You can find the VPC subnet CIDR in your AWS console (Example: 172.31.0.0/16) |
| `common_prefix`  | `no`  | Prefix used in all resource names/tags. Default: k8s |
| `ec2_associate_public_ip_address`  | `no`  |  Assign or not a pulic ip to the EC2 instances. Default: false |
| `instance_profile_name`  | `no`  | Instance profile name. Default: K8sInstanceProfile |
| `ami`  | `no`  | Ami image name. Default: ami-0a2616929f1e63d91, ubuntu 20.04 |
| `default_instance_type`  | `no`  | Default instance type used by the Launch template. Default: t3.large |
| `instance_types`  | `no`  | Array of instances used by the ASG. Dfault: { asg_instance_type_1 = "t3.large", asg_instance_type_3 = "m4.large", asg_instance_type_4 = "t3a.large" } |
| `k8s_version`  | `no`  | Kubernetes version to install  |
| `k8s_pod_subnet`  | `no`  | Kubernetes pod subnet managed by the CNI (Flannel). Default: 10.244.0.0/16 |
| `k8s_service_subnet`  | `no`  | Kubernetes pod service managed by the CNI (Flannel). Default: 10.96.0.0/12 |
| `k8s_dns_domain`  | `no`  | Internal kubernetes DNS domain. Default: cluster.local |
| `kube_api_port`  | `no`  | Kubernetes api port. Default: 6443 |
| `k8s_server_desired_capacity` | `no`        | Desired number of k8s servers. Default 3 |
| `k8s_server_min_capacity` | `no`        | Min number of k8s servers: Default 4 |
| `k8s_server_max_capacity` | `no`        |  Max number of k8s servers: Default 3 |
| `k8s_worker_desired_capacity` | `no`        | Desired number of k8s workers. Default 3 |
| `k8s_worker_min_capacity` | `no`        | Min number of k8s workers: Default 4 |
| `k8s_worker_max_capacity` | `no`        | Max number of k8s workers: Default 3 |
| `cluster_name`  | `no`  | Kubernetes cluster name. Default: k8s-cluster |
| `install_nginx_ingress`  | `no`  | Install or not nginx ingress controller. Default: false |
| `nginx_ingress_release`  | `no`  | Nginx ingress release to install. Default: v1.8.1|
| `install_certmanager`  | `no`  | Boolean value, install [cert manager](https://cert-manager.io/) "Cloud native certificate management". Default: true  |
| `certmanager_email_address`  | `no`  | Email address used for signing https certificates. Defaul: changeme@example.com  |
| `certmanager_release`  | `no`  | Cert manager release. Default: v1.12.2  |
| `efs_persistent_storage`  | `no`  | Deploy EFS for persistent sotrage  |
| `efs_csi_driver_release`  | `no`  | EFS CSI driver Release: v1.5.8   |
| `extlb_listener_http_port`  | `no`  | HTTP nodeport where nginx ingress controller will listen. Default: 30080 |
| `extlb_listener_https_port`  | `no`  | HTTPS nodeport where nginx ingress controller will listen. Default 30443 |
| `extlb_http_port`  | `no`  | External LB HTTP listen port. Default: 80 |
| `extlb_https_port`  | `no`  | External LB HTTPS listen port. Default 443 |
| `expose_kubeapi`  | `no`  | Boolean value, default false. Expose or not the kubeapi server to the internet. Access is granted only from *my_public_ip_cidr* for security reasons. |

## Infrastructure overview

The final infrastructure will be made by:

* two autoscaling group, one for the kubernetes master nodes and one for the worker nodes
* two launch template, used by the asg
* one internal load balancer (L4) that will route traffic to Kubernetes servers
* one external load balancer (L4) that will route traffic to Kubernetes workers
* one security group that will allow traffic from the VPC subnet CIDR on all the k8s ports (kube api, nginx ingress node port etc)
* one security group that will allow traffic from all the internet into the public load balancer (L4) on port 80 and 443
* four secrets that will store k8s join tokens

Optional resources:

* EFS storage to persist data

## Kubernetes setup

The installation of K8s id done by [kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/). In this installation [Containerd](https://containerd.io/) is used as CRI and [flannel](https://github.com/flannel-io/flannel) is used as CNI.

You can optionally install [Nginx ingress controller](https://kubernetes.github.io/ingress-nginx/).

To install Nginx ingress set the variable *install_nginx_ingress* to yes (default no).

### Nginx ingress controller

You can optionally install [Nginx ingress controller](https://kubernetes.github.io/ingress-nginx/) To enable the Nginx deployment set `install_nginx_ingress` variable to `true`.

The installation is the [bare metal](https://kubernetes.github.io/ingress-nginx/deploy/#bare-metal-clusters) installation, the ingress controller then is exposed via a NodePort Service.

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
spec:
  ports:
  - appProtocol: http
    name: http
    port: 80
    protocol: TCP
    targetPort: http
    nodePort: ${extlb_listener_http_port}
  - appProtocol: https
    name: https
    port: 443
    protocol: TCP
    targetPort: https
    nodePort: ${extlb_listener_https_port}
  selector:
    app.kubernetes.io/component: controller
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
  type: NodePort
```

To get the real ip address of the clients using a public L4 load balancer we need to use the proxy protocol feature of nginx ingress controller:

```yaml
---
apiVersion: v1
data:
  allow-snippet-annotations: "true"
  enable-real-ip: "true"
  proxy-real-ip-cidr: "0.0.0.0/0"
  proxy-body-size: "20m"
  use-proxy-protocol: "true"
kind: ConfigMap
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
    app.kubernetes.io/version: ${nginx_ingress_release}
  name: ingress-nginx-controller
  namespace: ingress-nginx
```

### Cert-manager

[cert-manager](https://cert-manager.io/docs/) is used to issue certificates from a variety of supported source.

## Deploy

We are now ready to deploy our infrastructure. First we ask terraform to plan the execution with:

```
terraform plan

...
...
Plan: 73 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + k8s_dns_name            = [
      + (known after apply),
    ]
  ~ k8s_server_private_ips  = [
      - [],
      + (known after apply),
    ]
  ~ k8s_workers_private_ips = [
      - [],
      + (known after apply),
    ]
  + private_subnets_ids     = [
      + (known after apply),
      + (known after apply),
      + (known after apply),
    ]
  + public_subnets_ids      = [
      + (known after apply),
      + (known after apply),
      + (known after apply),
    ]
  + vpc_id                  = (known after apply)

───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

Note: You didn't use the -out option to save this plan, so Terraform can't guarantee to take exactly these actions if you run "terraform apply" now.
```

now we can deploy our resources with:

```
terraform apply

...

Plan: 73 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + k8s_dns_name            = [
      + (known after apply),
    ]
  ~ k8s_server_private_ips  = [
      - [],
      + (known after apply),
    ]
  ~ k8s_workers_private_ips = [
      - [],
      + (known after apply),
    ]
  + private_subnets_ids     = [
      + (known after apply),
      + (known after apply),
      + (known after apply),
    ]
  + public_subnets_ids      = [
      + (known after apply),
      + (known after apply),
      + (known after apply),
    ]
  + vpc_id                  = (known after apply)

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

...
...

Apply complete! Resources: 73 added, 0 changed, 0 destroyed.

Outputs:

k8s_dns_name = "k8s-ext-<REDACTED>.elb.amazonaws.com"
k8s_server_private_ips = [
  tolist([
    "172.x.x.x",
    "172.x.x.x",
    "172.x.x.x",
  ]),
]
k8s_workers_private_ips = [
  tolist([
    "172.x.x.x",
    "172.x.x.x",
    "172.x.x.x",
  ]),
]
private_subnets_ids = [
  "subnet-xxxxxxxxxxxxxxxxx",
  "subnet-xxxxxxxxxxxxxxxxx",
  "subnet-xxxxxxxxxxxxxxxxx",
]
public_subnets_ids = [
  "subnet-xxxxxxxxxxxxxxxxx",
  "subnet-xxxxxxxxxxxxxxxxx",
  "subnet-xxxxxxxxxxxxxxxxx",
]
vpc_id = "vpc-xxxxxxxxxxxxxxxxx"
```
Now on one master node (connect via AWS SSM) you can check the status of the cluster with:

```
ubuntu@i-04d089ed896cfafe1:~$ sudo su -

root@i-04d089ed896cfafe1:~# kubectl get nodes
NAME                  STATUS   ROLES                  AGE     VERSION
i-0033b408f7a1d55f3   Ready    control-plane,master   3m33s   v1.23.5
i-0121c2149821379cc   Ready    <none>                 4m16s   v1.23.5
i-04d089ed896cfafe1   Ready    control-plane,master   4m53s   v1.23.5
i-072bf7de2e94e6f2d   Ready    <none>                 4m15s   v1.23.5
i-09b23242f40eabcca   Ready    control-plane,master   3m56s   v1.23.5
i-0cb1e2e7784768b22   Ready    <none>                 3m57s   v1.23.5

root@i-04d089ed896cfafe1:~# kubectl get ns
NAME              STATUS   AGE
cert-manager      Active   85s
default           Active   4m55s
ingress-nginx     Active   87s # <- ingress controller ns
kube-flannel      Active   4m32s
kube-node-lease   Active   4m55s
kube-public       Active   4m56s
kube-system       Active   4m56s

root@i-04d089ed896cfafe1:~# kubectl get pods --all-namespaces
NAMESPACE       NAME                                          READY   STATUS      RESTARTS        AGE
cert-manager    cert-manager-66d9545484-h4d9h                 1/1     Running     0               47s
cert-manager    cert-manager-cainjector-7d8b6bd6fb-zl7sg      1/1     Running     0               47s
cert-manager    cert-manager-webhook-669b96dcfd-b5pgk         1/1     Running     0               47s
ingress-nginx   ingress-nginx-admission-create-g62rk          0/1     Completed   0               50s
ingress-nginx   ingress-nginx-admission-patch-n9tc5           0/1     Completed   0               50s
ingress-nginx   ingress-nginx-controller-5c778bffff-bmk2c     1/1     Running     0               50s
kube-flannel    kube-flannel-ds-5fvx9                         1/1     Running     0               3m45s
kube-flannel    kube-flannel-ds-bvqkc                         1/1     Running     1 (3m13s ago)   3m35s
kube-flannel    kube-flannel-ds-hgxtn                         1/1     Running     1 (111s ago)    2m40s
kube-flannel    kube-flannel-ds-kp6tl                         1/1     Running     0               3m27s
kube-flannel    kube-flannel-ds-nvbbg                         1/1     Running     0               3m55s
kube-flannel    kube-flannel-ds-rhsqq                         1/1     Running     0               2m42s
kube-system     aws-node-termination-handler-478lj            1/1     Running     0               26s
kube-system     aws-node-termination-handler-5bk96            1/1     Running     0               26s
kube-system     aws-node-termination-handler-bkzrf            1/1     Running     0               26s
kube-system     aws-node-termination-handler-cx5ps            1/1     Running     0               26s
kube-system     aws-node-termination-handler-dfr44            1/1     Running     0               26s
kube-system     aws-node-termination-handler-vcq7z            1/1     Running     0               26s
kube-system     coredns-5d78c9869d-n7jcq                      1/1     Running     0               4m1s
kube-system     coredns-5d78c9869d-w9k5j                      1/1     Running     0               4m1s
kube-system     efs-csi-controller-74695cd876-66bw5           3/3     Running     0               28s
kube-system     efs-csi-controller-74695cd876-hl9g7           3/3     Running     0               28s
kube-system     efs-csi-node-7wgff                            3/3     Running     0               27s
kube-system     efs-csi-node-9v4nv                            3/3     Running     0               27s
kube-system     efs-csi-node-mjz2r                            3/3     Running     0               27s
kube-system     efs-csi-node-n4npv                            3/3     Running     0               27s
kube-system     efs-csi-node-pmpnc                            3/3     Running     0               27s
kube-system     efs-csi-node-s4prq                            3/3     Running     0               27s
kube-system     etcd-i-012c258d537d5ec2f                      1/1     Running     0               4m4s
kube-system     etcd-i-018fb1214f9fe07fe                      1/1     Running     0               3m7s
kube-system     etcd-i-0f73570d6dddb6d0b                      1/1     Running     0               3m27s
kube-system     kube-apiserver-i-012c258d537d5ec2f            1/1     Running     0               4m6s
kube-system     kube-apiserver-i-018fb1214f9fe07fe            1/1     Running     1 (3m4s ago)    3m4s
kube-system     kube-apiserver-i-0f73570d6dddb6d0b            1/1     Running     0               3m26s
kube-system     kube-controller-manager-i-012c258d537d5ec2f   1/1     Running     1 (3m15s ago)   4m7s
kube-system     kube-controller-manager-i-018fb1214f9fe07fe   1/1     Running     0               2m9s
kube-system     kube-controller-manager-i-0f73570d6dddb6d0b   1/1     Running     0               3m26s
kube-system     kube-proxy-4lwgv                              1/1     Running     0               2m40s
kube-system     kube-proxy-9hgtr                              1/1     Running     0               3m27s
kube-system     kube-proxy-d6zzp                              1/1     Running     0               4m1s
kube-system     kube-proxy-jwb8x                              1/1     Running     0               3m35s
kube-system     kube-proxy-q2ctc                              1/1     Running     0               2m42s
kube-system     kube-proxy-sgn7r                              1/1     Running     0               3m45s
kube-system     kube-scheduler-i-012c258d537d5ec2f            1/1     Running     1 (3m12s ago)   4m6s
kube-system     kube-scheduler-i-018fb1214f9fe07fe            1/1     Running     0               3m1s
kube-system     kube-scheduler-i-0f73570d6dddb6d0b            1/1     Running     0               3m26s
```

#### Public LB check

We can now test the public load balancer, nginx ingress controller and the security group ingress rules. On your local PC run:

```
curl -k -v https://k8s-ext-<REDACTED>.elb.amazonaws.com/
*   Trying 34.x.x.x:443...
* TCP_NODELAY set
* Connected to k8s-ext-<REDACTED>.elb.amazonaws.com (34.x.x.x) port 443 (#0)
* ALPN, offering h2
* ALPN, offering http/1.1
* successfully set certificate verify locations:
*   CAfile: /etc/ssl/certs/ca-certificates.crt
  CApath: /etc/ssl/certs
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.2 (IN), TLS handshake, Certificate (11):
* TLSv1.2 (IN), TLS handshake, Server key exchange (12):
* TLSv1.2 (IN), TLS handshake, Server finished (14):
* TLSv1.2 (OUT), TLS handshake, Client key exchange (16):
* TLSv1.2 (OUT), TLS change cipher, Change cipher spec (1):
* TLSv1.2 (OUT), TLS handshake, Finished (20):
* TLSv1.2 (IN), TLS handshake, Finished (20):
* SSL connection using TLSv1.2 / ECDHE-RSA-AES128-GCM-SHA256
* ALPN, server accepted to use h2
* Server certificate:
*  subject: C=IT; ST=Italy; L=Brescia; O=GL Ltd; OU=IT; CN=testlb.domainexample.com; emailAddress=email@you.com
*  start date: Apr 11 08:20:12 2022 GMT
*  expire date: Apr 11 08:20:12 2023 GMT
*  issuer: C=IT; ST=Italy; L=Brescia; O=GL Ltd; OU=IT; CN=testlb.domainexample.com; emailAddress=email@you.com
*  SSL certificate verify result: self signed certificate (18), continuing anyway.
* Using HTTP2, server supports multi-use
* Connection state changed (HTTP/2 confirmed)
* Copying HTTP/2 data in stream buffer to connection buffer after upgrade: len=0
* Using Stream ID: 1 (easy handle 0x55c6560cde10)
> GET / HTTP/2
> Host: k8s-ext-<REDACTED>.elb.amazonaws.com
> user-agent: curl/7.68.0
> accept: */*
> 
* Connection state changed (MAX_CONCURRENT_STREAMS == 128)!
< HTTP/2 404 
< date: Tue, 12 Apr 2022 10:08:18 GMT
< content-type: text/html
< content-length: 146
< strict-transport-security: max-age=15724800; includeSubDomains
< 
<html>
<head><title>404 Not Found</title></head>
<body>
<center><h1>404 Not Found</h1></center>
<hr><center>nginx</center>
</body>
</html>
* Connection #0 to host k8s-ext-<REDACTED>.elb.amazonaws.com left intact
```

*404* is a correct response since the cluster is empty.

## Deploy a sample stack

[Deploy ECK](deployments/) on Kubernetes

## Clean up

```
terraform destroy
```