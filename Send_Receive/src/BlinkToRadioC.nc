#include <Timer.h>
#include "BlinkToRadio.h"

module BlinkToRadioC {
	uses {
		interface Boot;
		interface SplitControl as RadioControl;

		interface Leds;
		interface Timer<TMilli> as Timer0;

		interface Packet;
		interface AMPacket;
		interface AMSendReceiveI;
	}
}

implementation {
	bool ack = FALSE;
	nx_uint16_t prevS;
	uint16_t counter = 0;
	message_t sendMsgBuf;
	message_t * sendMsg = &sendMsgBuf; // initially points to sendMsgBuf  

	event void Boot.booted() {
		call RadioControl.start();
	}
	;

	event void RadioControl.startDone(error_t error) {
		if(error == SUCCESS) {
			call Timer0.startPeriodic(TIMER_PERIOD_MILLI);
		}
	}
	;

	event void RadioControl.stopDone(error_t error) {
	}
	;

	event void Timer0.fired() {
		if(ack || counter == 0) {
			BlinkToRadioMsg * btrpkt;

			call AMPacket.setType(sendMsg, AM_BLINKTORADIO);
			call AMPacket.setDestination(sendMsg, DEST_ECHO);
			call AMPacket.setSource(sendMsg, TOS_NODE_ID);
			call Packet.setPayloadLength(sendMsg, sizeof(BlinkToRadioMsg));

			btrpkt = (BlinkToRadioMsg * )(call Packet.getPayload(sendMsg,
					sizeof(BlinkToRadioMsg)));
			counter++;
			btrpkt->type = TYPE_DATA;
			
			if (prevS == 1 || counter == 0){
				btrpkt->seq = 0;
				prevS = 0;
			} else if (prevS == 0){
				btrpkt->seq = 1;
				prevS = 1;
			}
			
			btrpkt->nodeid = TOS_NODE_ID;
			btrpkt->counter = counter;

			// send message and store returned pointer to free buffer for next message
			sendMsg = call AMSendReceiveI.send(sendMsg);
			ack = FALSE;
		}
	}

	event message_t * AMSendReceiveI.receive(message_t * msg) {
		uint8_t len = call Packet.payloadLength(msg);
		BlinkToRadioMsg * btrpkt = (BlinkToRadioMsg * )(call Packet.getPayload(msg,
				len));
		call Leds.set(btrpkt->counter);

		if(btrpkt->type == TYPE_DATA) {
			call AMPacket.setDestination(sendMsg, DEST_ECHO);
			call AMPacket.setSource(sendMsg, TOS_NODE_ID);
			call Packet.setPayloadLength(sendMsg, sizeof(BlinkToRadioMsg));
			
			btrpkt = (BlinkToRadioMsg * )(call Packet.getPayload(sendMsg, sizeof(BlinkToRadioMsg)));
			btrpkt->type = TYPE_ACK;
		}
		
		if(btrpkt->type == TYPE_ACK) {
			ack = TRUE;
		}

		return msg; // no need to make msg point to new buffer as msg is no longer needed
	}
}