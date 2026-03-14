#!/bin/bash

# Android simulation script for RunStrict
# Uses 'telnet' to feed waypoints to the emulator

echo "🏃 Starting Android simulated run..."

# waypoints (longitude, latitude)
waypoints=(
    "-122.4194,37.7749" "-122.4194,37.7758" "-122.4194,37.7767" "-122.4194,37.7776"
    "-122.4194,37.7785" "-122.4194,37.7794" "-122.4184,37.7794" "-122.4174,37.7794"
    "-122.4164,37.7794" "-122.4154,37.7794" "-122.4144,37.7794" "-122.4144,37.7785"
    "-122.4144,37.7776" "-122.4144,37.7767" "-122.4144,37.7758" "-122.4144,37.7749"
    "-122.4154,37.7749" "-122.4164,37.7749" "-122.4174,37.7749" "-122.4184,37.7749"
    "-122.4194,37.7749"
)

counter=1
total=${#waypoints[@]}

for point in "${waypoints[@]}"; do
    lonlat=$(echo $point | tr ',' ' ')
    echo "[$counter/$total] Moving to: $lonlat"
    (echo "auth N5gwTnA9Utfxm2Zp"; sleep 0.1; echo "geo fix $lonlat"; sleep 0.1; echo "quit") | nc localhost 5554
    
    if [ $counter -lt $total ]; then
        sleep 3
    fi
    counter=$((counter + 1))
done

echo "✅ Simulation complete."
