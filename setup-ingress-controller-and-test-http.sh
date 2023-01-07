#Enable Cilium ingress (it leverages Kubernetes ingress infrastructure and uses Envoy proxy for ingress and traffic management)

# ingressController.loadbalancerMode:
  # dedicated: The Ingress controller will create a dedicated loadbalancer for the Ingress.
  # shared: The Ingress controller will use a shared loadbalancer for all Ingress resources.
# If you only want to use envoy traffic management feature without Ingress support, you should only enable --enable-envoy-config 

helm upgrade cilium cilium/cilium \
     --namespace kube-system \
     --reuse-values \
     --set ingressController.enabled=true \
     --set ingressController.loadbalancerMode=dedicated
     

kubectl -n kube-system rollout restart deployment/cilium-operator
kubectl -n kube-system rollout restart ds/cilium

cilium status

#Rest example
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.11/samples/bookinfo/platform/kube/bookinfo.yaml
 
kubectl get pods -o wide

kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/HEAD/examples/kubernetes/servicemesh/basic-ingress.yaml

kubectl get CiliumEnvoyConfig
kubectl describe CiliumEnvoyConfig

kubectl get svc

kubectl get ingress

sudo apt  install jq

HTTP_INGRESS=$(kubectl get ingress basic-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo $HTTP_INGRESS
curl --fail -s http://"$HTTP_INGRESS"/details/1 | jq
curl --fail -s http://"$HTTP_INGRESS"















#****************************************************gRPC example*********************************************************************************
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/master/release/kubernetes-manifests.yaml

kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/HEAD/examples/kubernetes/servicemesh/grpc-ingress.yaml
  
kubectl get ingress

#Install grpcul
wget https://github.com/fullstorydev/grpcurl/releases/download/v1.7.0/grpcurl_1.7.0_linux_x86_64.tar.gz
tar -xvf grpcurl_1.7.0_linux_x86_64.tar.gz
chmod +x grpcurl
sudo cp grpcurl /usr/bin


#Since gRPC is binary-encoded, you also need the proto definitions for the gRPC services in order to make gRPC requests. 
# A .proto file is a description of a gRPC API written in the Protocol Buffers language specification. Protocol Buffers is a binary format. It is NOT a self-describing language. 
# Thus, there needs to be a common "dictionary" used by both the gRPC client and server to encode and decode text and numbers into the Protocol Buffers binary format.Download this for the demo app:
curl -o demo.proto https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/master/pb/demo.proto

GRPC_INGRESS=$(kubectl get ingress grpc-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

#To access the currency service:
grpcurl -plaintext -proto ./demo.proto $GRPC_INGRESS:80 hipstershop.CurrencyService/GetSupportedCurrencies
#To access the product catalog service:
grpcurl -plaintext -proto ./demo.proto $GRPC_INGRESS:80 hipstershop.ProductCatalogService/ListProducts













#*****************************************************************************TLS termination********************************************************************************
#Install Go
sudo apt install golang -y

#For testing purposes we'll create an self signed TSL cert using minica
git clone https://github.com/jsha/minica.git
cd minica/
go build
chmod +x minica

# On first run, minica generates a CA certificate and key (minica.pem and minica-key.pem). It also creates a directory called _.cilium.rocks containing a key and certificate file that we will use 
#for the ingress service.
./minica -domains '*.cilium.rocks'

# On first run, minica generates a CA certificate and key (minica.pem and minica-key.pem). It also creates a directory called _.cilium.rocks containing a key and certificate file that we will use 
#for the ingress service.
# Create a Kubernetes secret with this demo key and certificate:
kubectl create secret tls demo-cert --key=_.cilium.rocks/key.pem --cert=_.cilium.rocks/cert.pem


# The Ingress configuration for this demo provides the same routing as those demos but with the addition of TLS termination.
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/HEAD/examples/kubernetes/servicemesh/tls-ingress.yaml

kubectl get ingress

#On the client
#Add the virtual service IP to DNS
sudo nano /etc/hosts
curl --cacert minica.pem -v https://bookinfo.cilium.rocks/details/1


#Download demo.proto file if you have not done before
curl -o demo.proto https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/master/pb/demo.proto
grpcurl -proto ./demo.proto -cacert minica.pem hipstershop.cilium.rocks:443 hipstershop.ProductCatalogService/ListProducts 



#Cleanup
kubectl delete -f  https://raw.githubusercontent.com/cilium/cilium/HEAD/examples/kubernetes/servicemesh/tls-ingress.yaml
kubectl delete secret  demo-cert
kubectl delete -f https://raw.githubusercontent.com/cilium/cilium/HEAD/examples/kubernetes/servicemesh/grpc-ingress.yaml
kubectl delete -f https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/master/release/kubernetes-manifests.yaml
kubectl delete -f https://raw.githubusercontent.com/cilium/cilium/HEAD/examples/kubernetes/servicemesh/basic-ingress.yaml
kubectl delete -f  https://raw.githubusercontent.com/istio/istio/release-1.11/samples/bookinfo/platform/kube/bookinfo.yaml

helm upgrade cilium cilium/cilium \
     --namespace kube-system \
     --reuse-values \
     --set ingressController.enabled=false
     
kubectl -n kube-system rollout restart deployment/cilium-operator
kubectl -n kube-system rollout restart ds/cilium