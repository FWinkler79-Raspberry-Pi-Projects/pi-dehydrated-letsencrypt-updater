# User Configurations Folder

This folder contains the configurations to be maintained by users of this docker image.
All internal configurations are not accessible / relevant to users, so they have been separated.

## Relevant Confgurations:

* [domains.txt](domains.txt) - File containing the domains to request certificates for. See [Dehydrated Domains.txt Reference](https://github.com/dehydrated-io/dehydrated/blob/master/docs/domains_txt.md)
* [restart-containers.sh](restart-containers.sh) - Optional shell script that can be used to restart containers after certificates have been downloaded.

## References

* [Dehydrated](https://github.com/dehydrated-io/dehydrated/blob/master/README.md)
* [Dehydrated Domains.txt Reference](https://github.com/dehydrated-io/dehydrated/blob/master/docs/domains_txt.md)