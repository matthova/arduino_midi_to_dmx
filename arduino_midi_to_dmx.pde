
#include <DmxSimple.h>
#include <MIDI.h>

const uint16_t dmx_channels = 64;  // how many channels?
uint16_t current[dmx_channels];  // value for current dim level
uint16_t dest[dmx_channels];     // value for destination to ramp current level towards
uint16_t increment[dmx_channels];// value for speed of ramping of current dim level towards destination
byte commandByte;
byte noteByte;
byte velocityByte;

uint16_t pad_1 = 400;
uint16_t note_e_low = 500;
uint16_t note_f = 9;
uint16_t note_a = 13;
uint16_t note_c = 17;
uint16_t note_e_high = 21;
uint16_t pad_2 = 25;
uint16_t drum = 29;
uint16_t violin = 33;

    
void setup() {

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

void loop() {
  writeLights();
}

void writeLights(){
  for(uint16_t i = 0; i < dmx_channels; i++){
    if((i >= 1) && (i <= 3)){
      writeLight(pad_1, 1, i);
    }else if((i >= 5) && (i <= 7)){
      writeLight(note_e_low, 5, i);
    }else if((i >= 9) && (i <= 11)){
      writeLight(note_f, 9, i);
    }else if((i >= 13) && (i <= 15)){
      writeLight(note_a, 13, i);
    }else if((i >= 17) && (i <= 19)){
      writeLight(note_c, 17, i);
    }else if((i >= 21) && (i <= 23)){
      writeLight(note_e_high, 21, i);
    }else if((i >= 25) && (i <= 27)){
      writeLight(pad_2, 25, i);
    }else if(i == 32){
      writeLight(drum, 29, i);
    }else if((i >= 33) && (i <= 35)){
      writeLight(violin, 33, i);
    }
  }
}

void writeLight(uint16_t startChannel, uint16_t offset, uint16_t i){
  DmxSimple.write(startChannel + i - offset, ((current[i])>>8) & 0xff);
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
