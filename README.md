# VGN Departure Extractor

The VGN Departure Extractor is a data pipeline that
extracts departure information from Nuremberg's
public transport company VGN and saves it to Google Cloud Storage.
The whole pipeline can easily be deployed to Google Cloud
Platform (GCP) with Terraform.

## Architecture

GCP resources used in this are
[Cloud Scheduler](https://cloud.google.com/scheduler),
[Cloud Functions](https://cloud.google.com/functions),
[Cloud Tasks](https://cloud.google.com/tasks), and
[Cloud Storage](https://cloud.google.com/storage).

![Data Pipeline Architecture](docu/pictures/pipeline.jpg)

## Deployment

You need a GCP project with billing enabled. Also create a
Service Account with the role _Owner_. Export a Key as JSON file
and refer it in the following environment variables.

```bash
export TF_VAR_credentials_file=path/to/service/account.json
export TF_VAR_project_id=my-gcp-project
```

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

After `terraform apply` was executed successfully, the pipeline
is executing automatically as defined in the [Cloud Scheduler](main.tf).