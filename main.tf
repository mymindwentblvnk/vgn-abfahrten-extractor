terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.43.1"
    }
  }
}

provider "google" {
  credentials = file(var.credentials_file)
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}

# ############### #
# Service Account #
# ############### #
resource "google_service_account" "vgn_departure_extractor" {
  account_id   = "vgn-departure-extractor"
  display_name = "VGN Departure Extractor"
}

# https://stackoverflow.com/questions/47006062/how-do-i-list-the-roles-associated-with-a-gcp-service-account
resource "google_project_iam_member" "cloud_functions_invoker_role" {
  project = var.project_id
  role    = "roles/cloudfunctions.invoker"
  member  = "serviceAccount:${google_service_account.vgn_departure_extractor.email}"

  depends_on = [
    google_service_account.vgn_departure_extractor,
  ]
}

resource "google_project_iam_member" "cloud_tasks_enqueuer_role" {
  project = var.project_id
  role    = "roles/cloudtasks.enqueuer"
  member  = "serviceAccount:${google_service_account.vgn_departure_extractor.email}"

  depends_on = [
    google_service_account.vgn_departure_extractor,
  ]
}

resource "google_project_iam_member" "service_account_user_role" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.vgn_departure_extractor.email}"

  depends_on = [
    google_service_account.vgn_departure_extractor,
  ]
}

resource "google_project_iam_member" "storage_object_creator_role" {
  project = var.project_id
  role    = "roles/storage.objectCreator"
  member  = "serviceAccount:${google_service_account.vgn_departure_extractor.email}"

  depends_on = [
    google_service_account.vgn_departure_extractor,
  ]
}

# ######## #
# BigQuery #
# ######## #
resource "google_bigquery_table" "gcs_external_table" {
  dataset_id  = "raw"
  table_id    = "ext_vgn_departures"
  description = "External BigQuery table on the extracted API responses about VGN departures."
  deletion_protection = "false"

  external_data_configuration {
    ignore_unknown_values     = "true"
    autodetect                = "false"
    schema                    = <<EOF
[
        {
            "name": "Abfahrten",
            "type": "RECORD",
            "mode": "REPEATED",
            "fields": [
                {
                    "name": "Prognose",
                    "type": "BOOLEAN",
                    "mode": "NULLABLE"
                },
                {
                    "name": "Fahrtnummer",
                    "type": "STRING",
                    "mode": "NULLABLE"
                },
                {
                    "name": "Fahrtartnummer",
                    "type": "STRING",
                    "mode": "NULLABLE"
                },
                {
                    "name": "Latitude",
                    "type": "FLOAT",
                    "mode": "NULLABLE"
                },
                {
                    "name": "Longitude",
                    "type": "FLOAT",
                    "mode": "NULLABLE"
                },
                {
                    "name": "HaltesteigText",
                    "type": "STRING",
                    "mode": "NULLABLE"
                },
                {
                    "name": "AbfahrtszeitIst",
                    "type": "TIMESTAMP",
                    "mode": "NULLABLE"
                },
                {
                    "name": "AbfahrtszeitSoll",
                    "type": "TIMESTAMP",
                    "mode": "NULLABLE"
                },
                {
                    "name": "Fahrzeugnummer",
                    "type": "STRING",
                    "mode": "NULLABLE"
                },
                {
                    "name": "Richtungstext",
                    "type": "STRING",
                    "mode": "NULLABLE"
                },
                {
                    "name": "Besetzgrad",
                    "type": "STRING",
                    "mode": "NULLABLE"
                },
                {
                    "name": "Richtung",
                    "type": "STRING",
                    "mode": "NULLABLE"
                },
                {
                    "name": "Produkt",
                    "type": "STRING",
                    "mode": "NULLABLE"
                },
                {
                    "name": "Haltepunkt",
                    "type": "STRING",
                    "mode": "NULLABLE"
                },
                {
                    "name": "Linienname",
                    "type": "STRING",
                    "mode": "NULLABLE"
                }
            ]
    },
    {
        "name": "VAGKennung",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "Haltestellenname",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "VGNKennung",
        "type": "INTEGER",
        "mode": "NULLABLE"
    },
    {
        "name": "Metadata",
        "type": "RECORD",
        "mode": "NULLABLE",
        "fields": [
            {
                "name": "Timestamp",
                "type": "TIMESTAMP",
                "mode": "NULLABLE"
            },
            {
                "name": "Version",
                "type": "STRING",
                "mode": "NULLABLE"
            }
        ]
    },
    {
      "name": "Sonderinformationen",
      "type": "STRING",
      "mode": "REPEATED"
    }
]
EOF
    source_format             = "NEWLINE_DELIMITED_JSON"
    hive_partitioning_options {
      mode = "CUSTOM"
      source_uri_prefix        = "gs://${google_storage_bucket.vgn_departures_archive.name}/{year:INTEGER}/{month:INTEGER}/{day:INTEGER}"
      require_partition_filter = "false"
    }
    source_uris = [
      "gs://${google_storage_bucket.vgn_departures_archive.name}/*"
    ]
  }
}

