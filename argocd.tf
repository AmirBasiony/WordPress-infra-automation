resource "kubernetes_namespace" "argocd" {
  metadata { 
    name = "argocd" 
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "6.7.14" 
  
  set {
    name  = "configs.params.server.insecure"
    value = "true"
  }
  
  set {
    name  = "configs.cm.application.resourceTrackingMethod"
    value = "annotation"
  }
}


resource "kubernetes_manifest" "wordpress_app" {
  depends_on = [helm_release.argocd]

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "wordpress"
      namespace = "argocd"
    }
    spec = {
      project = "default"

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
}
