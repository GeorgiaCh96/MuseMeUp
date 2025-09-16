#!/bin/bash

# DEVELOPMENT PHASE SCRIPT, same as run_all_with_envs_XSYSTEM.sh
# 3/12/2024 LOOKS FOR ENVS AND CREATES THEM IF THEY DONT EXIST
# Changed LD_LIBRARY_PATH definitions at step 3
# 17/2/2025: automated 'ENTER' key press (At step 3)
# 1/5/2025: Included MEA in the bash script
# 2/5/2025: Changed dashboard main.py to accept user-defined ip-address and port
# 23/5/2025: Inside the wait_for_sensor_connection we included a 60-second timeout. If the connection with the PolarH10
# sensor fails, it displays a warning and skips the Stress Estimation app steps while continuing the script.
# 1/6/2025: Included music generation component in the bash script
# 20/8/2025: Defined how to detect the right conda base

# function to wait for sensor connection
wait_for_sensor_connection(){
    echo -e "\n\033[36mWaiting for Polar H10 sensor connection (60s timeout)...\033[0m"

    local timeout=60
    local elapsed=0
    local interval=1
    while ! grep -q "First data received" "$LOG_DIR/polar_logger.log"; do
        sleep $interval
        elapsed=$((elapsed + interval))
        if [ $elapsed -ge $timeout ]; then
            echo -e "\033[31mPolar H10 sensor not found after $timeout seconds.\033[0m"
            echo -e "\033[33mSkipping Stress Estimation app. Continuing with Mood Estimation app...\033[0m"
            return 1
        fi
    done

    echo -e "\033[32mPolar H10 sensor connection successful!\033[0m"

    # Run the sleep command in the background (fully detached)
    nohup bash -c "
        echo 'Sleeping for 30 seconds before sending ENTER key...'
        sleep 30

        xdotool windowactivate --sync \"$logger_window_id\"
        sleep 1  # Ensure window focus switch
        xdotool key Return
        echo 'ENTER key press sent successfully!'
    " >/dev/null 2>&1 &
}

# Function to stop all running processes
stop_processes() {
    echo -e "\n\033[31mCtrl+C detected! Stopping all processes...\033[0m"
    # Terminate all child processes of this script
    echo -e "\033[31mTerminating all processes in the group...\033[0m"
    kill -- -$$  # Sends the signal to the entire process group
    # wait a moment to ensure processes terminate
    sleep 2
    echo -e "\033[31m-----All processes stopped------\033[0m"
    exit 0
}

# Delete the old file sea/mea_results.json if exists
delete_if_exists() {
    local filename=$1
    local file_path=$(find . -type f -name "$filename" 2>/dev/null)

    if [[ -n "$file_path" ]]; then
        echo "Found: $file_path"
        rm "$file_path"
        echo "Deleted old $file_path"
    #else
    #    echo "$filename not found."
    fi
}


# Trap Ctrl+C (SIGINT) and call stop_processes
trap stop_processes SIGINT

delete_if_exists "mea_results_path.json"
delete_if_exists "sea_results_path.json"

# Check if x-terminal-emulator is installed
if ! command -v x-terminal-emulator &> /dev/null; then
    echo "Error: x-terminal-emulator is not installed."
    echo "Attempting to install gnome-terminal as a fallback..."

    # Run the installation command
    if sudo apt update && sudo apt install -y gnome-terminal; then
        echo "Installation successful. gnome-terminal is now installed and linked as x-terminal-emulator."
    else
        echo "Installation failed. Please install gnome-terminal manually using 'sudo apt install gnome-terminal'."
        exit 1
    fi
fi

# Check if xdotool is installed
if ! command -v xdotool &> /dev/null; then
  echo "Error: xdotool is not installed."
  echo "Attempting to install xdotool..."

    # Run the installation command
    if sudo apt update && sudo apt install -y xdotool; then
        echo "Installation successful. xdotool is now installed."
    else
        echo "Installation failed. Please install xdotool manually using 'sudo apt update && sudo apt install -y xdotool'."
        exit 1
    fi
fi

# Check if conda command exists at all
if ! command -v conda &> /dev/null; then
    echo "Error: Conda is not installed or not in PATH."
    echo "Please install Anaconda or Miniconda: https://docs.anaconda.com/anaconda/install/"
    exit 1
fi

