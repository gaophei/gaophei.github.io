# Configure RBAC in your Kubernetes Cluster

By Vikram Vaswani

3 years ago

- rbac
- kubernetes
- security

# Introduction

This guide will go through the basic Kubernetes Role-Based Access Control (RBAC) API Objects, together with two common use cases (create a user with limited access, and enable Helm). At the end of this guide, you should have enough knowledge to implement RBAC policies in your cluster. The examples here described were tested in Minikube, but they can be applied to any Kubernetes cluster.

From Kubernetes 1.6 onwards, RBAC policies are enabled by default. RBAC policies are vital for the correct management of your cluster, as they allow you to specify which types of actions are permitted depending on the user and their role in your organization. Examples include:

- Secure your cluster by granting privileged operations (accessing secrets, for example) only to admin users.
- Force user authentication in your cluster.
- Limit resource creation (such as pods, persistent volumes, deployments) to specific namespaces. You can also use quotas to ensure that resource usage is limited and under control.
- Have a user only see resources in their authorized namespace. This allows you to isolate resources within your organization (for example, between departments).

As a consequence of having RBAC enabled by default, you may have found errors like this when configuring network overlays (such as flanneld) or making Helm work in your cluster:

~~~routeros
```
the server does not allow access to the requested resource
```
~~~

This guide will show you how to work with RBAC so you can properly deal with issues like these.

# Prerequisites and assumptions

This guide makes the following assumptions:

