/*
============================================================================
Azure Stream Analytics - BookMyShow Query
============================================================================

Real-time stream processing for bookings and payments with proper joins.

Key Features:
1. Data Quality Validation
2. Time-Based Joins
3. Multi-Seat Flattening
4. JavaScript UDFs for Business Logic
5. Anomaly Detection

Required UDFs (Register in Functions first):
- CategorizeEvent(eventType, eventName)
- GetPaymentType(paymentMethod)
- GetSeatTier(seatPrice, avgPrice)
- CheckAnomaly(paymentTotal, retryAttempt, processingTime, timeDiff)

Usage:
1. Register UDFs from udfs.js file in Stream Analytics Functions
2. Copy this query to Stream Analytics job
3. Configure inputs: bookings, payments
4. Configure output: bookings-synapse
============================================================================
*/

-- ============================================================================
-- SECTION 1: VALIDATE AND TRANSFORM BOOKINGS STREAM
-- ============================================================================
-- Purpose: Extract booking data from Event Hub and validate data quality
-- Input: [bookings] stream from Azure Event Hub (bookingstopic)
-- Output: Clean, validated booking records with extracted customer/event info

WITH ValidatedBookings AS
(
    SELECT
        -- Core Booking Identifiers
        event.order_id,                    -- Unique order identifier
        event.booking_id,                  -- Unique booking identifier
        TRY_CAST(event.booking_time AS datetime) AS booking_time,  -- Booking timestamp
        
        -- Customer Demographics (for segmentation analysis)
        event.customer.customer_id,
        event.customer.name AS customer_name,
        event.customer.email AS customer_email,
        event.customer.phone AS customer_phone,
        event.customer.city AS customer_city,
        event.customer.age_group AS customer_age_group,  -- e.g., "18-25", "26-35"
        
        -- Event Information (for event popularity analysis)
        event.event_details.event_id,
        event.event_details.event_name,     -- e.g., "Concert - Summer Vibes"
        event.event_details.event_type,     -- e.g., "Concert", "Movie", "Play"
        event.event_details.event_location,
        event.event_details.event_venue AS event_venue,
        event.event_details.total_seats AS total_seats_booked,
        event.event_details.event_rating AS event_rating,  -- Customer rating (4.0-5.0)
        event.event_details.seats AS seats,  -- Seat array - will be flattened next
        
        -- Booking Business Metadata
        event.booking_metadata.total_amount AS booking_amount,  -- Gross booking amount
        event.booking_metadata.currency AS booking_currency,
        event.booking_metadata.booking_platform AS booking_platform,  -- "Mobile App", "Website", "Kiosk"
        event.booking_metadata.promo_code_applied AS promo_code,
        
        -- Time Intelligence (for temporal analysis)
        DATENAME(weekday, TRY_CAST(event.booking_time AS datetime)) AS booking_day_of_week,  -- "Monday", "Tuesday", etc.
        DATEPART(hour, TRY_CAST(event.booking_time AS datetime)) AS booking_hour,  -- 0-23 for hourly analysis
        
        System.Timestamp AS booking_enqueued_time  -- Stream processing timestamp
        
    FROM [bookings] AS event
    
    WHERE
        -- Data Quality Filters: Only process complete and valid records
        event.order_id IS NOT NULL                    -- Must have order ID
        AND event.customer.customer_id IS NOT NULL    -- Must have customer ID
        AND TRY_CAST(event.booking_time AS datetime) IS NOT NULL  -- Valid timestamp
        AND event.booking_metadata.total_amount > 0    -- Positive booking amount
),

-- ============================================================================
-- SECTION 2: FLATTEN SEATS ARRAY (One Row Per Seat)
-- ============================================================================
-- Purpose: Convert seat array to one row per seat for detailed seat-level analytics
-- Technique: CROSS APPLY GetArrayElements() to unwrap JSON array
-- Result: If booking has 3 seats, creates 3 rows with same booking info but different seat details

