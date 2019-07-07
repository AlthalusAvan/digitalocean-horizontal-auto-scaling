# digitalocean-horizontal-auto-scaling

## This software is in very early stages, and is not fully functional

A project to automatically scale your DO droplets based on data gathered from [NetData](https://github.com/netdata/netdata).

## Prerequisites

### Master Node

+ Ruby - Tested with version 2.5.5
+ Bundler for gem management

### Slave Nodes

+ Must be configured to run [NetData](https://github.com/netdata/netdata) automatically on startup

## Initial Setup

1. Clone or download this repository
2. Run `bundler install` to download gems (run `gem install bundler` if bundler is not installed on your system)
3. Copy `config/config.example.yml` to a new file named `config/config.yml`
4. Enter your DigitalOcean API key in the appropriate line of `config/config.yml`
5. Configure your autoscaling environment with DigitalOcean tags, CPU Thresholds and Min/Max droplets
6. Configure your droplet setup settings - helper commands are listed in comments, e.g. `ruby scaler.rb list regions` to list available droplet limits
7. Set your netdata port if it is different from default

## Available commands

### scale

`ruby scaler.rb scale`
Runs the autoscale function. This will gather information from the DO api about currently active droplets with the autoscaling tag set in `config/config.yml`, gather CPU usage information from netdata, and scale up or down if thresholds are exceeded (and droplet limits allow).
In most use cases this command should be executed using a cron job on a regular interval - recommended interval is 60 seconds.

### list
`ruby scaler.rb list {type}`
Lists configuration helper information from the DigitalOcean API. Type must be specified as one of the following:

#### images
`ruby scaler.rb list images`
Lists all available images _including DO default and marketplace images_ - in most cases you'll want to use `snapshots` instead. Use the `ID` field in config file.

Example output:
```
ID       Name    Type    Size(GB)        Distribution 
16376426        Cassandra on 14.04      snapshot        0.59    Ubuntu
25256991        14.04.5 x32     snapshot        0.43    Ubuntu
28282122        10.4 x64 ZFS    snapshot        0.75    FreeBSD
28282143        10.4 x64        snapshot        0.72    FreeBSD
...
```

#### keys
`ruby scaler.rb list keys`
Lists available SSH keys that can be added to VMs. Use the `ID` field in config file.

Example output:
```
ID       Name
19331324        Home Key
74063591        Work Key
```

#### regions
`ruby scaler.rb list regions`
Lists avilable DigitalOcean regions to deploy VMs in. Use the `Slug` field in config file.

Example output:
```
Slug     Name    Available
nyc1    New York 1      true
sgp1    Singapore 1     true
lon1    London 1        true
```

#### sizes
`ruby scaler.rb list sizes`
Lists sizes available for VMs. Use the `Slug` field in config file.

Example output:
```
Slug     VCpus   Memory(MB)      Disk(GB)        Price($/Mo) 
512mb   1       512     20      5.0
s-1vcpu-1gb     1       1024    25      5.0
1gb     1       1024    30      10.0
s-1vcpu-2gb     1       2048    50      10.0
```

#### Snapshots
`ruby scaler.rb list snapshots`
Lists your VM snapshots - not including public images. Use the `ID` field in config files.

Example output:
```
ID       Name    Size(GB)        Min Disk Size(GB)       Type
49113222        db-02 2019-07-02        1.71    60      droplet
49125561        db-03 2019-07-02        1.78    60      droplet
49193223        web-template-with-redis 1.79    60      droplet
```

## Helper Flags

### --verbose

Shows more logging information for diagnostics. Can be quite chatty, don't use this for every script run.

## To-Do List

- Add advanced error handling with better logging for debugging
- Add health checks with automatic restarting of unhealthy nodes
- Add scaling interval to limit how quickly nodes can be added / removed
- Reformat output lists as [tables](https://github.com/tj/terminal-table) for clearer output
