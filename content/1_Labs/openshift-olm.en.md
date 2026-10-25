---
title: 'Operators with OLM: the Grafana Operator'
date: 2026-10-25T09:30:00+10:00
draft: false
weight: 157
tags: ["OpenShift", "Operator", "OLM", "OperatorHub", "Grafana"]
---

**Author:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).
**Duration:** 15 minutes of demo, 30-40 minutes of lab

## Objective

On OpenShift, operators are installed and upgraded by the **Operator Lifecycle Manager** (OLM), from the catalogs displayed in the web console. This page has two parts:
1. **Demo, by the trainer**: install the Grafana Operator from the web console, in **All namespaces** mode.
2. **Lab, by the trainees**: find the objects OLM created (`Subscription`, `InstallPlan`, `ClusterServiceVersion`, `OperatorGroup`), create Grafana instances in their own namespace, and check that the operator keeps reconciling them.

Both parts run on the OpenShift cluster shared by all trainees: switch to it first with `kubectx <my-openshift-context>`.

{{% notice note %}}
An operator owns cluster-wide objects (its CRDs) and OLM runs a single copy of it per cluster: on a shared cluster, only the trainer installs, upgrades or uninstalls it. Trainees only create custom resources in their own namespace.
{{% /notice %}}

## Part 1 — Demo: install the Grafana Operator from the web console

Logged in to the web console as `kubeadmin`, in the **Administrator** perspective. Since OpenShift 4.20, the **Operators** menu is named **Ecosystem** and the OperatorHub is the **Software Catalog**; older versions use **Operators > OperatorHub**.

Keep a terminal open next to the console, to show the objects each click creates (`-w` only accepts a single resource type, hence `watch`):

```bash
watch -n 2 oc get subscription,installplan,csv -n openshift-operators
```

### 1. The catalogs

**Administration > Cluster Settings > Configuration > OperatorHub > Sources**: each catalog is a `CatalogSource`, a pod serving an index of operators.

```bash
oc get catalogsources -n openshift-marketplace
oc get pods -n openshift-marketplace
oc get packagemanifests -n openshift-marketplace | wc -l
```

Explain the four sources: **Red Hat** (supported by Red Hat), **Certified** (tested by Red Hat, supported by the vendor), **Community** (no support) and **Marketplace** (paid).

### 2. Find the operator

**Ecosystem > Software Catalog**, filter on the **Community** source and search for `Grafana`. Open the **Grafana Operator** card (the console warns that community operators are not supported by Red Hat) and show:
- the **capability level**, from *Basic Install* to *Auto Pilot*
- the **channels** (`v5`) and the available versions
- the **provided APIs**: `Grafana`, `GrafanaDashboard`, `GrafanaDatasource`...

The same information is available from the CLI:

```bash
oc get packagemanifest grafana-operator -n openshift-marketplace \
  -o jsonpath='{range .status.channels[*]}{.name}{" "}{.currentCSV}{"\n"}{end}'
```

### 3. Install it

Click **Install** and fill in the form:
- **Update channel**: `v5`
- **Installation mode**: **All namespaces on the cluster**, the operator goes to `openshift-operators` and watches every namespace. Point out that the operator lists the supported modes: some operators can only watch their own namespace.
- **Update approval**: **Manual**, so that every new version waits for an administrator

Click **Install**. The terminal shows a `Subscription`, then an `InstallPlan` with `APPROVED false`: nothing is installed yet.

### 4. Approve the InstallPlan

The console displays **Manual approval required**: click **Review manual InstallPlan**. The InstallPlan lists everything OLM is about to create: the CRDs, the ServiceAccount, the ClusterRoles and the operator Deployment. Click **Approve**.

The CSV goes through `Pending`, `InstallReady`, `Installing`, then `Succeeded`.

### 5. Tour of the installed operator

**Ecosystem > Installed Operators > Grafana Operator**:
- **Details**: the status of the CSV, the provided APIs
- **YAML**: the `ClusterServiceVersion`, which holds the operator Deployment, the owned CRDs and the RBAC it needs
- **Subscription**: the channel, the approval mode, the installed version; this is where an upgrade is approved, or the approval mode changed
- **Events**

Then **Workloads > Pods**, project `openshift-operators`: the operator is a plain pod. Finally switch to any other project: **Installed Operators** also lists the Grafana Operator there, because OLM copies the CSV in every namespace in **All namespaces** mode.

### 6. The same installation from the CLI

