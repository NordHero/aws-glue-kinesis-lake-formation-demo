data "aws_caller_identity" "current" {}

data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

data "aws_iam_policy_document" "firehose_policy_document" {
    statement {
      effect = "Allow"
      actions = [ "s3:*" ]
      resources = [ "${aws_s3_bucket.transactions_bucket.arn}/*" ]
    }
    statement {
      effect = "Allow"
      actions = [ "*" ]
      resources = [ aws_kinesis_stream.csv_stream.arn ]
    }
    statement {
      effect = "Allow"
      actions = [ "cloudwatch:*" ]
      resources = [ "*" ]
    }
}

data "aws_iam_policy_document" "glue_role_policy_document" {
    statement {
      effect = "Allow"
      actions = [ "s3:*" ]
      resources = [ 
        aws_s3_bucket.customer_data_bucket.arn,
        "${aws_s3_bucket.customer_data_bucket.arn}/*",
        aws_s3_bucket.transactions_bucket.arn,
        "${aws_s3_bucket.transactions_bucket.arn}/*",
        aws_s3_bucket.processed_data_bucket.arn,
        "${aws_s3_bucket.processed_data_bucket.arn}/*",
        aws_s3_bucket.glue_assets.arn,
        "${aws_s3_bucket.glue_assets.arn}/*"
       ]
    }
    statement {
      effect = "Allow"
      actions = [ "kinesis:*" ]
      resources = [ aws_kinesis_stream.csv_stream.arn ]
    }
    statement {
      effect = "Allow"
      actions = [ "cloudwatch:*" ]
      resources = [ "*" ]
    }
    statement {
      effect = "Allow"
      actions = [ "logs:*" ]
      resources = [ "*" ]
    }
    statement {
      effect = "Allow"
      actions = [ "lakeformation:*" ]
      resources = [ "*" ]
    }
    statement {
      effect = "Allow"
      actions = ["iam:PassRole"]
      resources = [ "*" ]
    }
}

data "aws_iam_policy_document" "data_analyst_policy_document" {
  statement {
    effect = "Allow"
    actions = [ "athena:*", "glue:*" ]
    resources = [ "*" ]
  }
  statement {
    effect = "Allow"
    actions = [ "s3:*" ]
    resources = [ aws_s3_bucket.athena_queries_bucket.arn, "${aws_s3_bucket.athena_queries_bucket.arn}/*" ]
  }
  # Amazon Athena requires IAM user to have the "lakeformation:GetDataAccess" permission when using Lake Formation
  statement {
    effect = "Allow"
    actions = [ "lakeformation:GetDataAccess" ]
    resources = [ "*" ]
  }
}