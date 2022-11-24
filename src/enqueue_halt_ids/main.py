import json
import os
from typing import List

import functions_framework
from google.cloud import tasks_v2

BUCKET_NAME = os.environ['BUCKET_NAME']
EXTRACT_DEPARTURES_URL = os.environ['EXTRACT_DEPARTURES_URL']
SERVICE_ACCOUNT_EMAIL = os.environ['SERVICE_ACCOUNT_EMAIL']

CLOUD_TASKS_QUEUE_NAME = os.environ['CLOUD_TASKS_QUEUE_NAME']
CLOUD_TASKS_QUEUE_REGION = os.environ['CLOUD_TASKS_QUEUE_REGION']
GCP_PROJECT_ID = os.environ['GCP_PROJECT_ID']


def enqueue_halt_ids(halt_ids: List[str]):
    client = tasks_v2.CloudTasksClient()
    parent = client.queue_path(GCP_PROJECT_ID, CLOUD_TASKS_QUEUE_REGION, CLOUD_TASKS_QUEUE_NAME)
    for halt_id in halt_ids:
        task = {
            'http_request': {
                'http_method': tasks_v2.HttpMethod.POST,
                'url': EXTRACT_DEPARTURES_URL,
                'body': json.dumps({'bucket_name': BUCKET_NAME, 'halt_id': halt_id}).encode(),
                "oidc_token": {
                    'service_account_email': SERVICE_ACCOUNT_EMAIL,
                },
            }
        }
        client.create_task(request={'parent': parent, 'task': task})


@functions_framework.http
def main(request):
    import csv
    with open('haltestellen.csv', 'r') as haltestellen_csv:
        reader = csv.DictReader(haltestellen_csv)
        halt_ids = {row['VGNKennung'] for row in reader if row['Betriebszweig'] == 'U-Bahn'}
    enqueue_halt_ids(halt_ids)
    return 'True'
