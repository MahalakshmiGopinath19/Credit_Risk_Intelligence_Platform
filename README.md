Credit Risk Intelligence Platform
📌 Project Overview
The Credit Risk Intelligence Platform is an end-to-end banking data
and machine learning project built to help understand customer credit
risk, lending behaviour, and potential loan default risk.
The platform transforms raw banking data into clean, structured,
business-ready datasets, prepares ML features for credit-risk
prediction, and presents the resulting insights through a dashboard.
The main business questions addressed are:
- Which customers have higher credit risk?
- What factors are associated with higher risk?
- How does risk vary across customer and loan segments?
- What is the likely default risk for a loan application?
- Which applications may require attention?
🎯 Objectives
- Build a structured Bronze, Silver, and Gold medallion
  architecture.
- Store raw source data in Amazon S3.
- Clean and transform banking data using Databricks.
- Build analytics-ready dimensional and fact structures in
  Snowflake.
- Prepare an ML-ready feature dataset for credit-risk prediction.
- Compare ML models using appropriate classification metrics.
- Identify important factors associated with credit risk.
- Present business and predictive insights through Power BI.
🏗️ Architecture
Source Documents
       ↓
    AWS S3
       ↓
Databricks Bronze
   (Raw Data)
       ↓
Databricks Silver
(Cleaned & Transformed)
       ↓
Snowflake Gold
(Business-Ready Data)
       ↓
Machine Learning
(Default Risk Prediction)
       ↓
Power BI Dashboard
(Business Insights)
Medallion Architecture
Bronze Layer - Stores raw data as received. - Data is maintained in
Delta tables.
Silver Layer - Cleans and standardizes the source data. - Handles
duplicates and missing values. - Applies data type transformations and
validation. - Creates customer-level enriched data.
Gold Layer - Converts cleaned data into business-ready structures. -
Uses a star-schema-based design. - Provides analytical tables and
ML-ready features.
📂 Dataset
The project uses the Home Credit Default Risk dataset.
Major source datasets include:
- Application data
- Bureau credit history
- Bureau balance history
- Previous applications
- POS Cash balance
- Credit card balance
- Installment payments
The datasets are connected mainly through customer and application
identifiers such as SK_ID_CURR and historical-record keys.
🧱 Gold Layer Data Model
The Gold layer is implemented in Snowflake using a star-schema
structure.
Fact Table
- FACT_CREDIT_RISK
Dimension Tables
- DIM_CUSTOMER
- DIM_CONTRACT_TYPE
- DIM_CUSTOMER_SEGMENT
- DIM_APPLICATION_METRICS
- DIM_SEGMENT_RISK
- DIM_CONTRACT_TYPE_RISK
ML Dataset
- ML_FEATURES
The fact table acts as the central table and connects with the dimension
tables for customer, contract, segment, application, and risk-related
analysis.
🤖 Machine Learning
The ML_FEATURES dataset contains the selected customer, loan,
credit-history, repayment, derived, and risk-related features required
for model training.
Prediction Objective
The ML task is a binary classification problem:
Predict whether a customer/application is likely to default based on
historical credit and application information.

The target variable is:
- TARGET = 0 → Non-default
- TARGET = 1 → Default
Model Evaluation
Models are evaluated using:
- Precision
- Recall
- F1-score
- ROC-AUC
- Confusion Matrix
Because default cases are the main risk class of interest, particular
attention is given to the model's ability to identify actual default
cases.
📊 Risk Analysis
The platform provides interpretable risk information through:
Risk Indicators
- Overdue Flag
- Payment Delay Flag
- High Credit Utilization Flag
- High Debt Flag
Customer Segmentation
Customers are grouped using:
- Income Segment
- Age Segment
- Credit Exposure Segment
Business Analysis
The platform supports analysis of:
- Application metrics
- Risk by customer segment
- Risk by contract type
- Credit exposure
- Debt exposure
- Default rates
- Customer risk patterns
📈 Dashboard
The Power BI dashboard presents the prepared Gold-layer and ML results
in a business-friendly format.
Key insights include:
- Total Customers
- Total Applications
- Default Rate
- Credit Exposure
- Key Risk Indicators
- Default Rate by Income Segment
- Top Risk Factors
- High-Risk Applications
- Predicted Default Risk
The dashboard helps business users understand both current credit-risk
patterns and ML-based predicted risk.
🛠️ Technology Stack
  Area               Technology
  Source Dataset     Kaggle -- Home Credit Default Risk
  Cloud Storage      Amazon S3
  Data Engineering   Databricks
  Processing         PySpark / Python
  Data Warehouse     Snowflake
  Machine Learning   Python / Snowpark ML
  Visualization      Power BI
  Development        VS Code / Jupyter
  Version Control    Git / GitHub
🔄 End-to-End Flow
Raw Banking Data
      ↓
Amazon S3
      ↓
Databricks Bronze
      ↓
Databricks Silver
      ↓
Snowflake Gold
      ↓
ML Features
      ↓
Model Training & Prediction
      ↓
Power BI
      ↓
Business Insights
📁 Project Structure
Credit-Risk-Intelligence-Platform/
│
├── data/
│   └── source data files
│
├── notebooks/
│   ├── Bronze/
│   ├── Silver/
│   └── Gold/
│
├── ml/
│   └── Credit_Risk_ML.py
│
├── dashboard/
│   └── Power BI dashboard
│
├── documentation/
│   └── project documentation
│
└── README.md
✅ Project Outcomes
- Structured raw banking data through a Bronze--Silver--Gold
  architecture.
- Created cleaned and enriched customer-level data.
- Built a reusable star-schema-based Gold data model.
- Prepared ML-ready credit-risk features.
- Developed and evaluated credit-risk classification models.
- Identified important risk factors and risk indicators.
- Created business-focused customer and loan risk analysis.
- Delivered credit-risk insights through an interactive dashboard.
🚀 Future Enhancements
- Automate the complete data ingestion and transformation workflow.
- Add model monitoring and periodic model retraining.
- Implement incremental data processing for newly arriving
  applications.
- Add real-time or near-real-time risk scoring.
- Deploy the ML model as an API for application-level predictions.
- Extend the dashboard with automated risk alerts.
👩‍💻 Project
Credit Risk Intelligence Platform
A data engineering, analytics, and machine learning solution for
understanding and predicting credit risk.
