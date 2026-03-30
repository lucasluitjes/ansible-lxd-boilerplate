# What?

Setup for building and testing ansible playbooks against Ubuntu systems *fast*.

TLDR: the `rebuild.sh` demo script makes a fresh Ubuntu installation, runs an ansible playbook to install Caddy and configure it, and uses `curl` to verify that Caddy is running correctly.

```
$ time ./rebuild.sh
real	0m11.664s
user	0m0.789s
sys	0m0.925s
```

# Why?

The workflow I like for building reliable ansible playbooks: make freshly installed VMs, run an ansible playbook against them to install dependencies and configure applications, run automated tests against those VMs, and delete the VMs. Ideally for every change.

This ensures the playbooks are accurate, and will work against fresh servers. But out of the box it's pretty slow.

# How?

* Use LXD system containers rather than full VMs.
* Configure LXD to use ZFS storage pool.
* Make snapshot of system container after creating it, and revert to snapshot on subsequent runs.
* Speeding up `apt install`:
  * Run apt-cacher-ng on the host, and configure apt on system containers to use it.
  * Configure apt in system containers to use `eatmydata`.
  * Disable updating man-db in system-containers.
* Enable ansible pipelining and persistent SSH connection.
* Ruby-specific (not part of the demo script):
  * Serve precompiled rubies on the host with nginx, and configure mise to install from there using `ruby.precompiled_url`.
  * Configure `bundler` to store compiled gems in `/data`, a volume that is persisted. (This reduces reproducibility slightly, consider making this optional.)

# Usage

* Copy boilerplate.
* Run `lxc-scripts/init-host.sh` on Ubuntu 24.04 to configure LXD, nginx, apt-cacher-ng. This permanently modifies your system, I recommend doing this in a (real) VM for isolation.
* `./rebuild.sh`

# Demo

For testing, `rebuild.sh` does the following:

* Provision system container with fresh Ubuntu installation. 
* Run ansible playbook that:
  * Installs Caddy. 
  * Configures Caddy with a vhost "caddy.local" which has a hardcoded http response "success!" 
* `curl https://caddy.local` and verify that the output contains "success!"

First run:

```
$ time ./rebuild.sh
Doing full rebuild. Alternatively you can run:
  Skip lxc provisioning: ./rebuild.sh fast
  Skip lxc provisioning and pass args to ansible: ./rebuild.sh fast -t caddy --check --diff

Storage volume caddy-data created
Creating caddy
Starting caddy
Device data added to caddy
Pushing SSH key
Setting up apt to use caching proxy
Set up eatmydata for apt installs
Disabling man-db updates during apt installs
Not building database; man-db/auto-update is not 'true'.
man-db.service is a disabled or a static unit not running, not starting it.
Doing apt-get update before snapshotting to speed up future runs
Making base snapshot
Verifying ssh is reachable
caddy is up at 10.225.118.112
Writing inventory to /tmp/tmp.izLaNwOWvA
Running: ansible-playbook -i /tmp/tmp.izLaNwOWvA caddy.yml

PLAY [Install Caddy] *************************************************************************************************************************************

TASK [Gathering Facts] ***********************************************************************************************************************************
ok: [10.225.118.112]

TASK [Install Caddy] *************************************************************************************************************************************
changed: [10.225.118.112]

TASK [Deploy Caddyfile] **********************************************************************************************************************************
changed: [10.225.118.112]

RUNNING HANDLER [Reload Caddy] ***************************************************************************************************************************
changed: [10.225.118.112]

PLAY RECAP ***********************************************************************************************************************************************
10.225.118.112             : ok=4    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0

Testing if https://caddy.local responds with 'success!' as configured
Tests passed!

real	0m30.449s
user	0m1.048s
sys	0m2.215s
```

Subsequent runs revert to snapshot of fresh install rather than launching a new system container:

```
$ time ./rebuild.sh
Doing full rebuild. Alternatively you can run:
  Skip lxc provisioning: ./rebuild.sh fast
  Skip lxc provisioning and pass args to ansible: ./rebuild.sh fast -t caddy --check --diff

caddy already exists. Restoring to base snapshot and starting
Verifying ssh is reachable
caddy is up at 10.225.118.112
Writing inventory to /tmp/tmp.NgC7O1tW3z
Running: ansible-playbook -i /tmp/tmp.NgC7O1tW3z caddy.yml

PLAY [Install Caddy] *************************************************************************************************************************************

TASK [Gathering Facts] ***********************************************************************************************************************************
ok: [10.225.118.112]

TASK [Install Caddy] *************************************************************************************************************************************
changed: [10.225.118.112]

TASK [Deploy Caddyfile] **********************************************************************************************************************************
changed: [10.225.118.112]

RUNNING HANDLER [Reload Caddy] ***************************************************************************************************************************
changed: [10.225.118.112]

PLAY RECAP ***********************************************************************************************************************************************
10.225.118.112             : ok=4    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0

Testing if https://caddy.local responds with 'success!' as configured
Tests passed!

real	0m11.664s
user	0m0.789s
sys	0m0.925s
```

When you're iterating and don't need full reproducibility, run `rebuild.sh fast` to skip reverting to a snapshot. It just re-runs the ansible playbook and does the `curl` based test again:

```
$ time ./rebuild.sh fast
Fast mode - skipping lxc reprovisioning step!
Writing inventory to /tmp/tmp.I5sJO1BABc
Running: ansible-playbook -i /tmp/tmp.I5sJO1BABc caddy.yml

PLAY [Install Caddy] *************************************************************************************************************************************

TASK [Gathering Facts] ***********************************************************************************************************************************
ok: [10.225.118.112]

TASK [Install Caddy] *************************************************************************************************************************************
ok: [10.225.118.112]

TASK [Deploy Caddyfile] **********************************************************************************************************************************
ok: [10.225.118.112]

PLAY RECAP ***********************************************************************************************************************************************
10.225.118.112             : ok=3    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0

Testing if https://caddy.local responds with 'success!' as configured
Tests passed!

real	0m2.539s
user	0m0.561s
sys	0m0.175s
```
