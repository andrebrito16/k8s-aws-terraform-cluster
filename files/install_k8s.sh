#!/bin/bash

render_kubeinit(){

HOSTNAME=$(hostname)
ADVERTISE_ADDR=$(ip -o route get to 8.8.8.8 | grep -Po '(?<=src )(\S+)')

cat <<-EOF > /root/kubeadm-init-config.yaml
---
apiVersion: kubeadm.k8s.io/v1beta3
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: abcdef.0123456789abcdef
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: $ADVERTISE_ADDR
  bindPort: ${kube_api_port}
nodeRegistration:
  criSocket: /run/containerd/containerd.sock
  imagePullPolicy: IfNotPresent
  name: $HOSTNAME
  taints: null
---
apiServer:
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta3
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager: {}
dns: {}
imageRepository: k8s.gcr.io
kind: ClusterConfiguration
kubernetesVersion: ${k8s_version}
controlPlaneEndpoint: ${control_plane_url}:${kube_api_port}
networking:
  dnsDomain: ${k8s_dns_domain}
  podSubnet: ${k8s_pod_subnet}
  serviceSubnet: ${k8s_service_subnet}
scheduler: {}
etcd:
  local:
    dataDir: /var/lib/etcd
---
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
EOF
}

wait_lb() {
while [ true ]
do
  curl --output /dev/null --silent -k https://${control_plane_url}:${kube_api_port}
  if [[ "$?" -eq 0 ]]; then
    break
  fi
  sleep 5
  echo "wait for LB"
done
}

wait_for_ca_secret(){
  res=$(aws secretsmanager get-secret-value --secret-id ${kubeadm_ca_secret_name} | jq -r .SecretString)
  while [[ -z "$res" ]]
  do
    echo "Waiting the ca hash ..."
    res=$(aws secretsmanager get-secret-value --secret-id ${kubeadm_ca_secret_name} | jq -r .SecretString)
    sleep 1
  done
}

wait_for_pods(){
  until kubectl get pods -A | grep 'Running'; do
    echo 'Waiting for k8s startup'
    sleep 5
  done
}

wait_for_masters(){
  until kubectl get nodes -o wide | grep 'control-plane,master'; do
    echo 'Waiting for k8s control-planes'
    sleep 5
  done
}

setup_env(){
  until [ -f /etc/kubernetes/admin.conf ]
  do
    sleep 5
  done
  echo "K8s initialized"
  export KUBECONFIG=/etc/kubernetes/admin.conf
}

render_kubejoin(){

HOSTNAME=$(hostname)
ADVERTISE_ADDR=$(ip -o route get to 8.8.8.8 | grep -Po '(?<=src )(\S+)')
CA_HASH=$(aws secretsmanager get-secret-value --secret-id ${kubeadm_ca_secret_name} | jq -r .SecretString)
KUBEADM_CERT=$(aws secretsmanager get-secret-value --secret-id ${kubeadm_cert_secret_name} | jq -r .SecretString)
KUBEADM_TOKEN=$(aws secretsmanager get-secret-value --secret-id ${kubeadm_token_secret_name} | jq -r .SecretString)

cat <<-EOF > /root/kubeadm-join-master.yaml
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: JoinConfiguration
discovery:
  bootstrapToken:
    token: $KUBEADM_TOKEN
    apiServerEndpoint: ${control_plane_url}:${kube_api_port}
    caCertHashes: 
      - sha256:$CA_HASH
controlPlane:
  localAPIEndpoint:
    advertiseAddress: $ADVERTISE_ADDR
    bindPort: ${kube_api_port}
  certificateKey: $KUBEADM_CERT
nodeRegistration:
  criSocket: /run/containerd/containerd.sock
  imagePullPolicy: IfNotPresent
  name: $HOSTNAME
  taints: null
---
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
EOF
}

render_nginx_config(){
cat <<-EOF > /root/nginx-ingress-config.yaml
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
    app.kubernetes.io/version: 1.1.3
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
EOF
}

k8s_join(){
  kubeadm join --config /root/kubeadm-join-master.yaml
  mkdir ~/.kube
  cp /etc/kubernetes/admin.conf ~/.kube/config
}

wait_for_secretsmanager(){
  res=$(aws secretsmanager get-secret-value --secret-id ${kubeadm_ca_secret_name} | jq -r .SecretString)
  while [[ -z "$res" ]]
  do
    echo "Waiting the ca hash ..."
    res=$(aws secretsmanager get-secret-value --secret-id ${kubeadm_ca_secret_name} | jq -r .SecretString)
    sleep 1
  done
}

generate_secrets(){
  wait_for_secretsmanager
  HASH=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')
  echo $HASH > /tmp/ca.txt

  TOKEN=$(kubeadm token create)
  echo $TOKEN > /tmp/kubeadm_token.txt

  CERT=$(kubeadm init phase upload-certs --upload-certs | tail -n 1)
  echo $CERT > /tmp/kubeadm_cert.txt

  aws secretsmanager update-secret --secret-id ${kubeadm_ca_secret_name} --secret-string file:///tmp/ca.txt
  aws secretsmanager update-secret --secret-id ${kubeadm_cert_secret_name} --secret-string file:///tmp/kubeadm_cert.txt
  aws secretsmanager update-secret --secret-id ${kubeadm_token_secret_name} --secret-string file:///tmp/kubeadm_token.txt
}

k8s_init(){
  kubeadm init --config /root/kubeadm-init-config.yaml
  mkdir ~/.kube
  cp /etc/kubernetes/admin.conf ~/.kube/config
}

setup_cni(){
  kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
}

first_instance=$(aws ec2 describe-instances --filters Name=tag-value,Values=k8s-server Name=instance-state-name,Values=running --query 'sort_by(Reservations[].Instances[], &LaunchTime)[:-1].[InstanceId]' --output text | head -n1)
instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

if [[ "$first_instance" == "$instance_id" ]]; then
  render_kubeinit
  k8s_init
  setup_env
  wait_for_pods
  setup_cni
  generate_secrets
  echo "Wait 180 seconds for control-planes to join"
  sleep 180
  wait_for_masters
  %{ if install_nginx_ingress }
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${nginx_ingress_release}/deploy/static/provider/baremetal/deploy.yaml
  render_nginx_config
  kubectl apply -f /root/nginx-ingress-config.yaml
  %{ endif }
else
  wait_for_ca_secret
  render_kubejoin
  wait_lb
  k8s_join
fi