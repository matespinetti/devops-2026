resource "aws_prometheus_workspace" "amp" {
  alias = "${local.name_prefix}-amp"
  tags = merge(local.common_tags, {
    Name      = "${local.name_prefix}-amp"
    Component = "amp"
  })
}
