#!/bin/sh
echo "Getting version of ubuntu deployed ..."
version="$(lsb_release -r -s)"

echo "Added Microsoft package repo ..."
wget https://packages.microsoft.com/config/ubuntu/$version/packages-microsoft-prod.deb
dpkg -i packages-microsoft-prod.deb

echo "Updating packages ..."
apt update
apt upgrade -y
apt update

echo "Install blob fuse package ..."
apt install blobfuse -y

echo "Installing Java OpenJDK 8 ..."
apt install openjdk-8-jdk -y

echo "Installing Pip3 ..."
apt install python3-pip -y

echo "Downloading Spark ..."
curl -o spark-dist.tgz -L -O http://apache.mirror.anlx.net/spark/spark-2.4.5/spark-2.4.5-bin-hadoop2.7.tgz
tar xvf spark-dist.tgz
if [ -d "/opt/spark" ]; then rm -Rf /opt/spark; fi
mv spark-2.4.5-bin-hadoop2.7/ /opt/spark

echo "Downloading Polynote ..."
curl -o polynote-dist.tar.gz -L -O https://github.com/polynote/polynote/releases/download/0.3.9/polynote-dist.tar.gz
tar -zxvpf polynote-dist.tar.gz
if [ -d "/opt/polynote" ]; then rm -Rf /opt/polynote; fi
mv polynote/ /opt/polynote

echo "Adding polynote config ..."
echo "# The host and port can be set by uncommenting and editing the following lines:" >> /opt/polynote/config.yml
echo "listen:" >> /opt/polynote/config.yml
echo "  host: 0.0.0.0" >> /opt/polynote/config.yml
echo "  port: 8192" >> /opt/polynote/config.yml
echo "" >> /opt/polynote/config.yml
echo "storage:" >> /opt/polynote/config.yml
echo "  dir: /home/$1/notebooks" >> /opt/polynote/config.yml
echo "  mounts:"  >> /opt/polynote/config.yml
echo "    shared_notebooks:"  >> /opt/polynote/config.yml
echo "      dir: /media/polydata/notebooks" >> /opt/polynote/config.yml
echo "    examples:"  >> /opt/polynote/config.yml
echo "      dir: /home/$1/examples" >> /opt/polynote/config.yml

echo "Setting user profile environment variables ..."
if [ -z "$JAVA_HOME" ]; then
    export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
    echo ""
    echo "export JAVA_HOME=$JAVA_HOME" >> /etc/bash.bashrc
    echo "export PATH=\"\$PATH:\$JAVA_HOME/bin"\" >> /etc/bash.bashrc
fi

if [ -z "$SPARK_HOME" ]; then
    export SPARK_HOME=/opt/spark
    echo ""
    echo "export SPARK_HOME=$SPARK_HOME" >> /etc/bash.bashrc
    echo "export PATH=\"\$PATH:\$SPARK_HOME/bin:\$SPARK_HOME/sbin"\" >> /etc/bash.bashrc
fi

if [ -z "$PYSPARK_ALLOW_INSECURE_GATEWAY" ]; then
    echo ""
    echo "export PYSPARK_ALLOW_INSECURE_GATEWAY=1" >> /etc/bash.bashrc
fi

if [ -z "$POLYNOTE_HOME" ]; then
    export POLYNOTE_HOME=/opt/polynote
    echo ""
    echo "export POLYNOTE_HOME=$POLYNOTE_HOME" >> /etc/bash.bashrc
    echo "export PATH=\"\$PATH:\$POLYNOTE_HOME"\" >> /etc/bash.bashrc
fi

echo "Installing python dependencies ..."
pip3 install jep jedi pyspark virtualenv numpy pandas fastparquet requests

echo "Set up polynote location"
chown -R $1:$1 /opt/polynote

echo "Create mount points and directories"

mkdir /mnt/blobfusetmp
chown -R $1:$1 /mnt/blobfusetmp

mkdir /media/polydata
chown -R $1:$1 /media/polydata

mkdir /home/$1/notebooks
chown -R $1:$1 /home/$1/notebooks

echo "Refreshing bash"
echo "accountName $2" >> /opt/polynote/connection.cfg
echo "accountKey $3" >> /opt/polynote/connection.cfg
echo "authType Key" >> /opt/polynote/connection.cfg
echo "containerName $4" >> /opt/polynote/connection.cfg

echo "blobfuse /media/polydata --tmp-path=/mnt/blobfusetmp -o attr_timeout=240 -o entry_timeout=240 -o negative_timeout=120 --config-file=/opt/polynote/connection.cfg --log-level=LOG_DEBUG --file-cache-timeout-in-seconds=120 -o allow_other" > /opt/polynote/mount.sh

echo "/opt/polynote/mount.sh  /media/polydata       fuse    _netdev" >> /etc/fstab

chmod a+x /opt/polynote/mount.sh
mount /media/polydata
mkdir /media/polydata/notebooks
mkdir /media/polydata/data

echo "Copy the demo notebook to the team shared location"
cp demo.ipynb /media/polydata/notebooks/

echo "Copy the example notebooks"
cp -R /opt/polynote/examples /home/$1/examples
chown -R $1:$1 /home/$1/examples

echo "Updating /etc/environment ..."
echo "JAVA_HOME=\"$JAVA_HOME"\" >> /etc/environment
echo "SPARK_HOME=\"$SPARK_HOME"\" >> /etc/environment
echo "PYSPARK_ALLOW_INSECURE_GATEWAY=1" >> /etc/environment
echo "POLYNOTE_HOME=\"$POLYNOTE_HOME"\" >> /etc/environment

echo "Creating and enabling service"
cp polynote-server.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable polynote-server.service
service polynote-server start
