# The Reflex Provisioner


# Introduction 
The reflex big data stack components are a combination of components from the Hortonworks distribution (HDFS, Yarn, Kafka and others), 
and several other 3rd party components. These components form the basis for the processing of the data. The requirement is to be able 
to install a complete big data solution which also provides high availability and scalability, in which, there are a wide variety of 
components. Also this installation should provide a variety of technologies to have readily available components to provide applications 
the ability to be able to choose what would work best for their specific usage.

# Components 


# Architecture 


# Documentation

Before starting the deployment of CDAP:

1) Change the environment and cdap variables in 'inventory/group_vars/all.yml'
2) Change the host entries into 'inventory/hosts'

After changing the variables and hosts entries, run the below commands to deploy or un-deploy the cdap.

Deploy CDAP:
ansible-playbook -i inventory/hosts playbooks/cdap/deploy_cdap.yml --ask-pass --user root

UnDeploy CDAP:
ansible-playbook -i inventory/hosts playbooks/cdap/undeploy_cdap.yml --ask-pass --user root
