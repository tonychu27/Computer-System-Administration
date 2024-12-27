#!/bin/sh
while true; do
	logrotate rotate.conf
	sleep 60
done
