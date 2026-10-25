---
marp: true
theme: custom-theme
paginate: true
backgroundColor: #ffffff
---

# How to develop with Kubernetes

<img src="images/logo.svg" alt="K8s School Logo" width="50%">

Fabrice Jammes — https://k8s-school.fr

---

## Debug a running pod

Start from the pod, and go one step deeper each time:

```bash
kubectl get pod                # status: Pending, ImagePullBackOff, CrashLoopBackOff...
kubectl describe pod <pod>     # events: scheduling, image pull, probes
kubectl logs <pod> --previous  # logs of the container that crashed
kubectl exec -it <pod> -- sh   # inspect the running container
```

When the container crashes too fast to be inspected: remove the probes and start it with `sleep infinity`, then `kubectl exec` into it.

Reference: [Debug Running Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/)

---

## `kubectl debug`

| Command | Use case |
|---|---|
| `kubectl debug -it <pod> --image=busybox --target=<container>` | **Ephemeral container** in the running pod, sharing the process namespace of the target: for images without a shell |
| `kubectl debug <pod> -it --copy-to=<copy> --container=<c> -- sh` | **Copy of the pod**, with another command or image: for containers which crash at startup |
| `kubectl debug node/<node> -it --image=busybox` | **Shell on a node**, host filesystem in `/host` |

On OpenShift: `oc debug deployment/<name>` (copy of the pod with a shell) and `oc debug node/<node>` then `chroot /host`.

---

## The inner loop problem

Developing a microservice which talks to other services in the cluster:

- **Build, push, deploy at each change**: minutes per iteration
- **Run everything locally** (Docker Compose, minikube): heavy, and differs from the real cluster
- **Mocks**: the integration bugs show up late

**Telepresence**: run **one** service on the workstation, with the IDE and the debugger, connected to the **real** cluster.

---

## Telepresence

- Open source, [telepresence.io](https://telepresence.io), CNCF Sandbox project since 2018
- "A network bridge between your workstation and the Kubernetes cluster"
- Client: a single binary, plus two daemons on the workstation
  - **user daemon**: the cluster session
  - **root daemon**: the network (TUN device) and DNS of the workstation, needs `sudo`
  - or `telepresence connect --docker`: daemons in a container, no `sudo`, but only the containers started by Telepresence reach the cluster
- Cluster side: the **traffic-manager** (namespace `ambassador`), installed with `telepresence helm install`, injects a **traffic-agent** sidecar in the workloads it intercepts

---

## Architecture: path of an intercepted request

1. A client calls `verylargejavaservice`, which calls `dataprocessingservice`, **in the cluster**
2. The **traffic-agent**, a sidecar injected in the `dataprocessingservice` pod, receives the request on port 3000
3. It sends it to the **traffic-manager** (namespace `ambassador`)
4. The traffic-manager forwards it to the **workstation**, in a gRPC tunnel opened through the API server: no inbound port on the workstation
5. The Telepresence daemons hand it to `localhost:3000`: `dataprocessingservice` **runs from the IDE**
6. The answer goes back the same way

In the other direction, `telepresence connect` adds routes and a DNS resolver on the workstation: `curl http://verylargejavaservice.default:8080` reaches the cluster.

---

## Commands

| Command | Effect |
|---|---|
| `telepresence connect` | The workstation reaches the cluster: `curl http://<service>.<namespace>` |
| `telepresence intercept <workload> --port 3000` | The traffic of the service goes to `localhost:3000`, the pod keeps running for the other ports |
| `telepresence replace <workload>` | The container is replaced by the local process: all its traffic, environment and volumes |
| `telepresence ingest <workload>` | The local process gets the environment and volumes of the container, no traffic is redirected |
| `telepresence wiretap <service>` | A copy of the traffic is sent to the local process, read-only |
| `telepresence list`, `status`, `detach`, `quit -s` | List the workloads, show the session, end an intercept, stop the daemons |

---

## Workflow

```bash
telepresence helm install            # once per cluster
telepresence connect                 # sudo password for the root daemon
curl http://dataprocessingservice.default:3000/color    # "green", from the cluster

go build -o /tmp/dps . && /tmp/dps & # run the service locally
telepresence intercept dataprocessingservice --port 3000

# Edit the code (color = "purple"), rebuild, restart the local process
curl http://verylargejavaservice.default:8080          # the page is now purple

telepresence detach dataprocessingservice
telepresence quit -s
```

---

## Telepresence: demo

https://github.com/k8s-school/demo-telepresence

- Sample application [edgey-corp-go](https://github.com/datawire/edgey-corp-go): `verylargejavaservice` ▶ `dataprocessingservice` ▶ `verylargedatastore`
- Runs in GitHub Actions, on a kind cluster: the CI tests the service built by the workflow against the real cluster
- On a shared cluster: one traffic-manager per cluster, and every developer intercepts its own workloads, in its own namespace

---

# Questions?

Thanks!

@fjammes on GitHub — https://k8s-school.fr
