#!/bin/bash

# Name of your AVD (must match exactly as listed in `avdmanager list avd`)
AVD_NAME="Pixel_6"

# Optional flags for performance
EMULATOR_FLAGS="-netfast -no-boot-anim -accel on -camera-back none"

# Check if emulator is already running
if pgrep -f "emulator.*$AVD_NAME" > /dev/null; then
  echo "✅ Emulator '$AVD_NAME' is already running."
else
  echo "🚀 Starting emulator: $AVD_NAME"
  nohup emulator -avd "$AVD_NAME" $EMULATOR_FLAGS > /dev/null 2>&1 &
  echo "⏳ Emulator is booting in the background..."
fi

