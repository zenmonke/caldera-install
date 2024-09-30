This is a bash script to install a copy of the Caldera (https://github.com/mitre/caldera) server locally on Kali Linux. Prerequisites include updating APT and installing Node.JS. 

Run from a directory like home that doesn't need sudo privileges for the easiest time. Server IP needs to be supplied for the script, this will be the IP address of the machine you are running the Caldera server from. 

Usage: ./Caldera-Install.sh <Server-IP>

and that's it! 

(This is my very first public Bash script I've written, due to needing to use Caldera in my current role. The Caldera team's instructions on Github are way too simple and lots of workarounds are needed in order to make it work. After lots of headaches and troubleshooting, this script looked to simplify this!)
