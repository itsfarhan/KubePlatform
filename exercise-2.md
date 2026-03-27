# Exercise 2 — Cloud-Native Application Challenges

> Based on **Chapter 2** of *Platform Engineering on Kubernetes* by Mauricio Salatino

---

## Objective

Deploy the Conference Application walking skeleton to a local Kubernetes cluster, inspect its internals, and intentionally break it to understand the real challenges of running cloud-native distributed applications.

---

## Step 1 — Choose Your Kubernetes Environment

Before anything, understand your options. The book covers three:

```
┌──────────────┬──────────────────────────────┬──────────────────────────────┐
│ Option       │ Pros                         │ Cons                         │
├──────────────┼──────────────────────────────┼──────────────────────────────┤
│ Local (KinD) │ Lightweight, fast to start,  │ Not a real cluster, limited  │
│              │ good for experiments         │ capacity, no real networking  │
├──────────────┼──────────────────────────────┼──────────────────────────────┤
│ On-Premises  │ Real hardware, closer to     │ Needs dedicated hardware and  │
│              │ production behavior          │ a mature ops team             │
├──────────────┼──────────────────────────────┼──────────────────────────────┤
│ Cloud (GKE,  │ Fully managed, pay-as-you-go,│ Costs money, possible vendor  │
│ EKS, AKS)   │ scales easily                │ lock-in, everything is remote │
└──────────────┴──────────────────────────────┴──────────────────────────────┘
```

For this exercise, we use **KinD (Kubernetes in Docker)** — local, free, and good enough for learning.

---

## Step 2 — Create the Local KinD Cluster

This creates a cluster with 1 control plane + 3 worker nodes. Port 80 is mapped so the app is accessible at `http://localhost`.

```bash
cat <<EOF | kind create cluster --name dev --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
- role: worker
EOF
```

**Cluster topology:**
```
┌─────────────────────────────────────────┐
│              KinD Cluster "dev"          │
│                                         │
│  ┌─────────────────┐                    │
│  │  control-plane  │ ◀── port 80/443    │
│  │  (ingress-ready)│    mapped to host  │
│  └─────────────────┘                    │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│  │ worker   │ │ worker   │ │ worker   │ │
│  └──────────┘ └──────────┘ └──────────┘ │
└─────────────────────────────────────────┘
```

---

## Step 3 — Install NGINX Ingress Controller

The Ingress Controller routes external traffic (from your browser) into services inside the cluster.

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

Wait for it to be ready:
```bash
kubectl get pods -n ingress-nginx
```

Expected output:
```
NAME                                        READY   STATUS      RESTARTS   AGE
ingress-nginx-admission-create-xxxxx        0/1     Completed   0          62s
ingress-nginx-admission-patch-xxxxx         0/1     Completed   0          62s
ingress-nginx-controller-xxxxxxxxxx-xxxxx   1/1     Running     0          62s
```

---

## Step 4 — Pre-load Container Images (Optional but Recommended)

Kafka (~335MB), PostgreSQL (~88MB), and Redis (~35MB) are heavy. Pre-loading saves 10+ minutes of wait time.

```bash
# From the platforms-on-k8s/chapter-2 directory
./kind-load.sh
```

---

## Step 5 — Install the Conference Application with Helm

Helm packages all Kubernetes resources (Deployments, Services, ConfigMaps, etc.) into a single installable chart.

```bash
helm install conference oci://docker.io/salaboy/conference-app --version v1.0.0
```

Monitor startup progress:
```bash
kubectl get pods -owide
```

Wait until all pods show `1/1 Running`. The `RESTARTS` column will show non-zero values — this is **normal**. Services like C4P depend on Redis being ready; Kubernetes restarts them until the dependency is up.

Expected final state:
```
NAME                                                    READY   STATUS    RESTARTS
conference-agenda-service-deployment-xxxx               1/1     Running   4
conference-c4p-service-deployment-xxxx                  1/1     Running   4
conference-frontend-deployment-xxxx                     1/1     Running   4
conference-kafka-0                                      1/1     Running   0
conference-notifications-service-deployment-xxxx        1/1     Running   4
conference-postgresql-0                                 1/1     Running   0
conference-redis-master-0                               1/1     Running   0
```

**What got deployed:**

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│                                                             │
│  Browser ──▶ Ingress (NGINX) ──▶ Frontend Service           │
│                                       │                     │
│                    ┌──────────────────┼──────────────────┐  │
│                    ▼                  ▼                   ▼  │
│              C4P Service       Agenda Service    Notifications│
│                    │                  │               │      │
│                    ▼                  ▼               ▼      │
│                  Redis           PostgreSQL          Kafka   │
└─────────────────────────────────────────────────────────────┘
```

Open `http://localhost` in your browser to see the app.

