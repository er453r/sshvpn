#!/bin/bash

host=$1
port=4444
interface_name="ssh_vpn"
local_virtual_address="10.109.255.1"
remote_virtual_address="10.109.0.1"
password="secret"

local_config="# generated automatically
$interface_name {
	type tun;
	password $password;
	up {
		ifconfig \"%% $local_virtual_address pointopoint $remote_virtual_address mtu 1200\";
	};
}
"

remote_config="# generated automatically
$interface_name {
	password $password;
	up {
		ifconfig \\\"%% $remote_virtual_address pointopoint $local_virtual_address mtu 1200\\\";
	};
}
"

echo "Connecting..."

temp=$(mktemp)

sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -t nat -A POSTROUTING -s $remote_virtual_address -j MASQUERADE

echo "$local_config" > $temp

sudo vtund -s -f $temp -P $port &

pid_vtund=$!

ssh $host -R $port:localhost:$port 'temp=$(mktemp); echo "'"$remote_config"'" > $temp; sudo vtund -n -f $temp -P '$port $interface_name' localhost' &> /dev/null &

sleep 3

ssh $host "sudo ip route add 0/0 dev tun0"

echo "VPN established"

sleep 30

echo "Clean up..."
sudo iptables -t nat -D POSTROUTING -s $remote_virtual_address -j MASQUERADE
sudo pkill vtund

echo "VPN closed"

