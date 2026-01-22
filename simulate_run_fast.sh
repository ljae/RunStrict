#!/bin/bash

# Fast version for quick testing (5 second intervals instead of 30)
# Same route but moves faster for rapid testing

DEVICE_ID="17E759CC-D3F9-47A9-97B4-23EB48E2CA0B"

echo "🏃‍♂️ Starting FAST simulated run (for quick testing)..."
echo "📍 ~100m updates every 5 seconds"
echo ""

waypoints=(
    "37.7749,-122.4194"  # Start
    "37.7758,-122.4194"
    "37.7767,-122.4194"
    "37.7776,-122.4194"
    "37.7785,-122.4194"
    "37.7794,-122.4194"  # 500m
    "37.7794,-122.4184"
    "37.7794,-122.4174"
    "37.7794,-122.4164"
    "37.7794,-122.4154"
    "37.7794,-122.4144"  # 1000m
    "37.7785,-122.4144"
    "37.7776,-122.4144"
    "37.7767,-122.4144"
    "37.7758,-122.4144"
    "37.7749,-122.4144"  # 1500m
    "37.7749,-122.4154"
    "37.7749,-122.4164"
    "37.7749,-122.4174"
    "37.7749,-122.4184"
    "37.7749,-122.4194"  # 2000m - complete
)

counter=1
total=${#waypoints[@]}

for point in "${waypoints[@]}"; do
    echo "[$counter/$total] 📍 $point"
    xcrun simctl location "$DEVICE_ID" set "$point"

    if [ $counter -lt $total ]; then
        sleep 5
    fi

    counter=$((counter + 1))
done

echo ""
echo "✅ Fast test complete! (~2km in ~2 minutes)"