---

## Step 6 — Interact with the Application

Walk through the full C4P flow:

1. Go to **Call for Proposals** → submit a proposal (fill Title, Description, Author, Email)
2. Go to **Backoffice → Review Proposals** → Approve or Reject it
3. Check **Backoffice → Notifications** → see the email that was sent
4. Check **Backoffice → Events** → see all events emitted: `New Proposal → New Agenda Item → Proposal Approved → Notification Sent`
5. Go to **Agenda** → see the approved talk listed

---

## Step 7 — Inspect Kubernetes Resources

### Deployments

Deployments define how containers run, how many replicas, and how updates are rolled out.

```bash
kubectl get deployments
```

```
NAME                                          READY   UP-TO-DATE   AVAILABLE
conference-agenda-service-deployment          1/1     1            1
conference-c4p-service-deployment             1/1     1            1
conference-frontend-deployment                1/1     1            1
conference-notifications-service-deployment   1/1     1            1
```

Describe one to see its full config (image, env vars, replicas, rolling update strategy):
```bash
kubectl describe deploy conference-frontend-deployment
```

Key things to look for:
- `Image` — the container image being used
- `Replicas` — how many copies are running
- `RollingUpdateStrategy` — how updates happen without downtime
- `Environment` — service URLs injected as env vars (e.g., `AGENDA_SERVICE_URL`)

### ReplicaSets

ReplicaSets are managed by Deployments and ensure the desired number of pods is always running.

```bash
kubectl get replicasets
```

### Services

Services provide stable DNS names and load balancing across pod replicas. Other services communicate using the service name, not IP addresses.

```bash
kubectl get services
```

```
NAME                      TYPE        CLUSTER-IP      PORT(S)
agenda-service            ClusterIP   10.96.90.100    80/TCP
c4p-service               ClusterIP   10.96.179.86    80/TCP
frontend                  ClusterIP   10.96.60.237    80/TCP
conference-kafka          ClusterIP   10.96.67.2      9092/TCP
conference-postgresql     ClusterIP   10.96.121.167   5432/TCP
conference-redis-master   ClusterIP   10.96.225.138   6379/TCP
notifications-service     ClusterIP   10.96.65.248    80/TCP
```

**Service discovery in Kubernetes:**
```
Frontend Pod
    │
    │  HTTP GET http://agenda-service/...
    ▼
agenda-service (ClusterIP)   ← Kubernetes DNS resolves this name
    │
    ▼
Agenda Pod(s)   ← load balanced across all replicas
```

### Ingress

Ingress routes external traffic into the cluster. Only the Frontend is exposed externally.

```bash
kubectl get ingress
kubectl describe ingress conference-frontend-ingress
```

```
Rules:
  Host   Path   Backends
  *      /      frontend:80
```

### Port-forward for debugging internal services

To access a service that isn't exposed externally (e.g., Agenda service directly):

```bash
kubectl port-forward svc/agenda-service 8080:80
curl -s localhost:8080/service/info | jq
```

---

## Step 8 — Break Things (The Real Learning)

### Challenge 1: Downtime is Not Allowed

Scale the Frontend to 2 replicas:
```bash
kubectl scale --replicas=2 deployments/conference-frontend-deployment
```

Enable the debug feature to see which replica is answering:
```bash
kubectl set env deployment/conference-frontend-deployment FEATURE_DEBUG_ENABLED=true
```

Go to Backoffice → Debug tab. Refresh every few seconds — you'll see different Pod Names and Node Names answering, proving load balancing is working.

**Now kill one replica:**
```bash
kubectl get pods   # copy one frontend pod ID
kubectl delete pod <POD_ID>
```

Kubernetes immediately creates a replacement. The app stays up because the second replica keeps serving traffic.

```
Before delete:          After delete:
Frontend <Service>      Frontend <Service>
    │                       │
    ├── Pod A (running)      ├── Pod A (running)
    └── Pod B (running)      └── Pod C (ContainerCreating) ← auto-replaced
```

**Now simulate real downtime — scale to 1 and kill it:**
```bash
kubectl scale --replicas=1 deployments/conference-frontend-deployment
kubectl delete pod <POD_ID>
```

Refresh `http://localhost` → you'll see `503 Service Temporarily Unavailable`. This is what we must avoid in production.

> **Lesson:** Always run at least 2 replicas for user-facing services.

---

### Challenge 2: Service Resilience

Scale the Agenda service to 0 (simulate it going down):
```bash
kubectl scale --replicas=0 deployments/conference-agenda-service-deployment
```

