locals {
  rg_name = "${var.rg_name}-rg"
}

resource "aws_resourcegroups_group" "rg" {
  name        = local.rg_name
  description = "Resource group for ${local.rg_name}"
  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = var.tag_key
          Values = [var.tag_value]
        }
      ]
    })
  }
}