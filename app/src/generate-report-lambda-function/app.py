import boto3
import logging
import os

from datetime import datetime
from datetime import timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)

REPORT_OBJECT_KEY_FORMAT = '%Y/%m/%d/%H%M%S%f.txt'

def lambda_handler(event, context):
    table_name = os.environ.get('DATASTORE_TABLE_NAME')
    if table_name is None:
        logger.error('Datastore table name should be configured in DATASTORE_TABLE_NAME env variable.')
        return

    total_count_item_key = os.environ.get('TOTAL_COUNT_ITEM_KEY')
    if total_count_item_key is None:
        logger.error('Total count item key should be configured in TOTAL_COUNT_ITEM_KEY env variable.')
        return

    report_bucket_name = os.environ.get('REPORT_BUCKET_NAME')
    if report_bucket_name is None:
        logger.error('Report bucket name should be configured in REPORT_BUCKET_NAME env variable.')

    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(table_name)

    response = table.get_item(
        Key={
            'PK': total_count_item_key
        }
    ) 

    item = response.get('Item')
    if item is None:
        logger.error('Database table should contains exactly one item with TOTAL_COUNT_ITEM_KEY primary key.')
        return

    total_count = item['value']

    s3 = boto3.resource('s3')

    body = str(total_count)
    report_object_key = datetime.strftime(datetime.now(timezone.utc), REPORT_OBJECT_KEY_FORMAT)

    object = s3.Object(report_bucket_name, report_object_key)
    object.put(Body=body)

    logger.info('Report stored successfuly into object \'%s\'.', report_object_key)

