---
title: 'OpenShift MachineSets and availability zones'
date: 2026-10-21T08:00:00+02:00
draft: false
weight: 155
tags: ["OpenShift", "MachineSet", "Machine API", "Azure", "availability zones"]
---

## Objective

On an OpenShift cluster installed with IPI (installer-provisioned infrastructure), the Machine API manages the nodes like pods: a `MachineSet` keeps a number of `Machine`s, and each `Machine` is a cloud VM which becomes a `Node`. In this lab you will:

- Find the MachineSets created by the installer, one per availability zone
- Create your own MachineSet in a given zone, and scale it up
- Follow a Machine from the VM creation to the Node, and schedule a pod on it
- Understand how a MachineSet selects its Machines, with a classic mistake

Complete this lab in 60 minutes: creating an Azure VM takes 5 to 10 minutes.

## Prerequisites

- The shared OpenShift IPI cluster on Azure, logged in with `oc` as cluster-admin
- The slides `OPENSHIFT.pdf`, section *Machine API*
- The lab [Pod placement]({{% ref "/1_Labs/antiaffinity" %}})

{{% notice warning %}}
Every Machine is a VM billed by Azure. The cluster is shared: only create **your** MachineSet, never scale it above **1** replica, never modify the MachineSets of the installer, and scale your MachineSet to 0 at the end of the lab.
{{% /notice %}}

## Setup

```bash
ID=$(whoami)
# Availability zone given by the trainer: 1, 2 or 3
ZONE=1
NS=machineset-$ID
oc new-project $NS

MAPI=openshift-machine-api
INFRA_ID=$(oc get infrastructure cluster -o jsonpath='{.status.infrastructureName}')
echo $INFRA_ID
```

`INFRA_ID` is the cluster name plus a random suffix: the installer prefixes all the cloud resources with it (VMs, disks, network, resource group).

## Exercise 1: explore the Machine API

1. List the MachineSets, the Machines and the Nodes. How are they linked?
2. In which zone is each MachineSet? Which fields of the MachineSet are specific to Azure?

{{%expand "Solution" %}}
```bash
oc get machinesets -n $MAPI
oc get machines -n $MAPI -o wide
oc get nodes -L topology.kubernetes.io/zone,node.kubernetes.io/instance-type
```

1. The installer creates one MachineSet per zone for the workers, named `<infra_id>-worker-<region><zone>`. The control plane nodes are Machines too, without MachineSet (or managed by a `ControlPlaneMachineSet`). Each Machine has a `NODE` column: the Node created by the VM when it joins the cluster.
2. The cloud specific part is `spec.template.spec.providerSpec.value`:

```bash
# Installer MachineSets only: the ones created by the trainees carry the label training/trainee
SOURCE=$(oc get machinesets -n $MAPI -l '!training/trainee' -o name | head -1)
oc get $SOURCE -n $MAPI -o jsonpath='{.spec.template.spec.providerSpec.value}' | jq '{kind, location, zone, vmSize, image, subnet}'
```

- `kind`: `AzureMachineProviderSpec`, the format of the `providerSpec` depends on the cloud provider
- `location`: the Azure region
- `zone`: the availability zone
- `vmSize`: the VM type, which sets the CPU and memory of the node
- `image`: the RHCOS image of the VM. `image.resourceID` points to the image the installer uploaded to an Azure Compute Gallery, in the cluster resource group (`/resourceGroups/<infra_id>-rg/providers/Microsoft.Compute/galleries/...`). A Marketplace image is given by `publisher`, `offer`, `sku` and `version` instead, with an empty `resourceID`
- `subnet`: the subnet of the cluster network the VM NIC is attached to (`<infra_id>-worker-subnet`)

A MachineSet is bound to **one** zone: to spread nodes across zones, use one MachineSet per zone.

{{% /expand%}}

3. Which operators and controllers run the Machine API? Which component initializes the Nodes and talks to Azure for them? Look at the namespaces `openshift-machine-api` and `openshift-cloud-controller-manager`.

{{%expand "Solution" %}}
The `machine-api-controllers` pod in `openshift-machine-api` runs the controllers, one per container:
- `machineset-controller` creates and deletes the Machines to match the replicas of each MachineSet
- `machine-controller` calls the Azure API to create and delete the VMs
- `nodelink-controller` links each Machine to its Node

