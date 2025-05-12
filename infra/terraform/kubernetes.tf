resource "azurerm_container_registry" "example" {
  count               = local.deploy_azure_container_registry ? 1 : 0
  name                = "acr${local.name}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = "Premium"
}

resource "azapi_resource" "aks" {
  type                      = "Microsoft.ContainerService/managedClusters@2024-03-02-preview"
  parent_id                 = azurerm_resource_group.example.id
  location                  = azurerm_resource_group.example.location
  name                      = "aks-${local.name}"
  schema_validation_enabled = false

  body = {
    identity = {
      type = "SystemAssigned"
    },
    properties = {
      agentPoolProfiles = [
        {
          name   = "systempool"
          count  = 3
          osType = "Linux"
          mode   = "System"
        }
      ]
      addonProfiles = {
        omsagent = {
          enabled = true
          config = {
            logAnalyticsWorkspaceResourceID = azurerm_log_analytics_workspace.example.id
            useAADAuth                      = "true"
          }
        }
      }
      azureMonitorProfile = {
        metrics = {
          enabled = true,
          kubeStateMetrics = {
            metricLabelsAllowlist      = "",
            metricAnnotationsAllowList = ""
          }
        },
        containerInsights = {
          enabled                         = true,
          logAnalyticsWorkspaceResourceId = azurerm_log_analytics_workspace.example.id
        }
      }
    }
    sku = {
      name = "Automatic"
      tier = "Standard"
    }
  }

  response_export_values = ["properties"]
}

resource "azurerm_role_assignment" "aks2" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  scope                = azapi_resource.aks.id
}

resource "azurerm_role_assignment" "example" {
  count                            = local.deploy_azure_container_registry ? 1 : 0
  principal_id                     = azapi_resource.aks.output.properties.identityProfile.kubeletidentity.objectId
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.example[0].id
  skip_service_principal_aad_check = true
}