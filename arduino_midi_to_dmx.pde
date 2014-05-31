
#include <DmxSimple.h>
#include <MIDI.h>

const uint16_t dmx_channels = 64;  // how many channels?
uint16_t current[dmx_channels];  // value for current dim level
uint16_t dest[dmx_channels];     // value for destination to ramp current level towards
uint16_t increment[dmx_channels];// value for speed of ramping of current dim level towards destination
byte commandByte;
byte noteByte;
byte velocityByte;

uint16_t 
  violin_1, violin_2, violin_3, violin_4, violin_5, violin_6, violin_7, violin_8, violin_9;

    
void setup() {

  light_controller_1();

  for(byte i = 0; i < dmx_channels; i++){
    current[i] = 0;
    dest[i] = 0;
    increment[i] = 100;
  }

  DmxSimple.maxChannel(512);
  DmxSimple.usePin(3);

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
  // Set CS22 bit for 64 prescaler
  TCCR2B |= (1 << CS22);   
  // enable timer compare interrupt
  TIMSK2 |= (1 << OCIE2A);
  
  sei();//allow interrupts

  MIDI.setHandleNoteOn(HandleNoteOn); 
  MIDI.setHandleNoteOff(HandleNoteOff);
  MIDI.begin(MIDI_CHANNEL_OMNI);    

}

void light_controller_1(){
  violin_1 = 1;
  violin_2 = 5;
  violin_3 = 9;
  violin_4 = 13;
  violin_5 = 17;
  violin_6 = 21;
  violin_7 = 25;
  violin_8 = 29;
  violin_9 = 33;
}

void loop() {
  writeLights();
}

void writeLights(){
  for(uint16_t i = 0; i < dmx_channels; i++){
    if((i >= 33) && (i <= 35)){
      writeLight(violin_1, 33, i);
      writeLight(violin_2, 33, i);
      writeLight(violin_3, 33, i);
      writeLight(violin_4, 33, i);
      writeLight(violin_5, 33, i);
      writeLight(violin_6, 33, i);
      writeLight(violin_7, 33, i);
      writeLight(violin_8, 33, i);
      writeLight(violin_9, 33, i);
    }
  }
}

void writeLight(uint16_t startChannel, uint16_t offset, uint16_t i){
  if(startChannel != 0){
    DmxSimple.write(startChannel + i - offset, ((current[i])>>8) & 0xff);
  }
}

void HandleNoteOn(byte channel, byte pitch, byte velocity) { 
  if (velocity == 0){
    HandleNoteOff(channel, pitch, velocity);
  }else{
    if(pitch < dmx_channels){
      dest[pitch] = velocity << 9;
    }
  }
}

void HandleNoteOff(byte channel, byte pitch, byte velocity) {
  if(pitch < dmx_channels){
    dest[pitch] = 0;
  }
}

ISR(TIMER0_COMPA_vect){//timer0 interrupt 2kHz smoothly fades dmx
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
      MIDI.read();
    }
  }
  while (Serial.available() > 2);//when at least three bytes available
}