FlattenedBookings AS
(
    SELECT
        -- Carry forward all booking information to each seat row
        b.order_id,
        b.booking_id,
        b.booking_time,
        b.customer_id,
        b.customer_name,
        b.customer_email,
        b.customer_phone,
        b.customer_city,
        b.customer_age_group,
        b.event_id,
        b.event_name,
        b.event_type,
        b.event_location,
        b.event_venue,
        b.event_rating,
        b.booking_amount,
        b.booking_currency,
        b.booking_platform,
        b.promo_code,
        b.total_seats_booked,
        b.booking_day_of_week,
        b.booking_hour,
        b.booking_enqueued_time,
        
        -- Extract individual seat details from array
        seat.arrayvalue.seat_number,       -- "VIP-10" or "12A"
        seat.arrayvalue.seat_section,      -- "VIP", "Gold", "Silver"
        seat.arrayvalue.price AS seat_price,  -- Price for this specific seat
        
        -- Business Logic: UDF to categorize event type
        udf.CategorizeEvent(b.event_type, b.event_name) AS event_category,  -- "Music Entertainment", "Cinema & Films", etc.
        
        -- Business Logic: UDF to determine seat price tier
        udf.GetSeatTier(seat.arrayvalue.price, b.booking_amount / CAST(b.total_seats_booked AS FLOAT)) AS seat_tier  -- "Premium Seat", "Standard Seat", "Economy Seat"
        
    FROM ValidatedBookings AS b
    CROSS APPLY GetArrayElements(b.seats) AS seat  -- Unwrap seats array: [seat1, seat2, seat3] → 3 rows
    
    WHERE 
        -- Data Quality: Ensure seat has valid data
        seat.arrayvalue.seat_number IS NOT NULL  -- Must have seat number
        AND seat.arrayvalue.price > 0             -- Positive seat price
),

-- ============================================================================
-- SECTION 3: VALIDATE AND TRANSFORM PAYMENTS STREAM
-- ============================================================================
-- Purpose: Extract payment data from Event Hub and validate transaction quality
-- Input: [payments] stream from Azure Event Hub (paymentstopic)
-- Output: Clean, validated payment records with financial breakdown

ValidatedPayments AS
(
    SELECT
        -- Payment Identifiers
        payment_id,                         -- Unique payment transaction ID
        transaction_id,                     -- External transaction reference
        order_id,                           -- Links to booking order_id for join
        TRY_CAST(payment_time AS datetime) AS payment_time,  -- Payment timestamp
        
        -- Financial Breakdown (Indian GST structure)
        amount.base_amount AS base_amount,         -- Ticket price before taxes/fees
        amount.gst_amount AS gst_amount,           -- 18% GST on ticket price
        amount.convenience_fee AS convenience_fee, -- Platform convenience fee
        amount.service_fee AS service_fee,         -- Service charge
        amount.total_amount AS total_amount,       -- Final amount customer paid
        amount.currency AS currency,               -- "INR"
        
        -- Payment Method & Status
        payment_method,                     -- "UPI", "Credit Card", "Debit Card", etc.
        payment_provider,                   -- "Razorpay", "PhonePe", "Paytm", etc.
        payment_status,                     -- "Success" or "Failed"
        failure_reason,                     -- If failed: "Insufficient funds", "Network timeout", etc.
        
        -- Business Logic: UDF to categorize payment method
        udf.GetPaymentType(payment_method) AS payment_type,  -- "Digital Payment", "Card Payment", "Online Payment"
        
        -- Performance Metrics (for SLA monitoring)
        processing_metadata.processing_time_ms AS processing_time_ms,  -- Processing duration
        processing_metadata.payment_gateway AS payment_gateway,        -- Gateway used
        processing_metadata.retry_attempt AS retry_attempt,            -- Number of retries
        
        System.Timestamp AS payment_enqueued_time  -- Stream processing timestamp
        
    FROM [payments]
    
    WHERE
        -- Data Quality Filters: Only process complete and valid payment records
        payment_id IS NOT NULL              -- Must have payment ID
        AND order_id IS NOT NULL            -- Must link to booking
        AND TRY_CAST(payment_time AS datetime) IS NOT NULL  -- Valid timestamp
),

-- ============================================================================
-- SECTION 4: JOIN BOOKINGS AND PAYMENTS (10-minute window)
-- ============================================================================
-- Purpose: Correlate booking events with corresponding payment events
-- Join Logic: INNER JOIN on order_id + time-bound window (10 minutes max gap)
-- Result: Complete transaction record with both booking and payment details

