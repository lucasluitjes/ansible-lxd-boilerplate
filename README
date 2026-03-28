# What?

Setup for building and testing ansible playbooks against Ubuntu systems *fast*.

# Why?

The workflow I like for building reliable ansible playbooks: make freshly installed VMs, run an ansible playbook against them to install dependencies and configure applications, run automated tests against those VMs, and delete the VMs. For every change.

This ensures the playbooks are always accurate, and will work against fresh servers. But out of the box it's pretty slow.

# How?

* Use LXD system containers rather than full VMs.
* Configure LXD to use ZFS storage pool.
* Make snapshot of system container after creating it, and revert to snapshot on subsequent runs.
* Speeding up `apt install`
        * Run apt-cacher-ng on the host, and configure apt on system containers to use it.
        * Configure apt in system containers to use `eatmydata`.
        * Disable updating man-db in system-containers.
* Enable ansible pipelining and persistent SSH connection.
* Ruby-specific
  * Serve precompiled rubies on the host with nginx, and configure mise to install from there using `ruby.precompiled_url`.
  * Optionally configure `bundler` to store compiled gems in `/data`, a volume that is persisted. This reduces reproducability slightly, consider making this an optional optimization.

# Usage

* Copy boilerplate
* Run `lxc-scripts/init-host.sh` to configure LXD, nginx, apt-cacher-ng. This permanently modifies your system, I recommend doing this in a (real) VM for isolation.
* `/rebuild.sh`

# Demo

For testing, `rebuild.sh` does the following:

* Provision system container with fresh Ubuntu installation. 
* Run ansible playbook that:
  * Installs Caddy. 
  * Configures Caddy with a vhost "caddy.local" which has a hardcoded http response "success!" 
* `curl https://caddy.local` and verify that the output contains "success!"

First run:

```
real	0m30.449s
user	0m1.048s
sys	0m2.215s
```

Subsequent runs revert to snapshot of fresh install rather than launching a new system container:

```
real	0m11.664s
user	0m0.789s
sys	0m0.925s
```

When you're iterating and don't need full reproducability, run `rebuild.sh fast` to skip reverting to a snapshot. It just re-runs the ansible playbook and does the `curl` based test again:

```
real	0m2.539s
user	0m0.561s
sys	0m0.175s
```
