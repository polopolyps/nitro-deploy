nitro-deploy
============

Deploy script suite compatible with Nitro project (>10.6).

NB: This suite of scripts should be used as example and configured as necessary to work in the required environments.


Requirements
============

These scripts require un-prompted SSH access to all the required machines using the configured user account.

This can be set-up using for example:

ssh-copy-id polopoly@gui-server

Also, it requires that the given account also has the privileges on the target machines to be able to stop & stop tomcat using the command

sudo /etc/init.d/tomcat stop | start <user>
sudo /etc/init.d/jboss stop | start <user>

Also, the user defined must have the necessary privileges to be able to remove copy files into the jboss & tomcat file structure. i.e.
It will try to replace $JBOSS_HOME/server/default/deploy/polopoly/cm-server*.ear, and the other WAR files in that folder.

Tomcat & Jboss must already have been installed & configured.

NB: As a temporary measure the script is configured to use the 'ci' tool to stop/start jboss

For Varnish integration, the script will attempt to connect to the configured Varnish hosts to set the fronts to sick before
they are stopped. The polopoly user must have the ability to run the following command without being prompted for a password:

sudo varnishadm -T $VARNISH_ADM_URL -S $VARNISH_ADM_SECRET backend.set_health $1 $2

To disable this feature, just set the list of Varnish hosts to be empty. 


e.g. for Jboss, configure run.conf:

Add the following to JAVA_OPTS
-DconnectionPropertiesFile=/home/polopoly/config/connection.properties
-Dp.ejbConfigurationUrl=file:///home/polopoly/config/ejb-configuration.properties
-Dp.connectionPropertiesUrl=http://cm-server:8081/connection-properties/connection.properties
-Djava.rmi.server.hostname=cm-server

For JBOSS ensure that it is started with the options:
-b 0.0.0.0 -Djboss.server.log.dir=<logfolder>

For tomcat, ensure that it is started with the following parameters set,
preferably by changing e.g. /etc/tomcat-init.cfg or /etc/default/tomcat7 or in tomcat/bin/setenv.sh

For all tomcat instances:
-Dp.connectionPropertiesUrl=http://cm-server:8081/connection-properties/connection.properties

For tomcat instances running SOLR:
-Dsolr.solr.home=/opt/filedata/solr
-Dsolr.is.slave=true (for a slave solr tomcat)
-Dsolr.is.master=true (for a master solr tomcat)

For tomcat instance running the statistics-server
-DstatisticsBaseDirectory=/opt/filedata


Profiles
========
Currently, only a profile for polopolydev has been created. This should be duplicated for prod, staging.
This can be done by copying the file polopolydev.config to prod.config. You will then need to review the settings
for the new profile to ensure that they match the target environment.


Usage
=====
Use the assemble-dist.sh script to create the necessary build artifacts from the source folder.
NB: It is currently only possible to create one set of build artifacts at a time. 

e.g. ./assemble-dist.sh polopolydev

where polopolydev is the profile to use.

The assemble-dist.sh script will create all the necessary artefects in the source folders target/dist 
subfolder. The contents of this folder could be manually zipped up and copied to the target system if
required, or moved to a folder specific to that release. 

This script will be executed from the same server that the assemble-dist.sh is executed from.

If the production system is not accessible, then you will need to FTP the the distribution into
a folder available on the production server that is capable of distributing the artefacts to all
other servers.

The assemble-dist.sh accepts a single parameter, which is the name of the profile to build.

Once the distribution has been created and is in the location specified by the relevant profile
configuration (see variable RELEASEDIRECTORY in the config files) then the perform_release.sh
script can be executed.

It accepts two parameters
Param1 : The profile to use, there must be a similarly named config file in the same folder.
Param2 : Optional Starting Step number. Useful if a step fails for some reason and you want to restart from where it left off.

For documentation on the config files see the comments in polopolydev.config

