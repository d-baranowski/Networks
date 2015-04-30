// $Id: AMSendReceiveP.nc,v 1.00 2011/02/26 10:41:00 regehr Exp $

/*
 * This filedraws heavily on BaseStationP which is part of the TinyOS-2.1.0 distribution.
 * It has been modified to provide a general purpose module for the transmission and
 * reception of radio messages. Messages sent over the AMSendReceiveI interface are cloned
 * before transmission then the clone is sent via a buffer to the UART. Messages received 
 * over the interface are cloned and the clone sent to the UART before signalling an event
 * over the interface. The UART procedures implement copy semantics but send and receive do not.
 *
 * Command send will return a pointer to a free message buffer which will normally be different
 * to that sent. If it is the same, then the message could not be sent.
 *
 * Event receive must return a pointer to a free message buffer which can be used for the next
 * reception. The integrity of this buffer is not guaranteed after the return. It is therefore
 * the responsiblity of the event handler to protect messages received as long as they are
 * needed. This can be done by copying out the received message buffer contents or returning a
 * message pointer to a different buffer to that received.
 *
 * Note that users of AMSendReceiveC must call the start command over the AMSendReceiveI
 * interface and then wait for the startDone event before tring to send messages.
 *
 *
 *
 *
 * "Copyright (c) 2000-2005 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
 * CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 * Copyright (c) 2002-2005 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */

/*
 * @author Phil Buonadonna
 * @author Gilman Tolle
 * @author David Gay
 * @author Alan Tully
 */

#include "AM.h"
#include "Serial.h"

module AMSendReceiveP {
  provides {
    interface SplitControl;
    interface AMSendReceiveI;
  }
  uses {
     interface SplitControl as SerialControl;
     interface SplitControl as RadioControl;

     interface Packet as UartPacket;
     interface AMPacket as UartAMPacket;
     interface AMSend as UartSend[am_id_t id];

     interface Packet as RadioPacket;
     interface AMPacket as RadioAMPacket;
     interface AMSend as RadioSend[am_id_t id];
     interface Receive as RadioReceive[am_id_t id];
  }
}

