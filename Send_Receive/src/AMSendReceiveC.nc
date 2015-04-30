configuration AMSendReceiveC {
  provides {
    interface SplitControl;
    interface Packet;
    interface AMPacket;
    interface AMSendReceiveI;
  }
}
implementation {
  components AMSendReceiveP;
  components ActiveMessageC as Radio;
  components SerialActiveMessageC as Serial;

  SplitControl = AMSendReceiveP;
  AMSendReceiveI = AMSendReceiveP;

  AMSendReceiveP.SerialControl -> Serial;
  AMSendReceiveP.RadioControl -> Radio;

  Packet = Radio;
  AMPacket = Radio;

  AMSendReceiveP.UartSend -> Serial;
  AMSendReceiveP.UartPacket -> Serial;
  AMSendReceiveP.UartAMPacket -> Serial;
  
  AMSendReceiveP.RadioPacket -> Radio;
  AMSendReceiveP.RadioAMPacket -> Radio;
  AMSendReceiveP.RadioSend -> Radio;
  AMSendReceiveP.RadioReceive -> Radio.Receive;

}
