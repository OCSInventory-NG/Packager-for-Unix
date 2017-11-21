#!/bin/sh


if [ "$(id -u)" != "0" ]; then
	echo "This script must be run as root" 1>&2
	exit 1
fi

OCS_PACKAGE_DIR=$(dirname "$0")
if [ $OCS_PACKAGE_DIR = "." ];then
	OCS_PACKAGE_DIR=$(pwd)
fi

LOG_FILE=$OCS_PACKAGE_DIR/packageOCSAgent.log

. $OCS_PACKAGE_DIR/packageOCSAgent.config

if [ $PROXY_HOST ];then
	export http_proxy=http://${PROXY_HOST}:${PROXY_PORT}
	export https_proxy=http://${PROXY_HOST}:${PROXY_PORT}
fi

echo "Install compilation tools"
if [ -f /etc/redhat-release ];then
	[ $(which gcc) ] || yum install -y gcc
	[ $(which make) ] || yum install -y make
	[ $(which rsync) ] || yum install -y rsync
	[ $(which g++) ] || yum install -y  gcc-c++
elif [ -f /etc/debian_version ];then
	apt-get update
	[ $(which gcc) ] || apt-get install -y gcc
	[ $(which make) ] || apt-get install -y make
	[ $(which rsync) ] || apt-get install -y rsync
	[ $(which g++) ] || apt-get install -y g++
else
	echo "Unknown Linux distribution"
	exit 1
fi

if [ $(which curl) ];then
	DOWNLOAD_TOOL=curl
	CURL_OPTS="-s -L --remote-name"
elif [ $(which wget) ];then
	DOWNLOAD_TOOL=wget
else
	echo "Neither curl or wget is installed, installing curl ..."
	if [ -f /etc/redhat-release ];then
        	yum install curl
	elif [ -f /etc/debian_version ];then
        	apt-get install curl
	fi
        DOWNLOAD_TOOL=curl
        CURL_OPTS="-s -L --remote-name"
fi

[ -d $OCS_INSTALL_DIR ] && rm -rf $OCS_INSTALL_DIR
mkdir -p $OCS_INSTALL_DIR/perl
[ -d $OCS_PACKAGE_DIR/data ] && rm -rf  $OCS_PACKAGE_DIR/data
mkdir $OCS_PACKAGE_DIR/data
[ -d $OCS_PACKAGE_DIR/work ] && rm -rf  $OCS_PACKAGE_DIR/work
mkdir $OCS_PACKAGE_DIR/work
[ -d $OCS_PACKAGE_DIR/scripts ] && rm -rf  $OCS_PACKAGE_DIR/scripts
mkdir $OCS_PACKAGE_DIR/scripts

cd $OCS_PACKAGE_DIR/data
$DOWNLOAD_TOOL $CURL_OPTS $PERL_DL_LINK
cd $OCS_PACKAGE_DIR/work

PERL_FILE_NAME=$(echo $PERL_DL_LINK  |  awk -F"/" '{print $NF}')
tar zxf $OCS_PACKAGE_DIR/data/$PERL_FILE_NAME
cd $(basename $PERL_FILE_NAME .tar.gz)

./Configure -des -Dprefix=$OCS_INSTALL_DIR/perl
if [ $(echo $?) != 0 ];then
	echo "Something went wrong during Perl Configure step"
	echo "Please check the log file $LOG_FILE"
	exit 1
fi

make
if [ $(echo $?) != 0 ];then
	echo "Something went wrong during \"make\" step"
	echo "Please check the log file $LOG_FILE"
	exit 1
fi

make test
if [ $(echo $?) != 0 ];then
	echo "Something went wrong during \"make test\" step"
	echo "Please check the log file $LOG_FILE"
	exit 1
fi

make install
if [ $(echo $?) != 0 ];then
	echo "Something went wrong during \"make install\" step"
	echo "Please check the log file $LOG_FILE"
	exit 1
fi


# Make Perl module function
make_perl_module () {
	cd $OCS_PACKAGE_DIR/data
	$DOWNLOAD_TOOL $CURL_OPTS $1
	cd $OCS_PACKAGE_DIR/work
	local FILE_NAME=$(echo $1 |  awk -F"/" '{print $NF}')
	tar zxf $OCS_PACKAGE_DIR/data/$FILE_NAME
	cd $(basename $FILE_NAME .tar.gz)
	$OCS_INSTALL_DIR/perl/bin/perl Makefile.PL
	make
	# [ -d blib/lib/auto ] && rm -rf blib/lib/auto
	rsync --recursive blib/lib/ $OCS_INSTALL_DIR/perl/lib/${PERL_VERSION}/
}

for url in `cat $OCS_PACKAGE_DIR/PerlModulesDownloadList.txt`
do
	make_perl_module $url
	if [ $(echo $?) != 0 ];then
		echo "Something went wrong during perl module installation step"
		echo "Please check the log file $LOG_FILE"
	fi
done

cd $OCS_PACKAGE_DIR/data
$DOWNLOAD_TOOL $CURL_OPTS $OCSAGENT_DL_LINK
cd $OCS_PACKAGE_DIR/work

OCS_FILE_NAME=$(echo $OCSAGENT_DL_LINK  |  awk -F"/" '{print $NF}')
tar zxf $OCS_PACKAGE_DIR/data/$OCS_FILE_NAME
cd $(basename $OCS_FILE_NAME .tar.gz)

