#!/bin/bash
if [[ $(id -u) -ne 0 ]] ; then echo "Please use root account to run this script" ; exit 1 ; fi
echo //==============================================================
echo   Nessus Latest Version download and installation script
echo //==============================================================
echo " + continue"
chattr -i -R /opt/nessus
echo " + make sure we meet all pre-requisites.."
apt update &>/dev/null
apt -y install curl dpkg expect &>/dev/null
echo " + stop existing nessusd service, just in case there is one already installed !"
/bin/systemctl stop nessusd.service &>/dev/null
echo " + downloading Nessus.."
curl -A Mozilla --request GET \
  --url 'https://www.tenable.com/downloads/api/v2/pages/nessus/files/Nessus-latest-debian10_amd64.deb' \
  --output 'Nessus-latest-debian10_amd64.deb' &>/dev/null
{ if [ ! -f Nessus-latest-debian10_amd64.deb ]; then
  echo " + Nessus downloading failed :/ Quit from installation. Download offline package from Nessus"
  exit 0
fi }
echo " + installing Nessus.."
dpkg -i Nessus-latest-debian10_amd64.deb &>/dev/null
echo " + First time to initial and start service"
/bin/systemctl start nessusd.service &>/dev/null
echo " + Nessus is initializing, lets wait about 20 seconds..."
sleep 20
echo " + stop nessus service.."
/bin/systemctl stop nessusd.service &>/dev/null
echo " + change nessus configuration to customized settings"
echo "   set nessus web gui port: 12345"
/opt/nessus/sbin/nessuscli fix --set xmlrpc_listen_port=12345 &>/dev/null
echo "   set theme: dark"
/opt/nessus/sbin/nessuscli fix --set ui_theme=dark &>/dev/null
echo "   set safe_checks: false"
/opt/nessus/sbin/nessuscli fix --set safe_checks=false &>/dev/null
echo "   set backend_log_level: performance"
/opt/nessus/sbin/nessuscli fix --set backend_log_level=performance &>/dev/null
echo "   set all auto_update: false"
/opt/nessus/sbin/nessuscli fix --set auto_update=false &>/dev/null
/opt/nessus/sbin/nessuscli fix --set auto_update_ui=false &>/dev/null
/opt/nessus/sbin/nessuscli fix --set disable_core_updates=true &>/dev/null
echo "   set report & telemetry: false"
/opt/nessus/sbin/nessuscli fix --set report_crashes=false &>/dev/null
/opt/nessus/sbin/nessuscli fix --set send_telemetry=false &>/dev/null
echo " + create admin user. It can be changed later after logged in（username:admin, password:netsec）"
cat > expect.tmp<<'EOF'
spawn /opt/nessus/sbin/nessuscli adduser admin
expect "password:"
send "netsec\r"
expect "password (enter again):"
send "netsec\r"
expect "*(uploading plugins)？ (y/n)*"
send "y\r"
expect "*(user can have a empty ruleset)"
send "\r"
expect "are you sure*"
send "y\r"
expect eof
EOF
expect -f expect.tmp &>/dev/null
rm -rf expect.tmp &>/dev/null
echo " + download latest plugins.."
curl -A Mozilla -o all-2.0.tar.gz \
  --url 'https://plugins.nessus.org/v2/nessus.php?f=all-2.0.tar.gz&u=4e2abfd83a40e2012ebf6537ade2f207&p=29a34e24fc12d3f5fdfbb1ae948972c6' &>/dev/null
{ if [ ! -f all-2.0.tar.gz ]; then
  echo " + plugin all-2.0.tar.gz download failed :/ Quit from installation. Download offline package from Nessus"
  exit 0
fi }
echo " + installing plugins.."
/opt/nessus/sbin/nessuscli update all-2.0.tar.gz &>/dev/null
echo " + get the version number.."
vernum=$(curl https://plugins.nessus.org/v2/plugins.php 2> /dev/null)
echo " + creating feed..."
cat > /opt/nessus/var/nessus/plugin_feed_info.inc <<EOF
PLUGIN_SET = "${vernum}";
PLUGIN_FEED = "ProfessionalFeed (Direct)";
PLUGIN_FEED_TRANSPORT = "Tenable Network Security Lightning";
EOF
echo " + protecting files.."
chattr -i /opt/nessus/lib/nessus/plugins/plugin_feed_info.inc &>/dev/null
cp /opt/nessus/var/nessus/plugin_feed_info.inc /opt/nessus/lib/nessus/plugins/plugin_feed_info.inc &>/dev/null
echo " + set all files as immutable..."
chattr +i /opt/nessus/var/nessus/plugin_feed_info.inc &>/dev/null
chattr +i -R /opt/nessus/lib/nessus/plugins &>/dev/null
echo " + remove immutable for those core files.."
chattr -i /opt/nessus/lib/nessus/plugins/plugin_feed_info.inc &>/dev/null
chattr -i /opt/nessus/lib/nessus/plugins  &>/dev/null
echo " + start service.."
/bin/systemctl start nessusd.service &>/dev/null
echo " + wait 20 more seconds to make sure server has enough time to start service"
sleep 20
echo " + Monitoring Nessus process. Following line will be updated every 10 seconds until it completed process 100%"
zen=0
while [ $zen -ne 100 ]
do
 statline=`curl -sL -k https://localhost:11127/server/status|awk -F"," -v k="engine_status" '{ gsub(/{|}/,""); for(i=1;i<=NF;i++) { if ( $i ~ k ){printf $i} } }'`
 if [[ $statline != *"engine_status"* ]]; then echo -ne "\n Issue：Nessus server not accessable？try it again..\n"; fi
 echo -ne "\r $statline"
 if [[ $statline == *"100"* ]]; then zen=100; else sleep 10; fi
done
echo -ne '\n  o Completed!\n'
echo
echo "        Access Nessus:  https://localhost:11127/ （or your VPS IP）"
echo "                             Username: admin"
echo "                             Password: netsec"
echo "                             Can be changed anytime"
echo
read -p "Press enter to continue"
