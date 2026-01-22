#!/bin/bash

# Simulate a 2km running route at ~10 min/km pace (realistic running speed)
# This script will move the simulator location to create a test run

DEVICE_ID="17E759CC-D3F9-47A9-97B4-23EB48E2CA0B"

echo "🏃 Starting simulated run..."
echo "📍 Each point is ~100m apart, updating every 30 seconds"
echo "⏱️  Total distance: ~2km"
echo ""

# Array of waypoints (latitude,longitude) forming a 2km route
waypoints=(
    "37.7749,-122.4194"  # Start
    "37.7758,-122.4194"  # ~100m north
    "37.7767,-122.4194"  # ~100m north
    "37.7776,-122.4194"  # ~100m north
    "37.7785,-122.4194"  # ~100m north
    "37.7794,-122.4194"  # ~100m north (500m)
    "37.7794,-122.4184"  # ~100m east
    "37.7794,-122.4174"  # ~100m east
    "37.7794,-122.4164"  # ~100m east
    "37.7794,-122.4154"  # ~100m east
    "37.7794,-122.4144"  # ~100m east (1000m)
    "37.7785,-122.4144"  # ~100m south
    "37.7776,-122.4144"  # ~100m south
    "37.7767,-122.4144"  # ~100m south
    "37.7758,-122.4144"  # ~100m south
    "37.7749,-122.4144"  # ~100m south (1500m)
    "37.7749,-122.4154"  # ~100m west
    "37.7749,-122.4164"  # ~100m west
    "37.7749,-122.4174"  # ~100m west
    "37.7749,-122.4184"  # ~100m west
    "37.7749,-122.4194"  # ~100m west - back to start (2000m)
)

counter=1
total=${#waypoints[@]}

for point in "${waypoints[@]}"; do
    echo "[$counter/$total] Moving to: $point"
    xcrun simctl location "$DEVICE_ID" set "$point"

    if [ $counter -lt $total ]; then
        echo "⏳ Waiting 30 seconds (simulating running speed)..."
        sleep 30
    fi

    counter=$((counter + 1))
done

echo ""
echo "✅ Simulated run complete!"
echo "📊 Total distance: ~2.0 km"
echo "🏆 Expected KP: ~200 points"
