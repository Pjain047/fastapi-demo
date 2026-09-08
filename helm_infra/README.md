# Helm deployment runbook

Run these commands from the repository root:

```powershell
cd .\helm_infra\fastapi-demo
```

## 1. Check Helm and Kubernetes access

```powershell
helm version
kubectl version --client
kubectl config current-context
kubectl get nodes
```

These commands confirm that Helm is installed and that kubectl can reach the
selected cluster. For Minikube, start the cluster first:

```powershell
minikube start
kubectl config use-context minikube
```

## 2. Inspect chart values

```powershell
helm show values .
```

This displays the configurable defaults in `values.yaml` without installing
anything.

## 3. Lint the chart

```powershell
helm lint .
```

This checks chart structure, templates, required values, and common Helm
problems. Fix lint errors before rendering or installing.

The GitHub Actions workflow runs this same validation automatically and stores
the lint output, rendered YAML, and Kubernetes validation output in the
`helm-validation` artifact.

## 4. Render templates locally

```powershell
helm template fastapi-demo . `
  --namespace fastapi-demo
```

This renders the final Kubernetes YAML without contacting the cluster. Use it
to inspect names, namespaces, environment variables, image tags, probes, and
HPA settings.

To save and inspect the rendered manifest:

```powershell
helm template fastapi-demo . `
  --namespace fastapi-demo `
  --output-dir .\rendered
```

The `rendered` directory is temporary and should not be committed.

## 5. Validate rendered Kubernetes YAML

With kubectl:

```powershell
helm template fastapi-demo . `
  --namespace fastapi-demo | kubectl apply --dry-run=client --validate=false -f -
```

This checks that kubectl can parse the rendered resources without changing the
cluster. `--validate=false` is required in CI because GitHub-hosted runners do
not have a Kubernetes API server from which kubectl can download the OpenAPI
schema.

For stricter schema validation, install `kubeconform` and run:

```powershell
helm template fastapi-demo . `
  --namespace fastapi-demo | kubeconform -strict -summary
```

The GitHub Actions runner performs this schema validation automatically using
the `ghcr.io/yannh/kubeconform` container. It also installs and verifies
`kubectl`, but does not run `kubectl apply` because that command can still try
to contact a Kubernetes API server for resource discovery. No Kubernetes
cluster is required for this CI job.

## 6. Create the namespace and install

Use Helm's namespace option so the namespace is created before the release
resources:

```powershell
helm upgrade --install fastapi-demo . `
  --namespace fastapi-demo `
  --create-namespace `
  --wait `
  --timeout 5m
```

`--upgrade --install` makes the command safe to run for both first install and
later deployments. `--create-namespace` creates `fastapi-demo` first. `--wait`
waits for the Deployment, Service, and HPA-related resources to become ready.

The chart also contains `templates/namespace.yaml`, but it is disabled by
default. This avoids conflicts because the namespace is managed by
`--create-namespace` rather than by the Helm release.

## 7. Verify the release

```powershell
helm status fastapi-demo --namespace fastapi-demo
helm list --namespace fastapi-demo
kubectl get all --namespace fastapi-demo
kubectl get configmap,secret,hpa --namespace fastapi-demo
kubectl get pods --namespace fastapi-demo -o wide
```

If pods are not ready, inspect their events and logs:

```powershell
kubectl describe pods --namespace fastapi-demo
kubectl logs deployment/fastapi-demo --namespace fastapi-demo --all-containers=true
kubectl get events --namespace fastapi-demo --sort-by=.lastTimestamp
```

## 8. Test the Service locally with Minikube

For a NodePort service:

```powershell
minikube service fastapi-demo --namespace fastapi-demo --url
```

Use the returned URL with `/health` or `/docs`.

## 9. Upgrade after a change

Change the image tag or another value without editing the chart:

```powershell
helm upgrade fastapi-demo . `
  --namespace fastapi-demo `
  --set image.tag=latest `
  --wait `
  --timeout 5m
```

Preview an upgrade before applying it:

```powershell
helm diff upgrade fastapi-demo . --namespace fastapi-demo
```

The `helm-diff` plugin is required for that command.

## 10. Roll back

List revisions:

```powershell
helm history fastapi-demo --namespace fastapi-demo
```

Roll back to a known revision:

```powershell
helm rollback fastapi-demo <REVISION> `
  --namespace fastapi-demo `
  --wait `
  --timeout 5m
```

## 11. Remove the Helm release

```powershell
helm uninstall fastapi-demo --namespace fastapi-demo
```

Because the namespace was created with `--create-namespace`, Helm does not
remove it automatically. Remove it separately only when the namespace is no
longer needed:

```powershell
kubectl delete namespace fastapi-demo
```

## Resource ordering

Helm does not rely on the filename order in `templates/`. It renders all
templates, sorts resources by Kubernetes kind, and sends them to the cluster.
`--create-namespace` is handled before the release installation, so the
namespace exists before namespaced ConfigMaps, Secrets, Services, Deployments,
and HPAs are created.

Resource creation order does not guarantee application readiness. Use
`--wait`, readiness probes, and `kubectl rollout status` to verify that the
application is actually ready:

```powershell
kubectl rollout status deployment/fastapi-demo `
  --namespace fastapi-demo `
  --timeout=5m
```

## `_helpers.tpl`

The `_helpers.tpl` file stores reusable named Helm templates. It is useful for
values that are calculated or repeated across multiple Kubernetes templates,
such as resource names and common labels.

Helpers are not Kubernetes resources and do not create anything by themselves.
They are functions that return rendered text when another template calls them
with `include`.

### Example helper

In `templates/_helpers.tpl`:

```gotemplate
{{- define "fastapi-demo.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
```

Use that helper in `templates/deployment.yaml`:

```gotemplate
metadata:
  labels:
    {{- include "fastapi-demo.labels" . | nindent 4 }}
```

During rendering, Helm expands the helper into:

```yaml
metadata:
  labels:
    app.kubernetes.io/name: fastapi-demo
    app.kubernetes.io/instance: fastapi-demo
    app.kubernetes.io/managed-by: Helm
```

### Helpers versus `values.yaml`

Use `values.yaml` for configuration that should be changeable by the person
installing the chart:

```yaml
replicaCount: 2
image:
  repository: prashantjain047/fastapi-demo
  tag: latest
```

Use `_helpers.tpl` for reusable naming, labels, selectors, and formatting
logic. For example, this chart uses helpers for:

- `fastapi-demo.name`: the chart name
- `fastapi-demo.fullname`: the release resource name
- `fastapi-demo.namespace`: the target namespace
- `fastapi-demo.labels`: shared Kubernetes labels
- `fastapi-demo.selectorLabels`: labels used by Services and Deployments

This keeps templates consistent and avoids repeating the same labels and name
logic in every resource file.