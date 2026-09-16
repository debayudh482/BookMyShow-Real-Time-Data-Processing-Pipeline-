# Architecture & Data Flow

## Overview

The BookMyShow Real-Time Data Processing Pipeline is an event-driven analytics architecture designed to process booking and payment events in real time.

The pipeline combines **Python, Azure Event Hubs, Azure Stream Analytics, Azure Synapse Analytics, n8n, JavaScript, and an LLM** to transform raw transactional events into automated business insights.

---

## High-Level Architecture

```text
                         ┌──────────────────────┐
                         │   Python Event       │
                         │     Generators       │
                         └──────────┬───────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
                    ▼                               ▼
           ┌────────────────┐              ┌────────────────┐
           │ Booking Events │              │ Payment Events │
           └───────┬────────┘              └───────┬────────┘
                   │                               │
                   └───────────────┬───────────────┘
                                   ▼
                         ┌─────────────────────┐
                         │    Azure Event Hubs │
                         │                     │
                         │ booking-events      │
                         │ payment-events      │
                         └──────────┬──────────┘
                                    │
                                    ▼
                       ┌─────────────────────────┐
                       │ Azure Stream Analytics  │
                       │                         │
                       │ • Input Processing      │
                       │ • Data Validation       │
                       │ • JS UDFs               │
                       │ • Type Normalization    │
                       │ • Window Joins          │
                       └────────────┬────────────┘
                                    │
                                    ▼
                       ┌─────────────────────────┐
                       │ Azure Synapse Analytics │
                       │                         │
                       │ • Fact Tables           │
                       │ • KPI Views             │
                       │ • Analytical Queries    │
                       └────────────┬────────────┘
                                    │
                                    ▼
                              ┌───────────┐
                              │    n8n    │
                              │ BI Agent  │
                              └─────┬─────┘
                                    │
                    ┌───────────────┼────────────────┐
                    │               │                │
                    ▼               ▼                ▼
              Synapse SQL      JavaScript          LLM
               KPI Queries      Processing       Analysis
                    │               │                │
                    └───────────────┼────────────────┘
                                    ▼
                         ┌─────────────────────┐
                         │ HTML Email Creation │
                         └──────────┬──────────┘
                                    ▼
                              ┌──────────┐
                              │ Outlook  │
                              └────┬─────┘
                                   ▼
                         ┌─────────────────────┐
                         │ Leadership Insights │
                         │       Email         │
                         └─────────────────────┘
```

---

## 1. Event Generation Layer

Mock transactional events are generated using Python to simulate a real-world movie booking platform.

Two independent event streams are produced:

### Booking Events

Contains information such as:

* `order_id`
* `booking_id`
* `booking_time`
* customer information
* movie information
* city
* booking amount

### Payment Events

Contains information such as:

* `order_id`
* payment information
* payment amount
* payment status
* payment timestamp

The shared `order_id` acts as the primary correlation key between booking and payment events.

---

## 2. Event Streaming Layer — Azure Event Hubs

The generated events are continuously published to **Azure Event Hubs**.

```text
Python
  │
  ├── Booking Producer ──► booking-events
  │
  └── Payment Producer ──► payment-events
```

Event Hubs provides the streaming ingestion layer between the simulated transactional systems and the downstream real-time processing layer.

This allows booking and payment events to arrive independently and be processed as they occur.

---

## 3. Stream Processing Layer — Azure Stream Analytics

Azure Stream Analytics consumes the Event Hub streams and performs real-time processing.

### Processing steps

```text
Raw Events
    │
    ▼
Input Streams
    │
    ▼
Validation
    │
    ▼
JavaScript UDFs
    │
    ▼
Type Normalization
    │
    ▼
Window-Based Join
    │
    ▼
Enriched Transaction
    │
    ▼
Synapse Output
```

### JavaScript UDFs

JavaScript User Defined Functions are used for operations such as:

* data cleaning
* validation
* type normalization
* field transformation

This allows transformation logic to be applied directly within the streaming pipeline.

---

## 4. Window-Based Event Correlation

Booking and payment events are generated independently, so they cannot simply be joined as static database records.

The Stream Analytics job uses **time-based windows** to correlate events.

```text
Booking Event
      │
      │ order_id
      │
      ▼
┌─────────────────────────────┐
│       Time Window           │
│                             │
│ Booking ──────► Payment     │
│                             │
│ Same order_id               │
│ Within allowed time range   │
└─────────────────────────────┘
```

The pipeline uses:

### Tumbling Window

Used for fixed, non-overlapping time intervals.

```text
|---------|---------|---------|
 Window 1   Window 2   Window 3
```

### Sliding Window

Used when overlapping time intervals are required.

```text
|---------------|
       |---------------|
              |---------------|
```

The streaming join uses the event timestamps associated with the incoming records rather than the time at which the records eventually arrive in Synapse.

---

## 5. Data Storage & Analytics — Azure Synapse

After real-time processing and enrichment, the resulting data is written into **Azure Synapse Analytics**.

The Synapse layer provides the analytical storage and SQL querying layer for downstream business intelligence.

Example logical flow:

```text
Booking Events
       +
Payment Events
       │
       ▼
Enriched Transactions
       │
       ▼
Synapse Fact Tables
       │
       ▼
SQL Aggregations / Views
```

