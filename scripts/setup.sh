#!/bin/sh
echo "Updating packages ..."
apt update
apt upgrade -y

echo "Installing Java OpenJDK 8 ..."
apt install openjdk-8-jdk -y

echo "Installing Pip3 ..."
apt install python3-pip -y

echo "Downloading Spark ..."
curl -L -O http://apache.mirror.anlx.net/spark/spark-2.4.4/spark-2.4.4-bin-hadoop2.7.tgz
tar xvf spark-2.4.4-bin-hadoop2.7.tgz
if [ -d "/opt/spark" ]; then rm -Rf /opt/spark; fi
mv spark-2.4.4-bin-hadoop2.7/ /opt/spark

echo "Downloading Polynote ..."
curl -L -O https://github.com/polynote/polynote/releases/download/0.2.13/polynote-dist-2.12.tar.gz
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
    echo ""
    echo "export SPARK_HOME=/opt/spark" >> /etc/bash.bashrc
    echo "export PATH=\"\$PATH:\$SPARK_HOME/bin:\$SPARK_HOME/sbin"\" >> /etc/bash.bashrc
fi

if [ -z "$PYSPARK_ALLOW_INSECURE_GATEWAY" ]; then
    echo ""
    echo "export PYSPARK_ALLOW_INSECURE_GATEWAY=1" >> /etc/bash.bashrc
fi

if [ -z "$POLYNOTE_HOME" ]; then
    echo ""
    echo "export POLYNOTE_HOME=/opt/polynote" >> /etc/bash.bashrc
    echo "export PATH=\"\$PATH:\$POLYNOTE_HOME"\" >> /etc/bash.bashrc
fi

echo "Installing python dependencies ..."
pip3 install jep jedi pyspark virtualenv numpy pandas fastparquet requests

chown -R $1:$1 /opt/polynote

bash