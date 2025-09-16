#!/bin/bash

sudo apt update
sudo apt install ffmpeg

# ensure we have sudo rights
if [ "$EUID" -ne 0 ]; then
  echo "⚠️ Please run this script with sudo to install system packages."
  echo "Usage: sudo bash start_app.sh"
  exit 1
fi

# installing portaudio dependency
if ! dpkg -s portaudio19-dev &> /dev/null; then
  echo "📦 Installing portaudio19-dev..."
  apt-get install -y portaudio19-dev
else
  echo "✅ portaudio19-dev already installed."
fi

# Install fluidsynth if needed
if ! command -v fluidsynth &> /dev/null; then
  echo "📦 Installing fluidsynth..."
  apt-get install -y fluidsynth
else
  echo "✅ fluidsynth already installed."
fi

# Set variables for downloading a soundfont and settings it to the default
SF2_URL="https://github.com/mrbumpy409/GeneralUser-GS/raw/main/GeneralUser-GS.sf2"
SF2_PATH="$HOME/GeneralUser-GS.sf2"
CONFIG_PATH="$HOME/.fluidsynth"

# Check if the SoundFont file already exists
if [ -f "$SF2_PATH" ]; then
  echo "SoundFont already exists at $SF2_PATH, skipping download."
else
  echo "Downloading SoundFont to $SF2_PATH..."
  wget -O "$SF2_PATH" "$SF2_URL"
  if [ $? -ne 0 ]; then
    echo "Error: Failed to download SoundFont."
    exit 1
  fi
fi

if [ -f "$CONFIG_PATH" ]; then
  echo "Config file $CONFIG_PATH already exists, skipping creation."
else
  echo "Creating FluidSynth config file at $CONFIG_PATH..."
  # Generate the .fluidsynth config file
cat > "$CONFIG_PATH" <<EOF
set synth.default-soundfont "$SF2_PATH"
set synth.device-id 16
set synth.polyphony 512
set synth.gain 0.5
set synth.reverb.damp 0.3
set synth.reverb.level 0.7
set synth.reverb.room-size 0.5
set synth.reverb.width 0.8
set synth.chorus.depth 3.6
set synth.chorus.level 0.55
set synth.chorus.nr 4
set synth.chorus.speed 0.36
EOF
fi

echo "Fluidsynth and soundfont installation completed!"
