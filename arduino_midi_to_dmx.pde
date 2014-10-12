
#include <DmxSimple.h>
#include <MIDI.h>

const byte dmx_channels = 64;  // how many channels?
byte dest[dmx_channels];     // value for destination to ramp current level towards
byte multiplier[dmx_channels];

void setup() {
	for(byte i = 0; i < dmx_channels; i++){
		dest[i] = 0;
		multiplier[i] = 0xfe;
	}

	DmxSimple.maxChannel(dmx_channels);
	DmxSimple.usePin(3);

	cli();//stop interrupts

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
	MIDI.setHandleControlChange(HandleControlChange);
	MIDI.begin(MIDI_CHANNEL_OMNI);
}

void loop() {
	writeLights();
}

void writeLights(){
	uint16_t result;
	for(byte i = 0; i < dmx_channels; i++){
		result = dest[i] * multiplier[i];
		DmxSimple.write(i + 1, result >> 8 & 0xff);
	}
}

void HandleNoteOn(byte channel, byte pitch, byte velocity) {
	if(pitch < dmx_channels){
		dest[pitch] = velocity << 1; // kick 7 bit value to 8 bits
	}
}

void HandleNoteOff(byte channel, byte pitch, byte velocity) {
	if(pitch < dmx_channels){
		dest[pitch] = 0;
	}
}

void HandleControlChange(byte channel, byte number, byte value){
	byte cc_start_channel = 64;
	if((number >= cc_start_channel) && (number < cc_start_channel + dmx_channels)){
		multiplier[number - cc_start_channel] = value << 1;
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