```bash
# The machine-api-operator deploys machine-api-controllers
oc get clusteroperator machine-api
oc get deployments,pods -n $MAPI
oc get deployment machine-api-controllers -n $MAPI \
  -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{"\n"}{end}'

# Logs of each controller
oc logs -n $MAPI deployment/machine-api-controllers -c machineset-controller --tail=20
oc logs -n $MAPI deployment/machine-api-controllers -c machine-controller --tail=20
oc logs -n $MAPI deployment/machine-api-controllers -c nodelink-controller --tail=20

# The link set by nodelink-controller: status.nodeRef on the Machine, an annotation on the Node
oc get machines -n $MAPI -o custom-columns=MACHINE:.metadata.name,NODE:.status.nodeRef.name
oc get nodes -o custom-columns=NODE:.metadata.name,MACHINE:'.metadata.annotations.machine\.openshift\.io/machine'
```

The **cloud controller manager** (CCM) is the other component that talks to the Azure API. Where the Machine API creates the VMs, the CCM takes care of the Nodes and of the Azure load balancers:
- `azure-cloud-controller-manager` (Deployment): when a Node joins, it sets its `providerID`, its addresses, the labels `topology.kubernetes.io/zone` and `node.kubernetes.io/instance-type`, then removes the `node.cloudprovider.kubernetes.io/uninitialized` taint. It deletes the Node when its VM is gone, and creates an Azure load balancer for each Service of type `LoadBalancer`
- `azure-cloud-node-manager` (DaemonSet): the part of node initialization that runs on each node

```bash
oc get clusteroperator cloud-controller-manager
oc get pods -n openshift-cloud-controller-manager-operator
oc get deployments,daemonsets,pods -n openshift-cloud-controller-manager -o wide

# Fields set by the CCM on the Nodes
oc get nodes -o custom-columns=NODE:.metadata.name,PROVIDER_ID:.spec.providerID,ZONE:'.metadata.labels.topology\.kubernetes\.io/zone'
```

The pattern is the same everywhere in OpenShift: a **ClusterOperator** (`machine-api`, `cloud-controller-manager`) deploys and configures **controllers**, which reconcile Kubernetes objects (Machines, Nodes, Services) with the real world (Azure VMs, load balancers).
{{% /expand%}}

## Exercise 2: create your MachineSet

Create a MachineSet `$INFRA_ID-worker-$ID-$ZONE`, copied from a worker MachineSet of the installer, with:

- `0` replicas
- the zone `$ZONE`
- the label `training/trainee=$ID` on the MachineSet and on its nodes

{{%expand "Solution" %}}
Copy an existing MachineSet: it already has the right image, network, identity and credentials. Keep only the name, namespace and labels of its `metadata` (this drops the fields managed by the API server: `uid`, `resourceVersion`, `managedFields`...), then change the replicas, the selector, the zone and the node labels:

```bash
NEW=$INFRA_ID-worker-$ID-$ZONE
oc get $SOURCE -n $MAPI -o json | jq --arg n "$NEW" --arg z "$ZONE" --arg id "$ID" '
  .metadata = {name: $n, namespace: .metadata.namespace, labels: (.metadata.labels + {"training/trainee": $id})}
  | del(.status)
  | .spec.replicas = 0
  | .spec.selector.matchLabels["machine.openshift.io/cluster-api-machineset"] = $n
  | .spec.template.metadata.labels["machine.openshift.io/cluster-api-machineset"] = $n
  | .spec.template.spec.providerSpec.value.zone = $z
  | .spec.template.spec.metadata.labels["training/trainee"] = $id' | oc apply -f -
oc get machineset $NEW -n $MAPI
```

- `spec.selector` and `spec.template.metadata.labels` must match: the MachineSet owns the Machines with the label `machine.openshift.io/cluster-api-machineset=<name>`. Forgetting to change it in both places makes your MachineSet fight with the source one.
- `spec.template.spec.metadata.labels` are the labels of the **Node**, not of the Machine.
- The `training/trainee` label on the MachineSet itself tells the trainees' MachineSets from the installer ones: `oc get machinesets -n $MAPI -l training/trainee`.
- The admission webhook of the Machine API validates the `providerSpec`: a wrong field is rejected at creation time, before any VM is created.
{{% /expand%}}

## Exercise 3: scale up and follow the Machine

Scale your MachineSet to 1, and follow the Machine until its Node is `Ready`. Which phases does the Machine go through?

{{%expand "Solution" %}}
```bash
oc scale machineset $NEW -n $MAPI --replicas=1
oc get machines -n $MAPI -l machine.openshift.io/cluster-api-machineset=$NEW -w
```

