resource "azurerm_container_app" "app" {
  name                         = var.app_name
  container_app_environment_id = var.container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = var.revision_mode

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = var.container_name
      image  = var.container_image
      cpu    = var.cpu
      memory = var.memory

      dynamic "env" {
        for_each = var.environment_variables
        content {
          name        = env.value.name
          value       = lookup(env.value, "value", null)
          secret_name = lookup(env.value, "secret_name", null)
        }
      }

      dynamic "liveness_probe" {
        for_each = var.liveness_probe != null ? [var.liveness_probe] : []
        content {
          transport               = liveness_probe.value.transport
          path                    = lookup(liveness_probe.value, "path", null)
          port                    = liveness_probe.value.port
          initial_delay           = lookup(liveness_probe.value, "initial_delay", 10)
          #period_seconds          = lookup(liveness_probe.value, "period_seconds", 30)
          failure_count_threshold = lookup(liveness_probe.value, "failure_count_threshold", 3)
        }
      }

      dynamic "readiness_probe" {
        for_each = var.readiness_probe != null ? [var.readiness_probe] : []
        content {
          transport               = readiness_probe.value.transport
          path                    = lookup(readiness_probe.value, "path", null)
          port                    = readiness_probe.value.port
          #period_seconds          = lookup(readiness_probe.value, "period_seconds", 10)
          failure_count_threshold = lookup(readiness_probe.value, "failure_count_threshold", 3)
        }
      }
    }
  }

  dynamic "ingress" {
    for_each = var.ingress != null ? [var.ingress] : []
    content {
      external_enabled = ingress.value.external_enabled
      target_port      = ingress.value.target_port
      transport        = lookup(ingress.value, "transport", "http")

      traffic_weight {
        percentage      = 100
        latest_revision = true
      }
    }
  }

  registry {
    server   = var.registry_server
    identity = var.registry_identity_id
  }

  dynamic "secret" {
    for_each = var.secrets
    content {
      name  = secret.value.name
      value = secret.value.value
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.identity_id]
  }

  tags = var.tags
}