Typical business metrics include:

* total revenue
* booking volume
* successful payments
* conversion rate
* top-performing cities
* recent transaction activity

A revenue summary view can also be used to expose aggregated metrics to downstream automation.

---

## 6. AI-Powered BI Automation — n8n

n8n acts as the workflow orchestration and automation layer.

The BI workflow retrieves business metrics from Synapse and prepares them for LLM-based analysis.

```text
Synapse
   │
   ▼
SQL KPI Query
   │
   ▼
JavaScript Processing
   │
   ▼
Time-Window Analysis
   │
   ▼
LLM
   │
   ▼
Business Summary
   │
   ▼
HTML Email
   │
   ▼
Outlook
```

### JavaScript Processing

Custom JavaScript functions are used within the n8n workflow for:

* KPI calculations
* formatting metrics
* time-window analysis
* preparing structured data for the LLM

For example, the workflow can prepare metrics for a recent 7-day period before sending them to the language model.

---

## 7. LLM Business Insight Generation

The processed KPI data is passed to an LLM through n8n.

The workflow uses separate system and user prompts to control how the model interprets the supplied metrics.

The LLM receives structured business information and generates a professional leadership-oriented summary.

Example logical input:

```text
Revenue: ₹XX,XXX
Bookings: XXXX
Conversion Rate: XX.X%
Top City: Kolkata
7-Day Revenue Growth: XX.X%
```

The generated response is then formatted as an HTML email.

> The LLM is used for business-language generation and insight summarization; the underlying KPI values are calculated from the data pipeline and SQL/JavaScript processing.

---

## 8. Automated Email Delivery

The final stage of the workflow sends the generated business summary through the Outlook integration.

```text
KPI Data
   ↓
LLM Analysis
   ↓
Professional HTML Summary
   ↓
Outlook
   ↓
Leadership Email
```

This removes the need for manually preparing and distributing recurring business reports.

---

# Architecture Components

| Layer               | Technology              | Responsibility                           |
| ------------------- | ----------------------- | ---------------------------------------- |
| Event Generation    | Python                  | Generate mock booking/payment events     |
| Streaming Ingestion | Azure Event Hubs        | Receive real-time events                 |
| Stream Processing   | Azure Stream Analytics  | Validate, transform and correlate events |
| Transformation      | JavaScript UDFs         | Cleaning and normalization               |
| Event Correlation   | ASA Windows             | Join booking/payment events              |
| Analytics Storage   | Azure Synapse Analytics | Store processed data                     |
| Analytics           | SQL                     | Calculate business KPIs                  |
| Workflow Automation | n8n                     | Orchestrate BI workflow                  |
| Custom Processing   | JavaScript              | KPI and time-window calculations         |
| AI                  | LLM                     | Generate business summaries              |
| Email Delivery      | Outlook                 | Distribute automated insights            |

---

# Architecture Screenshots

## 1. Azure Event Hubs

Shows the event streaming infrastructure used to receive booking and payment events.

![Event Hubs](screenshots/01-event-hub.png)

---

## 2. Azure Stream Analytics

Shows the configured Stream Analytics job and its streaming inputs/outputs.

![Stream Analytics](screenshots/02-stream-analytics.png)

---

## 3. Stream Analytics Query

Shows the real-time SQL processing logic, including validation, transformation and window-based event correlation.

![Stream Analytics Query](screenshots/03-asa-query.png)

---

## 4. Azure Synapse Analytics

Shows the downstream analytical tables/views receiving the processed streaming data.

![Synapse Analytics](screenshots/04-synapse.png)

---

## 5. n8n AI Workflow

Shows the automated workflow connecting Synapse KPI data, JavaScript processing, LLM analysis and email generation.

![n8n Workflow](screenshots/05-n8n-workflow.png)

---

## 6. Automated Leadership Email

Shows the final AI-generated business insight email delivered through Outlook.

![Leadership Email](screenshots/06-final-email.png)

---

# End-to-End Data Flow

The complete pipeline can be summarized as:

```text
Python
  │
  ▼
Booking / Payment Events
  │
  ▼
Azure Event Hubs
  │
  ▼
Azure Stream Analytics
  │
  ├── Validation
  ├── JavaScript UDFs
  ├── Type Normalization
  └── Window-Based Joins
  │
  ▼
Azure Synapse Analytics
  │
  ├── Fact Tables
  ├── SQL Views
  └── KPI Queries
  │
  ▼
n8n
  │
  ├── Retrieve KPIs
  ├── JavaScript Processing
  ├── 7-Day Analysis
  └── LLM
  │
  ▼
HTML Business Summary
  │
  ▼
Outlook
  │
  ▼
Automated Leadership Insights
```

## Key Engineering Concepts Demonstrated

* Event-driven architecture
* Real-time streaming ingestion
* Azure Event Hubs
* Azure Stream Analytics
* JavaScript UDFs
* Event-time processing
* Tumbling and sliding windows
* Streaming joins
* Azure Synapse Analytics
* SQL-based KPI generation
* Workflow automation with n8n
* JavaScript-based data transformation
* LLM-assisted business reporting
* Automated email delivery
* End-to-end cloud data engineering
