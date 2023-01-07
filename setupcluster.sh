#!/bin/bash


##################### Run this on all Linux nodes #######################

#Update the server
sudo apt-get update -y; sudo apt-get upgrade -y

#Get Kernel version
sudo hostnamectl

#Install helm
sudo snap install helm --classic

#Install containerd
sudo apt-get install containerd -y


#Configure containerd and start the service
sudo mkdir -p /etc/containerd
sudo su -
containerd config default  /etc/containerd/config.toml
exit

#Next, install Kubernetes. First you need to add the repository's GPG key with the command:
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add

#Add the Kubernetes repository
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"

#Install all of the necessary Kubernetes components with the command:
sudo apt-get install kubeadm kubelet kubectl -y

#Modify "sysctl.conf" to allow Linux Node’s iptables to correctly see bridged traffic
sudo nano /etc/sysctl.conf
    #Add this line: net.bridge.bridge-nf-call-iptables = 1

sudo -s
#Allow packets arriving at the node's network interface to be forwaded to pods. 
sudo echo '1' > /proc/sys/net/ipv4/ip_forward
exit

#Reload the configurations with the command:
sudo sysctl --system

#Load overlay and netfilter modules 
sudo modprobe overlay
sudo modprobe br_netfilter
  
#Disable swap by opening the fstab file for editing 
sudo nano /etc/fstab
    #Comment out "/swap.img"

#Disable swap from comand line also 
sudo swapoff -a

#Pull the necessary containers with the command:
sudo kubeadm config images pull

#***********************************************************************Setup cluster*****************************
####### This section must be run only on the Master node#############
sudo kubeadm init --skip-phases=addon/kube-proxy


#******************************************************************Run this on other nodes*****************
#Once the cluster is set up, it will print out a "kubeadm join " command, copy it to all other nodes that you want to join the cluster:
sudo kubeadm join ---

#**************************************


#Create a "$HOME/.kube" foler and copy the config from "/etc/kubernetes/admin.conf". The config file contains the necessary certs to log-in Kubernetes
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config


#Install cilium CLI
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-amd64.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
rm cilium-linux-amd64.tar.gz{,.sha256sum}

#Setup Helm repository
helm repo add cilium https://helm.cilium.io/

#Setup cilium 
helm install cilium cilium/cilium --version 1.12.3  --namespace kube-system --set kubeProxyReplacement=strict \
--set k8sServiceHost=192.168.0.64 --set k8sServicePort=6443 --set hubble.enabled=false
    

#Wait for a few mints

#***If "kubectl get nodes" shows "Not Ready"
#***Or  "kubectl get pods -n kube-system" shows "coredns-*" as "Pending",
#**Reboot node(s)
kubectl get nodes
kubectl get pods -n kube-system -o wide

kubectl -n kube-system get pods -l k8s-app=cilium -o wide
MASTER_CILIUM_POD=$(kubectl -n kube-system get pods -l k8s-app=cilium -o wide |  grep master | awk '{ print $1}' )
echo $MASTER_CILIUM_POD

#validate that the Cilium agent is running in the desired mode
kubectl exec -it -n kube-system $MASTER_CILIUM_POD -- cilium status | grep KubeProxyReplacement

kubectl exec -it -n kube-system $MASTER_CILIUM_POD -- cilium status --verbose

#Validate that Cilium installation
cilium status --wait

#***************************************************Setup Hubble******************************************************************
helm upgrade cilium cilium/cilium --version 1.12.3 \
   --namespace kube-system \
   --reuse-values \
   --set hubble.relay.enabled=true \
   --set hubble.enabled=true \
   --set hubble.ui.enabled=true


cilium status

#In order to access the observability data collected by Hubble, install the Hubble CL
export HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
curl -L --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-amd64.tar.gz{,.sha256sum}
sha256sum --check hubble-linux-amd64.tar.gz.sha256sum
sudo tar xzvfC hubble-linux-amd64.tar.gz /usr/local/bin
rm hubble-linux-amd64.tar.gz{,.sha256sum}


#In order to access the Hubble API, create a port forward to the Hubble service from your local machine
cilium hubble port-forward&

hubble status



