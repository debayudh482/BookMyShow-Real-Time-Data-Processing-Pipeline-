# BookMyShow Mock Data Generators

## Overview

This directory contains the Python-based mock event generators used to simulate transactional activity for the **BookMyShow Real-Time Data Processing Pipeline**.

Two independent event streams are generated:

1. **Booking Events**
2. **Payment Events**

Both streams are continuously published to separate **Azure Event Hubs**, where they are consumed by the downstream **Azure Stream Analytics** job for real-time processing and correlation.

```text
                    Python Mock Generators
                           │
             ┌─────────────┴─────────────┐
             │                           │
             ▼                           ▼
      Booking Generator           Payment Generator
             │                           │
             ▼                           ▼
       booking-events              payment-events
             │                           │
             └─────────────┬─────────────┘
                           ▼
                 Azure Stream Analytics
                           │
                           ▼
                  Azure Synapse Analytics
```

---

# Repository Structure

```text
data-generator/
│
├── mock_bookings.py
├── mock_payments.py
├── requirements.txt
└── README.md
```

| File               | Description                                      |
| ------------------ | ------------------------------------------------ |
| `mock_bookings.py` | Generates and publishes mock booking events      |
| `mock_payments.py` | Generates and publishes mock payment events      |
| `requirements.txt` | Python dependencies                              |
| `README.md`        | Documentation for the mock data generation layer |

---

# 1. Booking Data Generator

The booking generator simulates customer booking activity across different entertainment categories and publishes the generated events to Azure Event Hubs.

## Booking Event Types

The generator supports:

* Concerts
* Plays
* Movies
* Sports

Each event type has its own pricing range, seat sections and typical duration.

```text
Concert
├── VIP
├── Gold
├── Silver
└── Bronze

Play
├── Premium
├── Standard
└── Economy

Movie
├── Recliner
├── Premium
└── Standard

Sports
├── VIP
├── Premium
└── Standard
```

---

## Booking Data

Each booking event contains:

### Core Booking Information

```text
order_id
booking_id
booking_time
```

### Customer Information

```text
customer_id
name
email
phone
city
age_group
```

### Event Information

```text
event_id
event_name
event_type
event_location
event_venue
event_date
event_duration_hours
event_rating
seats
total_seats
```

### Booking Metadata

```text
total_amount
currency
booking_platform
promo_code_applied
booking_channel
```

The generator uses the `en_IN` Faker locale and a predefined set of major Indian cities to make the synthetic data suitable for the BookMyShow use case.

---

# 2. Seat and Pricing Simulation

Each booking contains between **1 and 4 seats**.

Seat pricing is generated dynamically based on:

```text
Event Type
     │
     ▼
Seat Section
     │
     ▼
Base Price
     │
     ▼
Section Multiplier
     │
     ▼
Final Seat Price
```

Section multipliers are used to create realistic variation between VIP, Premium, Standard and other seating categories.

The total booking amount is calculated by adding the individual seat prices.

---

# 3. Payment Data Generator

The payment generator simulates payment transactions associated with BookMyShow bookings.

It publishes payment events to a separate Azure Event Hub named:

```text
payment-events
```

The payment generator is designed to simulate different payment outcomes and capture transaction information for downstream revenue and payment-success analysis.

---

# Payment Event Structure

Each payment event contains:

### Transaction Information

```text
payment_id
transaction_id
order_id
payment_time
```

### Payment Information

```text
payment_method
payment_provider
payment_status
```

### Financial Information

```text
base_amount
gst_amount
gst_rate
convenience_fee
service_fee
total_amount
currency
```

### Processing Metadata

```text
processing_time_ms
payment_gateway
retry_attempt
3d_secure_enabled
```

### Failure Information

When a payment fails, a failure reason is also generated.

Possible failure scenarios include:

```text
Insufficient funds
Card declined by bank
Network timeout
Invalid payment details
Daily transaction limit exceeded
Security verification failed
```

