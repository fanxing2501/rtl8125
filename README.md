# Realtek RTL8125 2.5GbE PCIe

This repository contains the source code provided by Realtek for the RTL8125 2.5GbE PCIe controllers.

The source code is provided by Realtek as-is, without any kind of changelog. Git is only used for tracking down the changes introduced between versions.

## Original sources

You can find the original files provided by Realtek [here](https://www.realtek.com/Download/List?cate_id=584).

The same files from Realtek are provided as [release assets](https://github.com/openwrt/rtl8125/releases).

## R6S research build

This branch adds per-RX/TX queue counters for profiling the receive and transmit
hot paths on the NanoPi R6S:

```sh
ethtool -S wan | grep -E '(txq[01]|rxq[0-3])_(packets|bytes)'
```

Build and test artifacts are orchestrated through `jobs.yaml`. The `install-test`
job arms an automatic rollback before replacing the running module.

### Single-flow profiling

On the R6S, strict IOMMU invalidation made `arm_smmu_cmdq_issue_cmdlist`
consume about 39.6% of sampled A76 cycles during MTU 1500 bridge forwarding.
Keeping translated DMA domains while enabling lazy invalidation removed that
function from the measurable hot path:

```text
extraargs=cma=256M iommu.strict=0
```

With the same RSS key, a representative single TCP flow improved from about
1.75 Gbit/s to 2.32 Gbit/s without retransmissions. The main remaining sampled
costs were cache clean (21.1%), `rtl8125_rx_interrupt` (15.2%), memcpy (6.1%),
TX submission (4.3%), and TX completion (4.3%). Lazy invalidation retains IOMMU
address translation, but stale mappings may remain valid until a deferred flush.

## Disclaimer

Bug reports or issues should be reported directly to [Realtek](https://www.realtek.com).

This repository is used for OpenWrt development because the files provided by Realtek are protected with CAPTCHAs and can't be used for creating OpenWrt packages.