implementation {
/******************************************
 *
 * Global variables
 *
 ******************************************/

enum {
  UART_QUEUE_LEN = 12,
  RADIO_QUEUE_LEN = 12,
};

message_t  uartQueueBufs[UART_QUEUE_LEN];
message_t  * ONE_NOK uartQueue[UART_QUEUE_LEN];
uint8_t    uartIn, uartOut;
bool       uartBusy, uartFull;

message_t  radioQueueBufs[RADIO_QUEUE_LEN];
message_t  * ONE_NOK radioQueue[RADIO_QUEUE_LEN];
uint8_t    radioIn, radioOut;
bool       radioBusy, radioFull;

/******************************************
 *
 * Startup
 *
 ******************************************/

command error_t SplitControl.start() {
  uint8_t i;

  for (i = 0; i < UART_QUEUE_LEN; i++)
    uartQueue[i] = &uartQueueBufs[i];
  uartIn = uartOut = 0;
  uartBusy = FALSE;
  uartFull = TRUE;

  for (i = 0; i < RADIO_QUEUE_LEN; i++)
    radioQueue[i] = &radioQueueBufs[i];
  radioIn = radioOut = 0;
  radioBusy = FALSE;
  radioFull = TRUE;

  if ((call SerialControl.start() == SUCCESS)
    && (call RadioControl.start() == SUCCESS))
    return SUCCESS;
  else
    return FAIL;
}

command error_t SplitControl.stop(){return FAIL;}

event void SerialControl.startDone(error_t error) {
  if (error == SUCCESS) {
    uartFull = FALSE;
    if (!radioFull) signal SplitControl.startDone(SUCCESS);
  } else {
    signal SplitControl.startDone(FAIL);
  }
}

event void RadioControl.startDone(error_t error) {
  if (error == SUCCESS) {
    radioFull = FALSE;
    if (!uartFull) signal SplitControl.startDone(SUCCESS);
  } else {
    signal SplitControl.startDone(FAIL);
  }
}

event void SerialControl.stopDone(error_t error) {}
event void RadioControl.stopDone(error_t error) {}


/******************************************
 *
 * UART Send
 *
 ******************************************/

task void uartSendTask() {
  uint8_t len;
  uint8_t tmpLen;
  am_id_t id;
  am_addr_t addr, src;
  message_t* msg;
  atomic
    if (uartIn == uartOut && !uartFull) {
      uartBusy = FALSE;
      return;
    }

  msg = uartQueue[uartOut];
  tmpLen = len = call UartPacket.payloadLength(msg);
  id = call RadioAMPacket.type(msg);
  addr = call RadioAMPacket.destination(msg);
  src = call RadioAMPacket.source(msg);

  if (call UartSend.send[id](addr, uartQueue[uartOut], len) != SUCCESS)
    post uartSendTask();
}

message_t* sendToUart(am_id_t id, am_addr_t dest, message_t *msg, uint8_t len) {
  message_t *ret = msg;

  atomic {
    if (!uartFull) {
      am_addr_t source = call RadioAMPacket.source(msg);
      am_group_t grp = call RadioAMPacket.group(msg);
      uint8_t* from = call RadioPacket.getPayload(msg, len);
      uint8_t* to;
      uint8_t i;

      message_t *copy = uartQueue[uartIn];

      call UartPacket.setPayloadLength(copy, len);
      call UartAMPacket.setDestination(copy, dest);
      call UartAMPacket.setSource(copy, source);
      call UartAMPacket.setType(copy, id);
      call UartAMPacket.setGroup(copy, grp);
       
      to = (uint8_t*)call UartPacket.getPayload(copy, len);
      for (i = 0; i < len; i++) {
        to[i] = from[i];
      }

      uartIn = (uartIn + 1) % UART_QUEUE_LEN;

      if (uartIn == uartOut)
        uartFull = TRUE;

      if (!uartBusy) {
        post uartSendTask();
        uartBusy = TRUE;
      }
    }
  }
  return ret; // return original message
}

event void UartSend.sendDone[am_id_t id](message_t* msg, error_t error) {
  if (error == SUCCESS)
    atomic
      if (msg == uartQueue[uartOut]) {
        if (++uartOut >= UART_QUEUE_LEN)
          uartOut = 0;
        if (uartFull)
          uartFull = FALSE;
      }
  post uartSendTask();
}


/******************************************
 *
 * Radio Send
 *
 ******************************************/

task void radioSendTask() {
  message_t* msg;
  am_id_t id;
  am_addr_t dest;
  uint8_t len;
   
  atomic
    if (radioIn == radioOut && !radioFull) {
      radioBusy = FALSE;
      return;
    }

  msg = radioQueue[radioOut];
  len = call RadioPacket.payloadLength(msg);
  dest = call RadioAMPacket.destination(msg);
  id = call RadioAMPacket.type(msg);

  sendToUart(id, dest, msg, len);
  if (call RadioSend.send[id](dest, msg, len) != SUCCESS) 
    post radioSendTask();
}

command message_t* AMSendReceiveI.send(message_t *msg) {
  message_t *ret = msg;

  atomic
    if (!radioFull) {
      ret = radioQueue[radioIn];
      radioQueue[radioIn] = msg;
      if (++radioIn >= RADIO_QUEUE_LEN)
        radioIn = 0;
      if (radioIn == radioOut)
        radioFull = TRUE;

      if (!radioBusy) {
        post radioSendTask();
        radioBusy = TRUE;
      }
    }
  return ret;
}

event void RadioSend.sendDone[am_id_t id](message_t* msg, error_t error) {
  if (error == SUCCESS)
    atomic
      if (msg == radioQueue[radioOut]) {
        if (++radioOut >= RADIO_QUEUE_LEN)
          radioOut = 0;
        if (radioFull)
          radioFull = FALSE;
      }
  post radioSendTask();
}

/******************************************
 *
 * Radio Receive
 *
 ******************************************/


event message_t *RadioReceive.receive[am_id_t id](message_t *msg, void *payload, uint8_t len) {
  if (call RadioAMPacket.destination(msg) == TOS_NODE_ID) { 
    am_addr_t dest = call RadioAMPacket.destination(msg);
    sendToUart(id, dest, msg, len);
    return signal AMSendReceiveI.receive(msg);
  } else { // ignore broadcast messages
    return msg;
  }
}


}
