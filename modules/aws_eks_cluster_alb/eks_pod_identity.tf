data "aws_iam_policy_document" "pod_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

resource "aws_iam_role" "tasky" {
  name               = "eks-pod-identity-tasky"
  assume_role_policy = data.aws_iam_policy_document.pod_assume_role.json
}

resource "aws_iam_role_policy_attachment" "tasky_cluster_admin" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  role       = aws_iam_role.tasky.name
}

resource "aws_eks_pod_identity_association" "tasky" {
  cluster_name    = module.eks.cluster_name
  namespace       = "tasky"
  service_account = "tasky"
  role_arn        = aws_iam_role.tasky.arn
}

# resource "aws_eks_access_policy_association" "example" {
#   cluster_name  = module.eks.cluster_name
#   policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
#   principal_arn = aws_iam_role.tasky.arn

#   access_scope {
#     type       = "namespace"
#     namespaces = ["tasky"]
#   }
# }