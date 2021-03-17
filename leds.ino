#include <Adafruit_DotStar.h>
#include <PacketSerial.h>

PacketSerial_<COBS, 0, 350> myPacketSerial;

#define NUMPIXELS 300 
#define DATAPIN    4
#define CLOCKPIN   5
Adafruit_DotStar strip(NUMPIXELS, DATAPIN, CLOCKPIN, DOTSTAR_BGR);

void setup() {
    myPacketSerial.begin(9600);
    myPacketSerial.setStream(&Serial);
    myPacketSerial.setPacketHandler(&onPacketReceived);
  
    strip.begin();
    strip.clear();
    strip.show();
}

void loop() {
    myPacketSerial.update();
}

void onPacketReceived(const uint8_t* buffer, size_t size)
{
    strip.clear();
    for (int i = 0; i < size; i++) {
      if (buffer[i] > 0) {
        strip.setPixelColor(i, 0, buffer[i], 0);
      }
    }
    strip.show();
}
