# benchmark-disks

Test filesystem thru-puts for different read/write-patterns and produce plots to compare your different disks and disk setups.

![plot](.readme/plots.png)

With multiple disks in my system I wanted to find out what is a good setup;
where to put the root filesystem, where to put the docker cache, and what the trade-offs are.

Especially when it comes to the docker cache (`/var/lib/docker`) it's convenient to have it on a separate file system.
This way it wont use up your main disk space, or at least it's bounded.
If you use `lvm` then you can setup things quite flexibly.
The docker cache can still sit on the same physical disk, but at least on a different logical volume.

With `lvm` it's also super easy to make a logical volume that is a stripped raid on some of your SSD's.
That might be a good candidate for the docker cache.
Based on my tests, a few "aging" SSD's in a 4-way stripped raid can keep up with a very modern SSD.
That's a nice alternative for `/var/lib/docker`.

The python script is only here for orchestration and plotting.
The real benchmarking work is based on the excellent [fio](https://fio.readthedocs.io/en/latest/).

## usage

Run with:

> ./bench

If it's the first time, it will install apt and python dependencies.
See the file itself for details.
It's only tested with ubuntu 20.04.

There are only 2 subcommands: `run`, and `summary`.

First setup all the filesystems you want to test.
If you want to test some stripped raids, just setup a small logical volume with `lvm` for every configuration you want to test.
Ultimately, you need a writable location for every configuration you want to test.

Note: We test the filesystem, not the block device.
That means it also tests the filesystem type you chose,
not just the pure block device speed.

Then for every filesystem to test, run something like

> ./bench run --basefolder=./runs --name=disk-xyz-with-raid --testfile=~/test-lvs/some-raid --repeat=3

Name can be chose arbitrarily.
The testfile needs to be on the filesystem to be tested.

Whenever you want to see plots, run

> ./bench summary
 
It will put `plots.png` by default in `./runs`.
If you want to make different plots, look at `bench.py:summary`.
Plotting is based on panda `DataFrame`'s and `seaborn`.
