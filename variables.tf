variable "project_id" {
  description = "Google Project ID."
  type        = string
}

variable "credentials_path" {
  description = "GCP Credentials"
  type        = string
}

variable "region" {
  description = "Google Cloud region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  default = "us-central1-c"
}

variable "username" {
  description = "Teamwork Basic Auth - username (API key)"
  type        = string
}

variable "password" {
  description = "Teamwork Basic Auth - password"
  type        = string
}

variable "dataset_name" {
  description = "Bigquery Dataset Name"
  type        = string
}

variable "table_name" {
  description = "Bigquery table Name"
  type        = string
}

variable "teamwork_project_id" {
  description = "Teamwork project id"
  type        = string
}