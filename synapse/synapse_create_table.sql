/*
============================================================================
Azure Synapse - Table Schema for BookMyShow Project
============================================================================

Quick setup script with essential tables and indexes.

Usage:
1. Connect to Synapse Studio
2. Go to SQL pools
3. New SQL script → Blank
4. Paste and run this script
============================================================================
*/

-- Create Schema
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'bookymyshow')
BEGIN
    EXEC('CREATE SCHEMA bookymyshow');
END

-- Drop existing table if needed
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'bookings_fact' AND schema_id = SCHEMA_ID('bookymyshow'))
BEGIN
    DROP TABLE bookymyshow.bookings_fact;
END

-- ============================================================================
-- CREATE MAIN FACT TABLE: bookings_fact
-- ============================================================================
-- Purpose: Store real-time streaming transaction data from Stream Analytics
-- Grain: One row per seat per transaction (seat-level granularity)
-- Source: Azure Stream Analytics job output
-- Use Cases: Revenue analytics, customer segmentation, fraud detection, payment analysis

CREATE TABLE bookymyshow.bookings_fact
(
    -- ========== IDENTIFIERS ==========
    order_id NVARCHAR(50) NOT NULL,           -- Primary key part 1: Links booking & payment
    booking_id NVARCHAR(50) NULL,             -- Unique booking reference
    payment_id NVARCHAR(50) NULL,             -- Unique payment transaction ID
    transaction_id NVARCHAR(50) NULL,         -- External payment gateway transaction ID
    
    -- ========== TIME DIMENSION ==========
    booking_time DATETIME2 NOT NULL,          -- When booking was made
    payment_time DATETIME2 NULL,              -- When payment was processed
    booking_day_of_week NVARCHAR(20) NULL,    -- "Monday", "Tuesday", etc. (for trend analysis)
    booking_hour INT NULL,                    -- 0-23 (for peak hour analysis)
    
    -- ========== CUSTOMER DIMENSION ==========
    customer_id NVARCHAR(50) NOT NULL,        -- Primary key part 2
    customer_name NVARCHAR(200) NULL,
    customer_email NVARCHAR(200) NULL,        -- For customer communications
    customer_phone NVARCHAR(50) NULL,
    customer_city NVARCHAR(100) NULL,         -- For geographic analysis
    customer_age_group NVARCHAR(20) NULL,     -- "18-25", "26-35", "36-50", "50+" (demographics)
    
    -- ========== EVENT DIMENSION ==========
    event_id NVARCHAR(50) NOT NULL,           -- Primary key part 3: Event identifier
    event_name NVARCHAR(300) NULL,            -- Full event name
    event_type NVARCHAR(50) NULL,             -- "Concert", "Movie", "Play", "Sports"
    event_category NVARCHAR(100) NULL,        -- Categorized: "Music Entertainment", "Cinema & Films", etc.
    event_location NVARCHAR(300) NULL,        -- City, venue address
    event_venue NVARCHAR(200) NULL,           -- Venue name
    event_rating FLOAT NULL,                  -- Customer rating (4.0-5.0 range)
    
    -- ========== SEAT DIMENSION ==========
    seat_number NVARCHAR(20) NULL,            -- "VIP-10", "12A", etc.
    seat_section NVARCHAR(50) NULL,           -- "VIP", "Gold", "Silver", "Bronze"
    seat_price FLOAT NULL,                    -- Price for this specific seat
    seat_tier NVARCHAR(50) NULL,              -- Tier classification: "Premium Seat", "Standard Seat", "Economy Seat"
    total_seats_booked INT NULL,              -- Total seats in this booking
    
    -- ========== BOOKING METRICS ==========
    booking_amount FLOAT NULL,                -- Gross booking amount (before taxes/fees)
    booking_currency NVARCHAR(10) NULL,       -- "INR"
    booking_platform NVARCHAR(50) NULL,       -- "Mobile App", "Website", "Kiosk" (acquisition channel)
    promo_code NVARCHAR(50) NULL,             -- Discount code applied
    
    -- ========== PAYMENT METRICS (Indian GST Structure) ==========
    base_amount FLOAT NULL,                   -- Ticket price before taxes/fees
    gst_amount FLOAT NULL,                    -- 18% GST on ticket price
    convenience_fee FLOAT NULL,               -- Platform convenience fee
    service_fee FLOAT NULL,                   -- Service charge
    total_amount FLOAT NULL,                  -- Final amount customer paid (includes all fees)
    currency NVARCHAR(10) NULL,               -- "INR"
    
    -- ========== PAYMENT METHOD DIMENSION ==========
    payment_method NVARCHAR(100) NULL,        -- "UPI", "Credit Card", "Debit Card", "Wallet", etc.
    payment_provider NVARCHAR(100) NULL,      -- "Razorpay", "PhonePe", "Paytm", "Google Pay", etc.
    payment_type NVARCHAR(50) NULL,           -- Categorized: "Digital Payment", "Card Payment", "Online Payment"
    payment_status NVARCHAR(20) NULL,         -- "Success" or "Failed"
    failure_reason NVARCHAR(500) NULL,        -- Failure details if applicable
    
    -- ========== PROCESSING METRICS ==========
    processing_time_ms INT NULL,              -- Processing duration in milliseconds (for SLA monitoring)
    payment_gateway NVARCHAR(100) NULL,       -- Gateway identifier
    retry_attempt INT NULL,                   -- Number of retry attempts (for reliability analysis)
    
    -- ========== COMPUTED METRICS ==========
    seconds_between_events INT NULL,          -- Time gap between booking and payment (for efficiency analysis)
    fees_and_taxes FLOAT NULL,                -- Total additional charges beyond booking amount
    transaction_category NVARCHAR(50) NULL,   -- "High Value Success", "Standard Success", "Failed Transaction"
    alert_category NVARCHAR(50) NULL,         -- Anomaly flags: "Normal", "Very High Value", "Multiple Retries", "Slow Processing", "Payment Delay"
    
    -- ========== AUDIT TRAIL ==========
    created_at DATETIME2 NOT NULL             -- When record was written by Stream Analytics (for data lineage)

)
WITH
(
    DISTRIBUTION = ROUND_ROBIN                -- Even distribution across nodes for streaming data
);