# ############# #
# Cloud Storage #
# ############# #
resource "google_storage_bucket" "vgn_departures_archive" {
  name                        = "vgn-departures-archive"
  location                    = var.location
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = "true"
  force_destroy               = "true"
}

resource "google_storage_bucket" "vgn_departures_functions" {
  name                        = "vgn-departures-functions"
  location                    = var.location
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = "true"
}

data "archive_file" "enqueue_halt_ids_src" {
  type        = "zip"
  source_dir  = "departure_extractor/enqueue_halt_ids"
  output_path = "generated/enqueue_halt_ids.zip"
}

data "archive_file" "extract_departures_src" {
  type        = "zip"
  source_dir  = "departure_extractor/extract_departures"
  output_path = "generated/extract_departures.zip"
}

resource "google_storage_bucket_object" "enqueue_halt_ids" {
  name   = "${data.archive_file.enqueue_halt_ids_src.output_md5}.zip"
  bucket = google_storage_bucket.vgn_departures_functions.name
  source = data.archive_file.enqueue_halt_ids_src.output_path

  depends_on = [
    data.archive_file.enqueue_halt_ids_src,
  ]
}

resource "google_storage_bucket_object" "extract_departures_zip" {
  name   = "${data.archive_file.extract_departures_src.output_md5}.zip"
  bucket = google_storage_bucket.vgn_departures_functions.name
  source = data.archive_file.extract_departures_src.output_path

  depends_on = [
    data.archive_file.extract_departures_src,
  ]
}

# ############### #
# Cloud Functions #
# ############### #
# https://diarmuid.ie/blog/setting-up-a-recurring-google-cloud-function-with-terraform
resource "google_cloudfunctions_function" "extract_departures" {
  name        = "extract-departures"
  description = "Extracts departure information from VGN API and saves it to Cloud Storage"
  runtime     = "python310"

  environment_variables = {
    EXTRACT_URL_PATTERN = "https://start.vag.de/dm/api/v1/abfahrten/vgn/"
  }

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.vgn_departures_functions.name
  source_archive_object = google_storage_bucket_object.extract_departures_zip.name
  trigger_http          = true
  entry_point           = "main"

  depends_on = [
    google_storage_bucket.vgn_departures_functions,
    google_storage_bucket_object.extract_departures_zip,
  ]
}

resource "google_cloudfunctions_function" "enqueue_halt_ids" {
  name        = "enqueue-halt-ids"
  description = "Sends VGN halt ids to Cloud Tasks queue"
  runtime     = "python310"

  environment_variables = {
    BUCKET_NAME              = google_storage_bucket.vgn_departures_archive.name
    EXTRACT_DEPARTURES_URL   = google_cloudfunctions_function.extract_departures.https_trigger_url
    SERVICE_ACCOUNT_EMAIL    = google_service_account.vgn_departure_extractor.email
    GCP_PROJECT_ID           = var.project_id
    CLOUD_TASKS_QUEUE_REGION = google_cloud_tasks_queue.vgn_departures_queue.location
    CLOUD_TASKS_QUEUE_NAME   = google_cloud_tasks_queue.vgn_departures_queue.name
  }

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.vgn_departures_functions.name
  source_archive_object = google_storage_bucket_object.enqueue_halt_ids.name
  trigger_http          = true
  entry_point           = "main"

  depends_on = [
    google_storage_bucket.vgn_departures_archive,
    google_cloudfunctions_function.extract_departures,
    google_cloud_tasks_queue.vgn_departures_queue,
    google_service_account.vgn_departure_extractor,
    google_storage_bucket.vgn_departures_functions,
    google_storage_bucket_object.enqueue_halt_ids,
  ]
}

# ########### #
# Cloud Tasks #
# ########### #
resource "google_cloud_tasks_queue" "vgn_departures_queue" {
  name     = "vgn-departure-queue"
  location = var.region
}

# ############### #
# Cloud Scheduler #
# ############### #
resource "google_cloud_scheduler_job" "trigger_vgn_departure_extraction" {
  name        = "trigger-vgn-departure-extraction"
  description = "Trigger extraction of VGN departures every 5 minutes"
  schedule    = "*/3 5-9 * * 1-5"
  time_zone   = "Europe/Berlin"
  http_target {
    http_method = "GET"
    uri         = google_cloudfunctions_function.enqueue_halt_ids.https_trigger_url
    oidc_token {
      service_account_email = google_service_account.vgn_departure_extractor.email
    }
  }

  depends_on = [
    google_service_account.vgn_departure_extractor,
    google_cloudfunctions_function.enqueue_halt_ids,
  ]
}
