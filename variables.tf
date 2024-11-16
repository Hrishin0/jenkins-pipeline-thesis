variable "myregion" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "accountId" {
  description = "AWS account ID"
  type        = string
  default     = "536697233361"
}

variable "lambda_function_name" {
    type = string
    default = "getStudent"
}