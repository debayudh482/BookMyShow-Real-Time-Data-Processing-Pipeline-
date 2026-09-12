# 🎬 BookMyShow Real-Time Data Processing & AI Analytics Pipeline

An end-to-end **real-time data engineering pipeline** that simulates BookMyShow-style booking and payment events, processes them using **Azure Event Hubs and Azure Stream Analytics**, stores enriched transactional data in **Azure Synapse Analytics**, and automatically generates AI-powered business insights using **n8n and OpenAI**.

The project demonstrates a complete **event-driven analytics architecture**, combining real-time stream processing, SQL analytics, workflow automation, and LLM-powered reporting.

---

## 🏗️ Architecture

```text
                    ┌─────────────────────┐
                    │   Python Producers  │
                    │                     │
                    │ Booking Events      │
                    │ Payment Events      │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │    Azure Event Hub  │
                    │                     │
                    │ Booking Stream      │
                    │ Payment Stream      │
                    └──────────┬──────────┘
                               │
                               ▼
                ┌─────────────────────────────┐
                │ Azure Stream Analytics      │
                │                             │
                │ • Data Validation           │
                │ • Type Normalization        │
                │ • JavaScript UDFs           │
                │ • Tumbling Windows          │
                │ • Sliding Windows           │
                │ • Booking-Payment Join      │
                └──────────────┬──────────────┘
                               │
                               ▼
                ┌─────────────────────────────┐
                │ Azure Synapse Analytics      │
                │                             │
                │ Enriched Transaction Data   │
                │ Aggregated Business Metrics │
                └──────────────┬──────────────┘
                               │
                               ▼
                       ┌───────────────┐
                       │      n8n      │
                       │               │
                       │ SQL Queries   │
                       │ JS KPI Logic  │
                       │ Workflow      │
                       └───────┬───────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │    OpenAI Model     │
                    │                     │
                    │ Business Insights   │
                    │ Executive Summary   │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │ Outlook Email       │
                    │                     │
                    │ Weekly CXO Report   │
                    └─────────────────────┘
```

---

# 🚀 Project Overview

Modern ticket-booking platforms generate large volumes of transactional events continuously.

This project simulates a real-time BookMyShow-style system where:

* Customers create movie bookings.
* Payment events are generated independently.
* Events are streamed through Azure Event Hubs.
* Azure Stream Analytics processes the events in real time.
* Booking and payment events are correlated using time-window joins.
* Validated and enriched records are written to Azure Synapse Analytics.
* Business metrics are calculated using SQL and JavaScript.
* n8n orchestrates the reporting workflow.
* OpenAI generates an executive-level business summary.
* The final report is automatically delivered through Outlook.

---

# 🛠️ Tech Stack

| Technology                  | Purpose                                       |
| --------------------------- | --------------------------------------------- |
| **Python**                  | Mock event generation and Event Hub producers |
| **Azure Event Hubs**        | Real-time event ingestion                     |
| **Azure Stream Analytics**  | Stream processing and event correlation       |
| **JavaScript UDF**          | Custom data transformation and validation     |
| **SQL**                     | Data validation and business analytics        |
| **Azure Synapse Analytics** | Analytical data storage                       |
| **n8n**                     | Workflow orchestration                        |
| **OpenAI**                  | AI-powered business insight generation        |
| **JavaScript**              | KPI calculations and time-window analysis     |
| **Outlook**                 | Automated email delivery                      |

---

# 🔄 Data Flow

## 1. Event Generation

Python scripts continuously generate two independent event streams:

### Booking Events

Example:

```json
{
  "order_id": "ORD1001",
  "booking_id": "BK1001",
  "customer_id": "CUST501",
  "movie_id": "MOV101",
  "city": "Kolkata",
  "booking_time": "2026-09-12T18:30:10",
  "amount": 850
}
```

### Payment Events

Example:

```json
{
  "order_id": "ORD1001",
  "payment_id": "PAY9001",
  "payment_status": "SUCCESS",
  "payment_method": "UPI",
  "payment_amount": 850,
  "payment_time": "2026-09-12T18:30:15"
}
```

The two streams represent events arriving from separate transactional systems.

---

# 2. Azure Event Hubs

The generated events are continuously published to **Azure Event Hubs**.

Separate event streams are maintained for:

* Booking events
* Payment events

This simulates a real-world event-driven architecture where different transactional systems independently produce events.

---

# 3. Azure Stream Analytics

Azure Stream Analytics consumes the Event Hub streams and performs real-time processing.

### Processing includes:

* Schema validation
* Data type normalization
* Timestamp conversion
* Null/invalid value handling
* Event validation
* Booking-payment correlation
* Window-based stream joins
* Real-time enrichment

---

# 4. JavaScript UDF

Custom JavaScript User Defined Functions are used inside Stream Analytics for transformations that are easier to implement using JavaScript.

Examples include:

* Data normalization
* Validation
* Custom transformation logic
* String processing
* Business-specific rules

Conceptually:

