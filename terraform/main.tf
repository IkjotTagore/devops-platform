terraform{
    required_version = ">= 1.0"
}

provider "local"{}

locals {
    full_cluster_name = "${var.cluster_name}-${var.environment}"
}

resource "local_file" "cluster_name" {
    content = local.full_cluster_name
    filename = "${var.environment}_cluster_name.txt"
}