cp ocsinventory-agent /opt/ocsinventory/
cp -r lib/Ocsinventory $OCS_INSTALL_DIR/perl/lib/${PERL_VERSION}/

sed -i '1 s|^.*$|#!'${OCS_INSTALL_DIR}'/perl/bin/perl|' $OCS_INSTALL_DIR/ocsinventory-agent

mkdir -p $OCS_INSTALL_DIR/var/lib/ocsinventory-agent

# Download and compile nmap

cd $OCS_PACKAGE_DIR/data
$DOWNLOAD_TOOL $CURL_OPTS $NMAP_DL_LINK
cd $OCS_PACKAGE_DIR/work

NMAP_FILE_NAME=$(echo $NMAP_DL_LINK  |  awk -F"/" '{print $NF}')
tar zxf $OCS_PACKAGE_DIR/data/$NMAP_FILE_NAME
cd $(basename $NMAP_FILE_NAME .tgz)

./configure --prefix=${OCS_INSTALL_DIR}/nmap --without-zenmap
if [ $(echo $?) != 0 ];then
	echo "Something went wrong during Namp Configure step"
	echo "Please check the log file $LOG_FILE"
	exit 1
fi

make
if [ $(echo $?) != 0 ];then
	echo "Something went wrong during \"make\" step"
	echo "Please check the log file $LOG_FILE"
	exit 1
fi

make install
if [ $(echo $?) != 0 ];then
	echo "Something went wrong during \"make install\" step"
	echo "Please check the log file $LOG_FILE"
	exit 1
fi

 # End Nmap compilation

# Guess which Linux Distribution and which Distribution major version it is
if [ -f /etc/os-release ];then
	LINUX_DISTRIB=$(grep "^ID=" /etc/os-release | awk -F"=" '{print $2}' | tr -d "\"")
	DISTIB_MAJOR_VERSION=$(grep "^VERSION_ID=" /etc/os-release | awk -F"=" '{print $2}' | tr -d "\"" | cut -d. -f1)
else
	LINUX_DISTRIB="UnknownLinux"
	DISTIB_MAJOR_VERSION="UnknownVersion"
fi

echo $LINUX_DISTRIB
echo $DISTIB_MAJOR_VERSION

# Create addtional file (ParserDetails.ini) to avoid error message when executing agent
touch ${PARSER_INI_PATH}

# Create SH File with all agent configuration from packageOCSAgent.config
SH_COMMAND_LINE="${OCS_INSTALL_DIR}/ocsinventory-agent -s ${OCS_SERVER_URL} --basevardir=${OCS_INSTALL_DIR}/var/lib/ocsinventory-agent --tag=${OCS_AGENT_TAG} "

if [ "${OCS_AGENT_LAZY}" != 0 ];then
	echo "Activating lazy mode"
	SH_COMMAND_LINE=$SH_COMMAND_LINE"--lazy "
fi

if [ "${OCS_SSL_ENABLED}" != 0 ];then
	echo "Activating SSL inventory"
	cp ${OCS_SSL_CERTIFICATE_FULL_PATH} "$OCS_PACKAGE_DIR/files/cacert.pem"
	SH_COMMAND_LINE=$SH_COMMAND_LINE"--ca=${OCS_INSTALL_DIR}/files/cacert.pem "
fi

if [ "${OCS_LOG_FILE}" != 0 ];then
	echo "Activating log generation"
	SH_COMMAND_LINE=$SH_COMMAND_LINE"--logfile=${OCS_LOG_FILE_PATH} "
fi

# If crontab required from packageOCSAgent.config, create a crontab each X hours
if [ "${OCS_AGENT_CRONTAB}" != 0 ];then
	CRON_COMMAND_LINE="crontab -l | { cat; echo '0 ${OCS_AGENT_CRONTAB_HOUR} 0 0 0 ${SH_COMMAND_LINE}'; } | crontab -"
	echo "Crontab generated : ${CRON_COMMAND_LINE}"
fi

echo "Command generated for agent : ${SH_COMMAND_LINE}"

# Generate Agent SH to be executed
echo "Generating agent SH script"
echo "$SH_COMMAND_LINE" > $OCS_PACKAGE_DIR/scripts/execute_agent.sh

if [ ${OCS_AGENT_CRONTAB} != 0 ];then
	echo "Generating crontab SH script"
	echo "$CRON_COMMAND_LINE" > $OCS_PACKAGE_DIR/scripts/create_crontab.sh
fi

# Install finished, tar step
echo "$LINUX_DISTRIB $DISTIB_MAJOR_VERSION" > $OCS_INSTALL_DIR/os-version.txt

tar zcf $OCS_PACKAGE_DIR/ocsinventory-agent_${LINUX_DISTRIB}-${DISTIB_MAJOR_VERSION}.tar.gz $OCS_INSTALL_DIR

echo "Packaging successfully done"
echo "Package is $OCS_PACKAGE_DIR/ocsinventory-agent_${LINUX_DISTRIB}-${DISTIB_MAJOR_VERSION}.tar.gz"

echo "After deployment performed on another system, launch OCS Agent like this"
echo "${OCS_INSTALL_DIR}/scripts/execute_agent.sh"
echo "You can also, launch manually this command with all arguments"
echo "$SH_COMMAND_LINE"
