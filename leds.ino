#include <Adafruit_DotStar.h>

#define NUMPIXELS 300
#define DATAPIN    4
#define CLOCKPIN   5
Adafruit_DotStar strip(NUMPIXELS, DATAPIN, CLOCKPIN, DOTSTAR_BGR);

word index = 0;
unsigned long prev = millis();

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
    }
    strip.setPixelColor(index, 0, Serial.read(), 0);
    index++;
    prev = millis();
  }
  if (index >= NUMPIXELS) {
    strip.show();
    index = 0;
  }
}
