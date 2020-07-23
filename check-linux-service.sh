#!/usr/bin/env bash

# Inspired by Multi OS Service Check Script by Author: Jon Schipp - https://github.com/jonschipp
# Removed Multi OS Capabilities, and Updated Script to use only systemctl
# Removed Other Features to minimise Script to focus on what we need to test n a linux (Ubuntu >16) servers

########
# Examples:
# 1). Check Status of SSH Service on a Linux Machine
# $./check_service.sh -s sshd
# 2). Check Status of service running as User
# $./check_service.sh -s sshd -u nagios
# 3) . Show Help Message
# $./check_service.sh -h

# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

#The Following Section are from Jon Schipp
# Weather or not we can trust the exit code from the service management tool.
# Defaults to 0, put to 1 for systemd.  Otherwise we must rely on parsing the
# output from the service management tool.

TRUST_EXIT_CODE=0


usage()
{
cat <<EOF

Check status of system services for Linux, FreeBSD, OSX, and AIX.

     Options:
        -s <service>    Specify service name
        -u <user>       User if you need to ``sudo -u'' for launchctl (def: nagios, linux and osx only)
EOF
}

argcheck() {
# if less than n argument
if [ $ARGC -lt $1 ]; then
        echo "Missing arguments! Use \`\`-h'' for help."
        exit 1
fi
}

ARGC=$#
LIST=0
MANUAL=0
OS=null
argcheck 1

while getopts "hls:o:t:u:" OPTION
do
     case $OPTION in
         h)
             usage
             exit 0
             ;;
         s)
             SERVICE="$OPTARG"
             ;;
         u)
             USERNAME="$OPTARG"
             ;;
         \?)
             exit 1
             ;;
     esac
done

determine_service_tool() {
        if command -v systemctl >/dev/null 2>&1; then
                SERVICETOOL="systemctl status $SERVICE | grep -i Active"
                LISTTOOL="systemctl"
                if [ $USERNAME ]; then
                    SERVICETOOL="sudo -u $USERNAME systemctl status $SERVICE"
                    LISTTOOL="sudo -u $USERNAME systemctl"
                fi
        TRUST_EXIT_CODE=1
        elif command -v service >/dev/null 2>&1; then
                SERVICETOOL="service $SERVICE status"
                LISTTOOL="service --status-all"
                if [ $USERNAME ]; then
                    SERVICETOOL="sudo -u $USERNAME service $SERVICE status"
                    LISTTOOL="sudo -u $USERNAME service --status-all"
                fi
        elif command -v initctl >/dev/null 2>&1; then
                SERVICETOOL="status $SERVICE"
                LISTTOOL="initctl list"
                if [ $USERNAME ]; then
                    SERVICETOOL="sudo -u $USERNAME status $SERVICE"
                    LISTTOOL="sudo -u $USERNAME initctl list"
                fi
        elif command -v chkconfig >/dev/null 2>&1; then
                SERVICETOOL=chkconfig
                LISTTOOL="chkconfig --list"
                if [ $USERNAME ]; then
                    SERVICETOOL="sudo -u $USERNAME chkconfig"
                    LISTTOOL="sudo -u $USERNAME chkconfig --list"
                fi
        elif [ -f /etc/init.d/$SERVICE ] || [ -d /etc/init.d ]; then
                SERVICETOOL="/etc/init.d/$SERVICE status | tail -1"
                LISTTOOL="ls -1 /etc/init.d/"
                if [ $USERNAME ]; then
                    SERVICETOOL="sudo -u $USERNAME /etc/init.d/$SERVICE status | tail -1"
                    LISTTOOL="sudo -u $USERNAME ls -1 /etc/init.d/"
                fi
        else
                echo "Unable to determine the system's service tool!"
                exit 1
        fi

}

determine_service_tool

# Check the status of a service
STATUS_MSG=$(eval "$SERVICETOOL" 2>&1)
EXIT_CODE=$?

## Exit code from the service tool - if it's non-zero, we should
## probably return CRITICAL.  (though, in some cases UNKNOWN would
## probably be more appropriate)
[ $EXIT_CODE -ne 0 ] && echo "$STATUS_MSG" && exit $CRITICAL

## For systemd and most systems, $EXIT_CODE can be trusted - if it's 0, the service is running.
## Ref https://github.com/jonschipp/nagios-plugins/issues/15
[ $TRUST_EXIT_CODE -eq 1 ] && [ $EXIT_CODE -eq 0 ] && echo "$STATUS_MSG" && exit $OK 


case $STATUS_MSG in

*stop*)
        echo "$STATUS_MSG"
        exit $CRITICAL
        ;;
*STOPPED*)
        echo "$STATUS_MSG"
        exit $CRITICAL
        ;;
*not*running*)
        echo "$STATUS_MSG"
        exit $CRITICAL
        ;;
*NOT*running*)
        echo "$STATUS_MSG"
        exit $CRITICAL
        ;;
*NOT*RUNNING*)
        echo "$STATUS_MSG"
        exit $CRITICAL
        ;;
#*inactive*)
#        echo "$STATUS_MSG"
#        exit $CRITICAL
#        ;;
*dead*)
        echo "$STATUS_MSG"
        exit $CRITICAL
        ;;
*running*)
        echo "$STATUS_MSG"
        exit $OK
        ;;
*RUNNING*)
        echo "$STATUS_MSG"
        exit $OK
        ;;
*SUCCESS*)
        echo "$STATUS_MSG"
        exit $OK
        ;;
*[eE]rr*)
        echo "Error in command: $STATUS_MSG"
        exit $CRITICAL
        ;;
*[fF]ailed*)
        echo "$STATUS_MSG"
        exit $CRITICAL
        ;;
*[eE]nable*)
        echo "$STATUS_MSG"
        exit $OK
        ;;
*[dD]isable*)
        echo "$STATUS_MSG"
        exit $CRITICAL
        ;;
*[cC]annot*)
        echo "$STATUS_MSG"
        exit $CRITICAL
        ;;
*[aA]ctive*)
        echo "$STATUS_MSG"
        exit $OK
        ;;
*Subsystem*not*on*file)
        echo "$STATUS_MSG"
        exit $CRITICAL
        ;;
[1-9][1-9]*)
        echo "$SERVICE running: $STATUS_MSG"
        exit $OK
        ;;
"")
    echo "$SERVICE is not running: no output from service command"
    exit $CRITICAL
    ;;
*)
        echo "Unknown status: $STATUS_MSG"
        echo "Is there a typo in the command or service configuration?: $STATUS_MSG"
        exit $UNKNOWN
        ;;
*0\ loaded*)
        echo "$STATUS_MSG"
        exit $OK
        ;;
esac