# Find the right conda base
if [ -x "$HOME/anaconda3/bin/conda" ]; then
    conda_base="$HOME/anaconda3"
    echo "Found Anaconda installation"
elif [ -x "$HOME/miniconda3/bin/conda" ]; then
    conda_base="$HOME/miniconda3"
    echo "Found miniconda installation"
else
    echo "No conda installation found!"
    exit 1
fi

conda_bin="$conda_base/bin/conda"
echo "Using conda from: $conda_base"


if [ ! -x "$conda_bin" ]; then
    echo "Error: Conda binary not found at $conda_bin"
    exit 1
fi

# Function to ensure that conda env exists
ensure_conda_env() {
    local env_name=$1
    local yml_file=$2

    if ! $conda_bin info --envs | grep -q "$env_name"; then
        echo -e "\033[32mEnvironment '$env_name' not found. Creating it using '$yml_file'...\033[0m"
        if [ -f "$yml_file" ]; then
            $conda_bin env create -f "$yml_file"
        else
            echo -e "\033[31mError: '$yml_file' not found! Cannot create environment.\033[0m"
            exit 1
        fi
    else
        echo -e "\033[32mEnvironment '$env_name' already exists.\033[0m"
    fi
}


# Generalize activation command using the Conda base path
activate_command="source $conda_base/bin/activate"
# Define paths
current_dir=$(pwd)
LOG_DIR="$current_dir/logs"
mkdir -p "$LOG_DIR"
echo -e "The logs directory is: $LOG_DIR"

# Ensure conda environments are set up
ensure_conda_env "ctl_sensors_dashboard_conda_env_2024" "SEA_APP_Nov24/polar-h10-ecg-live-dashboard/ctl_sensors_dashboard_env.yml"
ensure_conda_env "ctl_sea_conda_env_2024" "SEA_APP_Nov24/sea-cnn-inference/ctl_sea_env.yml"
ensure_conda_env "ctl_polarh10_logger_conda_env_2024" "SEA_APP_Nov24/polar-h10-ecg-logger/ctl_polarh10_logger_env.yml"
ensure_conda_env "video_env" "museit-video-capture-with-FER-and-http-frame-transmission/environment.yml"

# if musicgen venv does not exist, create it
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/musicgen" || exit 1

if [[ -d "venv" ]]; then
    echo -e "\033[32mmusicgen venv already exists.\033[0m"
else
  echo -e "\033[32mmusicgen venv not found. Creating venv for musicgen ...\033[0m"
  # Find highest available Python 3.x version
  sudo apt install python3.10-dev portaudio19-dev build-essential  # Create the virtual env
  python3.10 -m venv venv || { echo "Failed to create venv"; exit 1; }

  source venv/bin/activate
  pip install --upgrade pip
  pip install -r requirements.txt
fi

# STEP 1: Run Dashboard on port 8050
dashboard_ip_address="0.0.0.0"
dashboard_port="8050"
echo -e "\n\033[36m***********************************\033[0m"
echo -e "\033[36mDASHBOARD\033[0m"
echo -e "\033[36mStarting Dashboard on port $dashboard_port...\033[0m"
cd "$current_dir/SEA_APP_Nov24/polar-h10-ecg-live-dashboard"
$activate_command ctl_sensors_dashboard_conda_env_2024
python -u src/main.py --ip_address "$dashboard_ip_address" --port "$dashboard_port" > "$LOG_DIR/dashboard.log" 2>&1 &
process_pids+=($!)
echo -e "\033[36mDashboard running on http://$dashboard_ip_address:$dashboard_port/ \033[0m"
echo -e "\033[36mDashboard PID: ${process_pids[-1]}\033[0m"

# STEP 2: Run Video Capture and Transmission
echo -e "\n\033[36m***********************************\033[0m"
echo -e "\033[36mMOOD ESTIMATION APP\033[0m"
echo -e "\033[36mStarting Video Capture and Transmission...\033[0m"
cd "$current_dir/museit-video-capture-with-FER-and-http-frame-transmission"
$activate_command video_env
python -u main_semkg_dataexport.py --ip_address "$dashboard_ip_address" --port "$dashboard_port" > "$LOG_DIR/video_capture.log" 2>&1 &
process_pids+=($!)
echo -e "\033[36mVideo Capture PID: ${process_pids[-1]}\033[0m"


