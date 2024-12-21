# User Configurations Folder

This folder contains the configurations to be maintained by users of this docker image.
All internal configurations are not accessible / relevant to users, so they have been separated.

## Relevant Confgurations:

* **domains.txt** - File containing the domains to request certificates for. 
  (See: https://github.com/dehydrated-io/dehydrated/blob/master/docs/domains_txt.md)
* **restart-containers.sh** - Optional shell script that can be used to restart containers after certificates have been downloaded.
* **set-permissions.sh** - Optional shell script that can be used to alter permissions of downloaded certificates folder.
