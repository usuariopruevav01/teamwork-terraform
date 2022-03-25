import pandas as pd
import requests
from requests.auth import HTTPBasicAuth
from google.cloud import bigquery
from google.oauth2 import service_account
import json
import os

def send_data_bq(event, context):
    """Triggered from a message on a Cloud Pub/Sub topic.
    Args:
         event (dict): Event payload.
         context (google.cloud.functions.Context): Metadata for the event.
    """

    # KEYS FOR BASIC AUTHENTICATION
    
    USERNAME = os.environ.get('USERNAME')  # Personal Teamwork API Key
    PASSWORD = os.environ.get('PASSWORD')

    # CONSTANTS
    TEAMWORK_PROJECT_ID = os.environ.get('TEAMWORK_PROJECT_ID')
    KEY_PATH = 'gcpcredentials.json'
    TABLE_ID = os.environ.get('TABLE_ID')

    # URLS
    tasks_url = 'https://attachlatam.eu.teamwork.com/projects/{}/tasks.json'
    task_time_url = 'https://attachlatam.eu.teamwork.com/tasks/{}/time/total.json'

    # AUTH
    AUTH = HTTPBasicAuth(USERNAME, PASSWORD)

    # TASKS REQUEST
    tasks_response = requests.get(tasks_url.format(TEAMWORK_PROJECT_ID), auth=AUTH)
    tasks = tasks_response.json()

    new_tasks = []

    for task in tasks['todo-items']:
        task_times_response = requests.get(
            task_time_url.format(task['id']), auth=AUTH)
        task_times = task_times_response.json(
        )['projects'][0]['tasklist']['task']

        filtered_task = {
            'id': task['id'],
            'project_id': task['project-id'],
            'created_on': task['created-on'],
            'start_date': task['start-date'],
            'due_date': task['due-date'],
            'status': task['status'],
            'creator_id': task['creator-id'],
            'creator_fullname': task['creator-firstname'] + ' ' + task['creator-lastname'],
            'responsible_party_ids': task['responsible-party-ids'] if 'responsible-party-ids' in task  else '',
            'responsible_names': task['responsible-party-names'] if 'responsible-party-names' in task else '',
            'progress': task['progress'],
            'description': task['description'],
            'estimated_hours': task_times['time-estimates']['total-hours-estimated'],
            'total_hours': task_times['time-totals']['total-hours-sum'],
            'billable_hours': task_times['time-totals']['billable-hours-sum'],
            'non_billable_hours': task_times['time-totals']['non-billable-hours-sum'],
        }
        new_tasks.append(filtered_task)

    # DATAFRAME
    dtypes = {
        'id': str,
        'project_id': str,
        'created_on': str,
        'start_date': str,
        'due_date': str,
        'status': str,
        'creator_id': str,
        'creator_fullname': str,
        'responsible_party_ids': str,
        'responsible_names': str,
        'progress': int,
        'description': str,
        'estimated_hours': float,
        'total_hours': float,
        'billable_hours': float,
        'non_billable_hours': float,
    }

    df = pd.DataFrame.from_dict(new_tasks).astype(dtypes)

    # BIGQUERY AUTHENTICATION
    credentials = service_account.Credentials.from_service_account_file(
        KEY_PATH, scopes=["https://www.googleapis.com/auth/cloud-platform"],
    )
    client = bigquery.Client(credentials=credentials,
                             project=credentials.project_id)

    # BIGQUERY TABLE CREATION FROM A DATAFRAME
    job_config = bigquery.LoadJobConfig(write_disposition='WRITE_TRUNCATE')
    job = client.load_table_from_dataframe(df, TABLE_ID, job_config=job_config)