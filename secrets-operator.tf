resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true
  version          = "0.9.0"

  # create (RBAC, service account)
  # the serviceAccount links to the IAM role allowing access to Secrets Manager.
  values = [
    yamlencode({
      rbac = {
        create = true
      }
      serviceAccount = {
        create = true
        name   = "external-secrets-sa"
      }
    })
  ]
}