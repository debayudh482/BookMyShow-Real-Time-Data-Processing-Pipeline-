/*
============================================================================
JavaScript User-Defined Functions for Stream Analytics
============================================================================

Register these functions in Azure Stream Analytics:
1. Go to Stream Analytics Job → Functions
2. Click "Add" → "JavaScript UDF"
3. Copy each function below (one at a time)
4. Save and reference in query

Author: Data Engineering Team
============================================================================
*/

// ============================================================================
// Function 1: Categorize Event
// Usage: CategorizeEvent(eventType, eventName)
// ============================================================================
function CategorizeEvent(eventType, eventName) {
    var category = eventType;
    var subCategory = 'Standard';
    
    var lowerName = (eventName || '').toLowerCase();
    
    if (lowerName.includes('music') || lowerName.includes('concert') || lowerName.includes('dj')) {
        subCategory = 'Music Entertainment';
    } else if (lowerName.includes('theatre') || lowerName.includes('drama') || lowerName.includes('play')) {
        subCategory = 'Theatre & Drama';
    } else if (lowerName.includes('movie') || lowerName.includes('film') || lowerName.includes('cinema')) {
        subCategory = 'Cinema & Films';
    } else if (lowerName.includes('cricket') || lowerName.includes('football') || lowerName.includes('sports')) {
        subCategory = 'Sports & Events';
    }
    
    return subCategory;
}

// ============================================================================
// Function 2: Get Payment Type
// Usage: GetPaymentType(paymentMethod)
// ============================================================================
function GetPaymentType(paymentMethod) {
    if (!paymentMethod) return 'Unknown';
    
    if (paymentMethod === 'Credit Card' || paymentMethod === 'Debit Card') {
        return 'Card Payment';
    } else if (paymentMethod === 'UPI' || paymentMethod === 'Wallet' || paymentMethod === 'Net Banking') {
        return 'Digital Payment';
    } else if (paymentMethod === 'PayPal') {
        return 'Online Payment';
    }
    
    return 'Other Payment';
}

// ============================================================================
// Function 3: Get Seat Tier
// Usage: GetSeatTier(seatPrice, avgPrice)
// ============================================================================
function GetSeatTier(seatPrice, avgPrice) {
    if (!seatPrice || !avgPrice || avgPrice === 0) return 'Standard Seat';
    
    var ratio = seatPrice / avgPrice;
    
    if (ratio > 1.2) return 'Premium Seat';
    if (ratio < 0.8) return 'Economy Seat';
    
    return 'Standard Seat';
}

// ============================================================================
// Function 4: Check Anomaly
// Usage: CheckAnomaly(paymentTotal, retryAttempt, processingTime, timeDiff)
// ============================================================================
function CheckAnomaly(paymentTotal, retryAttempt, processingTime, timeDiff) {
    if (paymentTotal < 50) return 'Very Low Value';
    if (paymentTotal > 5000) return 'Very High Value';
    if (retryAttempt > 2) return 'Multiple Retries';
    if (processingTime > 3000) return 'Slow Processing';
    if (timeDiff > 600) return 'Payment Delay';
    
    return 'Normal';
}

