#!/bin/sh
echo "Updating packages ..."
apt update
apt upgrade -y
apt update

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
curl -o polynote-dist.tar.gz -L -O https://github.com/polynote/polynote/releases/download/0.3.2/polynote-dist.tar.gz
tar -zxvpf polynote-dist.tar.gz
if [ -d "/opt/polynote" ]; then rm -Rf /opt/polynote; fi
mv polynote/ /opt/polynote

echo "Adding polynote config ..."
echo "# The host and port can be set by uncommenting and editing the following lines:" >> /opt/polynote/config.yml
echo "listen:" >> /opt/polynote/config.yml
echo "  host: 0.0.0.0" >> /opt/polynote/config.yml
echo "  port: 8192" >> /opt/polynote/config.yml

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

chown -R $1:$1 /opt/polynote

echo "Refreshing bash"
bash

echo "Updating /etc/environment"
echo "JAVA_HOME=\"$JAVA_HOME"\" >> /etc/environment
echo "SPARK_HOME=\"$SPARK_HOME"\" >> /etc/environment
echo "PYSPARK_ALLOW_INSECURE_GATEWAY=1" >> /etc/environment
echo "POLYNOTE_HOME=\"$POLYNOTE_HOME"\" >> /etc/environment

echo "Creating and enabling service"
cp polynote-server.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable polynote-server.service
service polynote-server start
