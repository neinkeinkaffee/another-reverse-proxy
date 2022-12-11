# another-rpi-reverse-proxy

## K3s setup

Install k3s server 
```
curl -sfL https://get.k3s.io | sh -
mkdir ~/.kube
echo "export KUBECONFIG=~/.kube/config" >> ~/.bashrc
source ~/.bashrc
sudo k3s kubectl config view --raw > "$KUBECONFIG"
chmod 600 $KUBECONFIG
```

Print server token
```
sudo cat /var/lib/rancher/k3s/server/node-token
```

Install k3s agents 
```
curl -sfL https://get.k3s.io | K3S_URL=${SERVER_HOST}:6443 K3S_TOKEN=${SERVER_TOKEN} sh -
```

```
kubectl create configmap hello-html --from-file pods/hello.html
kubectl create configmap goodbye-html --from-file pods/goodbye.html
kubectl apply -f pods/hello.yaml
kubectl apply -f pods/goodbye.yaml
```

## Reverse proxy setup

### EC2 reverse proxy

Start the reverse proxy on EC2
```
terraform -chdir=terraform apply
```

### Autossh tunnel

Copy the contents of the tunnel folder to the k3s server node, then enable and start the services
```
sudo mv ~/update-known-hosts.sh /user/bin
sudo mv ~/*.service /lib/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable autossh-tunnel.service
sudo systemctl enable known-hosts.service
sudo systemctl start autossh-tunnel.service
sudo systemctl start known-hosts.service
```