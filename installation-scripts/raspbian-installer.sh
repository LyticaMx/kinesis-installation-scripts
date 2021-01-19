#!/bin/bash

# Use root user
[ "$UID" -eq 0 ] || exec sudo bash "$0" "$@"

dir=$(pwd)

while getopts ":a:s:r:n:" opt; do
  case $opt in
    a) key="$OPTARG"
    ;;
    s) secret="$OPTARG"
    ;;
    r) region="$OPTARG"
    ;;
    n) name="$OPTARG"
    ;;
  esac
done

if [ -z "$key" ]
then
  echo >&2 "Must provide an aws access key id (-a)!"; exit 1;
fi

if [ -z "$secret" ]
then
  echo >&2 "Must provide an aws secret key (-s)!"; exit 1;
fi

if [ -z "$region" ]
then
  echo >&2 "Must provide an aws region (-r)!"; exit 1;
fi

if [ -z "$name" ]
then
  echo >&2 "Must provide a kinesis stream name (-n)!"; exit 1;
fi

# Check for internet connection
echo -e "GET http://google.com HTTP/1.0\n\n" | nc google.com 80 -w 3 > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo >&2 "Must have internet connection!"; exit 1;
fi

# Update and upgrade OS
apt-get update
sudo apt upgrade

# Install build dependencies
apt-get install cmake m4 git build-essential -y

# Install Gstreamer
apt-get install libssl-dev libcurl4-openssl-dev liblog4cplus-dev \
libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev gstreamer1.0-plugins-base-apps \
gstreamer1.0-plugins-bad gstreamer1.0-plugins-good gstreamer1.0-plugins-ugly gstreamer1.0-tools -y

# Clone kinesis producer library
cd
mkdir kinesis
cd kinesis
git clone https://github.com/awslabs/amazon-kinesis-video-streams-producer-sdk-cpp.git .

# Build library with Gstreamer plugin
mkdir build; cd build; cmake .. -DBUILD_GSTREAMER_PLUGIN=ON

# Make library
make

source ~/.bashrc

conf_file="/etc/systemd/system/streaming.service"
if [ -e $conf_file ]; then
  rm $conf_file
  echo "Previous service conf file found, replacing..."
fi

echo -e "[Unit]" >> $conf_file
echo -e "Description=AWS Kinesis streaming service" >> $conf_file
echo -e "Wants=network-online.target" >> $conf_file
echo -e "After=network-online.target" >> $conf_file

echo -e "\n[Service]" >> $conf_file
echo -e "Environment=GST_PLUGIN_PATH=${dir}/kinesis/build" >> $conf_file
echo -e "Environment=LD_LIBRARY_PATH=${dir}/kinesis/open-source/local/lib" >> $conf_file
echo -e "Environment=AWS_ACCESS_KEY_ID=${aws_access_key}" >> $conf_file
echo -e "Environment=AWS_SECRET_ACCESS_KEY=${aws_secret_key}" >> $conf_file
echo -e "Environment=AWS_DEFAULT_REGION=${aws_region}" >> $conf_file
echo -e "WorkingDirectory=${dir}/kinesis/build" >> $conf_file
echo -e "ExecStart=${dir}/kinesis/build/kvs_gstreamer_sample ${stream-name}" >> $conf_file

echo -e "\n[Install]" >> $conf_file
echo -e "WantedBy=multi-user.target" >> $conf_file

systemctl daemon-reload
echo "Starting tunnel as a service..."
systemctl start streaming
sleep 5

streaming_status="$(systemctl is-active streaming.service)"
if [ "${streaming_status}" = "active" ]; then
    systemctl enable streaming.service
    echo "Successfully kinesis stream: ${name}"
else
  systemctl status streaming.service
fi