Refresh the app. The Frontend still loads — it shows cached agenda entries instead of crashing. The Backoffice Debug tab shows the Agenda service as unhealthy.

```
User ──▶ Frontend ──▶ Agenda Service (DOWN)
                │
                └──▶ Returns cached response instead of error
```

> **Lesson:** Services must handle downstream failures gracefully. Don't propagate errors to users — use cached responses, fallbacks, or degraded modes.

Restore it:
```bash
kubectl scale --replicas=1 deployments/conference-agenda-service-deployment
```

---

### Challenge 3: Application State

Scale the Agenda service to 2 replicas:
```bash
kubectl scale --replicas=2 deployments/conference-agenda-service-deployment
```

This works cleanly because the Agenda service stores state in **PostgreSQL** (external to the pod). Both replicas read/write the same database.

```
Frontend
    │
    ▼
Agenda Service (ClusterIP)
    ├── Pod A ──▶ PostgreSQL ◀── shared state
    └── Pod B ──▶ PostgreSQL
```

**What if state was in-memory?**
```
Frontend
    │
    ▼
Agenda Service (ClusterIP)
    ├── Pod A  [in-memory: talks A, B, C]
    └── Pod B  [in-memory: talks X, Y, Z]  ← different data!
```

Users would get inconsistent results depending on which pod answered. This is why stateless services backed by external stores are essential for scalability.

> **Lesson:** Keep services stateless. Delegate all state to external stores (Redis, PostgreSQL, etc.).

---

### Challenge 4: Inconsistent Data

Even with external databases, data can become inconsistent across services. For example: a talk appears on the Agenda but was never approved in C4P.

The solution is a **consistency checker** — a Kubernetes CronJob that periodically reconciles data across services:

```
CronJob (runs every night at midnight)
    │
    ├── 1. Query Agenda Service → get all published talks
    ├── 2. Query C4P Service → verify each talk was approved
    ├── 3. Query Notifications Service → verify emails were sent
    └── 4. If inconsistency found → send alert via Notifications Service
```

> **Lesson:** Distributed systems need eventual consistency mechanisms. Build reconciliation jobs early.

---

### Challenge 5: Observability

Without observability, you're flying blind. The recommended stack:

```
All Services
    │  (emit metrics, traces, logs)
    ▼
OpenTelemetry Collector
    │
    ├──▶ Prometheus (metrics storage)
    │        └──▶ Grafana (dashboards)
    │
    └──▶ Jaeger / Tempo (distributed tracing)
```

Check notification service logs as a basic example:
```bash
kubectl logs -f deployment/conference-notifications-service-deployment
```

> **Lesson:** Instrument your walking skeleton with OpenTelemetry from day one. Adding it later is painful.

---

### Challenge 6: Security & Identity

The Conference app currently has no authentication. In a real system:

```
User
  │
  ▼
Frontend ──▶ Identity Management (Keycloak / Zitadel)
  │               │
  │         ◀── JWT token with roles/groups
  │
  ├──▶ C4P Service       (role: speaker)
  ├──▶ Agenda Service    (role: public)
  └──▶ Backoffice        (role: organizer)
```

The Frontend handles the OAuth2 login flow. Once authenticated, it propagates the user context (JWT) to backend services.

> **Lesson:** Plan identity management early. Retrofitting auth into a distributed system is significantly harder than building it in from the start.

---

## Cleanup

Remove the Helm release and PersistentVolumeClaims:

```bash
helm uninstall conference

# Delete PVCs (required before reinstalling)
kubectl delete pvc data-conference-kafka-0 data-conference-postgresql-0 redis-data-conference-redis-master-0
```

Delete the entire cluster:
```bash
kind delete clusters dev
```

---

## Summary

| What You Did | What You Learned |
|---|---|
| Created a KinD cluster | Local vs. remote Kubernetes trade-offs |
| Installed app with Helm | Helm as a Kubernetes package manager + templating engine |
| Inspected Deployments, Services, Ingress | How Kubernetes resources relate to each other |
| Scaled replicas up/down | How Kubernetes self-heals and load balances |
| Killed pods intentionally | Why multiple replicas are non-negotiable |
| Scaled a service to 0 | How to build resilient services with fallbacks |
| Scaled a stateful service | Why external state storage is required for scalability |

These are the exact challenges that the platform (built in chapters 3–9) is designed to solve.

---

## Next: Chapter 3 — Service Pipelines

Now that the app is running, the next question is: **how do we build and release new versions of these services automatically?**

Chapter 3 introduces **Tekton** and **Dagger** to automate the build, test, and package pipeline for each service.
