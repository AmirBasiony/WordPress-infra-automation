resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "6.7.14"

  namespace        = kubernetes_namespace_v1.argocd.metadata[0].name
  create_namespace = false

  wait    = true
  timeout = 900

  # important: ensure CRDs are installed by the chart
  set {
    name  = "crds.install"
    value = "true"
  }

  # your current settings
  set {
    name  = "configs.params.server.insecure"
    value = "true"
  }
  set {
    name  = "configs.cm.application.resourceTrackingMethod"
    value = "annotation"
  }
}

resource "helm_release" "argocd_apps" {
  name       = "argocd-apps"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name

  wait    = true
  timeout = 900

  values = [
    yamlencode({
      applications = {
        wordpress = {
          namespace = "argocd"
          project   = "default"

          source = {
            repoURL        = "https://github.com/AmirBasiony/K8s-GitOps-wordpress.git"
            targetRevision = "main"
            path           = "wordpress/overlays/prod"
          }

          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "wordpress"
          }

          syncPolicy = {
            automated = {
              prune    = true
              selfHeal = true
            }
            syncOptions = [
              "CreateNamespace=true",
              "ApplyOutOfSyncOnly=true"
            ]
          }
        }
      }
    })
  ]

  depends_on = [helm_release.argocd]
}


