# Mock Payment Data Generator for BookMyShow
# This script generates realistic payment events for BookMyShow bookings and publishes them to Azure Event Hub

from azure.eventhub import EventHubProducerClient, EventData
from azure.eventhub.exceptions import EventHubError
import json
import time
import random
from faker import Faker
from datetime import datetime
import logging

# Configure logging for better debugging and monitoring
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize Faker for generating realistic test data
fake = Faker('en_IN')

# Azure Event Hub Configuration
# TODO: Replace with your actual Event Hub connection string
EVENT_HUB_CONNECTION_STR = 'E*******'
EVENT_HUB_NAME = 'payment-events'

# Global counters for generating unique identifiers
# IMPORTANT: order_id_counter MUST match mock_bookings.py starting value for joins to work
order_id_counter = 2000  # SAME AS mock_bookings.py
payment_id_counter = 3000
transaction_id_counter = 10000

# Payment method configurations with realistic failure rates
PAYMENT_METHODS = {
    "Credit Card": {
        "failure_rate": 0.02,  # 2% failure rate
        "processing_time_ms_range": (500, 1500),
        "popularity_weight": 0.40
    },
    "Debit Card": {
        "failure_rate": 0.03,  # 3% failure rate
        "processing_time_ms_range": (400, 1200),
        "popularity_weight": 0.30
    },
    "UPI": {
        "failure_rate": 0.01,  # 1% failure rate (very popular in India)
        "processing_time_ms_range": (200, 800),
        "popularity_weight": 0.50
    },
    "Net Banking": {
        "failure_rate": 0.04,  # 4% failure rate
        "processing_time_ms_range": (1000, 3000),
        "popularity_weight": 0.15
    },
    "Wallet": {
        "failure_rate": 0.02,  # 2% failure rate
        "processing_time_ms_range": (150, 600),
        "popularity_weight": 0.35
    },
    "PayPal": {
        "failure_rate": 0.03,  # 3% failure rate
        "processing_time_ms_range": (800, 2500),
        "popularity_weight": 0.10
    }
}


def calculate_tax_and_fees(amount):
    """
    Calculate realistic taxes and fees for Indian bookings.
    
    Args:
        amount: Base booking amount
    
    Returns:
        dict: Tax and fee breakdown
    
    Business Logic:
        - GST @ 18% on ticket amount
        - Convenience fee @ 2.5% or minimum ₹20
        - Service fee @ ₹15 flat
    """
    gst_rate = 0.18
    convenience_fee_rate = 0.025
    convenience_fee_min = 20
    service_fee = 15
    
    # Calculate GST
    gst_amount = round(amount * gst_rate, 2)
    
    # Calculate convenience fee
    convenience_fee = max(amount * convenience_fee_rate, convenience_fee_min)
    
    # Calculate total
    total_amount = amount + gst_amount + convenience_fee + service_fee
    
    return {
        "base_amount": round(amount, 2),
        "gst_amount": round(gst_amount, 2),
        "gst_rate": 0.18,
        "convenience_fee": round(convenience_fee, 2),
        "service_fee": round(service_fee, 2),
        "total_amount": round(total_amount, 2),
        "currency": "INR"
    }


def generate_payment_data(order_id=None, booking_amount=None):
    """
    Generate realistic payment data with enhanced business logic.
    
    Args:
        order_id: Optional order ID to link with booking (if not provided, generates new)
        booking_amount: Optional booking amount (if not provided, generates random)
    
    Returns:
        dict: A dictionary containing payment details
    
    Business Logic:
        - Simulates realistic payment method distribution based on Indian market
        - Applies proper GST and fees calculation
        - Generates realistic failure scenarios
        - Includes payment metadata for analytics
    """
    global payment_id_counter, transaction_id_counter, order_id_counter
    
    # Generate unique identifiers
    payment_id = payment_id_counter
    transaction_id_counter += 1
    payment_id_counter += 1
    
    # Generate order_id using same counter as bookings script
    if not order_id:
        current_order_id = order_id_counter
        order_id_counter += 1
        order_id = f"order_{current_order_id:06d}"
    
    # If booking amount not provided, generate random amount based on realistic pricing
    if not booking_amount:
        # Generate amount based on typical ticket prices + multiple seats
        base_ticket_price = random.randint(100, 800)
        num_seats = random.randint(1, 4)
        booking_amount = base_ticket_price * num_seats
    
    # Calculate taxes and fees
    financial_details = calculate_tax_and_fees(booking_amount)
    
    # Select payment method based on popularity weights
    payment_method = random.choices(
        list(PAYMENT_METHODS.keys()),
        weights=[method["popularity_weight"] for method in PAYMENT_METHODS.values()]
    )[0]
    
    method_config = PAYMENT_METHODS[payment_method]
    
    # Determine payment status based on failure rate
    payment_status = "Success" if random.random() > method_config["failure_rate"] else "Failed"
    
    # Generate payment time
    payment_time = datetime.utcnow()
    
    # Simulate processing time
    processing_time_ms = random.randint(*method_config["processing_time_ms_range"])
    
    # Generate failure reasons if payment failed
    failure_reason = None
    if payment_status == "Failed":
        failure_reasons = [
            "Insufficient funds",
            "Card declined by bank",
            "Network timeout",
            "Invalid payment details",
            "Daily transaction limit exceeded",
            "Security verification failed"
        ]
        failure_reason = random.choice(failure_reasons)
    
    # Build payment data
    payment_data = {
        "payment_id": f"payment_{payment_id:06d}",
        "transaction_id": f"TXN{transaction_id_counter:08d}",
        "order_id": order_id,
        "payment_time": payment_time.strftime("%Y-%m-%dT%H:%M:%S.%fZ"),
        "payment_method": payment_method,
        "payment_provider": get_payment_provider(payment_method),
        "payment_status": payment_status,
        "amount": financial_details
    }
    
    # Add processing metadata
    payment_data["processing_metadata"] = {
        "processing_time_ms": processing_time_ms,
        "payment_gateway": f"Gateway{random.randint(1, 3)}",
        "retry_attempt": random.choice([1, 2, 3]) if payment_status == "Success" else random.randint(1, 3),
        "3d_secure_enabled": True if payment_method in ["Credit Card", "Debit Card"] else False
    }
    
    # Add failure reason if applicable
    if failure_reason:
        payment_data["failure_reason"] = failure_reason
    
    return payment_data


