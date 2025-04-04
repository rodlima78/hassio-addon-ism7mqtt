#!/usr/bin/with-contenv bashio

export CONFIG_PATH=/data/options.json

export DEBUG_LOGGING=$(bashio::config 'debug_logging')


export ISM7_MQTTHOST="$(bashio::config 'mqtt_host')"
export ISM7_MQTTPORT="$(bashio::config 'mqtt_port')"
export ISM7_MQTTUSERNAME="$(bashio::config 'mqtt_user')"
export ISM7_MQTTPASSWORD="$(bashio::config 'mqtt_password')"


if [[ "$ISM7_MQTTHOST" == "null" ]]; then
    export ISM7_MQTTHOST="$(bashio::services mqtt 'host')"
    export ISM7_MQTTPORT="$(bashio::services mqtt 'port')"
    export ISM7_MQTTUSERNAME="$(bashio::services mqtt 'username')"
    export ISM7_MQTTPASSWORD="$(bashio::services mqtt 'password')"
    echo "Reading config from MQTT broker add-on: $ISM7_MQTTHOST/$ISM7_MQTTUSERNAME"
else
    echo "Using config from add-on configuration: $ISM7_MQTTHOST/$ISM7_MQTTUSERNAME"
fi



function start_ism7mqtt() {
    export ISM7_HOMEASSISTANT_ID=$1
    export ISM7_IP=$2
    export ISM7_PASSWORD=$3
    export ISM7_INTERVAL=$4

    echo "Removing legacy retained topics for $ISM7_HOMEASSISTANT_ID ..."
    mosquitto_sub -h "$ISM7_MQTTHOST" -p "$ISM7_MQTTPORT" --username "$ISM7_MQTTUSERNAME" --pw "$ISM7_MQTTPASSWORD" --retained-only -t 'homeassistant/#'  -W 1 -v 2>/dev/null | grep "/${ISM7_HOMEASSISTANT_ID}_.* {" | cut -f1 -d' {' | while read line; do
      echo "Removing $line" | ts
      mosquitto_pub -h "$ISM7_MQTTHOST" -p "$ISM7_MQTTPORT" --username "$ISM7_MQTTUSERNAME" --pw "$ISM7_MQTTPASSWORD" -t "${line}" -r -n
    done || true

    if [ $ISM7_INTERVAL = "" ]; then
        export ISM7_INTERVAL=60
    fi

    cd /app

    parameters="/config/ism7-parameters-$ISM7_HOMEASSISTANT_ID.json"
    if ! [ -f $parameters ]; then
        echo "Creating initial configuration $parameters"
        /app/ism7config -t $parameters | ts
        if ! [ -f $parameters ]; then
            echo "Parameter file creation seems to have failed. Please report to the ism7mqtt project: https://github.com/rodlima78/ism7mqtt/issues/new"
            exit -1
        fi
    fi

    lines="$(cat $parameters| grep -E '^\s*[0-9]+,?$' | wc -l)"
    if (( $lines > 150 )); then
        echo
        echo "======= WARNING WARNING WARNING ======="
        echo "Your parameter file $parameters contains a lot of parameters!"
        echo "If you encounter issues with disconnects or some parameters not being updated, read here:"
        echo "https://github.com/rodlima78/hassio-addon-ism7mqtt?tab=readme-ov-file#important-if-some-entities-are-unavailable"
        echo "======= WARNING WARNING WARNING ======="
        echo
    fi

    # Not really needed, most of it could also be read from env, but helps identifying which process is which
    ISM_ARGS="--hass-id=$ISM7_HOMEASSISTANT_ID --interval=$ISM7_INTERVAL --ipAddress=$ISM7_IP -t $parameters"
    if [[ "$DEBUG_LOGGING" == "true" ]]; then
        ISM_ARGS+=" -d"
    fi

    while [ true ]; do
        echo "Starting ism7mqtt $ISM_ARGS"
        /app/ism7mqtt $ISM_ARGS | ts || echo "ism7mqtt unexpectedly quit with return code $?"
        sleep 10
    done

}

HA_DISCOVERY_ID=$(bashio::config 'device_name')
ISM7_IP=$(bashio::config 'ism7_ip')
ISM7_PASSWORD=$(bashio::config 'ism7_password')
INTERVAL=$(bashio::config 'interval')

echo "Setting up ism7mqtt $HA_DISCOVERY_ID $ISM7_IP"
start_ism7mqtt $HA_DISCOVERY_ID $ISM7_IP $ISM7_PASSWORD $INTERVAL &


# Set username and password for the broker
for device in $(bashio::config 'additional_devices|keys'); do
  devname=$(bashio::config "additional_devices[${device}].device_name")
  ip=$(bashio::config "additional_devices[${device}].ism7_ip")
  password=$(bashio::config "additional_devices[${device}].ism7_password")
  interval=$(bashio::config "additional_devices[${device}].interval")

  echo "Setting up ism7mqtt $devname $ip"
  start_ism7mqtt $devname $ip $password $interval &
done


wait
