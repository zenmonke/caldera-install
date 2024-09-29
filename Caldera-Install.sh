#!/bin/bash

# Function to display a progress bar instead outputting lots of data
show_progress() {
    local pid=$1
    local delay=0.5
    local spin=('|' '/' '-' '\')

    while ps | grep -q "$pid"; do
        for i in "${spin[@]}"; do
            echo -ne "\rWorking $i"
            sleep $delay
        done
    done
    echo -ne "\rWorking... Done!\n"
}

# Check if the IP address argument is supplied
if [ -z "$1" ]; then
    echo "Error: No server IP address supplied."
    echo "Usage: $0 <SERVER-IP>"
    exit 1
fi

# Step 1: Check if Node.js is installed
read -n 1 -p "Has APT been updated recently and is Node.js (v16 or higher) installed? (y/n): " NODE_INSTALLED

if [ "$NODE_INSTALLED" != "y" ]; then
    echo
    echo "APT must be up to date and Node.js must be installed as a prerequisite. Install from https://nodejs.org/en/download/package-manager"
    echo
    echo "Once APT is updated and Node.js is installed, rerun script."
    exit 1
fi
echo
# Step 2: Install Golang
echo "Installing Golang.."
sudo -v
sudo apt install -y golang > /dev/null 2>&1 &
GoLang_PID=$!
show_progress $GoLang_PID

# Step 3: Clone the Caldera repo
echo "Cloning Caldera repository..."
git clone https://github.com/mitre/caldera.git --recursive > /dev/null 2>&1 &
Caldera_PID=$!
show_progress $Caldera_PID

# Step 4: Navigate to the Caldera directory
cd caldera || exit

# Step 5: Install Python dependencies
echo "Installing Python dependencies..."
pip3 install -r requirements.txt > /dev/null 2>&1 &
PIP_PID=$!
show_progress $PIP_PID

# Step 6: Build Caldera server, run it, then kill it automatically
echo "Building Caldera server and waiting for 'all systems ready' message (takes about 60-90 seconds)..."
python3 server.py --build > /dev/null 2>&1 &

# Get the server process ID (PID)
SERVER_PID=$!

# Check for the open port to know when the server is ready-
# Loop to check if port 8888 is open (replace with your actual port if different)
while ! nc -z localhost 8888; do
    sleep 1  # Wait for 1 second before checking again
done

# Once the port is open, we know the server is up
echo
echo "Caldera server is now up, but bringing down so can configure."
echo
# Send SIGINT to the server process
echo "Stopping the server process with SIGINT..."
kill -SIGINT $SERVER_PID

# Wait for the server to stop
sleep 5

# Use pkill to ensure all python3 server.py processes are terminated
echo "Ensuring all server.py processes are terminated..."
pkill -f "python3 server.py"

# Check if any server.py processes are still running
if pgrep -f "python3 server.py"; then
    echo "Some server.py processes are still running. Forcefully terminating them..."
    pkill -9 -f "python3 server.py"
fi

echo "Caldera server stopped successfully."
echo
# Step 7: Fix any npm vulnerabilities
echo "Running npm audit fix..."
npm audit fix --force > /dev/null 2>&1 &
NPM_PID=$!
show_progress $NPM_PID

# Step 8: Update conf/local.yml
echo "Updating config files with $1..."
sed -i "s|^\s*app.contact.http:.*|app.contact.http: http://$1:8888|g" conf/local.yml
sed -i "s|^\s*app.frontend.api_base_url:.*|app.frontend.api_base_url: http://$1:8888|g" conf/local.yml

# Step 9: Update plugins/magma/.env
echo "Updating more config files with $1..."
sed -i "s|http://localhost:8888|http://$1:8888|g" plugins/magma/.env
echo

# Step 10: Rebuild and start the server
echo "Rebuilding server and waiting for 'all systems ready' message..."
python3 server.py --build --fresh > /dev/null 2>&1 &

# Get the server process ID (PID)
SERVER_PID=$!

# Check for the open port to know when the server is ready, which loops to check if port 8888 is open
while ! nc -z localhost 8888; do
    sleep 1  # Wait for 1 second before checking again
done

# Once the port is open, we know the server is up
echo "Caldera server is up and running!"

# Send SIGINT to the server process
echo "Stopping the server process with SIGINT..."
kill -SIGINT $SERVER_PID

# Wait for the server to stop
sleep 5

# Use pkill to ensure all python3 server.py processes are terminated
echo "Ensuring all server.py processes are terminated..."
pkill -f "python3 server.py"

# Check if any server.py processes are still running
if pgrep -f "python3 server.py"; then
    echo "Some server.py processes are still running. Forcefully terminating them..."
    pkill -9 -f "python3 server.py"
fi

echo "Caldera server stopped successfully."
echo

# Step 11: Display the local.yml file for credentials
echo -e "\033[31mDisplaying credentials- \033[0m"
echo
tail -n 4 conf/local.yml
echo
echo -e "Caldera installation and configuration completed! Now you can run \033[33mpython3 server.py\033[0m from the caldera directory."
