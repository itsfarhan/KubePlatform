# KubePlatform

A hands-on journey building a cloud-native Internal Developer Platform (IDP) on top of Kubernetes, following the book **"Platform Engineering on Kubernetes"** by Mauricio Salatino.

---

## What Is This?

This project documents the practical implementation of platform engineering concepts using open-source cloud-native tools. The goal is to build a platform that enables development teams to deliver software faster and more reliably — without needing to understand every underlying tool.

The platform is built progressively, chapter by chapter, using a **Conference Application** as the walking skeleton — a real enough app to expose genuine challenges, simple enough to stay focused on platform concepts.

---

## Progress So Far

### ✅ Chapter 1 — Platforms on Top of Kubernetes (Concepts)

**What was covered:**

- Defined what a platform is: a collection of services and tools that help teams deliver software to customers
- Understood why Kubernetes is a **meta-platform** (a platform to build platforms), not a platform itself
- Learned the 3 pillars every good platform must have:
  - **APIs** — contracts for teams to request/provision resources
  - **Golden Paths to Production** — automated workflows from code to live customers
  - **Visibility** — dashboards and metrics to see what's running and what's broken
- Introduced **Platform Engineering** as a discipline: a dedicated team that picks tools, hides complexity behind clean APIs, and treats dev teams as internal customers
- Understood why you can't just buy a platform off the shelf (OpenShift, Tanzu, etc. still require customization)
- Introduced the **CNCF Landscape** as the ecosystem of open-source tools used to build platforms

**The Walking Skeleton — Conference Application:**

The app used throughout the entire book. It has 4 microservices:

```
┌─────────────────────────────────────────────────────────┐
│                   Conference Application                 │
│                                                         │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────┐  │
│  │ Frontend │───▶│   C4P    │───▶│  Agenda Service  │  │
│  │ (NextJS) │    │ Service  │    │  (approved talks) │  │
│  └──────────┘    └──────────┘    └──────────────────┘  │
│        │                │                               │
│        │         ┌──────────────┐                       │
│        └────────▶│Notifications │                       │
│                  │   Service    │                       │
│                  └──────────────┘                       │
└─────────────────────────────────────────────────────────┘
```

**Call for Proposals (C4P) Flow:**
1. Speaker submits a proposal via the C4P form
2. Organizer reviews and approves/rejects it in the Backoffice
3. Notification email is automatically sent to the speaker
4. If approved, the talk is published on the Agenda page

The app is **event-driven** — every action emits an event (visible in Backoffice → Events tab), which is key to how it integrates with platform tooling in later chapters.

**Key takeaway:** Monolith vs. Microservices trade-offs were discussed. Microservices bring independent scaling, polyglot freedom, and resilience — but at the cost of distributed system complexity. The rest of the book is about managing that complexity with the right platform tools.

---

### ✅ Chapter 2 — Cloud-Native Application Challenges (Hands-On)

See [Exercise 2](./exercise-2.md) for the full hands-on walkthrough.

**What was covered:**

- Deployed the Conference Application to a local KinD Kubernetes cluster using Helm
- Inspected Kubernetes resources: Deployments, ReplicaSets, Services, Ingress
- Explored and intentionally broke the application to understand real cloud-native challenges

**The 6 Cloud-Native Challenges discovered:**

| Challenge | What It Means |
|---|---|
| Downtime is not allowed | Always run multiple replicas for user-facing services |
| Service resilience | Services must handle downstream failures gracefully (cached responses, fallbacks) |
| Application state | Stateless services backed by external DBs (Redis, PostgreSQL) scale cleanly; in-memory state does not |
| Inconsistent data | Distributed data needs eventual consistency checks (e.g., CronJob reconcilers) |
| Observability | OpenTelemetry + Prometheus + Grafana needed from day one, not as an afterthought |
| Security & Identity | OAuth2 + identity management (Keycloak/Zitadel) must be planned early |

**Full architecture deployed:**

