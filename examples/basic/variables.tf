variable "subscription_id" {
  description = "Set the subscription for resources (or define environment variable ARM_SUBSCRIPTION_ID)"

  type    = string
  default = null
}

variable "tenant_id" {
  description = "Set the subscription for resources (or define environment variable ARM_TENANT_ID)"

  type    = string
  default = null
}
