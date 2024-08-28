import datetime
import sys

from awsglue import DynamicFrame
from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from awsglue.job import Job
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql import DataFrame, Row
from pyspark.sql import functions as SqlFuncs

args = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Kinesis stream data source
kinesis_data_frame = glueContext.create_data_frame.from_catalog(database="demo-database",table_name="stream-table", additional_options={"startingPosition": "earliest", "inferSchema": "false"}, transformation_ctx="kinesis_data_frame")

# Customer data catalog source
datacatalog_source = glueContext.create_dynamic_frame.from_catalog(database="demo-database", table_name="customers-table", transformation_ctx="datacatalog_source")

def processBatch(data_frame, batchId):
    if (data_frame.count() > 0):
        kinesis_dynamic_frame = DynamicFrame.fromDF(data_frame, glueContext, "from_data_frame")
        # Drop duplicates from kinesis stream
        drop_kinesis_duplicates =  DynamicFrame.fromDF(kinesis_dynamic_frame.toDF().dropDuplicates(), glueContext, "drop_kinesis_duplicates")

        # Change kinesis schema for join
        change_kinesis_schema = ApplyMapping.apply(frame=drop_kinesis_duplicates, mappings=[("invoiceno", "string", "invoiceno", "string"), ("stockcode", "string", "stockcode", "string"), ("description", "string", "description", "string"), ("quantity", "int", "quantity", "int"), ("invoicedate", "string", "invoicedate", "string"), ("unitprice", "float", "unitprice", "float"), ("customerid", "string", "customerid", "string"), ("country", "string", "order_country", "string")], transformation_ctx="change_kinesis_schema")

        # Join data from stream and customer data
        change_kinesis_schemaDF = change_kinesis_schema.toDF()
        datacatalog_source_DF = datacatalog_source.toDF()
        
        join = DynamicFrame.fromDF(change_kinesis_schemaDF.join(datacatalog_source_DF, (change_kinesis_schemaDF['customerid'] == datacatalog_source_DF['customer_id']), "left"), glueContext, "join")
        
    if join.count() > 0:
            now = datetime.datetime.now()
            year = now.year
            month = now.month
            day = now.day
            hour = now.hour
            
            destination_path = f"s3://nh-processed-pipeline-data/{year:04}/{month:02}/{day:02}/{hour:02}/"
            destination_write = glueContext.write_dynamic_frame.from_options(frame=join, connection_type="s3", format="glueparquet", connection_options={"path": destination_path, "partitionKeys": []}, transformation_ctx="destination_write")

glueContext.forEachBatch(frame = kinesis_data_frame, batch_function = processBatch, options = {"windowSize": "100 seconds", "checkpointLocation": args["TempDir"] + "/" + args["JOB_NAME"] + "/checkpoint/"})
job.commit()