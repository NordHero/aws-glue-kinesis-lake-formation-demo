resource "aws_s3_bucket" "glue_assets" {
  bucket = "nh-data-demo-glue-assets"
}

resource "aws_s3_bucket" "athena_queries_bucket" {
  bucket = "athena-queries-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_object" "glue_jobs" {
  for_each = fileset("../glue_jobs/", "*")

  bucket = aws_s3_bucket.glue_assets.id
  key = "/scripts/${each.value}"
  source = "../glue_jobs/${each.value}"
}

resource "aws_s3_bucket" "processed_data_bucket" {
  bucket = "nh-processed-pipeline-data"
}

resource "aws_iam_role" "glue_role" {
    name = "glue-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = {
                    Service = "glue.amazonaws.com"
                }
            }
        ]
    })
  
}

resource "aws_iam_role_policy" "glue_policy" {
    name = "glue-policy"
    policy = data.aws_iam_policy_document.glue_role_policy_document.json
    role = aws_iam_role.glue_role.id
}

resource "aws_iam_role_policy_attachment" "glue_service_role_policy_attachment" {
    role = aws_iam_role.glue_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_glue_catalog_database" "demo_db" {
  name = "demo-database"
  description = "Database for Kinesis, Lake Formation and Glue demo"
}

resource "aws_glue_catalog_table" "customer_data_table" {
  name = "customers-table"
  database_name = aws_glue_catalog_database.demo_db.name
  parameters = {
    classification = "csv"
  }
  storage_descriptor {
    location = "s3://${aws_s3_bucket.customer_data_bucket.bucket}/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.OpenCSVSerde"
      parameters = {
        "separatorChar" = ","
        "quoteChar"     = "\""
      }
    }
    columns {
      name = "customer_id"
      type = "string" 
    }
    columns {
      name = "first_name"
      type = "string"
    }
    columns {
      name = "last_name"
      type = "string"
    }
    columns {
      name = "email_address"
      type = "string"
    }
    columns {
      name = "phone_number"
      type = "string"
    }
    columns {
      name = "address"
      type = "string"
    }
    columns {
      name = "city"
      type = "string"
    }
    columns {
      name = "state"
      type = "string"
    }
    columns {
      name = "zip_code"
      type = "string"  
    }
    columns {
      name = "country"
      type = "string"
    }
    columns {
      name = "date_of_birth"
      type = "string" 
    }
    columns {
      name = "gender"
      type = "string"
    }
    columns {
      name = "registration_rate"
      type = "string"  
    }
  }
  
}
resource "aws_glue_catalog_table" "transaction_data_table" {
  name = "transaction-table"
  database_name = aws_glue_catalog_database.demo_db.name
  parameters = {
    classification = "csv"
  }
  storage_descriptor {
    location = "s3://${aws_s3_bucket.transactions_bucket.bucket}/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.OpenCSVSerde"
      parameters = {
        "separatorChar" = ","
        "quoteChar"     = "\""
      }
    }
    columns {
      name = "invoiceno"
      type = "string"
    }
    columns {
      name = "stockcode"
      type = "string"
    }
    columns {
      name = "description"
      type = "string"
    }
    columns {
      name = "quantity"
      type = "int"
    }
    columns {
      name = "invoicedate"
      type = "string"
    }
    columns {
      name = "unitprice"
      type = "float"
    }
    columns {
      name = "customerid"
      type = "string"
    }
    columns {
      name = "country"
      type = "string"
    }
  }
}

resource "aws_glue_catalog_table" "stream_data_table" {
  name = "stream-table"
  database_name = aws_glue_catalog_database.demo_db.name
  parameters = {
    classification = "csv"
  }
  
  storage_descriptor {
    location = aws_kinesis_stream.csv_stream.name
    parameters = {
      typeOfData = "kinesis",
      streamARN = aws_kinesis_stream.csv_stream.arn
    }
    columns {
      name = "invoiceno"
      type = "string"
    }
    columns {
      name = "stockcode"
      type = "string"
    }
    columns {
      name = "description"
      type = "string"
    }
    columns {
      name = "quantity"
      type = "int"
    }
    columns {
      name = "invoicedate"
      type = "string"
    }
    columns {
      name = "unitprice"
      type = "float"
    }
    columns {
      name = "customerid"
      type = "string"
    }
    columns {
      name = "country"
      type = "string"
    }
  }
}

resource "aws_cloudwatch_log_group" "streaming_job_logs" {
  name = "streaming-job-logs"
  retention_in_days = 1
}

resource "aws_glue_job" "stream_join_job" {
  name = "stream-join-job"
  role_arn = aws_iam_role.glue_role.arn
  glue_version = "4.0"
  worker_type = "G.025X"
  number_of_workers = 2
  max_retries = 0

  command {
    name = "gluestreaming"
    script_location = "s3://${aws_s3_bucket.glue_assets.bucket}/scripts/stream_join_job.py"
  }
  default_arguments = {
    "--continuous-log-logGroup"          = aws_cloudwatch_log_group.streaming_job_logs.name
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"                   = "true"
    "--TempDir" = "s3://${aws_s3_bucket.glue_assets.bucket}/temp/"
    "--job-language" = "python",
    "--enable-glue-datacatalog" = "true",
    "--job-bookmark-option" = "job-bookmark-disable"
  }
}

resource "aws_glue_crawler" "processed_data_crawler" {
  name         = "processed-data-crawler"
  # A seperate IAM role for the crawler can also be created
  role         = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.demo_db.name
  
  s3_target {
    path = "s3://${aws_s3_bucket.processed_data_bucket.bucket}/"
  }

  recrawl_policy {
    recrawl_behavior = "CRAWL_EVERYTHING"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "DEPRECATE_IN_DATABASE"
  }

  lake_formation_configuration {
    use_lake_formation_credentials = true
  }

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Tables = {
        TableThreshold = 1
      }
    }
    CreatePartitionIndex = true
  })
}