```text
Raw Event
   ↓
JavaScript UDF
   ↓
Validated / Normalized Event
   ↓
Stream Processing
```

---

# 5. Window-Based Stream Join

Booking and payment events do not necessarily arrive at the same time.

Therefore, the pipeline uses **time-based windows** to correlate events.

For example:

```text
Booking Event
     │
     │
     │   Time Window
     │◄──────────────────►│
     │                    │
     │              Payment Event
     │
     └────── Join ────────┘
```

The join is based on a common transaction identifier such as:

```text
order_id
```

along with event-time constraints.

This allows the system to correlate transactions that occur within the defined processing window.

### Windowing strategies used

* **Tumbling Windows**
* **Sliding Windows**

These enable real-time transaction correlation and time-based analytics.

---

# 6. Azure Synapse Analytics

The processed and enriched stream is written into **Azure Synapse Analytics**.

The analytical layer contains information such as:

* Order ID
* Booking ID
* Customer ID
* Movie ID
* City
* Booking timestamp
* Payment timestamp
* Payment status
* Payment method
* Booking amount
* Payment amount
* Transaction status

This data becomes the foundation for downstream business analytics.

---

# 📊 Business Analytics

SQL queries are used to generate business KPIs from Synapse.

Example metrics include:

### Revenue

```sql
SELECT
    SUM(payment_amount) AS total_revenue
FROM booking_payment_data
WHERE payment_status = 'SUCCESS';
```

### Successful Transactions

```sql
SELECT
    COUNT(*) AS successful_transactions
FROM booking_payment_data
WHERE payment_status = 'SUCCESS';
```

### Top Performing Cities

```sql
SELECT
    city,
    SUM(payment_amount) AS revenue
FROM booking_payment_data
WHERE payment_status = 'SUCCESS'
GROUP BY city
ORDER BY revenue DESC;
```

### Conversion Rate

```text
Conversion Rate =
Successful Bookings / Total Booking Attempts × 100
```

Additional metrics can include:

* Revenue
* Booking volume
* Successful payments
* Failed payments
* Conversion rate
* Top-performing cities
* Payment-method distribution
* Revenue trends
* Recent-period performance

---

# 🤖 AI-Powered Business Intelligence Agent

The downstream reporting workflow is automated using **n8n + OpenAI**.

The workflow retrieves business metrics from Synapse and transforms them into an executive-level summary.

### Workflow

```text
Synapse
   ↓
SQL KPI Queries
   ↓
JavaScript Processing
   ↓
Time-Window Analysis
   ↓
OpenAI Chat Model
   ↓
AI Business Summary
   ↓
HTML Email
   ↓
Outlook
```

---

# ⚙️ n8n Workflow

The n8n workflow performs the following operations:

### Step 1 — Retrieve Data

Queries Synapse for relevant business metrics.

### Step 2 — KPI Processing

Custom JavaScript functions process the returned metrics.

Examples:

* Revenue calculations
* Conversion rate
* Growth comparison
* Last 7-day analysis
* City-level performance
* Payment success rate

### Step 3 — Build AI Prompt

The processed metrics are passed to the OpenAI Chat Model together with custom instructions.

The prompt is designed to make the model produce a professional business-oriented summary rather than simply returning raw numbers.

### Step 4 — Generate Executive Summary

The AI analyzes the metrics and produces insights such as:

```text
Revenue increased during the reporting period.

Kolkata and Mumbai contributed the highest revenue.

UPI represented the largest share of successful payments.

Payment failures increased during specific periods and may require further investigation.
```

### Step 5 — Generate HTML Email

The AI-generated insights are formatted into a professional HTML email.

### Step 6 — Automated Delivery

The final report is automatically sent through the Outlook integration.

---

# 🧠 AI Reporting

The AI layer is designed to convert:

```text
Raw Metrics
     ↓
Business KPIs
     ↓
Contextual Analysis
     ↓
Executive Insights
     ↓
Leadership Email
```

Instead of requiring an analyst to manually prepare weekly reports, the workflow automatically generates a business-oriented summary.

---

# 📈 Example KPIs

The system can generate metrics such as:

| KPI                 | Description                                      |
| ------------------- | ------------------------------------------------ |
| Total Revenue       | Revenue generated from successful payments       |
| Total Bookings      | Number of booking events                         |
| Successful Payments | Successfully completed transactions              |
| Failed Payments     | Transactions where payment failed                |
| Conversion Rate     | Successful bookings relative to booking attempts |
| Top City            | City generating the highest revenue              |
| Payment Method      | Distribution of payment methods                  |
| 7-Day Revenue       | Revenue generated during the recent 7-day period |
| Revenue Trend       | Change in revenue over time                      |

---

# 🔐 Security Considerations

Sensitive credentials and secrets should **not** be committed to GitHub.

The repository should use:

* Environment variables
* Azure Key Vault / secure secret storage
* n8n credentials
* `.gitignore`
* Azure managed identities where applicable

Example:

