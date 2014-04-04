
#include <DmxSimple.h>
#include <MIDI.h>


const uint16_t dmx_channels = 64;  // how many channels?
uint16_t current[dmx_channels];  // value for current dim level
uint16_t dest[dmx_channels];     // value for destination to ramp current level towards
uint16_t increment[dmx_channels];// value for speed of ramping of current dim level towards destination
// high=(input>>8) & 0xff
byte commandByte;
byte noteByte;
byte velocityByte;
    
void setup() {

  for(byte i = 0; i < dmx_channels; i++){
    current[i] = 0;
    dest[i] = 0;
    increment[i] = 1;
  }
  DmxSimple.usePin(3);

  MIDI.setHandleNoteOn(HandleNoteOn); 
  MIDI.setHandleNoteOff(HandleNoteOff);
  //MIDI.setHandleControlChange(HandleCC);
  MIDI.begin();

  cli();//stop interrupts

  //set timer0 interrupt at 2kHz
  TCCR0A = 0;// set entire TCCR0A register to 0
  TCCR0B = 0;// same for TCCR0B
  TCNT0  = 0;//initialize counter value to 0
  // set compare match register for 2khz increments
  OCR0A = 124;// = (16*10^6) / (2000*64) - 1 (must be <256)
  // turn on CTC mode
  TCCR0A |= (1 << WGM01);
  // Set CS01 and CS00 bits for 64 prescaler
  TCCR0B |= (1 << CS01) | (1 << CS00);   
  // enable timer compare interrupt
  TIMSK0 |= (1 << OCIE0A);

  //set timer2 interrupt every 128us
  TCCR2A = 0;// set entire TCCR2A register to 0
  TCCR2B = 0;// same for TCCR2B
  TCNT2  = 0;//initialize counter value to 0
  // set compare match register for 7.8khz increments
  OCR2A = 255;// = (16*10^6) / (7812.5*8) - 1 (must be <256)
  // turn on CTC mode
  TCCR2A |= (1 << WGM21);
  // Set CS11 bit for 8 prescaler
  TCCR2B |= (1 << CS11);   
  // enable timer compare interrupt
  TIMSK2 |= (1 << OCIE2A);
  
  sei();//allow interrupts
}

void loop() {
  for(byte i = 0; i < dmx_channels; i++){
    DmxSimple.write(i+1, ((dest[i])>>8) & 0xff);
  }
}

void HandleNoteOn(byte channel, byte pitch, byte velocity) { 
  if(pitch < dmx_channels){
    dest[pitch] = velocity << 8;
  }
}

void HandleNoteOff(byte channel, byte pitch, byte velocity) {
  if(pitch < dmx_channels){
    dest[pitch] = 0;
  }
}
//void HandleCC(byte channel, byte pitch, byte velocity) {
//
// }

ISR(TIMER0_COMPA_vect){//timer0 interrupt 2kHz 
  for(byte i = 0; i < dmx_channels; i++){
    if(current[i] != dest[i]){
      if(current[i] < dest[i]){
        if(0xffff - increment[i] < current[i]){
          current[i] = 0xffff;
        }else{
          current[i] += increment[i];
        }
      }else{
        if(current[i] < increment[i]){
          current[i] = dest[i];
        }else{
          current[i] -= increment[i];
        }
      }
    }
  }
}

ISR(TIMER2_COMPA_vect) {//checks for incoming midi every 128us
  do{
    if (Serial.available()){
      commandByte = Serial.read();//read first byte
      noteByte = Serial.read();//read next byte
      velocityByte = Serial.read();//read final byte
    }
  }
  while (Serial.available() > 2);//when at least three bytes available
}
