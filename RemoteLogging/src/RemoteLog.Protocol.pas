{ @abstract(Remote logging protocol: ports and message formats shared by
  @link(RemoteLog.Sender) and the LogReceiver app.)

  Remote logging is 100% optional and has nothing to do with Steam: a
  program streams its log lines over the local network to the LogReceiver
  app (RemoteLogging/LogReceiver), which asks its user to accept each
  sender and saves every session to a file.

  The protocol is plain text, so it can be tried with any TCP client:
  @unorderedList(
    @item(The receiver broadcasts @link(RL_ANNOUNCE) lines on UDP port
      @link(RL_DISCOVERY_PORT) about once a second:
      @code(TSTEAMAPI-LOGRECEIVER 1 <tcp port> <receiver name>).)
    @item(A sender connects to that TCP port and sends one line:
      @code(HELLO <app>|<platform>|<machine>|<session>).)
    @item(The receiver asks its user; it answers @code(OK) and keeps the
      connection, or @code(NO) and closes it. A session it has accepted
      before (a reconnect) is answered @code(OK) at once.)
    @item(After @code(OK) every further line from the sender is one log
      line. UTF-8, lines end with LF.))
  There is no password: the Accept click is the protection, and the
  receiver only listens while it runs. Do not use it on untrusted
  networks - nothing is encrypted. }
unit RemoteLog.Protocol;

interface

const
  { UDP port the receiver broadcasts its announcement on. }
  RL_DISCOVERY_PORT = 47811;
  { Default TCP port the receiver accepts senders on. }
  RL_DEFAULT_TCP_PORT = 47812;
  { Ports the receiver tries, from @link(RL_DEFAULT_TCP_PORT) up, when the
    default is taken; the announcement names the one it got. }
  RL_PORT_TRIES = 10;
  { First word of the receiver's UDP announcement. }
  RL_ANNOUNCE = 'TSTEAMAPI-LOGRECEIVER';
  { Protocol version in the announcement. }
  RL_VERSION = '1';
  { First word of the sender's greeting line. }
  RL_HELLO = 'HELLO';
  { Receiver's answer: the sender was accepted. }
  RL_ACCEPTED = 'OK';
  { Receiver's answer: the sender was refused (the connection then closes). }
  RL_REFUSED = 'NO';
  { Separator of the fields in the greeting line. }
  RL_FIELD_SEPARATOR = '|';

implementation

end.
