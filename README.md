# devops-training (EKS/Kubernetes)

Repository contains:
- Terraform scripts to create VPC (with public and private subnets) dedicated for EKS usage.
Terraform also creates IAM roles:
    - node_group_role_arn: should be attached to EKS node group
    - ingress_controller_role_arn: should be attached to alb ingress controller pod
    (by setting podAnnotations."iam\.amazonaws\.com/role"=[ingress_controller_role_name] variable while installing ingress controller helm chart)
- Helm charts to setup [kube2iam](https://github.com/jtblin/kube2iam) and aws-alb-ingress-controller
- Few K8s manifest files to deploy simple replication controller for pods with nginx server or simple hello-world container from pluralsight course
- K8s manifest file to deploy service of LoadBalancer or NodePort type (NodePort type needed if you want to use ingress)
- K8s manifest files to configure ingress for service from previous step

### VPC architecture:
It is terraformed version of AWS cloudformation [stack](https://amazon-eks.s3.us-west-2.amazonaws.com/cloudformation/2020-04-21/amazon-eks-vpc-private-subnets.yaml)
This VPC has two public and two private subnets. 
One public and one private subnet are deployed to the same Availability Zone.
The other public and private subnets are deployed to a second Availability Zone in the same Region.
AWS recommends this option for all production deployments. 

This option allows you to deploy your worker nodes to private subnets and allows Kubernetes to deploy
load balancers to the public subnets that can load balance traffic to pods running on worker nodes in the private subnets.

Public IP addresses are automatically assigned to resources deployed to one of the public subnets, but public IP addresses are not assigned to any resources deployed to the private subnets.
The worker nodes in private subnets can communicate with the cluster and other AWS services, and pods can communicate outbound to the internet through a NAT gateway that is deployed in each Availability Zone.
A security group is deployed that denies all inbound traffic and allows all outbound traffic. 

The subnets are tagged so that Kubernetes is able to deploy load balancers to them.
For more information about subnet tagging, see [Subnet tagging requirement](https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html#vpc-subnet-tagging). 
For more information about this type of VPC, see [VPC with public and private subnets (NAT)](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Scenario2.html). 

### Requirements (tested on MacOS):

- helm (tested with v3.1.2)
- aws-iam-authenticator (tested with v0.5.0) - in some cases might not be needed
- eksctl (tested with 0.17.0-rc.0)
- kubectl (tested with GitVersion:"v1.14.3")
- awscli (tested with aws-cli/1.16.258)
- Correctly configured AWS CLI Credentials

see [this](https://docs.aws.amazon.com/eks/latest/userguide/getting-started-eksctl.html) guide

### How to run it:

1. In `terraform` directory run `terraform apply -var eks_cluster_name=[name_of_cluster]`. You can modify manually terraform variables if needed (in `terraform/main.tf`)
2. Set correct cluster name and subnet ids in `cluster_without_nodes.yaml` and Run `eksctl create cluster -f cluster_without_nodes.yaml`
3. In AWS console find your cluster and create new node group attaching an iam role from terraform's `node_group_role_arn` output
4. In `helm_charts` directory Run `helm install kube2iam --set=aws.region=[region_name]--set=rbac.create=true --set=host.iptables=true --set=host.interface=eni+ --set=extraArgs.base-role-arn=arn:aws:iam::[your_aws_account_id]:role/ ./kube2iam`  
For example:  
`helm install kube2iam --set=aws.region=eu-west-1 --set=rbac.create=true --set=host.iptables=true --set=host.interface=eni+ --set=extraArgs.base-role-arn=arn:aws:iam::890769921003:role/ ./kube2iam`  
This will install kube2iam which will allow to attach an iam roles directly to your pods and they will use this iam role while making aws requests instead a role that is attached to ec2 node.  
Note that in your environment the host.interface might be different than eni+ depending on which virtual network you use e.g:
    - for Calico, use cali+ (the interface name is something like cali1234567890)
    - for kops (on kubenet), use cbr0
    - for CNI, use cni0
    - for EKS/amazon-vpc-cni-k8s, even with calico installed uses eni+. (Each pod gets an interface like eni4c0e15dfb05)
    - for weave use weave
    - for flannel use cni0
    - for kube-router use kube-bridge
    - for OpenShift use tun0
    - for Cilium use lxc+  
5. In `helm_charts` directory Run `helm install aws-alb-ingress-controller --set clusterName=[name_of_cluster] --set awsRegion=[cluster_region] --set autoDiscoverAwsVpcID=true --set podAnnotations."iam\.amazonaws\.com/role"=[name_of_ingress_controller_role]  --namespace kube-system ./aws-alb-ingress-controller`  
For example:  
`helm install aws-alb-ingress-controller --set clusterName=rdrewniak-cluster --set awsRegion=eu-west-1 --set autoDiscoverAwsVpcID=true --set podAnnotations."iam\.amazonaws\.com/role"=rdrewniak-role-for-alb-ingress-controller-pod --namespace kube-system ./aws-alb-ingress-controller`  
This will install ALB ingress controller which will be able to create ALB in AWS for your ingress services

6. Run `kubectl create -f hello-world-rc.yaml` to create replication controller for pods with hello-world app
7. Run `kubectl create -f hello-world-NP-svc.yaml` to create NodePort service for hello-world pods
8. Run `kubectl create -f ingress.yaml` to create ingress for hello-world service
9. Wait few seconds and run `kubectl get ingress test-ingress` and check if some address was attached to it. If it doesn't have an address then most probably something is wrong with kube2iam or ingress-controller deployment or a role attached to ingress-controller pod does not have correct policies.
10. Now you should be able to access hello-world app by going to ingress address.

### NOTES: 
 - In helm install commands you can use --dry-run flag to see what will be deployed into your cluster without applying any changes
 - Before running terraform destroy. Please remove manually all ALB's (if any) and all it's related security groups.
 - Thanks to kube2iam it is possible to directly attach an iam role to pods. To do that the pods need to be annotated with iam.amazonaws.com/role: [role_name] or iam.amazonaws.com/role: [role_arn] (if extraArgs.base-role-arn was not set in kube2iam helm chart installation)
 - The role that you want to attach to your pods needs to allow node group iam role to assume it. An example trust relationship looks like this:
 ```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::890769921003:role/RDrewniakEKSManagedNodeGroupRole"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```