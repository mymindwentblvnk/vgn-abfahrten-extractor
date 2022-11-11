import csv

import requests
from datetime import datetime
from google.cloud import storage


def get_departures(halt_id: str) -> str:
    if halt_id:
        response = requests.get(url=f'https://start.vag.de/dm/api/v1/abfahrten/vgn/{halt_id}')
        return response.text


def upload_to_cloud_storage(bucket_name: str, file_name: str, content: str):
    storage_client = storage.Client()
    bucket = storage_client.get_bucket(bucket_name)
    blob = bucket.blob(file_name)
    blob.upload_from_string(content)


if __name__ == '__main__':
    with open('4477ebfd-a084-4826-b85b-2cd63b7caa13.csv', 'r') as data:
        reader = csv.DictReader(data)
        vgn_ids = set([r['VGNKennung'] for r in reader if r['VGNKennung']])

    now = datetime.now()
    bucket_name = 'vgn-departures'
    for index, halt_id in enumerate(vgn_ids, 1):
        file_name = f'{now.year}/{now.month}/{now.day}/{now.hour}/{halt_id}/{now.microsecond}.json'

        departures_json = get_departures(halt_id)
        upload_to_cloud_storage(bucket_name, file_name, departures_json)

        print(f"Wrote file {index}/{len(vgn_ids)}: {bucket_name}/{file_name}")
