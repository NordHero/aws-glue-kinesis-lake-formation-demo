resource "aws_s3_bucket" "transactions_bucket" {
  bucket = "nh-transactions-data-bucket"
}

resource "aws_s3_bucket" "customer_data_bucket" {
  bucket = "nh-customer-data-bucket"
}

resource "aws_s3_object" "customer_data_object" {
    bucket = aws_s3_bucket.customer_data_bucket.id
    key = "customer-data.csv"
    source = "../data/fake_customer_data.csv"
}

resource "aws_kinesis_stream" "csv_stream" {
  name = "transaction_data_stream"
  retention_period = 24

  shard_level_metrics = [ 
    "IncomingBytes", "OutgoingBytes"
   ]

   stream_mode_details {
     stream_mode = "ON_DEMAND"
   }
}

resource "aws_iam_role" "firehose_role" {
  name = "firehose-delivery-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
                Service = "firehose.amazonaws.com"
            }
        }
    ]
  })
}

resource "aws_iam_role_policy" "firehose_policy" {
  name = "firehose-delivery-policy"
  policy = data.aws_iam_policy_document.firehose_policy_document.json
  role = aws_iam_role.firehose_role.id
}

resource "aws_cloudwatch_log_group" "firehose_log_group" {
  name = "/aws/kinesisfirehose/csv-firehose-delivery-stream"
  retention_in_days = 1
}

resource "aws_cloudwatch_log_stream" "firehose_log_stream" {
  name = "DeliveryStream"
  log_group_name = aws_cloudwatch_log_group.firehose_log_group.name
}

resource "aws_kinesis_firehose_delivery_stream" "firehose_stream" {
  name = "csv-firehose-delivery-stream"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.transactions_bucket.arn
    buffering_interval = 5
    cloudwatch_logging_options {
      enabled = true
      log_group_name = aws_cloudwatch_log_group.firehose_log_group.name
      log_stream_name = aws_cloudwatch_log_stream.firehose_log_stream.name
    }
  }

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.csv_stream.arn
    role_arn = aws_iam_role.firehose_role.arn
  }
}