def get_payment_provider(payment_method):
    """
    Get payment provider based on payment method.
    
    Args:
        payment_method: The payment method used
    
    Returns:
        str: Payment provider name
    """
    provider_mapping = {
        "Credit Card": random.choice(["Razorpay", "Stripe", "CCAvenue"]),
        "Debit Card": random.choice(["Razorpay", "CCAvenue", "PayU"]),
        "UPI": random.choice(["PhonePe", "Google Pay", "Paytm", "BHIM UPI"]),
        "Net Banking": random.choice(["HDFC Bank", "ICICI Bank", "Axis Bank", "SBI Bank"]),
        "Wallet": random.choice(["Paytm", "PhonePe", "Freecharge", "Mobikwik"]),
        "PayPal": "PayPal"
    }
    return provider_mapping.get(payment_method, "Generic Provider")


def publish_payment_event(producer, payment_data):
    """
    Publish a single payment event to Event Hub.
    
    Args:
        producer: EventHubProducerClient instance
        payment_data: Dictionary containing payment data
    
    Returns:
        bool: True if successful, False otherwise
    """
    try:
        # Serialize data to JSON
        event_data_json = json.dumps(payment_data, default=str)
        event_data = EventData(event_data_json)
        
        # Send event with partition key for better distribution
        # Using order_id as partition key ensures same-order events go to same partition
        producer.send_batch([event_data], partition_key=payment_data["order_id"])
        
        status_emoji = "✓" if payment_data["payment_status"] == "Success" else "✗"
        logger.info(f"{status_emoji} Payment Event Published - Payment ID: {payment_data['payment_id']}, "
                   f"Order: {payment_data['order_id']}, "
                   f"Amount: ₹{payment_data['amount']['total_amount']}, "
                   f"Status: {payment_data['payment_status']}")
        return True
        
    except EventHubError as e:
        logger.error(f"Event Hub error publishing payment {payment_data.get('payment_id')}: {e}")
        return False
    except Exception as e:
        logger.error(f"Unexpected error publishing payment {payment_data.get('payment_id')}: {e}")
        return False


def main():
    """
    Main execution loop for continuous payment data generation.
    
    Sends payment events every 5 seconds with random variation.
    Handles graceful shutdown and error recovery.
    """
    logger.info("=" * 80)
    logger.info("BookMyShow Payment Data Generator - Starting Stream")
    logger.info("=" * 80)
    
    try:
        # Initialize Event Hub producer client
        producer = EventHubProducerClient.from_connection_string(
            conn_str=EVENT_HUB_CONNECTION_STR,
            eventhub_name=EVENT_HUB_NAME
        )
        logger.info(f"Connected to Event Hub: {EVENT_HUB_NAME}")
        
        event_count = 0
        success_count = 0
        failure_count = 0
        
        # Main event generation loop
        while True:
            try:
                # Generate new payment data
                payment_data = generate_payment_data()
                
                # Publish to Event Hub
                success = publish_payment_event(producer, payment_data)
                
                if success:
                    event_count += 1
                    if payment_data["payment_status"] == "Success":
                        success_count += 1
                    else:
                        failure_count += 1
                    
                    # Periodic summary
                    if event_count % 10 == 0:
                        success_rate = (success_count / event_count) * 100
                        logger.info(f"Total events: {event_count} | "
                                   f"Success: {success_count} | "
                                   f"Failed: {failure_count} | "
                                   f"Success Rate: {success_rate:.2f}%")
                
                # Random sleep between 3-7 seconds to simulate real-world variation
                sleep_interval = random.uniform(3, 7)
                time.sleep(sleep_interval)
                
            except KeyboardInterrupt:
                logger.info("\nReceived keyboard interrupt. Shutting down gracefully...")
                break
            except Exception as e:
                logger.error(f"Error in main loop: {e}")
                time.sleep(5)  # Wait before retrying
                
    except Exception as e:
        logger.error(f"Fatal error: {e}")
    finally:
        # Cleanup
        if 'producer' in locals():
            producer.close()
            logger.info("Event Hub connection closed")
        
        # Final summary
        if event_count > 0:
            success_rate = (success_count / event_count) * 100
            logger.info(f"Session ended. Total events: {event_count} | "
                       f"Success Rate: {success_rate:.2f}%")
        logger.info("=" * 80)


if __name__ == "__main__":
    main()
