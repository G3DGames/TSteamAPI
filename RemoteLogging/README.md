# RemoteLogging - optional

**This folder is 100% optional. It has nothing to do with Steam or the
Steamworks library**, and nothing in `lib/`, `fmx/`, `vcl/`, `lcl/` or the
packages uses it. It exists for one job: getting a program's log from a
device without a keyboard or a convenient screen (a Steam Deck or similar
handheld, a TV PC, ...) onto your desk machine while you test.

You can ignore it completely: the demos work exactly the same without it.

## What it is

| Part | What it does |
|---|---|
| `LogReceiver/` | A small FMX app for your desk machine. It announces itself on the local network, asks you to **Accept** each program that wants to send its log, shows the lines live and saves each session to a file in `Documents/LogReceiver`. |
| `src/RemoteLog.Sender.pas` | The sending side, one class (`TRemoteLogSender`). A program hands it log lines; it finds receivers, connects and streams the lines in the background. |
| `src/RemoteLog.Protocol.pas` | Ports and message formats, shared by both. |

Delphi only (it uses Indy, which comes with Delphi): Windows, macOS, Linux
and Android. A release build of LogReceiver may be offered with the
project's releases for people without Delphi.

## Using it

1. Start **LogReceiver** on your desk machine and choose the network the
   device is on in **Listen on**, then **OK**. The list puts the machine's
   real network first (Windows: an Ethernet / Wi-Fi adapter with a default
   gateway and no VPN / virtual name; other systems cannot tell), then
   192.168.x.x, 172.16-31.x.x and 10.x.x.x addresses (VPNs, virtual
   machines and WSL usually come last). It listens on that address only
   and remembers the choice for next time. The first time, allow it
   through the firewall on **private** networks. **File -> Exit** closes it.
2. In the program on the device, choose **File -> Send log to receiver**
   - in SteamInputDemo also **DPadUp + Y + LeftBumper held together** on
   the controller (SteamOS shows every main window full screen, the menu
   is awkward there). It looks for receivers for 2.5 seconds in the
   background and connects to the one that answers - no questions on the
   device (if several answer, the first; the log names them all). None:
   the log says so; start LogReceiver, press OK there, and try again.
3. LogReceiver asks *"Accept the log of ... from ...?"* - click **Yes**.
   The program sends everything logged so far, then every new line.
4. **File -> Stop sending log** ends it; so does closing the program (the
   last lines are still sent).

If the connection drops, the sender keeps the lines and reconnects every 3
seconds; LogReceiver lets the same session back in without asking again and
appends to the same file.

## Security

There is no password: **clicking Accept is the protection**, and the
receiver only listens while it is running. Nothing is encrypted - use it on
your own network, not on public Wi-Fi.

## Protocol

Plain text, so any TCP client (`nc`, PuTTY in raw mode) can stand in for a
sender while testing:

- **Discovery:** the receiver broadcasts, once a second, on **UDP port
  47811**: `TSTEAMAPI-LOGRECEIVER 1 <tcp port> <receiver name>`, sent
  from the chosen address to its network's broadcast address
  (192.168.1.255, ...) and to 255.255.255.255 (Windows may send the
  latter out of another adapter, e.g. a VPN).
- **Connection:** the sender connects to **TCP port 47812** and sends one
  line: `HELLO <app>|<platform>|<machine>|<session>`. If 47812 is taken
  (a second LogReceiver, another program), the receiver uses the next
  free port up to 47821 and announces that one - senders that discover it
  need nothing.
- **Discovery port in use** (UDP 47811, e.g. two programs on one machine
  searching at the same moment): the sender logs it; try again.
- **Answer:** `OK` (accepted, the connection stays open) or `NO` (refused,
  the connection closes). A session id accepted before is answered `OK`
  without asking.
- **Log lines:** after `OK`, every line from the sender is one log line.
  UTF-8, lines end with LF.

## Adding it to another program

```pascal
uses RemoteLog.Sender;

// find receivers in the background (the handler runs on the main thread;
// keep FDiscovery and free it later - not inside the handler)
FDiscovery := TRemoteLogDiscovery.Create(2500, ReceiversFound);
...
FSender := TRemoteLogSender.Create;
FSender.OnStatus := RemoteLogStatus;            // optional, main thread
FSender.Start('192.168.1.20', 47812, 'MyApp');  // or a receiver found
...
FSender.Send(Line);                             // from your log routine, any thread
...
FSender.Free;                                   // sends what is queued (up to 1 s), then stops
```

Add `RemoteLogging\src` to the program's unit search path. Nothing else in
the repository needs it.
