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
| `src/RemoteLog.SenderFPC.pas` | The same sending side for **Free Pascal / Lazarus** (same classes and methods), on FPC's own `Sockets` unit - no Indy, no extra package. Used by demos/VirtualGamepadLCL and demos/SteamDemoLCL (through demos/Shared/DemoRemoteLog.pas). |
| `src/RemoteLog.Protocol.pas` | Ports and message formats, shared by all three. |

LogReceiver and RemoteLog.Sender are Delphi (they use Indy, which comes
with Delphi): Windows, macOS, Linux and Android. RemoteLog.SenderFPC is
Free Pascal 3.2.2: Windows, Linux, macOS. A release build of LogReceiver
may be offered with the project's releases for people without Delphi.

## Using it

1. Start **LogReceiver** on your desk machine and choose the network the
   device is on in **Listen on**, then **OK**. The list puts the machine's
   real network first (Windows: an Ethernet / Wi-Fi adapter with a default
   gateway and no VPN / virtual name; other systems cannot tell), then
   192.168.x.x, 172.16-31.x.x and 10.x.x.x addresses (VPNs, virtual
   machines and WSL usually come last). It listens on that address only
   and remembers the choice for next time. The first time, allow it
   through the firewall on **private** networks. **File -> Clear Log**
   empties the lines shown (the session's log file keeps them);
   **File -> Exit** closes it. Its icon is an ear (purple tile), to find
   it on the task bar (`LogReceiver.ico` / `.icns`, drawn by
   `tools/gen_icons.py`).
2. In the program on the device, choose **File -> Send log to receiver**
   - in SteamInputDemo also **DPadUp + Y + LeftBumper held together** on
   the controller, in VirtualGamepad **Start Remote Logging** in the
   overlay menu (hold Start) (SteamOS shows every main window full screen, the menu
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
appends to the same file. That is the sender's default (`Retry = True`, used
by SteamInputDemo and the VirtualGamepads). The SteamDemos (FMX, VCL, LCL,
SteamDemoPad - through `demos/Shared/DemoRemoteLog.pas`) try ONCE
(`Retry = False`): their menu item reads *Connecting...* and is greyed
until the receiver accepts (then *Stop sending*), and a refusal, no Accept
within 2 minutes or a failed / lost connection turns it back into *Send* -
the log says why. `TRemoteLogSender.State` (`rlsIdle`, `rlsConnecting`,
`rlsAccepted`, declared in RemoteLog.Protocol) tells a program which it is;
it is set before each `OnStatus` message.

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
the repository needs it. With Free Pascal / Lazarus write
`uses RemoteLog.SenderFPC;` instead - the code above stays the same.
