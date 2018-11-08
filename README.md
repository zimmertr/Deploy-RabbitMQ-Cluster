# Deploy RabbitMQ Cluster

## Summary
These scripts will provision a RabbitMQ cluster on a Linux server by performing the following actions:

  * Provision an LVM volume from an attached Disk                                   
  * Automatically mount disk with fstab entry                                                     
  * Specify a static networking configuration                                                     
  * Upgrade packages and install couchbase                                                        
  * Modify the earling encryption cookie                                                          
  * Disable the firewall                                                                          
  * Set a higher value for linux ulimit                                                           
  * Initialize the RMQ node
  * Join the node to the cluster _(Second script only)_

## Instructions

1. Modify the scripts with your environment details.
2. Execute the first script to initialize the node and cluster.
3. Execute the second script to initialize the node and connect to the cluster.
