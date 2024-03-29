data "kubectl_filename_list" "manifests" {
  pattern = "../k8s-service/*.yaml"
}
resource "kubectl_manifest" "test" {
  count     = length(data.kubectl_filename_list.manifests.matches)
  yaml_body = file(element(data.kubectl_filename_list.manifests.matches, count.index))
}