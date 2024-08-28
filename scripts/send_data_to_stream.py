import argparse
import csv
import time

import boto3


class Variables():
    csv_file_path = '../data/transaction_data_modified.csv'
    kinesis_client = boto3.client('kinesis', region_name='eu-west-1')

def arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("--stream-name", "-sn", required=True, help="Name of the Kinesis Data Stream")
    parser.add_argument("--interval", "-i", type=int, required=True, help="Time interval (in seconds) between two writes")
    parser.add_argument("--max-rows", "-mr", type=int, default=150, help="Maximum number of rows to write (max: 150)")
    args = parser.parse_args()

    return args


def send_csv_to_kinesis(stream_name, interval, max_rows, csv_file=Variables.csv_file_path):
    client = Variables.kinesis_client

    with open(csv_file, 'r') as file:
        csv_reader = csv.reader(file)
        next(csv_reader)  # Skip the header row

        rows_written = 0
        for row in csv_reader:
            invoice_id = row[0]  # First column contains the invoice ID
            partition_key = invoice_id
            data = ','.join(row)
            encoded_data = f"{data}\n".encode('utf-8')  # Encode the data as bytes
            
            response = client.put_record(
                StreamName=stream_name,
                Data=encoded_data,
                PartitionKey=partition_key
            )
            print(f"Record sent to shard: {response}")

            time.sleep(interval)

            rows_written += 1
            if rows_written >= max_rows:
                break

args = arguments()

send_csv_to_kinesis(args.stream_name, args.interval, args.max_rows)