```bash
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: grafana-operator
  namespace: openshift-operators
spec:
  channel: v5
  name: grafana-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Manual
EOF

# Approve the pending InstallPlan
IP=$(oc get subscription grafana-operator -n openshift-operators -o jsonpath='{.status.installPlanRef.name}')
oc patch installplan "$IP" -n openshift-operators --type merge -p '{"spec":{"approved":true}}'
```

### 7. Uninstall, at the end of the training

**Installed Operators > Grafana Operator > Actions > Uninstall Operator**. It removes the `Subscription` and the CSV, so the operator Deployment goes away, but OLM keeps the CRDs and the custom resources of every namespace. Remove the CRDs explicitly:

```bash
oc get crd -o name | grep grafana.integreatly.org | xargs -r oc delete
```

The solutions are validated by [`ex1-olm-grafana.sh`](https://github.com/k8s-school/openshift-advanced/blob/main/labs/7_operators/ex1-olm-grafana.sh): `-s` installs the operator, `-c` uninstalls it and removes its CRDs.

## Part 2 — Lab

{{% notice tip %}}
The Grafana Operator has been installed by the trainer in Part 1. Do not install, upgrade or uninstall it.
{{% /notice %}}

### Setup

```bash
NS="grafana-$USER"
oc new-project "$NS"
```

### Exercise 1 — The objects created by OLM

1. Which `Subscription` installed the Grafana Operator, from which catalog and which channel? Is the upgrade approval automatic or manual?

{{%expand "Answer" %}}
```bash
oc get subscription -n openshift-operators
oc get subscription grafana-operator -n openshift-operators -o yaml
```

`spec.source` is the catalog (`community-operators`, a `CatalogSource` of the `openshift-marketplace` namespace), `spec.channel` the update channel and `spec.installPlanApproval` the approval mode. With `Manual`, every new version waits in an `InstallPlan` until an administrator approves it.

```bash
oc get catalogsources -n openshift-marketplace
oc get installplan -n openshift-operators
```
{{% /expand%}}

2. Which version of the operator is installed? Which CRDs does it own?

{{%expand "Answer" %}}
The `ClusterServiceVersion` (CSV) describes one version of the operator: its Deployment, the CRDs it owns and the RBAC it needs.

```bash
oc get csv -n openshift-operators
CSV=$(oc get subscription grafana-operator -n openshift-operators -o jsonpath='{.status.installedCSV}')
oc get csv "$CSV" -n openshift-operators \
  -o jsonpath='{range .spec.customresourcedefinitions.owned[*]}{.kind}{" "}{.name}{"\n"}{end}'
oc get crd | grep grafana.integreatly.org
```
{{% /expand%}}

3. Where does the operator run? Which namespaces does it watch?

{{%expand "Answer" %}}
```bash
oc get deployments,pods -n openshift-operators
oc get operatorgroup -n openshift-operators -o yaml
```

The operator is a plain Deployment in `openshift-operators`. The `global-operators` `OperatorGroup` has no `targetNamespaces`: operators installed in this namespace watch **all namespaces**.
{{% /expand%}}

4. Run `oc get csv` in your own namespace. Why does the Grafana Operator CSV appear there?

{{%expand "Answer" %}}
```bash
oc get csv -n "$NS"
oc get csv "$CSV" -n "$NS" -o jsonpath='{.status.reason}{"\n"}'
```

In `AllNamespaces` mode, OLM copies the CSV in every namespace (reason `Copied`): this tells the users of a namespace which operators, and which APIs, are available to them. The console uses it to display **Installed Operators** in each project.

OLM also creates `admin`, `edit`, `view` and `crdview` ClusterRoles for each CRD, aggregated into the standard roles: a project administrator can create Grafana instances without any extra RBAC.

```bash
oc get clusterroles | grep grafanas.grafana.integreatly.org
```
{{% /expand%}}

### Exercise 2 — Create a Grafana instance

Create a `Grafana` custom resource in your namespace, either from the console (**Operators > Installed Operators > Grafana Operator > Grafana > Create Grafana**, check the YAML view) or with:

```bash
cat <<EOF | oc apply -n "$NS" -f -
apiVersion: grafana.integreatly.org/v1beta1
kind: Grafana
metadata:
  name: grafana
  labels:
    dashboards: grafana
spec:
  config:
    log:
      mode: console
  route:
    spec: {}
EOF
```

1. Watch the status of the instance. Which objects did the operator create?

{{%expand "Answer" %}}
```bash
oc get grafana grafana -n "$NS" -w
oc get deployment,service,route,configmap,secret,serviceaccount -n "$NS"
oc get deployment grafana-deployment -n "$NS" \
  -o jsonpath='{.metadata.ownerReferences[*].kind}{"/"}{.metadata.ownerReferences[*].name}{"\n"}'
```

The `STAGE STATUS` column first shows `failed`: the operator cannot reach Grafana until its pod is running, and retries. It turns to `success` once Grafana answers.

From a few lines of YAML, the operator created a Deployment, two Services, a Route with edge TLS termination, ConfigMaps holding `grafana.ini` and the plugins list, a ServiceAccount and a Secret with the admin credentials. They are all owned by the `Grafana` resource: deleting it deletes them.
{{% /expand%}}

2. Retrieve the admin credentials and the URL of Grafana, then log in.

{{%expand "Answer" %}}
```bash
oc get secret grafana-admin-credentials -n "$NS" -o jsonpath='{.data.GF_SECURITY_ADMIN_USER}' | base64 -d; echo
oc get secret grafana-admin-credentials -n "$NS" -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 -d; echo
oc get route grafana-route -n "$NS" -o jsonpath='{.spec.host}{"\n"}'
```

Open `https://<host>` in a browser, or check from the command line:

```bash
curl -sk "https://$(oc get route grafana-route -n "$NS" -o jsonpath='{.spec.host}')/api/health"
```
{{% /expand%}}

### Exercise 3 — Reconciliation

Delete the Grafana Deployment, then watch the Deployments of your namespace. What happens, and why?

{{%expand "Answer" %}}
```bash
oc delete deployment grafana-deployment -n "$NS"
oc get deployments -n "$NS" -w
```

The operator recreates the Deployment within seconds: it continuously compares the objects it owns with the desired state described in the `Grafana` resource, and fixes any drift. To change Grafana, edit the custom resource, not the objects generated from it.
{{% /expand%}}

### Exercise 4 — Datasource and dashboard as code

Create a datasource and a dashboard for your instance:

```bash
cat <<EOF | oc apply -n "$NS" -f -
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDatasource
metadata:
  name: testdata
spec:
  instanceSelector:
    matchLabels:
      dashboards: grafana
  datasource:
    name: TestData
    type: grafana-testdata-datasource
    access: proxy
    isDefault: true
---
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: hello
spec:
  instanceSelector:
    matchLabels:
      dashboards: grafana
  json: |
    {
      "title": "Hello $USER",
      "panels": [
        {
          "type": "timeseries",
          "title": "Random walk",
          "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
          "targets": [{"refId": "A", "scenarioId": "random_walk"}]
        }
      ]
    }
EOF
```

1. Check that the dashboard appears in your Grafana. How does the operator know which Grafana instance should receive it?

{{%expand "Answer" %}}
```bash
oc get grafanadatasources,grafanadashboards -n "$NS"
```

Open **Dashboards** in Grafana, or:

```bash
HOST=$(oc get route grafana-route -n "$NS" -o jsonpath='{.spec.host}')
GF_USER=$(oc get secret grafana-admin-credentials -n "$NS" -o jsonpath='{.data.GF_SECURITY_ADMIN_USER}' | base64 -d)
GF_PASS=$(oc get secret grafana-admin-credentials -n "$NS" -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 -d)
curl -sk -u "$GF_USER:$GF_PASS" "https://$HOST/api/search?type=dash-db"
```

The `instanceSelector` matches the labels of the `Grafana` resource (`dashboards: grafana`). By default it only selects instances of the **same namespace**: the other trainees use the same label, but your dashboard does not reach their Grafana (unless `spec.allowCrossNamespaceImport: true`).
{{% /expand%}}

### Exercise 5 — Uninstalling an operator

Do not run it: what would happen to your Grafana instance if the trainer uninstalled the Grafana Operator from the console?

{{%expand "Answer" %}}
Uninstalling an operator deletes its `Subscription` and its CSV, so the operator Deployment goes away. OLM does **not** delete the CRDs, nor the custom resources: your `Grafana` resource and the Grafana Deployment keep running, but nothing reconciles them any more (a deleted Deployment would not come back, a new dashboard would never be loaded).

Removing the CRDs is a separate, explicit step, and it deletes every custom resource of that type in **all namespaces**. This is why, on a shared cluster, operators are managed by the cluster administrators only.
{{% /expand%}}

### Cleanup

```bash
oc delete project "$NS"
```
