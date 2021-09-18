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
