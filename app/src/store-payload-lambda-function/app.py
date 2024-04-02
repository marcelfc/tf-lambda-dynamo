import boto3
import logging
import os
import time
import uuid

from http import HTTPStatus

HTTP_METHOD = 'POST'
HTTP_PATH = '/'

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def status_code(status_code):
    return {
        'status_code': status_code
    }

def bad_request():
    return status_code(HTTPStatus.BAD_REQUEST)

def not_found():
    return status_code(HTTPStatus.NOT_FOUND)

def internal_server_error():
    return status_code(HTTPStatus.INTERNAL_SERVER_ERROR)

def ok():
    return status_code(HTTPStatus.OK)

def lambda_handler(event, context):
    requestContext = event.get('requestContext')
    if requestContext is None:
        logger.error('Property \'requestContext\' not found in the Lambda event payload.')
        return internal_server_error()

    http = requestContext.get('http')
    if http is None: 
        logger.error('Property \'http\' not found in the Lambda event payload.')
        return internal_server_error()

    method = http.get('method')
    path = http.get('path')
    
    if method != HTTP_METHOD or path != HTTP_PATH:
        logger.warn('Handler supports only %s %s requests.', HTTP_METHOD, HTTP_PATH)
        return not_found()

    body = event.get('body')
    if body is None:
        return bad_request()

    # get table name from env variables
    table_name = os.environ.get('DATASTORE_TABLE_NAME')
    if table_name is None:
        logger.error('Datastore table name should be configured in DATASTORE_TABLE_NAME env variable.')
        return internal_server_error()

    # get TOTAL_COUNT item key from env variables
    total_count_item_key = os.environ.get('TOTAL_COUNT_ITEM_KEY')
    if total_count_item_key is None:
        logger.error('TOTAL_COUNT item key should be configured in TOTAL_COUNT_ITEM_KEY env variable.')
        return internal_server_error()

    # put new payload and increment total count in one transaction
    dynamodb = boto3.client('dynamodb')

    payload_id = f'PAYLOAD-{str(uuid.uuid4()).upper()}'
    created_at = str(time.time())

    dynamodb.transact_write_items(
        TransactItems=[
            {
                'Put': {
                    'TableName': table_name,
                    'Item': {
                        'PK': {
                            'S': payload_id
                        },
                        'created_at': {
                            'N': created_at
                        },
                        'content': {
                            'S': body
                        }
                    }
                }
            },
            {
                'Update': {
                    'TableName': table_name,
                    'Key': {
                        'PK': {
                            'S': total_count_item_key
                        }
                    },
                    'ExpressionAttributeNames': {
                        '#value': 'value'
                    },
                    'ExpressionAttributeValues': {
                        ':increase': {
                            'N': '1'
                        }
                    },
                    'UpdateExpression': 'SET #value = #value + :increase'
                }
            }
        ]
    ) 

    logger.info('Payload stored into the datastore successfully.')

    return ok()