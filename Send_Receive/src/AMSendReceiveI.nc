interface AMSendReceiveI {
  command message_t* send(message_t* msg);
  event message_t* receive(message_t *msg);
}
