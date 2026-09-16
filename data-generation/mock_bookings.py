# mock_bookings.py

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
fake = Faker('en_IN')  # Using Indian locale for BookMyShow context

# Azure Event Hub Configuration
EVENT_HUB_CONNECTION_STR = 'E*******'
EVENT_HUB_NAME = 'booking-events'

# Global counters for generating unique identifiers
# IMPORTANT: Both mock_bookings.py and mock_payments.py use same starting counter
# to ensure join works properly in Stream Analytics
order_id_counter = 2000
booking_id_counter = 5000

# Event catalog for more realistic data generation
EVENT_TYPES = {
    "Concert": {
        "base_price_range": (200, 1500),
        "seat_sections": ['VIP', 'Gold', 'Silver', 'Bronze'],
        "typical_duration_hours": 2.5
    },
    "Play": {
        "base_price_range": (100, 800),
        "seat_sections": ['Premium', 'Standard', 'Economy'],
        "typical_duration_hours": 2.0
    },
    "Movie": {
        "base_price_range": (150, 600),
        "seat_sections": ['Recliner', 'Premium', 'Standard'],
        "typical_duration_hours": 2.5
    },
    "Sports": {
        "base_price_range": (300, 2000),
        "seat_sections": ['VIP', 'Premium', 'Standard'],
        "typical_duration_hours": 3.0
    }
}

# Indian cities for more realistic event locations
MAJOR_CITIES = [
    "Mumbai", "Delhi", "Bangalore", "Hyderabad", "Chennai",
    "Kolkata", "Pune", "Ahmedabad", "Jaipur", "Surat"
]


def generate_booking_data():
    """
    Generate realistic booking data with enhanced business logic.
    
    Returns:
        dict: A dictionary containing booking details including:
            - order_id: Unique booking identifier
            - booking_time: ISO format timestamp
            - customer: Customer demographics and information
            - event_details: Comprehensive event information
            - booking_metadata: Additional booking insights
    
    Business Logic:
        - Generates variable number of seats (1-4) to simulate different booking sizes
        - Associates seats with realistic pricing based on event type
        - Includes customer demographics for analytics
        - Adds booking metadata for business intelligence
    """
    global order_id_counter, booking_id_counter
    
    # Generate unique identifiers
    order_id = order_id_counter
    booking_id_counter += 1
    order_id_counter += 1
    
    # Randomly select event type with weighted distribution
    event_type = random.choices(
        list(EVENT_TYPES.keys()),
        weights=[0.35, 0.25, 0.30, 0.10]  # More concerts and movies
    )[0]
    
    event_config = EVENT_TYPES[event_type]
    
    # Generate seats with realistic pricing
    num_seats = random.randint(1, 4)  # Most bookings are for 1-4 people
    seats = []
    total_booking_amount = 0
    
    for i in range(num_seats):
        seat_section = random.choice(event_config['seat_sections'])
        base_price = random.randint(*event_config['base_price_range'])
        
        # Apply section multiplier
        section_multiplier = {
            'VIP': 2.0, 'Premium': 1.5, 'Gold': 1.3, 'Recliner': 1.4,
            'Standard': 1.0, 'Silver': 0.8, 'Economy': 0.6, 'Bronze': 0.5
        }.get(seat_section, 1.0)
        
        seat_price = int(base_price * section_multiplier)
        total_booking_amount += seat_price
        
        # Generate seat number based on section
        if event_type == "Movie":
            seat_number = f"{random.randint(1, 20)}{random.choice(['A', 'B', 'C', 'D', 'E', 'F'])}"
        else:
            seat_number = f"{seat_section[0]}-{random.randint(1, 100)}"
        
        seats.append({
            "seat_number": seat_number,
            "seat_section": seat_section,
            "price": seat_price
        })
    
    # Generate booking time with some variation
    booking_time = datetime.utcnow()
    
    return {
        "order_id": f"order_{order_id:06d}", 
        "booking_id": f"booking_{booking_id_counter:06d}",
        "booking_time": booking_time.strftime("%Y-%m-%dT%H:%M:%S.%fZ"),
        "customer": {
            "customer_id": f"cust{random.randint(1000, 9999)}",
            "name": fake.name(),
            "email": fake.email(),
            "phone": fake.phone_number(),
            "city": random.choice(MAJOR_CITIES),
            "age_group": random.choice(["18-25", "26-35", "36-50", "50+"])
        },
        "event_details": {
            "event_id": f"event{random.randint(1, 50):03d}",
            "event_name": f"{event_type} - {fake.catch_phrase()}",
            "event_type": event_type,
            "event_location": f"{random.choice(MAJOR_CITIES)}, India",
            "event_venue": fake.company(),
            "event_date": fake.future_date(end_date='+180d').isoformat(),
            "event_duration_hours": event_config['typical_duration_hours'],
            "event_rating": round(random.uniform(4.0, 5.0), 1),
            "seats": seats,
            "total_seats": len(seats)
        },
        "booking_metadata": {
            "total_amount": total_booking_amount,
            "currency": "INR",
            "booking_platform": random.choice(["Mobile App", "Website", "Kiosk"]),
            "promo_code_applied": random.choice([None, "WEEKEND10", "STUDENT20"]),
            "booking_channel": random.choice(["Organic", "Referral", "Social Media", "Advertisement"])
        }
    }


def publish_booking_event(producer, booking_data):
    """
    Publish a single booking event to Event Hub.
    
    Args:
        producer: EventHubProducerClient instance
        booking_data: Dictionary containing booking data
    
    Returns:
        bool: True if successful, False otherwise
    """
    try:
        # Serialize data to JSON
        event_data_json = json.dumps(booking_data, default=str)
        event_data = EventData(event_data_json)
        
        # Send event with partition key for better distribution
        # Using order_id as partition key ensures same-order events go to same partition
        producer.send_batch([event_data], partition_key=booking_data["order_id"])
        
        logger.info(f"✓ Booking Event Published - Order ID: {booking_data['order_id']}, "
                   f"Customer: {booking_data['customer']['name']}, "
                   f"Event: {booking_data['event_details']['event_name']}")
        return True
        
    except EventHubError as e:
        logger.error(f"Event Hub error publishing booking {booking_data.get('order_id')}: {e}")
        return False
    except Exception as e:
        logger.error(f"Unexpected error publishing booking {booking_data.get('order_id')}: {e}")
        return False


def main():
    """
    Main execution loop for continuous booking data generation.
    
    Sends booking events every 5 seconds with random variation.
    Handles graceful shutdown and error recovery.
    """
    logger.info("=" * 80)
    logger.info("BookMyShow Booking Data Generator - Starting Stream")
    logger.info("=" * 80)
    
    try:
        # Initialize Event Hub producer client
        producer = EventHubProducerClient.from_connection_string(
            conn_str=EVENT_HUB_CONNECTION_STR,
            eventhub_name=EVENT_HUB_NAME
        )
        logger.info(f"Connected to Event Hub: {EVENT_HUB_NAME}")
        
        event_count = 0
        
        # Main event generation loop
        while True:
            try:
                # Generate new booking data
                booking_data = generate_booking_data()
                
                # Publish to Event Hub
                success = publish_booking_event(producer, booking_data)
                
                if success:
                    event_count += 1
                    if event_count % 10 == 0:
                        logger.info(f"Total events published: {event_count}")
                
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
        
        logger.info(f"Session ended. Total events published: {event_count}")
        logger.info("=" * 80)


if __name__ == "__main__":
    main()
