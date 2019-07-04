# digitalocean-horizontal-auto-scaling

A project to automatically scale your DO droplets based on data gathered from [NetData](https://github.com/netdata/netdata).

## Prerequisites

### Master Node

+ Ruby - Tested with version 2.5.5
+ Bundler for gem management

### Slave Nodes

+ Must be configured to run [NetData](https://github.com/netdata/netdata) automatically on startup
