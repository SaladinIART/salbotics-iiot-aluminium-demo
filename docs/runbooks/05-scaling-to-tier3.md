# Runbook 05 — Scaling to Tier 3 (Kubernetes)

## When to use this runbook

You need to run NEXUS across multiple servers with high-availability, automated restarts, rolling deployments, and horizontal scaling. Kubernetes (Tier 3) provides all of these — `helm install` is the single command that replaces `docker compose up`.

**Tier 2** (multi-site, Docker Compose, one host per site) → **Tier 3** (Kubernetes cluster, EMQX cluster, Helm-managed)

---

## Prerequisites

| Tool | Min version | Install |
|------|------------|---------|
| `kubectl` | 1.29 | https://kubernetes.io/docs/tasks/tools/ |
| `helm` | 3.14 | https://helm.sh/docs/intro/install/ |
| Minikube (local) or a managed K8s cluster (GKE/EKS/AKS) | — | https://minikube.sigs.k8s.io |
| GHCR images published (release workflow ran) | — | See `.github/workflows/release.yml` |

---

## Step 1 — Build and push images

If you haven't already pushed images to GHCR, tag a release:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The `release.yml` GitHub Actions workflow will build and push all 5 images automatically. Check the Actions tab for status.

Alternatively, build and push manually:

```bash
# Set your GitHub username
GHCR_USER=saladinart   # change this

docker build -t ghcr.io/$GHCR_USER/nexus-iiot-api:1.0.0       -f services/api/Dockerfile .
docker build -t ghcr.io/$GHCR_USER/nexus-iiot-alerting:1.0.0  -f services/alerting/Dockerfile .
docker build -t ghcr.io/$GHCR_USER/nexus-iiot-collector:1.0.0 -f services/collector/Dockerfile .
docker build -t ghcr.io/$GHCR_USER/nexus-iiot-ingestor:1.0.0  -f services/ingestor/Dockerfile .
docker build -t ghcr.io/$GHCR_USER/nexus-iiot-modbus-sim:1.0.0 -f sim/modbus_sim/Dockerfile .

echo $GITHUB_TOKEN | docker login ghcr.io -u $GHCR_USER --password-stdin

for svc in api alerting collector ingestor modbus-sim; do
  docker push ghcr.io/$GHCR_USER/nexus-iiot-$svc:1.0.0
done
```

---

## Step 2 — Start local Kubernetes (Minikube)

```bash
minikube start --memory=4096 --cpus=4 --disk-size=20g
kubectl config use-context minikube
```

---

## Step 3 — Create namespace and add Helm repos

```bash
kubectl create namespace nexus

helm repo add timescale https://charts.timescale.com
helm repo add grafana   https://grafana.github.io/helm-charts
helm repo update

# Update Helm dependencies
cd helm/nexus
helm dependency update
cd ../..
```

---

## Step 4 — Create a production values override

Create `helm/nexus/values-prod.yaml` (git-ignored — never commit secrets):

```yaml
imageRegistry: ghcr.io/saladinart   # your GHCR namespace
imageTag: "1.0.0"

secrets:
  postgresPassword: "your-strong-db-password"
  mqttPassword: "your-strong-mqtt-password"
  apiKey: "your-api-key-here"
  grafanaAdminPassword: "your-grafana-password"

ingress:
  enabled: true
  className: nginx
  host: nexus.yourdomain.com
  tls:
    enabled: true
    secretName: nexus-tls
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod

api:
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 6
```

---

## Step 5 — Install the chart

```bash
helm install nexus ./helm/nexus \
  --namespace nexus \
  --values helm/nexus/values-prod.yaml \
  --wait \
  --timeout 10m
```

---

## Step 6 — Verify all pods are Running

```bash
kubectl get pods -n nexus
```

Expected output (all `Running` or `Completed`):

```
NAME                                READY   STATUS    RESTARTS
nexus-alerting-xxx                  1/1     Running   0
nexus-api-xxx                       1/1     Running   0
nexus-api-yyy                       1/1     Running   0
nexus-collector-xxx                 1/1     Running   0
nexus-emqx-xxx                      1/1     Running   0
nexus-ingestor-xxx                  1/1     Running   0
nexus-modbus-sim-xxx                1/1     Running   0
nexus-timescaledb-0                 1/1     Running   0
nexus-grafana-xxx                   1/1     Running   0
```

---

## Step 7 — Access the platform

**Without Ingress (Minikube testing):**

```bash
# API + frontend
kubectl port-forward svc/nexus-api 8000:8000 -n nexus &

# Grafana
kubectl port-forward svc/nexus-grafana 3000:3000 -n nexus &
```

Then open:
- `http://localhost:8000` — NEXUS frontend
- `http://localhost:8000/docs` — Swagger UI
- `http://localhost:3000` — Grafana

**Verify the API:**

```bash
curl -s -H "X-API-Key: your-api-key-here" \
  http://localhost:8000/api/v1/assets | python3 -m json.tool
```

---

## Step 8 — Rolling upgrades

```bash
# Update values and upgrade in place — zero downtime for the API (2 replicas)
helm upgrade nexus ./helm/nexus \
  --namespace nexus \
  --values helm/nexus/values-prod.yaml \
  --set imageTag=1.1.0
```

---

## Useful kubectl commands

```bash
# Watch pod status in real time
kubectl get pods -n nexus -w

# Follow alerting logs
kubectl logs -n nexus -l app.kubernetes.io/component=alerting -f

# Follow API logs
kubectl logs -n nexus -l app.kubernetes.io/component=api -f

# Describe a pod (events, resource usage)
kubectl describe pod -n nexus <pod-name>

# Scale API replicas manually
kubectl scale deployment nexus-api --replicas=4 -n nexus

# Open a psql session inside TimescaleDB
kubectl exec -n nexus -it nexus-timescaledb-0 -- \
  psql -U iiot -d iiot -c "SELECT COUNT(*) FROM telemetry;"
```

---

## Uninstall

```bash
helm uninstall nexus --namespace nexus
kubectl delete namespace nexus   # also deletes PVCs — all data lost
```

To keep data:
```bash
helm uninstall nexus --namespace nexus
# PVCs remain — re-install will reuse the existing TimescaleDB volume
```

---

## Troubleshooting

| Symptom | Check |
|---------|-------|
| Pods stuck in `ImagePullBackOff` | `kubectl describe pod <name> -n nexus` — verify GHCR image tag exists and is public, or create an `imagePullSecret` |
| TimescaleDB pod in `Pending` | Check PVC: `kubectl get pvc -n nexus` — ensure storage class has a provisioner |
| API `CrashLoopBackOff` | `kubectl logs -n nexus <api-pod>` — usually a DB connection failure, check `nexus-timescaledb` is Ready |
| `helm dependency update` fails | Run `helm repo update` first, check internet access from your machine |
| Minikube out of disk space | `minikube delete && minikube start --disk-size=30g` |