---

# 4. Payment Method Simulation

The payment generator supports multiple payment methods:

```text
Credit Card
Debit Card
UPI
Net Banking
Wallet
PayPal
```

Each method has its own simulated:

* failure rate
* processing-time range
* popularity weight

This produces variation in payment behavior and allows downstream analytics to examine payment success rates and processing characteristics.

---

# 5. Financial Calculation

The payment generator calculates additional charges on the booking amount.

The simulated financial model includes:

```text
Base Booking Amount
        │
        ├── GST
        ├── Convenience Fee
        └── Service Fee
        │
        ▼
   Total Amount
```

The current generator applies:

```text
GST                  → 18%
Convenience Fee      → 2.5% or minimum ₹20
Service Fee          → ₹15
Currency             → INR
```

These calculations are implemented in the `calculate_tax_and_fees()` function.

---

# 6. Booking–Payment Correlation

A key design element of the mock data generation layer is the use of a shared `order_id`.

Both generators start their `order_id` counters at:

```text
2000
```

This is intentionally done so that booking and payment streams can be correlated downstream.

Conceptually:

```text
Booking Stream                       Payment Stream
──────────────                       ──────────────

order_002000 ─────────────────────► order_002000
order_002001 ─────────────────────► order_002001
order_002002 ─────────────────────► order_002002
       │                                    │
       └────────────────┬───────────────────┘
                        ▼
                 Stream Analytics
                        │
                  Window Join
                        │
                        ▼
              Enriched Transaction
```

The shared `order_id` becomes the logical correlation key used by the downstream real-time processing pipeline.

---

# 7. Event-Time Generation

Both generators create timestamps using the current UTC time.

### Booking

```text
booking_time
```

### Payment

```text
payment_time
```

These timestamps are important for the downstream Stream Analytics processing because the pipeline can correlate booking and payment events based on their event times.

---

# 8. Azure Event Hubs Integration

The two generators publish to separate Event Hubs:

```text
Python Booking Generator
          │
          ▼
    booking-events


Python Payment Generator
          │
          ▼
    payment-events
```

Events are serialized into JSON before being sent to Azure Event Hubs.

Both generators use the corresponding `order_id` as the Event Hub partition key.

This provides consistent partitioning for events associated with the same order.

---

# 9. Continuous Streaming

Both generators operate continuously.

The general execution pattern is:

```text
Generate Event
      │
      ▼
Serialize to JSON
      │
      ▼
Publish to Event Hub
      │
      ▼
Wait 3–7 seconds
      │
      ▼
Generate Next Event
      │
      └──────────────► Repeat
```

A randomized delay between 3 and 7 seconds is used to introduce variation in event arrival rather than producing events at an exact fixed interval.

---

# 10. Payment Success and Failure Simulation

The payment generator does not produce only successful transactions.

Payment status is determined using the configured failure rate for the selected payment method.

```text
Payment Method
      │
      ▼
Failure Rate
      │
      ▼
Random Outcome
   ┌──┴──┐
   ▼     ▼
Success Failed
          │
          ▼
    Failure Reason
```

This creates a more realistic stream for downstream analytics such as:

* payment success rate
* payment failure rate
* failed-payment reasons
* payment-method performance

The generator also maintains runtime counters for successful and failed payment events and periodically logs the calculated success rate.

---

# 11. Payment Processing Metadata

For every payment event, the generator simulates additional transaction-processing information.

Examples include:

```text
Processing Time
Payment Gateway
Retry Attempt
3D Secure Status
```

Credit and debit card payments have 3D Secure enabled in the generated data, while other payment methods do not.

This provides additional dimensions that can be used for future analytics.

---

# 12. Logging and Error Handling

Both generators use Python's `logging` module for runtime monitoring.

The generators log information such as:

```text
Event publication
Order ID
Booking/Payment ID
Transaction status
Event count
Errors
Connection status
Shutdown status
```