```text
.env
credentials.json
*.key
*.pem
```

These files should be excluded from version control.

---

# 📁 Repository Structure

```text
bookmyshow-realtime-data-pipeline/
│
├── architecture/
│   └── architecture.png
│
├── data-generation/
│   ├── booking_producer.py
│   └── payment_producer.py
│
├── stream-analytics/
│   ├── booking-payment-join.sql
│   ├── javascript-udf.js
│   └── README.md
│
├── synapse/
│   ├── create_tables.sql
│   └── analytics_queries.sql
│
├── n8n/
│   ├── workflow.json
│   └── README.md
│
├── sample-data/
│   ├── booking_sample.json
│   └── payment_sample.json
│
├── screenshots/
│   ├── event-hub.png
│   ├── stream-analytics.png
│   ├── synapse.png
│   ├── n8n-workflow.png
│   └── ai-email.png
│
├── .gitignore
└── README.md
```

---

# ▶️ How to Run

## Prerequisites

You should have access to:

* Azure subscription
* Azure Event Hubs
* Azure Stream Analytics
* Azure Synapse Analytics
* Python 3.x
* n8n
* OpenAI API access
* Outlook integration

---

## Step 1 — Configure Azure Event Hubs

Create Event Hubs for:

```text
booking-events
payment-events
```

Configure the required connection information securely.

---

## Step 2 — Run Python Producers

Install dependencies:

```bash
pip install azure-eventhub
```

Run the booking producer:

```bash
python booking_producer.py
```

Run the payment producer:

```bash
python payment_producer.py
```

The producers continuously publish events to Event Hubs.

---

## Step 3 — Configure Stream Analytics

Configure:

```text
Event Hub Inputs
        ↓
Stream Analytics Query
        ↓
Synapse Output
```

Add the required JavaScript UDFs and configure the booking/payment window join.

---

## Step 4 — Configure Synapse

Create the required destination tables using the SQL scripts provided in:

```text
/synapse/create_tables.sql
```

---

## Step 5 — Configure n8n

Import:

```text
/n8n/workflow.json
```

Configure:

* Synapse/database credentials
* OpenAI credentials
* Outlook credentials

Then activate the workflow.

---

# 📸 Screenshots

The repository contains screenshots demonstrating the major components of the project.

### Azure Event Hubs

![Event Hubs](screenshots/event-hub.png)

### Azure Stream Analytics

![Stream Analytics](screenshots/stream-analytics.png)

### Azure Synapse Analytics

![Synapse](screenshots/synapse.png)

### n8n Workflow

![n8n Workflow](screenshots/n8n-workflow.png)

### AI-Generated Executive Email

![AI Email](screenshots/ai-email.png)

---

# 🎯 Key Engineering Concepts Demonstrated

This project demonstrates practical understanding of:

* Real-time data ingestion
* Event-driven architecture
* Azure Event Hubs
* Stream processing
* Azure Stream Analytics
* Event-time processing
* Tumbling windows
* Sliding windows
* Stream-to-stream joins
* JavaScript UDFs
* Data validation
* Data type normalization
* Azure Synapse Analytics
* SQL analytics
* KPI computation
* Workflow orchestration
* n8n automation
* LLM integration
* AI-powered business reporting
* Automated email delivery

---

# 💡 Why This Project Is Relevant to Data Engineering

The project combines multiple layers of a modern data platform:

```text
                    DATA ENGINEERING
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
   Data Ingestion    Data Processing    Data Storage
        │                 │                 │
   Event Hubs       Stream Analytics     Synapse
        │                 │                 │
        └─────────────────┼─────────────────┘
                          │
                     BI / Analytics
                          │
                         n8n
                          │
                     AI / LLM
                          │
                   Business Insights
```

This makes the project representative of a modern cloud data engineering workflow rather than a standalone SQL or ETL project.

---

# 🔮 Future Improvements

Potential improvements include:

* Implementing Azure Data Factory for batch ingestion
* Adding Databricks/Spark processing for large-scale historical data
* Implementing Delta Lake architecture
* Adding CI/CD using Azure DevOps or GitHub Actions
* Adding monitoring and alerting
* Implementing dead-letter handling for invalid events
* Adding schema evolution
* Introducing customer-level analytics
* Adding a Power BI dashboard
* Implementing automated anomaly detection
* Adding historical trend analysis
* Introducing a semantic layer for the AI agent

---

# 👨‍💻 Author

**Debayudh Kundu**

B.Tech — Computer Science & Engineering

Interested in:

* Data Engineering
* Azure Data Engineering
* Cloud Data Platforms
* Real-Time Data Processing
* Data Analytics
* AI-powered Data Applications

---

## ⭐ Project Highlights

> **Real-time Azure pipeline + Stream Processing + Synapse Analytics + n8n Automation + OpenAI-powered Business Intelligence**

This project demonstrates how streaming transactional data can be transformed into **real-time analytical data and automated executive insights** using modern cloud data engineering technologies.
