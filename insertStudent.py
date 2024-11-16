import json
import boto3

# Create a DynamoDB object using the AWS SDK
dynamodb = boto3.resource('dynamodb')
# Use the DynamoDB object to select our table
table = dynamodb.Table('Student')

# Define the handler function that the Lambda service will use as an entry point
def lambda_handler(event, context):
   
    # Extract values from the event object
    student_id = event['id']
    name = event['name']
    student_class = event['class']
    age = event['age']
    
    # Write student data to the DynamoDB table and save the response
    response = table.put_item(
        Item={
            'id': student_id,
            'name': name,
            'class': student_class,
            'age': age
        }
    )
    
    # Return a success response
    return {
        'statusCode': 200,
        'body': json.dumps('Student data saved successfully!')
    }