Azure Event Hub errors and unexpected exceptions are handled separately.

The producers are also closed during cleanup when the generator is stopped.

---

# 13. Dependencies

The generators use:

```text
Python
azure-eventhub
Faker
```

Install the required packages with:

```bash
pip install azure-eventhub Faker
```

If a `requirements.txt` file is included, install everything using:

```bash
pip install -r requirements.txt
```

---

# 14. Configuration

Each generator requires an Azure Event Hubs connection string and Event Hub name.

### Booking

```text
EVENT_HUB_NAME = booking-events
```

### Payment

```text
EVENT_HUB_NAME = payment-events
```

For the portfolio repository, Azure credentials should **not** be hard-coded in the Python files.

Use environment variables instead:

```python
import os

EVENT_HUB_CONNECTION_STR = os.getenv(
    "EVENT_HUB_CONNECTION_STR"
)
```

Then configure the value locally.

### Security

**Never commit:**

* Azure Event Hub connection strings
* Shared access keys
* API keys
* passwords
* tokens
* cloud credentials

If credentials have previously been committed to a repository, rotate/revoke them before making the repository public.

---

# 15. Running the Generators

Run the booking generator:

```bash
python mock_bookings.py
```

Run the payment generator:

```bash
python mock_payments.py
```

For the complete real-time pipeline, both streams should be running so that Azure Stream Analytics can receive booking and payment events.

```text
Terminal 1
──────────
python mock_bookings.py
        │
        ▼
booking-events


Terminal 2
──────────
python mock_payments.py
        │
        ▼
payment-events
```

---

# 16. End-to-End Role in the Project

The mock data generators represent the **source layer** of the BookMyShow real-time architecture.

```text
┌──────────────────────────┐
│   Booking Generator     │
│        Python           │
└────────────┬─────────────┘
             │
             ▼
      booking-events
             │
             │
             ├──────────────────────┐
             │                      │
             │                      ▼
             │             Azure Stream Analytics
             │                      ▲
             │                      │
             │                      │
      payment-events               │
             ▲                      │
             │                      │
┌────────────┴─────────────┐        │
│   Payment Generator      │        │
│         Python           │        │
└──────────────────────────┘        │
                                    │
                         Booking + Payment
                              Window Join
                                    │
                                    ▼
                         Azure Synapse Analytics
                                    │
                                    ▼
                                   n8n
                                    │
                                    ▼
                                  LLM
                                    │
                                    ▼
                            Outlook Email
```

---

# Engineering Concepts Demonstrated

This mock data generation layer demonstrates:

* Python event generation
* Synthetic data generation
* Nested JSON event structures
* Event-driven architecture
* Azure Event Hubs
* Multiple independent event streams
* Event-time generation
* Event partitioning
* Booking/payment correlation
* Transaction simulation
* Payment success/failure modeling
* Financial calculations
* Runtime logging
* Exception handling
* Continuous event streaming
* Graceful resource cleanup

---

# Data Flow Summary

```text
                  MOCK DATA GENERATION
                           │
             ┌─────────────┴─────────────┐
             │                           │
             ▼                           ▼
       Booking Events              Payment Events
             │                           │
             ▼                           ▼
     booking-events              payment-events
             │                           │
             └─────────────┬─────────────┘
                           │
                           ▼
                 Azure Stream Analytics
                           │
                     order_id Join
                           │
                           ▼
                  Enriched Transactions
                           │
                           ▼
                  Azure Synapse Analytics
                           │
                           ▼
                    Business KPIs
                           │
                           ▼
                          n8n
                           │
                           ▼
                          LLM
                           │
                           ▼
                  Automated Email
```

## Purpose

The objective of these generators is not to reproduce a production booking platform. They provide a controlled, continuously changing event stream that allows the downstream Azure architecture to demonstrate **real-time ingestion, stream processing, event correlation, analytical storage, KPI generation, and automated AI-powered reporting**.
