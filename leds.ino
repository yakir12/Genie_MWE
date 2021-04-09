#include <Adafruit_DotStar.h>

#define NUMPIXELS 300
#define DATAPIN    4
#define CLOCKPIN   5
Adafruit_DotStar strip(NUMPIXELS, DATAPIN, CLOCKPIN, DOTSTAR_BGR);

word index = 0;
unsigned long prev = millis();
byte color[3];
byte coli = 0;

void setup() {
  Serial.begin(115200);

  strip.begin();
  strip.clear();
  strip.show();
}

void loop() {
  if (Serial.available() > 0) {
    if (millis() - prev > 1000) {
      index = 0;
      coli = 0;
    }
    color[coli] = Serial.read();
    coli++;
    if (coli == 3) {
      strip.setPixelColor(index, color[0], color[1], color[2]);
      index++;
      coli = 0;
    }
    if (index == NUMPIXELS) {
      strip.show();
      index = 0;
      coli = 0;
    }
    prev = millis();
  }
}
