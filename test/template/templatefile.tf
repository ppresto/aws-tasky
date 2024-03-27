resource "local_file" "test" {
  content  = templatefile("${path.module}/mongo-systemd.sh",
  {
    BUCKET_NAME = "test"
  })
  filename = "${path.module}/rendered-mongo-systemd.sh"
}
