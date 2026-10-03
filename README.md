# R-Tuned LAN Patcher

A LAN patcher for **R-Tuned** running through **TeknoParrot**, designed to allow linked cabinets to communicate over a normal Windows Ethernet or Wi-Fi network.

> **Current status:** 2-cabinet play is tested and working. 3- and 4-cabinet support is currently **not tested** and needs community validation.

## Status

| Configuration | Status |
|---|---|
| 2 Cabinets | ✅ **TESTED** |
| 3 Cabinets | ⚠️ **NOT TESTED** |
| 4 Cabinets | ⚠️ **NOT TESTED** |

The 2-cabinet implementation has successfully completed network checking, linked two physical cabinets over Wi-Fi, started a multiplayer race, completed a full race, and returned to the game normally.

## What Was Discovered

R-Tuned uses an internal Sega virtual network in the `192.168.64.x` range, while TeknoParrot transports the network traffic using **UDP port 10600**.

The important discovery was that the Sega virtual network does **not** need to be replaced.

Instead, the patch keeps R-Tuned's internal addressing intact and translates only the physical network destination to the real Windows IP address of each cabinet.

```text
R-Tuned / Sega virtual network
        192.168.64.x
             |
             |  transport translation
             v
Normal Windows LAN / Wi-Fi
        192.168.x.x
             |
             v
         UDP 10600
```

### Virtual Cabinet Addresses

Reverse engineering and packet captures identified the following virtual addressing:

```text
2 Cabinets
CAB1 -> 192.168.64.1
CAB2 -> 192.168.64.2

3 Cabinets
CAB1 -> 192.168.64.17
CAB2 -> 192.168.64.18
CAB3 -> 192.168.64.19

4 Cabinets
CAB1 -> 192.168.64.33
CAB2 -> 192.168.64.34
CAB3 -> 192.168.64.35
CAB4 -> 192.168.64.36
```

R-Tuned already contains native logic for iterating through multiple peer destinations.

## Why a TX Patch Wasn't Enough

Redirecting outgoing traffic to the real Windows IP addresses worked: thousands of R-Tuned packets were successfully exchanged between the two PCs.

However, R-Tuned still rejected incoming packets.

The receive path compared the **actual source IP returned by `recvfrom()`** with the **virtual Sega IP contained inside the packet**.

For example:

```text
Physical source IP: 192.168.2.212
Virtual Sega IP:    192.168.64.2
```

Because these addresses are intentionally different, the packet failed R-Tuned's original validation.

A minimal RX modification was therefore added to accept this specific IP mismatch while leaving the rest of the receive logic intact.

This combination of **TX destination translation + minimal RX handling** produced the first fully working 2-cabinet setup.

## Tested Result

Two physical R-Tuned cabinets have successfully communicated over a normal Wi-Fi network using TeknoParrot.

Validated behavior:

- ✅ R-Tuned starts normally
- ✅ Network checking completes
- ✅ Both cabinets detect each other
- ✅ Multiplayer race starts
- ✅ Full race completes successfully
- ✅ Game returns normally afterward
- ✅ Sega virtual network remains intact
- ✅ Gameplay traffic remains on UDP `10600`

## V2.2b — V2.1 Extended

V2.2b is intended to extend the proven V2.1 architecture to additional cabinets.

The patcher allows selection of:

```text
2 Cabinets  - TESTED
3 Cabinets  - NOT TESTED
4 Cabinets  - NOT TESTED
```

For 2 cabinets, the goal is strict compatibility with the known-good V2.1 behavior.

The 3- and 4-cabinet modes should be considered **experimental until validated on real multi-cabinet installations**.

## Community Testing Wanted

We currently only have access to two physical cabinets.

If you have a **3- or 4-cabinet R-Tuned setup**, testing and packet captures would be greatly appreciated.

Please report:

```text
Patcher version:
Number of cabinets:

CAB1 Windows IP:
CAB2 Windows IP:
CAB3 Windows IP:
CAB4 Windows IP:

LINK IDs:

CHECKING NETWORK: PASS / FAIL
All cabinets detected: YES / NO
Race started: YES / NO
Full race completed: YES / NO
Return to menu: YES / NO

Wireshark capture available: YES / NO
Notes:
```

For Wireshark analysis, the useful display filter is:

```text
udp.port == 10600
```

Captures from every cabinet are ideal when troubleshooting.

## Technical Notes

Some of the key reverse-engineering findings include:

- R-Tuned/TeknoParrot gameplay/link traffic was observed on UDP port `10600`.
- Link/network packets observed during testing were 164 bytes.
- The virtual `192.168.64.x` network is part of the game's protocol and should remain intact.
- R-Tuned maintains a destination table containing `sockaddr_in` structures for its peers.
- The transmit routine already iterates according to the configured cabinet count.
- A per-node size of `224` bytes was observed in the network structures.
- Four-cabinet captures confirmed a table size of `896` (`224 × 4`).
- Physical LAN addresses and Sega virtual cabinet identities can be separated successfully.

## Important

Always keep an untouched backup of your original `dsr_HD`.

The **2-cabinet configuration is the only configuration currently validated on real hardware**. Do not treat 3- or 4-cabinet support as confirmed until community testing proves otherwise.

## Project Goal

The goal is not to rewrite R-Tuned's multiplayer protocol.

The goal is to preserve the original Sega networking behavior while making its physical transport usable on a standard modern Windows LAN or Wi-Fi network.

---

### Current Project Status

**2 Cabinets:** ✅ Tested and working  
**3 Cabinets:** ⚠️ Not tested  
**4 Cabinets:** ⚠️ Not tested

Community testing and Wireshark captures are welcome.
