 #include <Timer.h>
 #include "BlinkToRadio.h"
 
configuration BlinkToRadioAppC {}

implementation {
  components BlinkToRadioC;

  components MainC;
  components LedsC;
  components AMSendReceiveC as Radio;
  components new TimerMilliC() as Timer0;

  BlinkToRadioC.Boot -> MainC;
  BlinkToRadioC.RadioControl -> Radio;

  BlinkToRadioC.Leds -> LedsC;
  BlinkToRadioC.Timer0 -> Timer0;

  BlinkToRadioC.Packet -> Radio;
  BlinkToRadioC.AMPacket -> Radio;
  BlinkToRadioC.AMSendReceiveI -> Radio;
}
