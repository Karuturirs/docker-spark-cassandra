#!/usr/bin/env bash
sudo docker run -it --name cassandra-seed --link spark-master:spark_master -d karuturirs/docker-spark-cassandra