JoinedData AS
(
    SELECT
        -- ========== BOOKING INFORMATION ==========
        b.order_id,                     -- Primary key for join
        b.booking_id,
        b.booking_time,
        b.booking_day_of_week,          -- For day-of-week analysis
        b.booking_hour,                 -- For hourly trend analysis
        
        -- ========== CUSTOMER INFORMATION ==========
        b.customer_id,
        b.customer_name,
        b.customer_email,
        b.customer_phone,
        b.customer_city,                -- For geographic analysis
        b.customer_age_group,           -- For demographic segmentation
        
        -- ========== EVENT INFORMATION ==========
        b.event_id,
        b.event_name,
        b.event_type,
        b.event_category,               -- Categorized by UDF: "Music Entertainment", etc.
        b.event_location,
        b.event_venue,
        b.event_rating,                 -- For popularity analysis
        
        -- ========== SEAT INFORMATION ==========
        b.seat_number,                  -- Individual seat from flattened array
        b.seat_section,                 -- "VIP", "Gold", "Silver", etc.
        b.seat_price,                   -- Per-seat price
        b.seat_tier,                    -- Tier from UDF: "Premium Seat", etc.
        b.total_seats_booked,           -- Total seats in this booking
        
        -- ========== BOOKING METADATA ==========
        b.booking_amount,               -- Gross booking amount
        b.booking_currency,
        b.booking_platform,             -- Acquisition channel
        b.promo_code,                   -- Applied discount code
        
        -- ========== PAYMENT INFORMATION ==========
        p.payment_id,
        p.transaction_id,
        p.payment_time,
        
        -- Financial Breakdown
        p.base_amount,                  -- Ticket price before fees
        p.gst_amount,                   -- GST @ 18%
        p.convenience_fee,              -- Platform fee
        p.service_fee,                  -- Service charge
        p.total_amount,                 -- Total amount paid
        p.currency,
        
        -- ========== PAYMENT METHOD INFO ==========
        p.payment_method,               -- "UPI", "Credit Card", etc.
        p.payment_provider,             -- "Razorpay", "PhonePe", etc.
        p.payment_type,                 -- Categorized by UDF
        p.payment_status,               -- "Success" or "Failed"
        p.failure_reason,               -- Failure details if applicable
        
        -- ========== PROCESSING METRICS ==========
        p.processing_time_ms,           -- For performance monitoring
        p.payment_gateway,              -- Gateway identifier
        p.retry_attempt,                -- For reliability analysis
        
        -- ========== COMPUTED METRICS ==========
        -- Time Gap Analysis: How long between booking and payment?
        DATEDIFF(second, b.booking_time, p.payment_time) AS seconds_between_events,
        
        -- Financial Analysis: Additional fees and taxes beyond booking amount
        p.total_amount - b.booking_amount AS fees_and_taxes,
        
        -- Transaction Category: Business classification based on amount and status
        CASE 
            WHEN p.payment_status = 'Success' AND udf.CheckAnomaly(p.total_amount, p.retry_attempt, p.processing_time_ms, DATEDIFF(second, b.booking_time, p.payment_time)) = 'Normal' AND p.total_amount > 500 THEN 'High Value Success'
            WHEN p.payment_status = 'Success' AND udf.CheckAnomaly(p.total_amount, p.retry_attempt, p.processing_time_ms, DATEDIFF(second, b.booking_time, p.payment_time)) = 'Normal' THEN 'Standard Success'
            WHEN p.payment_status = 'Failed' THEN 'Failed Transaction'
            ELSE 'Unknown'
        END AS transaction_category,
        
        -- Anomaly Detection: UDF flags suspicious patterns
        udf.CheckAnomaly(p.total_amount, p.retry_attempt, p.processing_time_ms, DATEDIFF(second, b.booking_time, p.payment_time)) AS alert_category,
        
        -- Audit Trail: When was this record processed by stream analytics?
        System.Timestamp AS created_at
        
    FROM FlattenedBookings AS b
    INNER JOIN ValidatedPayments AS p
    ON b.order_id = p.order_id                                    -- Match on same order
        AND DATEDIFF(minute, b, p) BETWEEN 0 AND 10                -- Payment within 10 minutes of booking
)

-- ============================================================================
-- SECTION 5: OUTPUT TO SYNAPSE DATA WAREHOUSE
-- ============================================================================
-- Purpose: Write transformed data to Azure Synapse Analytics for BI/reporting
-- Output: All columns from JoinedData sent to bookings-synapse output
-- Table: bookymyshow.bookings_fact (created by synapse_create_table.sql)

SELECT
    *  -- All 40+ columns: identifiers, demographics, financials, metrics, alerts
INTO
    [bookings-synapse]  -- Configure this output in Stream Analytics Job settings
FROM
    JoinedData;

-- Query Complete! Data flows: Event Hub → Stream Analytics → Synapse → Dashboards