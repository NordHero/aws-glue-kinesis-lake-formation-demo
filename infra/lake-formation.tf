resource "aws_iam_role" "data_analyst_role" {
  name = "data-analyst-role"
  description = "Example IAM role for a data analyst with limited Lake Formation permissions"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
                AWS = "arn:aws:iam::905418179990:root"
            }
        }
    ]
  })
}

resource "aws_iam_role_policy" "attach_data_analyst_policy" {
  name = "data-analyst-policy"
  policy = data.aws_iam_policy_document.data_analyst_policy_document.json
  role = aws_iam_role.data_analyst_role.name
  
}

resource "aws_lakeformation_resource" "processed_data_bucket_lf" {
  arn = aws_s3_bucket.processed_data_bucket.arn
}

resource "aws_lakeformation_data_lake_settings" "lf_admin" {
  admins = [ data.aws_iam_session_context.current.issuer_arn, aws_iam_role.glue_role.arn ]
}

resource "aws_lakeformation_permissions" "glue_database_permissions" {
  principal = aws_iam_role.glue_role.arn
  permissions = [ "ALL" ]
  permissions_with_grant_option = [ "ALL" ]
  
  database {
    name = aws_glue_catalog_database.demo_db.name
  }
}

resource "aws_lakeformation_permissions" "glue_tables_permissions" {
  principal = aws_iam_role.glue_role.arn
  permissions = [ "ALL" ]
  permissions_with_grant_option = [ "ALL" ]
  
  table {
    database_name = aws_glue_catalog_database.demo_db.name
    wildcard = true
  }
}

resource "aws_lakeformation_permissions" "processed_data_glue_permissions" {
  principal = aws_iam_role.glue_role.arn
  permissions = [ "DATA_LOCATION_ACCESS" ]

  data_location {
    arn = aws_lakeformation_resource.processed_data_bucket_lf.arn
  }
}