#!/bin/bash

# --- CONFIG ---
PORT=5001
VENV_DIR="venv"
REQUIREMENTS_FILE="requirements.txt"

# --- CHECK & KILL PROCESS USING PORT ---
PID=$(lsof -ti tcp:$PORT)

if [ -n "$PID" ]; then
    echo "Port $PORT is in use by PID $PID. Killing process..."
    kill -9 $PID
else
    echo "Port $PORT is available."
fi


# --- SET UP VIRTUAL ENVIRONMENT ---
if [ ! -d "$VENV_DIR" ]; then
    echo "Virtual environment not found. Creating one..."
    python3.10 -m venv $VENV_DIR  # requirements need python >=3.10

    echo "Installing requirements..."
    source $VENV_DIR/bin/activate
    pip install --upgrade pip  # Optional but recommended
    pip install -r $REQUIREMENTS_FILE
else
    echo "Virtual environment already exists."
    source $VENV_DIR/bin/activate
fi


# --- START UVICORN SERVER ---
cd src/
uvicorn api:app --host 0.0.0.0 --port $PORT &

# --- WAIT FOR SERVER TO START ---
echo "Waiting for server to start on port $PORT..."
while ! nc -z localhost $PORT; do
  sleep 1
done
echo "Server is up! Sending curl requests..."

# --- MAKE CURL REQUESTS ---
CINST=Guitar # Guitar, Piano, Viola
BINST=ElectricBass # ElectricBass, Violoncello, Contrbass

# Validation URL (GET)
validate_url="http://localhost:$PORT/validate?chords_instrument=$cinst&bass_instrument=$binst"

status=$(curl -s -o /dev/null -w "%{http_code}" "$validate_url")

echo "HTTP Status Code: $status"

# If status is 404, exit
if [ "$status" -eq 404 ]; then
    echo "❌ Invalid instrument! Exiting..."
    exit 1
fi

url1="http://localhost:$PORT/begin?melody_flag=0&chords_instrument=$CINST&BINST=$BINST"
curl -X POST "$url1" -H "Content-Type: application/json" &

url2="http://localhost:$PORT/monitor"
curl -X POST "$url2" -H "Content-Type: application/json" &

while true; do
    sleep 1
done