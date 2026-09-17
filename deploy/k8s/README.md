# Thoth on Kubernetes

Plain manifests — `kubectl apply -k .` or `kustomize build .`. No Helm, nothing to install
first.

## What this deploys

One replica behind a `ReadWriteOnce` volume, a ClusterIP Service, and an Ingress that
re-encrypts to the pod.

**Do not raise `replicas`.** Thoth stores everything — the database, uploads, TLS material,
the generated session secret — in one SQLite file with one writer. That is also why the
Deployment uses `strategy: Recreate`: a RollingUpdate would briefly run two pods against the
same volume. Scaling out is not a configuration change, it is a different storage engine.

## Before you apply

Edit these:

| Where | What |
|---|---|
| `configmap.yaml` | `BASE_URL` — the public `https://` URL. The server refuses to start on an `http://` one. |
| `ingress.yaml` | the host (twice: `spec.tls[0].hosts` and `spec.rules[0].host`), `ingressClassName`, and how the certificate is issued |
| `pvc.yaml` | `storage`, and `storageClassName` if the cluster has no usable default |
| `deployment.yaml` | the image tag — pin a published release, not `latest` |

Then create the Secret out of band. `secret.example.yaml` is a template with no values in it
and is deliberately **not** listed in `kustomization.yaml`, so no credential can be committed
through it:

```bash
kubectl create namespace thoth
kubectl -n thoth create secret generic thoth \
  --from-literal=SESSION_SECRET="$(openssl rand -hex 32)" \
  --from-literal=ADMIN_EMAIL=admin@example.com \
  --from-literal=ADMIN_PASSWORD="$(openssl rand -base64 24)"
kubectl apply -k .
```

`ADMIN_EMAIL`/`ADMIN_PASSWORD` only bootstrap the first administrator so nobody has to race
for the setup page on a public URL; drop them from the Secret once the account exists.
`SESSION_SECRET` is optional — with none set the app generates one into the volume and reuses
it — but setting it explicitly means a restored volume does not sign everyone out.

Everything else is configured in the UI and stored in the database: SMTP, OIDC client IDs and
secrets, group-to-role mapping, branding, work mode. There is no environment variable for any
of it, by design.

## Ingress: two shapes

**A — re-encrypt to the pod (what these manifests do).** The pod terminates TLS with its own
certificate and the ingress talks HTTPS to it, so nothing inside the cluster is in the clear.
ingress-nginx does not verify the upstream certificate, which is what makes a self-signed one
workable:

```yaml
nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
```

Leave `TRUST_PROXY: "false"`.

**B — plain HTTP to the pod.** If your ingress controller cannot re-encrypt, drop the
`backend-protocol` annotation and set `TRUST_PROXY: "true"` in the ConfigMap. The port does
not change: the same listener answers both, deciding per connection from the first byte. The
cost is that session cookies and directory data cross the cluster network unencrypted between
the controller and the pod — choose A unless you have to.

Traefik's equivalent of A is a `ServersTransport` with `insecureSkipVerify: true` plus a
`scheme: https` service annotation.

## Health probes

All three probes are plain HTTP against `/api/health`. That works because the app answers
exactly that one path in the clear for probes and 301s everything else to HTTPS — so a
kubelet probe needs no certificate handling. `startupProbe` is generous on purpose: the first
start generates a certificate and runs every migration against an empty database.

## Private registry

If the image is not public, give the namespace a pull secret and uncomment
`imagePullSecrets` in `deployment.yaml`:

```bash
kubectl -n thoth create secret docker-registry ghcr \
  --docker-server=ghcr.io --docker-username=<user> --docker-password=<token with read:packages>
```

## Upgrading

Bump the image tag and re-apply. `Recreate` stops the old pod before the new one starts, so
expect a few seconds of downtime; migrations run on start. Take a backup first — Settings →
Maintenance → *Download database backup*, or snapshot the PVC.

## Troubleshooting

**Pod crashlooping on a write.** `readOnlyRootFilesystem: true` is set, with an `emptyDir` at
`/tmp`. Everything the app writes lands in `/data` or `/tmp`; if that ever stops holding, this
is the first thing to flip. The logs name the path.

**`BASE_URL must be https://`.** Exactly what it says — the app refuses to start rather than
serve a deployment that would leak.

**A redirect loop.** Shape B without `TRUST_PROXY: "true"`: the ingress forwards plain HTTP,
the app redirects to HTTPS, the ingress forwards plain HTTP again.

**Which build is running.** Settings → Maintenance → *About this instance*, or
`GET /api/version` with a session. A release image reports its version, commit and build time.
