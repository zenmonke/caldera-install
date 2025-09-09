#!/bin/bash
SERVER_IP=$1

# Function to display a progress bar instead of outputting lots of data
show_progress() {
    local pid=$1
    local delay=0.5
    local spin=('|' '/' '-' '\')

    while ps -p "$pid" > /dev/null 2>&1; do
        for i in "${spin[@]}"; do
            echo -ne "\rWorking $i"
            sleep $delay
        done
    done
    echo -ne "\rWorking... Done!\n"
}

# Check if the IP address argument is supplied
if [ -z "$SERVER_IP" ]; then
    echo "Error: No server IP address supplied."
    echo "Usage: $0 <SERVER-IP>"
    exit 1
fi

# Step 1: Check if prereqs installed
if ! command -v python3.11 &> /dev/null; then
    echo "Python 3.11 is not installed. You can install utilizing my script at https://github.com/cmurphy06/RescalePy"
    exit 1
fi

# Check for Node.js v16+
NODE_PATH=$(command -v node)

if [ -z "$NODE_PATH" ]; then
  echo "[ X ] Node.js is not installed or not in PATH. Please install Node.js v16.0 or higher. https://nodejs.org/en/download"
  exit 1
fi

# Get current version number
NODE_VERSION=$("$NODE_PATH" -v | sed 's/^v//')
REQUIRED_VERSION="16.0.0"

# Compare versions
version_check=$(printf "%s\n%s" "$REQUIRED_VERSION" "$NODE_VERSION" | sort -V | head -n1)
if [ "$version_check" = "$NODE_VERSION" ] && [ "$NODE_VERSION" != "$REQUIRED_VERSION" ]; then
  echo -e "\033[31m[ X ] Node.js version $NODE_VERSION is too old. Please install v$REQUIRED_VERSION or higher.\033[0m"
  exit 1
fi


# Step 2: Install Dependencies
echo "Prompting for sudo password if needed..."
echo
sudo -v
echo "Installing required system packages for build..."
sudo apt install -y golang build-essential libxml2-dev libxslt1-dev python3-dev libffi-dev libssl-dev > /dev/null 2>&1 &
DEPS_PID=$!
show_progress $DEPS_PID

# Step 3: Clone the Caldera repo
echo "Cloning Caldera repository..."
git clone https://github.com/mitre/caldera.git --recursive > /dev/null 2>&1 &
Caldera_PID=$!
show_progress $Caldera_PID

# Step 4: Navigate to the Caldera directory
cd caldera || { echo "Failed to enter caldera directory."; exit 1; }

# Step 5: Set Up Python Virtual Environment
echo "Setting up Python virtual environment..."
python3.11 -m venv venv > /dev/null 2>&1 &
VENV_PID=$!
show_progress $VENV_PID

# Activate the virtual environment
source venv/bin/activate

# Verify that the virtual environment is activated
if [ "$VIRTUAL_ENV" != "" ]; then
    echo "Virtual environment activated."
else
    echo "Failed to activate virtual environment."
    exit 1
fi

# Ensure pip is available in the virtual environment
if ! command -v pip &> /dev/null; then
    echo "pip not found in virtual environment, installing..."
    sudo apt install -y python3-pip > /dev/null 2>&1 &
    PIP_INSTALL_PID=$!
    show_progress $PIP_INSTALL_PID
fi

# Step 6: Install Python dependencies
echo "Installing Python dependencies..."
pip install --upgrade pip > /dev/null 2>&1 &
PIP_UPGRADE_PID=$!
show_progress $PIP_UPGRADE_PID

pip install -r requirements.txt > pip_install.log 2>&1 &
PIP_INSTALL_PID=$!
show_progress $PIP_INSTALL_PID

# Step 7: Build Caldera server, run it, then kill it automatically
echo "Building Caldera server and waiting for 'all systems ready' message (takes about 60-90 seconds)..."
python server.py --build 2>&1 | tee caldera_build.log &
SERVER_PID=$!

# Check for the open port to know when the server is ready
while ! timeout 1 bash -c "</dev/tcp/$SERVER_IP/8888" &> /dev/null; do
    sleep 1  # Wait for 1 second before checking again
done

# Once the port is open, we know the server is up
echo
echo "Caldera server is now up, but bringing it down so you can configure."
echo

# Send SIGINT to the server process
echo "Stopping the server process with SIGINT..."
kill -SIGINT $SERVER_PID

# Wait for the server to stop
sleep 5

# Use pkill to ensure all python server.py processes are terminated
echo "Ensuring all server.py processes are terminated..."
pkill -f "python server.py"

# Check if any server.py processes are still running
if pgrep -f "python server.py" > /dev/null; then
    echo "Some server.py processes are still running. Forcefully terminating them..."
    pkill -9 -f "python server.py"
fi

echo "Caldera server stopped successfully."
echo

# Step 8: Fix any npm vulnerabilities
echo "Running npm audit fix..."
npm audit fix --force > /dev/null 2>&1 &
NPM_PID=$!
show_progress $NPM_PID

# Step 9: Update conf/local.yml
echo "Updating config files with $SERVER_IP..."
sed -i "s|^\s*app.contact.http:.*|app.contact.http: http://$SERVER_IP:8888|g" conf/local.yml
sed -i "s|^\s*app.frontend.api_base_url:.*|app.frontend.api_base_url: http://$SERVER_IP:8888|g" conf/local.yml

# Step 10: Update plugins/magma/.env
#This step is throwing an error from sed now, do not see plugins/magma/.env after installation since last version update. Script continues without issue though, may remove once verified do not need.  
echo "Updating more config files with $SERVER_IP..."
sed -i "s|http://localhost:8888|http://$SERVER_IP:8888|g" plugins/magma/.env
echo

# Step 11: Rebuild and start the server
echo "Rebuilding server and waiting for 'all systems ready' message..."
python server.py --build --fresh > /dev/null 2>&1 &
SERVER_PID=$!

# Check for the open port to know when the server is ready
while ! timeout 1 bash -c "</dev/tcp/$SERVER_IP/8888" &> /dev/null; do
    sleep 1  # Wait for 1 second before checking again
done

# Once the port is open, we know the server is up
echo "Caldera server is up and running!"

# Send SIGINT to the server process
echo "Stopping the server process with SIGINT..."
kill -SIGINT $SERVER_PID

# Wait for the server to stop
sleep 5

# Use pkill to ensure all python server.py processes are terminated
echo "Ensuring all server.py processes are terminated..."
pkill -f "python server.py"

# Check if any server.py processes are still running
if pgrep -f "python server.py" > /dev/null; then
    echo "Some server.py processes are still running. Forcefully terminating them..."
    pkill -9 -f "python server.py"
fi
echo "Caldera server stopped successfully."
echo

# Step 12: Final Messages
echo -e "\033[31m>>===[:: CALDERA IS NOW READY TO KICK A** AND CHEW BUBBLE GUM! ::]===<<\033[0m"
echo
# Step 13: Display the local.yml file for credentials
echo "Displaying credentials, saved to caldera/credentials.txt-"
echo
grep -E '^\s*(red|blue):' conf/local.yml | tee credentials.txt
echo
echo -e "Now just navigate to the Caldera directory, activate the Python virtual environment with  \033[33msource venv/bin/activate\033[0m, and then run \033[33mpython server.py\033[0m"

#deactivate python virtual environment
deactivate
