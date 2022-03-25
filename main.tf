terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.5.0"
    }
  }
}

provider "google" {
  credentials = file(var.credentials_path)

  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Storage configuration
data "archive_file" "pubsub_trigger" {
  type        = "zip"
  source_dir  = "${path.module}/function"
  output_path = "${path.module}/function_trigger.zip"
}
resource "google_storage_bucket" "functions" {
  project = var.project_id
  name    = "${var.project_id}-functions"
}
resource "google_storage_bucket_object" "pubsub_trigger" {
  bucket = google_storage_bucket.functions.name
  name   = "pubsub_trigger-${data.archive_file.pubsub_trigger.output_md5}.zip"
  source = data.archive_file.pubsub_trigger.output_path
}

# Cloud Function configuration
resource "google_project_service" "cloudbuild" {
  project                    = var.project_id
  service                    = "cloudbuild.googleapis.com"
  disable_dependent_services = true
}
resource "google_project_service" "cloudfunctions" {
  project                    = var.project_id
  service                    = "cloudfunctions.googleapis.com"
  disable_dependent_services = true
}
resource "google_cloudfunctions_function" "pubsub_trigger" {
  project               = var.project_id
  name                  = "cronjob-pubsub"
  region                = var.region
  entry_point           = "send_data_bq"
  runtime               = "python39"
  source_archive_bucket = google_storage_bucket.functions.name
  source_archive_object = google_storage_bucket_object.pubsub_trigger.name
  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = google_pubsub_topic.cronjobtopic.name
  }
  environment_variables = {
    USERNAME            = var.username
    PASSWORD            = var.password
    TEAMWORK_PROJECT_ID = var.teamwork_project_id
    TABLE_ID            = "${var.project_id}.${var.dataset_name}.${var.table_name}"
  }
  depends_on = [
    google_project_service.cloudbuild,
    google_project_service.cloudfunctions
  ]
}

# Pub/Sub configuration
resource "google_project_service" "pubsub" {
  project                    = var.project_id
  service                    = "pubsub.googleapis.com"
  disable_dependent_services = true
}
resource "google_pubsub_topic" "cronjobtopic" {
  project = var.project_id
  name    = "cron-topic"
  depends_on = [
    google_project_service.pubsub,
  ]
}

# Scheduler configuration
resource "google_project_service" "cloudscheduler" {
  project                    = var.project_id
  service                    = "cloudscheduler.googleapis.com"
  disable_dependent_services = true
}
resource "google_cloud_scheduler_job" "cron_pubsub_job" {
  project   = var.project_id
  region    = google_cloudfunctions_function.pubsub_trigger.region
  name      = "cron-pubsub-job"
  schedule  = "30 8 * * 1-5" #L-V at 8:30 am
  time_zone = "America/Lima"
  pubsub_target {
    topic_name = google_pubsub_topic.cronjobtopic.id
    data       = base64encode("Pub/Sub message")
  }
  depends_on = [
    google_project_service.cloudscheduler,
  ]
}