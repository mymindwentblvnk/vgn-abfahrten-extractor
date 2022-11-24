import os
from datetime import datetime

import functions_framework
import requests
from google.cloud import storage

EXTRACT_URL_PATTERN = os.environ['EXTRACT_URL_PATTERN']


def get_content(extract_url: str) -> str:
    if extract_url:
        return requests.get(url=extract_url).text


def upload_to_cloud_storage(bucket_name: str, file_name: str, content: str):
    bucket = storage.Client().get_bucket(bucket_name)
    blob = bucket.blob(file_name)
    blob.upload_from_string(content)


def generate_extract_url(halt_id: str) -> str:
    return EXTRACT_URL_PATTERN + halt_id if EXTRACT_URL_PATTERN.endswith('/') else f'{EXTRACT_URL_PATTERN}/{halt_id}'


def generate_file_name(now, halt_id):
    day = ("0" + str(now.day))[-2:]
    month = ("0" + str(now.month))[-2:]
    hours = ("0" + str(now.hour))[-2:]
    minutes = ("0" + str(now.minute))[-2:]
    seconds = ("0" + str(now.second))[-2:]
    return f'{now.year}/{month}/{day}/{halt_id}-{hours}{minutes}{seconds}.json'


@functions_framework.http
def main(request):
    json = request.get_json(force=True)
    bucket_name = json['bucket_name']
    halt_id = json['halt_id']

    if halt_id and bucket_name:
        now = datetime.now()
        extract_url = generate_extract_url(halt_id)
        file_name = generate_file_name(now, halt_id)
        departures_json = get_content(extract_url)
        upload_to_cloud_storage(bucket_name, file_name, departures_json)
    return 'True'
