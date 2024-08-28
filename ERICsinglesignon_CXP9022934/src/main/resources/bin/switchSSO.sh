#!/bin/bash




# set -x
action="-action"
on="on"
off="off"
help="--help"
msg="Try 'switchSSO.sh --help' for more information."
manual="
Usage: switchSSO.sh -action on
or:    switchSSO.sh -action off

-action on              the type of action to be performed turning SSO ON
-action off             the type of action to be performed turning SSO OFF
"
msgOFF="SSO is already off."
msgON="SSO is already on."

ssoONfile="/etc/httpd/conf.d/40_ftsso_main.conf"
ssoOFFfile="/etc/httpd/conf.d/40_ftsso_main.conf.disabled"




function apache(){
   service httpd restart
   printf "\nwaiting for Apache."
   until service httpd status 2>&1 > /dev/null
        do
                sleep 1
                printf "."
        done
   printf " done\n"
}


if [[ $# -gt 0 &&  $1 == $action && ($2 == $on || $2 == $off) ]];
then

      httpd -M 2> /dev/null | grep dsame
      if [ $? -eq 0 ]; then
          if [ $2 == $off ]; then
              mv $ssoONfile   $ssoOFFfile
              if [ $? == 0 ]; then
                 apache
              fi
           else
              echo $msgON
           fi
       else
          if [ $2 == $on ]; then
              mv $ssoOFFfile $ssoONfile
              if [ $? == 0 ]; then
                 apache
              fi
           else
              echo $msgOFF
           fi
        fi
elif [[ $1 =~ $help ]];
then
        echo $manual
else
        echo $msg
fi