-- ============================================================================
-- CREATE ANALYTICS VIEWS
-- ============================================================================
-- Purpose: Pre-aggregated views for quick Power BI dashboards and reports
-- Note: These views aggregate data and should be refreshed periodically

-- ========== VIEW 1: REVENUE SUMMARY ==========
-- Purpose: Daily revenue breakdown by event category and payment status
-- Use Case: Executive dashboards, revenue reporting, trend analysis
-- Granularity: One row per day per event category per payment status
IF EXISTS (SELECT * FROM sys.views WHERE name = 'v_revenue_summary' AND schema_id = SCHEMA_ID('bookymyshow'))
    DROP VIEW bookymyshow.v_revenue_summary;

CREATE VIEW bookymyshow.v_revenue_summary
AS
SELECT
    CAST(booking_time AS DATE) AS booking_date,  -- Group by date
    event_category,                               -- Group by category
    payment_status,                               -- Group by status
    COUNT(*) AS transaction_count,                -- Number of transactions
    SUM(total_amount) AS total_revenue,          -- Total revenue in INR
    AVG(total_amount) AS avg_transaction_value,  -- Average order value
    SUM(CASE WHEN payment_status = 'Success' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS success_rate  -- Payment success percentage
FROM bookymyshow.bookings_fact
WHERE booking_time >= DATEADD(day, -30, GETUTCDATE())  -- Last 30 days rolling window
GROUP BY CAST(booking_time AS DATE), event_category, payment_status;

