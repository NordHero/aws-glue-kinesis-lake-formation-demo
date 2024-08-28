# aws-glue-kinesis-lake-formation-demo
This repository is for setting up a basic demo for showcasing AWS Glue, Kinesis and Lake Formation 

The data in `/data/transaction_data_original.csv` is from UCI Machine Learning Repository and created by Daqing Chen. See this [link](https://archive.ics.uci.edu/dataset/352/online+retail) from details. 

The dataset is under a [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/legalcode) (CC BY 4.0) license. The dataset is modified in the file `/data/transactions_data_modified.csv` so that the `CustomerID`is replaced by an UUID from the `fake_customer_data.csv` file.