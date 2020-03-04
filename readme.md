# Using Terraform and Kubespray to build Kubernetes Clusters

# Terraform
- install the latest terraform https://www.terraform.io/downloads.html
- Create and Ubuntu or Centos Template in vSphere. I have tested Ubuntu 16 and 18 mostly. Centos7 works and if you use minimal image you need to pre-install the perl packaged for the VMware customization to work.
- There are versions of the open-vm-tools package that break everything. 
- Edit the ```provider.tf``` file to match your environment
- Edit ```cluster.tf``` with the proper information for your cluster including IP's, Template Name, Folder, Cluster, etc.


** If this is the first time running terraform: **
```
terraform init
```
Then run this everytime to be sure what is going to happen"
```
terraform plan
```
If you like you you see from the output, terraform plan should return no errors and say something like it plans on adding 6 new...
```
terraform apply 
```
Within VMware you should now have some shiny new vm's

# Kubespray
In your cluster directory make sure the ```inventory.ini```  file matches the IP's for your environment. Additionally make sure your ssh key is copied to your nodes. Ansible is what is underneath kubespray and ansible works best with ssh publickey. Also, to reduce extra flags in ansible you can add NOPASSwD:ALL to your users access for sudo. 

***The "-b" flag tells ansible to "become" another user aka run sudo. The "-K" (uppercase K) will prompt for the sudo password if you are unable to use teh NOPASSWD settings for sudo.***

If you are going to use PSO make sure you have checked the pre-requisites.
https://github.com/purestorage/helm-charts
There is an anisble playbook I use to install the right packages on the VMs (ubuntu).

```
ansible-playbook -i dev/inventory.ini -b -v prereqs.yaml 
```
### Install kubernetes with kubespray
The kubespray directory here is not automatically updating, I suggest cloning this fresh:
```
git clone git@github.com:kubernetes-sigs/kubespray.git
```
There are all kinds of things you can edit in Kubespray. At time of writing this readme the current version of k8s deployed by kubespray is 1.16.7. So far 1.17 is not available but I have found 1.16 to be pretty stable. I am looking for 1.17 so I can get some CSI Snapshot Source features as default without feature gates.

Now to run the ansible-playbook for kubespray add more -vvvv if you want more details
```
ansible-playbook -i dev/inventory.ini -b -v kubespray/cluster.yml
```
To prompt for sudo password.
```
ansible-playbook -i dev/inventory.ini -b -v kubespray/cluster.yml -K
```
Depdending on the number of hosts this will take from 8-15 minutes.

## Retrieving  and Combine cluster configs
Run the get-me-kys.yaml. This will go to each master vm and grab the kubeconfig and name it config.<master host name>

```
ansible-playbook -i dev/inventory.ini -b -v get-me-keys.yaml
```

If you end up with many config files you can combine them. Then I show how a merge them into a config.all file then copy it to the ~/.kube/ directory. Most default kubectl installations look for the config at ~/.kube/config. So I copy and rename the file while backing up the old one.

For example:
```
KUBECONFIG=config.dev:config.lab:config.prod

kubectl config view --raw > config.all

mv ~/.kube/config ~/.kube/config.backup.$(date +%Y-%m-%d)
cp config.all ~/.kube/config
```

## Post install per Cluster (optional)
### Install nginx first
This will install the nginx ingress and a open a service with type Loadbalancer. The service will not get an ip 
```
# from your cluster directory
cd dev
# this is pulled from github and could change or get updated to break, YMMV
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml
kubectl apply -f nginx-service-lb.yaml
# Check the service is created will remain pending
kubectl get svc -A
```
### Install metallb
edit metallb-config.yaml with a free ip range in your environment

```
# use cluster directory you are building
cd dev
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.8.3/manifests/metallb.yaml
kubectl apply -f metallb-config.yaml

# might take a few minutes for the service to get the IP, usually just a few seconds though
kubectl get svc -n ingress-nginx

```
Now when you create applications you can first create a svc with clusterIP and then enable the ingress to use the host name as below. This is a very basic example.

```
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: goweb-ingress
spec:
  rules:
  - host: go.lab.newstack.local
    http:
      paths:
      - path: /
        backend:
          serviceName: gowebapp
          servicePort: 80
```

### Roadmap
- Using Jenkins to build the clusters via a git push.
- Kubespray can deploy the nginx ingress and metallb for you. Have to see how that works.