# STEP 3: Run real-time stress estimation model
echo -e "\n\033[36m***********************************\033[0m"
echo -e "\033[36mSTRESS ESTIMATION APP\033[0m"
echo -e "\033[36mStarting Stress Estimation Model...\033[0m"
cd "$current_dir/SEA_APP_Nov24/sea-cnn-inference/src/online_inference"
$activate_command ctl_sea_conda_env_2024
python -u main_noKAFKA.py --config online_inference_config_noKAFKA.json --results_filename sea_results.json > "$LOG_DIR/stress_estimation.log" 2>&1 &
process_pids+=($!)
echo -e "\033[36mStress Estimation Model PID: ${process_pids[-1]}\033[0m"
echo -e "\033[36mWaiting for ZeroMQ server to be ready...\033[0m"
# Wait for ZeroMQ server readiness
while ! grep -q "Client waiting to receive message with metadata from server..." "$LOG_DIR/stress_estimation.log"; do
    sleep 1
done
echo -e "\033[36mZeroMQ server is ready! Proceeding...\033[0m"


# STEP 4: Run Polar H10 Logger, sending data to the dashboard on port 8050
echo -e "\n\033[36m***********************************\033[0m"
echo -e "\033[36mPOLARH10 LOGGER\033[0m"
echo -e "\033[36mStarting Polar H10 Logger and sending data to Dashboard on port $dashboard_port...\033[0m"
echo -e "\033[36m(Connection with Polar H10 sensor might take a while, track connection status on the Dashboard)\033[0m"

cd "$current_dir/SEA_APP_Nov24/polar-h10-ecg-logger"
logger_window_name="Polar H10 Logger"
logger_config_filename="example_session_config.json"
zmq_server_port="5555"

# Launch logger in a new terminal
env LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu x-terminal-emulator -e bash -c \
"echo -ne '\033]0;$logger_window_name\007'; \
echo 'Initializing Polar H10 Logger...\n
In case you wish to terminate the application, you have to terminate the logger by pressing CTRL+C inside this terminal.'; \
export LD_LIBRARY_PATH=$conda_base/envs/ctl_polarh10_logger_conda_env_2024/lib:$conda_base/envs/ctl_polarh10_logger_conda_env_2024/lib/intel64:$LD_LIBRARY_PATH; \
./main_encrypted_exe \"$logger_config_filename\" \
--dashboard_server_url $dashboard_ip_address \
--dashboard_server_port $dashboard_port \
--zmq_server_port $zmq_server_port \
> \"$LOG_DIR/polar_logger.log\" 2>&1; exec bash" &


# Start waiting for sensor connection in the background
(
    sleep 10  # Allow time for logger terminal to start
    logger_window_id=""
    while [ -z "$logger_window_id" ]; do
        logger_window_id=$(xdotool search --onlyvisible --name "$logger_window_name" | tail -1)
        sleep 1
    done

    echo -e "\n\033[36mLogger terminal detected: $logger_window_id\033[0m"

    if ! wait_for_sensor_connection; then
        echo -e "\033[33m[Warning] Polar H10 Logger is running but no data will be processed.\033[0m"
    fi
) &  # Entire block runs in the background
process_pids+=($!)ls
echo -e "\033[36mPolar H10 Logger window PID: ${process_pids[-1]}\033[0m"

echo -e "\n\033[36m***********************************\033[0m"

# STEP 5: Start music generation script
musicgen_window_name="Music Generation"
echo -e "\033[36mMUSIC GENERATION \033[0m"
process_pids+=($!)
echo -e "\033[36mMusic Generation  PID: ${process_pids[-1]}\033[0m"
echo -e "\n\033[36mStarting music generation application in a new terminal\033[0m"

cd "$current_dir/musicgen"

# Launch start_app.sh in a new terminal window
gnome-terminal --title="$musicgen_window_name" -- bash -c "./start_app.sh > '$LOG_DIR/musicgen.log' 2>&1; exec bash"

# Wait indefinitely, allowing the signal handler to manage termination
echo -e "\n\033[32mAll processes are running. Press Ctrl+C to stop.\033[0m"

cd ../

# start reading the predictions and send post requests
python3 read_predictions.py localhost 5001  > "$LOG_DIR/musicgen.log"

while true; do
    sleep 1
done
