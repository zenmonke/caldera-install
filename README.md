This is a bash script to install a copy of the Caldera (https://github.com/mitre/caldera) server locally on Kali Linux. Prerequisites include updating APT and installing Node.JS. 

Run from a directory like home that doesn't need sudo privileges for the easiest time. Server IP needs to be supplied for the script, this will be the IP address of the machine you are running the Caldera server from. 

Usage: ./Caldera-Install.sh [Server-IP]

You'll be prompted for your sudo password. One the script has completed running, it will output the credentials that were generated for initial login. Now browse to http://[Server-IP]:8888 and log in with either the blue or red username. 

Note: installing Caldera with this script currently only allows you to log in using the IP address ran with the script. If you try to login using http://127.0.0.1:8888 or http://localhost:8888, you will be prompted for username and password, but you will not be able to login. No error comes back. 

(This is my very first public Bash script I've written, due to needing to use Caldera in my current role. The Caldera team's instructions on Github are way too simple and lots of workarounds are needed in order to make it work. After lots of headaches and troubleshooting, this script looked to simplify this!)