The Machine goes through the phases `Provisioning` (the Azure VM is being created), `Provisioned` (the VM exists, it boots and asks to join the cluster), then `Running` (the Node is linked). In another terminal:

```bash
# The VM boots with the ignition config of the worker-user-data Secret,
# then its kubelet asks for a certificate, approved automatically by the cluster
oc get csr -w
oc get nodes -l training/trainee=$ID -L topology.kubernetes.io/zone -w
```

If the Machine stays in `Provisioning` or goes to `Failed`, read its status and the controller logs:

```bash
MACHINE=$(oc get machines -n $MAPI -l machine.openshift.io/cluster-api-machineset=$NEW -o name)
oc get $MACHINE -n $MAPI -o jsonpath='{.status.errorMessage}{"\n"}'
oc logs -n $MAPI deployment/machine-api-controllers -c machine-controller | grep $ID
```

A quota error (`OperationNotAllowed`, `QuotaExceeded`) means the Azure subscription has no vCPU left in this region: the cluster is shared, scale to 0 and ask the trainer.
{{% /expand%}}

## Exercise 4: run a pod on your node

Deploy `nginxinc/nginx-unprivileged:1.27-alpine` with 2 replicas in the namespace `$NS`, only on your node. Then check the zone of the pods.

{{%expand "Solution" %}}
```bash
oc create deployment web --image=nginxinc/nginx-unprivileged:1.27-alpine --replicas=2
oc patch deployment web -p "{\"spec\":{\"template\":{\"spec\":{\"nodeSelector\":{\"training/trainee\":\"$ID\"}}}}}"
oc rollout status deployment web
oc get pods -o wide
oc get node -l training/trainee=$ID -L topology.kubernetes.io/zone
```

The node labels come from the MachineSet: every node created by it gets them, so `nodeSelector` and affinities keep working when the MachineSet replaces a node. The label `topology.kubernetes.io/zone` is set by the cloud provider: use it in `topologySpreadConstraints` to spread an application across zones.

A MachineSet can also set taints on its nodes (`spec.template.spec.taints`), for example to dedicate nodes to the infrastructure components (router, registry, monitoring): see *Creating infrastructure machine sets* in the OpenShift documentation.
{{% /expand%}}

## Exercise 5: a Machine without its MachineSet

A colleague wants one more node quickly. They copy your Machine to a new one with a different name, and apply it. What happens? Explain.

{{%expand "Solution" %}}
```bash
oc get $MACHINE -n $MAPI -o json | jq --arg n "$NEW-copy" '
  del(.metadata.uid, .metadata.resourceVersion, .metadata.creationTimestamp, .metadata.generation,
      .metadata.managedFields, .metadata.generateName, .metadata.ownerReferences, .spec.providerID, .status)
  | .metadata.name = $n' | oc apply -f -
oc get machines -n $MAPI -l machine.openshift.io/cluster-api-machineset=$NEW
oc logs -n $MAPI deployment/machine-api-controllers -c machineset-controller | grep $NEW
# controller.go:302] Too many replicas for machine.openshift.io/v1beta1, Kind=MachineSet openshift-machine-api/<name>, need 1, deleting 1
```

The copy keeps the label `machine.openshift.io/cluster-api-machineset`: it matches the selector of your MachineSet, which now sees 2 Machines for 1 replica, and deletes one of them. With the default `spec.deletePolicy: Random`, it can delete the new Machine **or the one running your pods**.

This is the same reconciliation loop as a ReplicaSet with its pods. To add a node, scale the MachineSet: it is the only owner of its Machines.

Check that your MachineSet is back to 1 running Machine before going on.
{{% /expand%}}

## Clean up

```bash
oc delete project $NS
oc scale machineset $NEW -n $MAPI --replicas=0
oc get machines -n $MAPI -l machine.openshift.io/cluster-api-machineset=$NEW -w
# Once no Machine is left
oc delete machineset $NEW -n $MAPI
```

Scaling down drains the node first: its pods are evicted, then the VM is deleted.

## Going further

- Autoscaling: a `ClusterAutoscaler` (one per cluster) and a `MachineAutoscaler` per MachineSet scale the MachineSets when pods are `Pending` for lack of resources (trainer demo)
- `MachineHealthCheck`: replace automatically the Machines whose Node is `NotReady`
- The OpenShift documentation: *Machine management*, *Creating a compute machine set on Azure*
