#!/usr/bin/env bash

HOST=host.otherthings.net

while true; do
	response=$(ssh-keyscan -H $HOST)
	if [[ $response ]]; then
		ssh-keygen -R $HOST
		ssh-keyscan -H $HOST > "/home/pi/.ssh/known_hosts"
	fi
	sleep 10
done
