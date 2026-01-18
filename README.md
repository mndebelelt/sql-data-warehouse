# SQL Data Warehouse Project (Medallion Architecture)

This project demonstrates the design and implementation of a modern **SQL Server-based data warehouse** using the **Bronze / Silver / Gold (Medallion) architecture**.  
It simulates ingesting data from multiple operational sources (CRM and ERP), transforming it through structured layers, and producing analytics-ready datasets.

---
## 🏗️ Data Architecture

1. **Bronze Layer**: Raw ingestion of source data with minimal transformation 
2. **Silver Layer**: Cleansed, standardized, and conformed datasets  
3. **Gold Layer**: Business-ready dimensional model (facts and dimensions)


Architecture diagrams and data models are available in the `/docs` folder.
---

## 📖 Project Overview

This project involves:

1. **Data Architecture**: Designing a Modern Data Warehouse using **Bronze**, **Silver**, and **Gold** layers.
2. **ETL Pipelines**: Extracting, transforming, and loading data from source systems into the warehouse.
3. **Data Modeling**: Developing fact and dimension tables optimized for analytical queries.
---

---

## 🚀 Project Requirements

### Building the Data Warehouse (Data Engineering)

#### Objective
Develop a modern data warehouse using SQL Server to consolidate sales data, enabling analytical reporting and informed decision-making.

#### Specifications
- **Data Sources**: Import data from two source systems (ERP and CRM) provided as CSV files.
- **Data Quality**: Cleanse and resolve data quality issues prior to analysis.
- **Integration**: Combine both sources into a single, user-friendly data model designed for analytical queries.
- **Scope**: Focus on the latest dataset only; historization of data is not required.
- **Documentation**: Provide clear documentation of the data model to support both business stakeholders.

---


## 📂 Repository Structure
```
data-warehouse-project/
│
├── datasets/                           # Raw datasets used for the project (ERP and CRM data)
│
├── docs/                               # Project documentation and architecture details
│   ├── high_level_architecture.png        # The high level architecture overview
│   ├── data_catalog.md                 # Catalog of datasets, including field descriptions and metadata
│   ├── data_models.png              # Data models
│ 
│
├── scripts/                            # SQL scripts for ETL and transformations
│   ├── bronze/                         # Scripts for extracting and loading raw data
│   ├── silver/                         # Scripts for cleaning and transforming data
│   ├── gold/                           # Scripts for creating analytical models
│
├── tests/                              # Test scripts
│
└──README.md                           # Project overview and instructions
```
---


## Prerequisites
- SQL Server
- SQL Server Management Studio (SSMS) or Azure Data Studio

## Credits
This project is based on the guided SQL Data Warehouse project by **Data With Baraa**.
I used it as a learning foundation and extended it. 