- You have [Minikube installed](https://docs.bitnami.com/kubernetes/get-started-kubernetes/#option-1-install-minikube) on your local computer with RBAC enabled:

  ```bash
  minikube start --extra-config=apiserver.Authorization.Mode=RBAC
  ```

- You have a [Kubernetes cluster](https://docs.bitnami.com/kubernetes/get-started-kubernetes/#option-1-create-a-cluster-using-minikube) running.

- You have the [*kubectl* command line (kubectl CLI)](https://docs.bitnami.com/kubernetes/get-started-kubernetes/#step-3-install-kubectl-command-line) installed.

- You have [Helm](https://docs.bitnami.com/kubernetes/get-started-kubernetes/#step-4-install-helm) installed.

- You have intermediate level of understanding of [how Kubernetes works](https://kubernetes.io/docs/concepts/), and its [core resources and operations](https://kubernetes.io/docs/concepts/overview/kubernetes-api/). You are expected to be familiar with concepts like:

  - [Pods](https://kubernetes.io/docs/concepts/workloads/pods/pod/)
  - [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
  - [Namespaces](https://kubernetes.io/docs/user-guide/namespaces/)
  - [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
  - [Replicasets](https://kubernetes.io/docs/user-guide/replicasets/)
  - [PersistentVolumes](https://kubernetes.io/docs/concepts/storage/volumes/)
  - [ConfigMaps](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/)
  - [Nodes](https://kubernetes.io/docs/concepts/architecture/nodes/)

- You have [OpenSSL](https://wiki.openssl.org/index.php/Binaries) installed locally.

# RBAC API objects

One basic Kubernetes feature is that [all its resources are modeled API objects](https://kubernetes.io/docs/concepts/overview/working-with-objects/kubernetes-objects/), which allow CRUD (Create, Read, Update, Delete) operations. Examples of resources are:

- [Pods](https://kubernetes.io/docs/concepts/workloads/pods/pod/).
- [PersistentVolumes](https://kubernetes.io/docs/concepts/storage/volumes/).
- [ConfigMaps](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/).
- [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/).
- [Nodes](https://kubernetes.io/docs/concepts/architecture/nodes/).
- [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/).
- [Namespaces](https://kubernetes.io/docs/user-guide/namespaces/).

Examples of possible operations over these resources are:

- *create*
- *get*
- *delete*
- *list*
- *update*
- *edit*
- *watch*
- *exec*

At a higher level, resources are associated with [API Groups](https://kubernetes.io/docs/concepts/overview/kubernetes-api/#api-groups) (for example, Pods belong to the *core* API group whereas Deployments belong to the *apps* API group). For more information about all available resources, operations, and API groups, check the [Official Kubernetes API Reference](https://kubernetes.io/docs/reference/kubernetes-api/).

To manage RBAC in Kubernetes, apart from resources and operations, we need the following elements:

- Rules: A rule is a set of operations (verbs) that can be carried out on a group of resources which belong to different API Groups.
- Roles and ClusterRoles: Both consist of rules. The difference between a Role and a ClusterRole is the scope: in a Role, the rules are applicable to a single namespace, whereas a ClusterRole is cluster-wide, so the rules are applicable to more than one namespace. ClusterRoles can define rules for cluster-scoped resources (such as nodes) as well. Both Roles and ClusterRoles are mapped as API Resources inside our cluster.
- Subjects: These correspond to the entity that attempts an operation in the cluster. There are three types of subjects:
  - User Accounts: These are global, and meant for humans or processes living outside the cluster. There is no associated resource API Object in the Kubernetes cluster.
  - Service Accounts: This kind of account is namespaced and meant for intra-cluster processes running inside pods, which want to authenticate against the API.
  - Groups: This is used for referring to multiple accounts. There are some groups created by default such as *cluster-admin* (explained in later sections).
- RoleBindings and ClusterRoleBindings: Just as the names imply, these bind subjects to roles (i.e. the operations a given user can perform). As for Roles and ClusterRoles, the difference lies in the scope: a RoleBinding will make the rules effective inside a namespace, whereas a ClusterRoleBinding will make the rules effective in all namespaces.

You can find examples of each API element in the [Kubernetes official documentation](https://kubernetes.io/docs/admin/authorization/rbac/).

# Use case 1: Create user with limited namespace access

In this example, we will create the following User Account:

- Username: employee
- Group: bitnami

We will add the necessary RBAC policies so this user can fully manage deployments (i.e. use *kubectl run* command) only inside the *office* namespace. At the end, we will test the policies to make sure they work as expected.

## Step 1: Create the office namespace

- Execute the *kubectl create* command to create the namespace (as the admin user):

  ```bash
  kubectl create namespace office
  ```

## Step 2: Create the user credentials

As previously mentioned, Kubernetes does not have API Objects for User Accounts. Of the available ways to manage authentication (see [Kubernetes official documentation](https://kubernetes.io/docs/admin/authentication) for a complete list), we will use OpenSSL certificates for their simplicity. The necessary steps are:

- Create a private key for your user. In this example, we will name the file *employee.key*:

  ```bash
  openssl genrsa -out employee.key 2048
  ```

- Create a certificate sign request *employee.csr* using the private key you just created (*employee.key* in this example). Make sure you specify your username and group in the *-subj* section (CN is for the username and O for the group). As previously mentioned, we will use *employee* as the name and *bitnami* as the group:

  ```bash
  openssl req -new -key employee.key -out employee.csr -subj "/CN=employee/O=bitnami"
  ```

- Locate your Kubernetes cluster certificate authority (CA). This will be responsible for approving the request and generating the necessary certificate to access the cluster API. Its location is normally */etc/kubernetes/pki/*. In the case of Minikube, it would be *~/.minikube/*. Check that the files *ca.crt* and *ca.key* exist in the location.

- Generate the final certificate *employee.crt* by approving the certificate sign request, *employee.csr*, you made earlier. Make sure you substitute the CA_LOCATION placeholder with the location of your cluster CA. In this example, the certificate will be valid for 500 days:

  ```bash
  openssl x509 -req -in employee.csr -CA CA_LOCATION/ca.crt -CAkey CA_LOCATION/ca.key -CAcreateserial -out employee.crt -days 500
  ```

- Save both *employee.crt* and *employee.key* in a safe location (in this example we will use */home/employee/.certs/*).

- Add a new context with the new credentials for your Kubernetes cluster. This example is for a Minikube cluster but it should be similar for [others](https://kubernetes.io/docs/setup/pick-right-solution/):

  ```bash
  kubectl config set-credentials employee --client-certificate=/home/employee/.certs/employee.crt  --client-key=/home/employee/.certs/employee.key
  kubectl config set-context employee-context --cluster=minikube --namespace=office --user=employee
  ```

  Now you should get an access denied error when using the *kubectl* CLI with this configuration file. This is expected as we have not defined any permitted operations for this user.

  ```bash
  kubectl --context=employee-context get pods
  ```

## Step 3: Create the role for managing deployments

- Create a *role-deployment-manager.yaml* file with the content below. In this *yaml* file we are creating the rule that allows a user to execute several operations on Deployments, Pods and ReplicaSets (necessary for creating a Deployment), which belong to the *core* (expressed by "" in the *yaml* file), *apps*, and *extensions* API Groups:

  ```dts
  kind: Role
  apiVersion: rbac.authorization.k8s.io/v1beta1
  metadata:
    namespace: office
    name: deployment-manager
  rules:
  - apiGroups: ["", "extensions", "apps"]
    resources: ["deployments", "replicasets", "pods"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"] # You can also use ["*"]
  ```

- Create the Role in the cluster using the *kubectl create role* command:

  ```bash
  kubectl create -f role-deployment-manager.yaml
  ```

## Step 4: Bind the role to the employee user

- Create a *rolebinding-deployment-manager.yaml* file with the content below. In this file, we are binding the *deployment-manager* Role to the User Account *employee* inside the *office* namespace:

  ```less
  kind: RoleBinding
  apiVersion: rbac.authorization.k8s.io/v1beta1
  metadata:
    name: deployment-manager-binding
    namespace: office
  subjects:
  - kind: User
    name: employee
    apiGroup: ""
  roleRef:
    kind: Role
    name: deployment-manager
    apiGroup: ""
  ```

- Deploy the RoleBinding by running the *kubectl create* command:

  ```bash
  kubectl create -f rolebinding-deployment-manager.yaml
  ```

## Step 5: Test the RBAC rule

Now you should be able to execute the following commands without any issues:

~~~routeros
```bash
kubectl --context=employee-context run --image bitnami/dokuwiki mydokuwiki
kubectl --context=employee-context get pods
```
~~~

If you run the same command with the *--namespace=default* argument, it will fail, as the *employee* user does not have access to this namespace.

~~~routeros
```bash
kubectl --context=employee-context get pods --namespace=default
```
~~~

Now you have created a user with limited permissions in your cluster.

# Use case 2: Enable Helm in your cluster

 **Tip**

This section assumes that you have Helm v2.x installed in your cluster. Helm v3.x no longer requires Tiller. Check [this link](https://docs.bitnami.com/kubernetes/get-started-kubernetes/#step-4-install-helm) for instructions.

Helm v2.x comprises of two parts: a client and a server (Tiller) inside the kube-system namespace. Tiller runs inside your Kubernetes cluster, and manages releases (installations) of your charts. To be able to do this, Tiller needs access to the Kubernetes API. By default, RBAC policies will not allow Tiller to carry out these operations, so we need to do the following:

- Create a Service Account *tiller* for the Tiller server (in the kube-system namespace). As we mentioned before, Service Accounts are meant for intra-cluster processes running in Pods.
- Bind the *cluster-admin* ClusterRole to this Service Account. We will use ClusterRoleBindings as we want it to be applicable in all namespaces. The reason is that we want Tiller to manage resources in all namespaces.
- Update the existing Tiller deployment (*tiller-deploy*) to associate its pod with the Service Account *tiller*.

The *cluster-admin* ClusterRole exists by default in your Kubernetes cluster, and allows superuser operations in all of the cluster resources. The reason for binding this role is because with Helm charts, you can have deployments consisting of a wide variety of Kubernetes resources. For instance:

- [Pods](https://kubernetes.io/docs/concepts/workloads/pods/pod/)
- [PersistentVolumes](https://kubernetes.io/docs/concepts/storage/volumes/)
- [ConfigMaps](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/)
- [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Namespaces](https://kubernetes.io/docs/user-guide/namespaces/)
- [Replicasets](https://kubernetes.io/docs/user-guide/replicasets/)
- [Roles](https://kubernetes.io/docs/admin/authorization/rbac/#role-and-clusterrole)
- [RoleBindings](https://kubernetes.io/docs/admin/authorization/rbac/#rolebinding-and-clusterrolebinding)

So to make Helm compatible with any existing chart, binding the *cluster-admin* to the *tiller* Service Account is the best option. However, if you plan to use a very specific type of Helm chart (for example, one that only creates [ConfigMaps](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/), [Pods](https://kubernetes.io/docs/concepts/workloads/pods/pod/), [PersistentVolumes](https://kubernetes.io/docs/concepts/storage/volumes/) and [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)), you could create more restrictive RBAC rules.

## Step 1: Create the Tiller service account

- Create a *tiller-serviceaccount.yaml* file using *kubectl*:

  ```bash
  kubectl create serviceaccount tiller --namespace kube-system
  ```

## Step 2: Bind the Tiller service account to the *cluster-admin* role

- Create a *tiller-clusterrolebinding.yaml* file with the following contents:

  ```less
  kind: ClusterRoleBinding
  apiVersion: rbac.authorization.k8s.io/v1beta1
  metadata:
    name: tiller-clusterrolebinding
  subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system
  roleRef:
    kind: ClusterRole
    name: cluster-admin
    apiGroup: ""
  ```

- Deploy the ClusterRoleBinding:

  ```bash
  kubectl create -f tiller-clusterrolebinding.yaml
  ```

## Step 3: Update the existing Tiller deployment

- Update the existing *tiller-deploy* deployment with the Service Account you created earlier:

  ```bash
  helm init --service-account tiller --upgrade
  ```

- Wait a few seconds for the Tiller server to be redeployed.

## Step 4: Test the new Helm RBAC rules

- All being well, you should be able to execute this command without errors:

  ```bash
  helm ls
  ```

And that's it! You have configured Helm RBAC rules in your Kubernetes cluster.

# Useful links

Now you are able to perform basic RBAC operations in your Kubernetes cluster. If you want to know more about RBAC and user authorization in Kubernetes, take a look at the following links:

- [Official Kubernetes documentation for RBAC](https://kubernetes.io/docs/admin/authorization/rbac/)
- [Google Container Engine documentation for RBAC](https://cloud.google.com/container-engine/docs/role-based-access-control)
- [Official Kubernetes documentation for Authorization](https://kubernetes.io/docs/admin/authentication/)