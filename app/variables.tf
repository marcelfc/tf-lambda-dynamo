variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "store_payload_lambda_function_name" {
  type    = string
  default = "store-payload"
}

variable "datastore_table_name" {
  type    = string
  default = "payload-datastore"
}

variable "datastore_total_count_item_key" {
  type    = string
  default = "TOTAL_COUNT"
}

variable "report_bucket_exists" {
  type    = bool
  default = true
}

variable "report_bucket_name" {
  type = string
}

variable "generate_report_lambda_function_name" {
  type    = string
  default = "generate-report"
}

variable "generate_report_lambda_function_schedule" {
  type    = string
  default = "rate(7 days)"
}