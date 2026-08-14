# Realtek RTL8125 2.5GbE PCIe

This repository contains the source code provided by Realtek for the RTL8125 2.5GbE PCIe controllers.

The source code is provided by Realtek as-is, without any kind of changelog. Git is only used for tracking down the changes introduced between versions.

## Original sources

You can find the original files provided by Realtek [here](https://www.realtek.com/Download/List?cate_id=584).

The same files from Realtek are provided as [release assets](https://github.com/openwrt/rtl8125/releases).

## Disclaimer

Bug reports or issues should be reported directly to [Realtek](https://www.realtek.com).

This repository is used for OpenWrt development because the files provided by Realtek are protected with CAPTCHAs and can't be used for creating OpenWrt packages.

## Paired queue test build

This branch adds load-time queue limits and records the ingress RX queue on each
skb so Linux can preserve the queue index when forwarding through a bridge:

```sh
insmod r8125.ko rx_queues=2 tx_queues=2
```

The default value for both parameters is `0`, which retains the upstream
automatic selection. The research build also exposes per-queue packet and byte
counters through `ethtool -S`.

Build and guarded testing use `groot jobs build` and `groot jobs install-test`.
Persistent installation uses `groot jobs install-persistent`: it installs the
module into the running kernel's module tree, disables `r8169`, and rebuilds
the initramfs so `r8125` is loaded directly with two RX and TX queues.

```sh
groot jobs install-persistent
```
