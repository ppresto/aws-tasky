# Create AWS LoadBalancer Controller IAM Policy and Role for EKS cluster.
# Role
# arn:aws:iam::729755634065:role/${module.eks.cluster_name}-load-balancer-controller
module "lb_irsa" {
  source                                 = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name                              = "${module.eks.cluster_name}-load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
  depends_on = [ module.eks ]
}

# The below section requires the correct kubernetes and helm providers to be setup.
# Providers can't be dynamically configured to support multiple eks clusters so use argoCD for Flux instead
#

# - Creates AWS LB Controller service account
# - Applys the above IAM role to the service account
# - Uses Helm to install the AWS LB controller with the sa

resource "kubernetes_service_account" "lb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/component" = "controller"
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = module.lb_irsa.iam_role_arn
    }
  }
  depends_on = [ module.eks ]
}

resource "helm_release" "lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = false
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.lb_controller.metadata[0].name
  }
}