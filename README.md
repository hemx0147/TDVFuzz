<h1 align="center">
  <br>TDVFuzz: Fuzzing Intel's Trust Domain Virtual Firmware</br>
</h1>

<!-- <p align="center">
  <a href="https://github.com/intel/ccc-linux-guest-hardening/actions/workflows/ci.yml">
    <img src="https://github.com/intel/ccc-linux-guest-hardening/actions/workflows/ci.yml/badge.svg" alt="CI">
  </a>
</p> -->

This project contains tools, scripts and documents for fuzzing Intel TDVF in the context of Confidential Cloud Computing threat model.

All components and scripts are provided for research and validation purposes only.

# Project overview:

After running the repository deployment task, the repo will be structured as follows:
- [`workdir`](https://github.com/hemx0147/TDVFuzz/tree/master/workdir): the main working directory containing the fuzzer script
- [`code-locations`](https://github.com/hemx0147/TDVFuzz/tree/master/code-locations): scripts and other tools for finding critical code locations in TDVF
- [`debug`](https://github.com/hemx0147/TDVFuzz/tree/master/debug): scripts and other tools regarding bug analysis & debugging of TDVF
- [`scripts`](https://github.com/hemx0147/TDVFuzz/tree/master/scripts): a general directory containing miscellaneous scripts
- `targets`: fuzzing targets including Tianocore EDK and a fixed TDVF test version
- `tools`: third-party tools that are useful for this project (e.g. Ghidra, CodeQL, PeInfo)
- `saved-workdirs`: instances of kAFL working directories (per default only in memory under `/dev/shm`) saved on disk

Additionally, in the [`workdir/bkc`](https://github.com/hemx0147/TDVFuzz/tree/master/workdir/bkc) directory, you will find:
- [`audit`](https://github.com/hemx0147/TDVFuzz/tree/master/workdir/bkc/audit): threat surface enumaration using static analysis
- [`kafl`](https://github.com/hemx0147/TDVFuzz/tree/master/workdir/bkc/kafl): configs and tools for Linux fuzzing with kAFL
- [`syzkaller`](https://github.com/hemx0147/TDVFuzz/tree/master/workdir/bkc/syzkaller): configs and tools for generating guest activity with Syzkaller
- [`coverage`](https://github.com/hemx0147/TDVFuzz/tree/master/workdir/bkc/coverage): tools for matching coverage and trace data against audit list

# Getting started

## Platform Requirements

- The setup requires a Gen-6 or newer Intel CPU (for Intel PT) and sufficient
  RAM to run several VMs at once.
- A modifed Linux host kernel is used for TDX emulation and VM-based snapshot
  fuzzing. This setup does not run inside a VM or container!

## Installation Requirements

The userspace installation and fuzzing workflow has been tested for recent
Ubuntu (>=20.04) and Debian (>=bullseye). It only requires Python3:

- `python3`
- `python3-venv`

~~~
sudo apt-get install python3 python3-venv
~~~

## Installation

Clone this repo to a new directory, e.g. `~/tdvfuzz`:

```shell
git clone git@github.com:hemx0147/TDVFuzz.git tdvfuzz
cd ~/tdvfuzz
```

We use Ansible playbooks to support local or remote installation.

### Local

- installation directory: `<repo_root>/`

Run the deployment with:
~~~
make deploy
~~~

You will be prompted for your root password.
If you are using a _passwordless sudo_ setup, just skip this by pressing enter.

### Remote

- installation directory: `$HOME/ccc`

You will have to update the `deploy/inventory` file to describe your nodes, according to [Ansible's inventory guide](https://docs.ansible.com/ansible/latest/user_guide/intro_inventory.html).
Make sure to **remove** the first line:

~~~
localhost ansible_connection=local
~~~

And run the deployment:

~~~
make deploy
~~~

Note: if your nodes require a proxy setup, update the `group_vars/all.yml`.

## Activate the environment

When the installation is complete, you will find several tools and scripts
inside the installation directory of the target system.

All subsequent steps assume that you have activated the installation environment.
This is done either by sourcing the `env.sh` script, or by typing `make env`,
which launches a sub-shell that makes it easier to exit and switch environments:

```shell
make env
```

# Kernel Hardening Workflow

Now that the necessary components are installed, you can pursue by one the following:

1. [Generate smatch audit list](./docs/generate_smatch_audit_list.md)
2. [Run kAFL boot and usermode harnesses](./bkc/kafl)
3. [Batch-Running Campaigns and Smatch Coverage](./docs/batch_run_campaign.md)

# Targeting your own guest kernel [TBD]

1. Port the provided guest kernel harnesses to your target kernel
2. Set `$LINUX_GUEST` to your target kernel source tree
3. Perform the above workflow steps based on your new target kernel
