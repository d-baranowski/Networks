#ifndef BLINKTORADIO_H
#define BLINKTORADIO_H
 
enum {
  AM_BLINKTORADIO = 6,
  DEST_ECHO = 2,
  TIMER_PERIOD_MILLI = 1000,
};

enum {
  TYPE_DATA = 0x55,
  TYPE_ACK = 0xCC,
};
 
typedef nx_struct BlinkToRadioMsg {
  nx_uint16_t type;
  nx_uint16_t seq;
  nx_uint16_t nodeid;
  nx_uint16_t counter;
} BlinkToRadioMsg;

#endif