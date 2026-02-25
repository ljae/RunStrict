#!/bin/bash

# Realistic GPS simulation for testing navigation camera
# ~6m per step, 2-second intervals → ~3 m/s = 10.8 km/h (5'33" pace)
# GPS validator limits: max 25 km/h, max 8:00 min/km for hex capture
#
# Route: North 30 steps → East 30 steps → South 30 steps
# Total: ~540m in ~3 minutes

DEVICE_ID="17E759CC-D3F9-47A9-97B4-23EB48E2CA0B"
INTERVAL=2  # seconds between updates

# At lat 37.77°: 0.000054° lat ≈ 6m north, 0.000069° lng ≈ 6m east
LAT_STEP="0.000054"
LNG_STEP="0.000069"

# Starting point (San Jose / Cupertino area matching previous test)
START_LAT="37.77490"
START_LNG="-122.41940"

echo "Starting realistic GPS simulation for camera test..."
echo "Speed: ~3 m/s (10.8 km/h, 5'33\"/km pace)"
echo "Step: ~6m every ${INTERVAL}s"
echo "Route: North → East → South (~540m total)"
echo ""
echo ">>> START THE RUN IN THE APP, then this script provides GPS <<<"
echo ""

current_lat=$START_LAT
current_lng=$START_LNG
step=0
total=90

# Phase 1: Go North (30 steps)
echo "--- Phase 1: Heading NORTH ---"
for i in $(seq 1 30); do
    step=$((step + 1))
    echo "[$step/$total] lat=$current_lat lng=$current_lng (North)"
    xcrun simctl location "$DEVICE_ID" set "$current_lat,$current_lng"
    current_lat=$(echo "$current_lat + $LAT_STEP" | bc)
    sleep $INTERVAL
done

# Phase 2: Go East (30 steps)
echo "--- Phase 2: Heading EAST ---"
for i in $(seq 1 30); do
    step=$((step + 1))
    echo "[$step/$total] lat=$current_lat lng=$current_lng (East)"
    xcrun simctl location "$DEVICE_ID" set "$current_lat,$current_lng"
    current_lng=$(echo "$current_lng + $LNG_STEP" | bc)
    sleep $INTERVAL
done

# Phase 3: Go South (30 steps)
echo "--- Phase 3: Heading SOUTH ---"
for i in $(seq 1 30); do
    step=$((step + 1))
    echo "[$step/$total] lat=$current_lat lng=$current_lng (South)"
    xcrun simctl location "$DEVICE_ID" set "$current_lat,$current_lng"
    current_lat=$(echo "$current_lat - $LAT_STEP" | bc)
    sleep $INTERVAL
done

echo ""
echo "Simulation complete! (~540m in ~3 min)"
echo "Check: chase camera pitch, bearing rotation at turns, route line, hex highlight"
