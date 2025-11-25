---
title: 'Multi-Container Pod Design Patterns'
date: 2025-11-24T14:15:26+10:00
draft: false
weight: 10
tags: ["kubernetes", "pod", "containers"]
---

**Auteur:** Fabrice JAMMES ([LinkedIn](https://www.linkedin.com/in/fabrice-jammes-5b29b042/)).
**Date:** Nov 24, 2025 · 10 min read

## Quick Exercise: Fix the Bugs! 🐛

### Objective

Create a pod with an init container and a sidecar - **There are 2 bugs to fix!**

### Scenario
- **Init container**: generates an `index.html` with system info
- **Main container**: nginx 1.25.3 web server
- **Sidecar**: counts requests in access logs every 10 seconds

### Task
Deploy the following pod and fix the errors:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: webapp-demo
spec:
  initContainers:
  - name: setup-content
    image: busybox:1.37.0
    command:
    - sh
    - -c
    - |
      echo "Creating /web/index.html"
      echo "<h1>Welcome!</h1>" > /web/index.html
      echo "<p>Pod: $HOSTNAME</p>" >> /web/index.html
      echo "<p>Generated at: $(date)</p>" >> /web/index.html
    volumeMounts:
    - name: html-content
      mountPath: /web

  containers:
  - name: nginx
    image: nginx:1.25.3
    ports:
    - containerPort: 80
    volumeMounts:
    - name: web-content
      mountPath: /usr/share/nginx/html
    - name: logs
      mountPath: /var/log/nginx

  - name: request-counter
    image: busybox:1.37.0
    command:
    - sh
    - -c
    - |
      while true; do
        echo "=== $(date) ==="
        echo "Total requests: $(wc -l < /logs/access.log 2>/dev/null || echo 0)"
        sleep 10
      done
    volumeMounts:
    - name: nginx-logs
      mountPath: /logs

  volumes:
  - name: web-content
    emptyDir: {}
  - name: logs
    emptyDir: {}
```

### Questions

1. **Find the 2 bugs** (hint: check volume names carefully!)
2. What happens when you try to deploy this pod?
3. How do you debug init container failures?
4. Once fixed, how can you verify:
   - The init container completed successfully?
   - The nginx server is running?
   - The sidecar is counting requests?

### Debugging Commands

```bash
# Deploy the pod
kubectl apply -f webapp-demo.yaml

# Check pod status
kubectl get pod webapp-demo
```

{{%expand "Troubleshooting" %}}

```bash
# Check init container logs
kubectl logs webapp-demo -c setup-content

# Check nginx logs
kubectl logs webapp-demo -c nginx

# Check sidecar logs
kubectl logs webapp-demo -c request-counter

# Describe the pod to see events
kubectl describe pod webapp-demo

# Port-forward to test nginx (once fixed)
kubectl port-forward webapp-demo 808<ID>:80

# Test the web server
curl localhost:808<ID>
```

{{% /expand%}}

### Expected Behavior (After Fix)

1. Init container runs first and creates `/web/index.html`
2. Nginx starts and serves the HTML file
3. Sidecar continuously counts requests every 10 seconds
4. All containers share volumes properly

---

{{%expand "Solution" %}}

### Bugs Found

1. **Init container bug**: Uses volume name `html-content` but the volume is defined as `web-content`
2. **Sidecar bug**: Uses volume name `nginx-logs` but the volume is defined as `logs`

### Corrected YAML

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: webapp-demo
spec:
  initContainers:
  - name: setup-content
    image: busybox:1.37.0
    command:
    - sh
    - -c
    - |
      echo "Creating /web/index.html"
      echo "<h1>Welcome!</h1>" > /web/index.html
      echo "<p>Pod: $HOSTNAME</p>" >> /web/index.html
      echo "<p>Generated at: $(date)</p>" >> /web/index.html
    volumeMounts:
    - name: web-content          # ✅ Fixed: was html-content
      mountPath: /web

  containers:
  - name: nginx
    image: nginx:1.25.3
    ports:
    - containerPort: 80
    volumeMounts:
    - name: web-content
      mountPath: /usr/share/nginx/html
    - name: logs
      mountPath: /var/log/nginx

  - name: request-counter
    image: busybox:1.37.0
    command:
    - sh
    - -c
    - |
      while true; do
        echo "=== $(date) ==="
        echo "Total requests: $(wc -l < /logs/access.log 2>/dev/null || echo 0)"
        sleep 10
      done
    volumeMounts:
    - name: logs                 # ✅ Fixed: was nginx-logs
      mountPath: /logs

  volumes:
  - name: web-content
    emptyDir: {}
  - name: logs
    emptyDir: {}
```

{{% /expand%}}

### Key Learning Points

- Volume names must match exactly between `volumeMounts` and `volumes` definitions
- Init containers must complete before main containers start
- Multiple containers in a pod share the same volumes
- Use `kubectl describe pod` to identify volume mount errors
- Init container failures prevent the pod from starting