```
                        ┌─────────────────────────────────────────┐
                        │           Kubernetes Cluster (KinD)      │
                        │                                         │
  Browser ──────────────┼──▶ Ingress (NGINX)                      │
  http://localhost       │        │                                │
                        │        ▼                                │
                        │   ┌──────────┐                          │
                        │   │ Frontend │                          │
                        │   │  (Pod)   │                          │
                        │   └────┬─────┘                          │
                        │        │ routes to:                     │
                        │   ┌────┴──────────────────────┐         │
                        │   ▼           ▼               ▼         │
                        │ ┌─────┐   ┌──────┐   ┌──────────────┐  │
                        │ │ C4P │   │Agenda│   │Notifications │  │
                        │ │ Svc │   │ Svc  │   │    Svc       │  │
                        │ └──┬──┘   └──┬───┘   └──────┬───────┘  │
                        │    │         │               │          │
                        │    ▼         ▼               ▼          │
                        │ ┌──────┐ ┌──────┐       ┌───────┐      │
                        │ │Redis │ │ PG   │       │ Kafka │      │
                        │ └──────┘ └──────┘       └───────┘      │
                        └─────────────────────────────────────────┘
```

---

## Roadmap (Upcoming Chapters)

| Chapter | Topic | Tools |
|---|---|---|
| 3 | Service Pipelines — building & packaging apps | Tekton, Dagger, GitHub Actions |
| 4 | Environment Pipelines — deploying with GitOps | Argo CD |
| 5 | Multi-Cloud Infrastructure provisioning | Crossplane |
| 6 | Building the Platform itself | vcluster |
| 7 | Platform Capabilities I — shared app concerns | Dapr, OpenFeature |
| 8 | Platform Capabilities II — release strategies | Knative Serving, Argo Rollouts |
| 9 | Measuring the Platform — DORA metrics | CloudEvents, CDEvents, Keptn |

---

## Prerequisites

```bash
# Required tools and versions
Docker     v24.0.2+
kubectl    v1.27.3+
KinD       v0.20.0+
Helm       v3.12.3+
```

---

## Repository Structure

```
KubePlatform/
│
├── README.md                        ← You are here (project overview + progress)
├── exercise-2.md                    ← Chapter 2 hands-on walkthrough
│
│── Cluster Setup
├── kind-config.yaml                 ← KinD cluster definition (1 control-plane + 3 workers)
├── kind-load.sh                     ← Pre-loads container images into KinD to skip slow pulls
│
│── Application Install
├── install.sh                       ← Installs the Conference App via the local Helm chart
├── install-infra.sh                 ← Installs infrastructure only (Redis, PostgreSQL, Kafka) separately
├── kafka.yaml                       ← Standalone Kafka manifest (used by install-infra.sh)
│
│── Container Images
├── Dockerfile.agenda-service        ← Builds the Agenda service image (Go)
├── Dockerfile.c4p-service           ← Builds the C4P (Call for Proposals) service image (Go)
├── Dockerfile.frontend-go           ← Builds the Frontend service image (Go)
├── Dockerfile.notifications-service ← Builds the Notifications service image (Go)
├── build-push.sh                    ← Builds all 4 images and pushes them to your container registry
│
└── helm/
    └── conference-app/              ← Local Helm chart for the full Conference Application
        ├── Chart.yaml               ← Chart metadata and dependency declarations (Redis, PostgreSQL)
        ├── values.yaml              ← All configurable values (registry, image tags, infra toggles)
        └── templates/
            ├── agenda-service.yaml        ← Deployment + Service for Agenda
            ├── c4p-service.yaml           ← Deployment + Service for C4P
            ├── frontend.yaml              ← Deployment + Service for Frontend
            ├── notifications-service.yaml ← Deployment + Service for Notifications
            ├── kafka.yaml                 ← Kafka Deployment + Service (toggled by install.infrastructure)
            ├── ingress.yaml               ← NGINX Ingress rule → routes / to frontend
            ├── c4p-sql-init.yaml          ← ConfigMap with SQL schema for PostgreSQL init
            └── NOTES.txt                  ← Post-install message shown by Helm
```

### When to use which script

| Script | When to use |
|---|---|
| `kind-load.sh` | Before installing — pre-loads images into KinD to avoid slow pulls |
| `install.sh` | Install everything (app + infra) via the local Helm chart in one shot |
| `install-infra.sh` | Install only Redis, PostgreSQL, Kafka — useful if you want to manage infra separately |
| `build-push.sh` | After modifying service source code — rebuilds and pushes images to your registry |

---

## Reference

- Book: [Platform Engineering on Kubernetes — Mauricio Salatino (Manning)](https://www.manning.com/books/platform-engineering-on-kubernetes)
- Source code & tutorials: [github.com/salaboy/platforms-on-k8s](https://github.com/salaboy/platforms-on-k8s)
- CNCF Landscape: [landscape.cncf.io](https://landscape.cncf.io)
- Free Kubernetes credits: [github.com/learnk8s/free-kubernetes](https://github.com/learnk8s/free-kubernetes)
