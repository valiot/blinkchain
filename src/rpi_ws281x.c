#include <stdlib.h>
#include <strings.h>
#include <errno.h>
#include <err.h>

#include "rpi_ws281x/ws2811.h"
#include "base64.h"
#include "utils.h"

#define DMA_CHANNEL 5

typedef struct {
  size_t width;
  size_t height;
  uint16_t *topology;
} canvas_t;

void init_canvas(canvas_t *canvas) {
  size_t width, height;
  if (scanf("%lu %lu ", &width, &height) != 2) {
    errx(EXIT_FAILURE, "Argument error in init_canvas command");
  }
  size_t topology_size = sizeof(uint16_t) * width * height;
  size_t buffer_size = (topology_size * 4 / 3) + 4; // 4 bytes for potential padding and string terminator
  char *base64_buffer = malloc(buffer_size);
  char format[16], nl;
  sprintf(format, "%%%lus%%c", buffer_size - 1);
  if (scanf(format, base64_buffer, &nl) != 2 || nl != '\n') {
    errx(EXIT_FAILURE, "Unable to read topology from init_canvas command");
  }
  printf("Called init_canvas(%lu, %lu, %s)\n", width, height, base64_buffer);
  canvas->width = width;
  canvas->height = height;
  int decoded_size;
  canvas->topology = (uint16_t *)unbase64(base64_buffer, strlen(base64_buffer), &decoded_size);
  free(base64_buffer);
  int i;
  for(i=0;i<(topology_size/sizeof(uint16_t));i++) {
    printf("[%i]: %hu\n", i, canvas->topology[i]);
  }
  if (topology_size != decoded_size) {
    errx(EXIT_FAILURE, "Base64-encoded topology size didn't match");
  }
}

void set_pixel(ws2811_channel_t *channels, const canvas_t *canvas) {
  uint16_t x, y;
  uint8_t r, g, b, w;
  if (scanf("%hu %hu %hhu %hhu %hhu %hhu", &x, &y, &r, &g, &b, &w) != 6) {
    errx(EXIT_FAILURE, "Argument error in set_pixel command");
  }
  printf("Called set_pixel(%hu, %hu, %hhu, %hhu, %hhu, %hhu)", x, y, r, g, b, w);
}

int main(int argc, char *argv[]) {
  if (argc != 5)
    errx(EXIT_FAILURE, "Usage: %s <Channel 1 GPIO Pin> <Channel 1 LED Count> <Channel 2 GPIO Pin> <Channel 2 LED Count>", argv[0]);

  uint8_t gpio_pin1 = atoi(argv[1]);
  uint32_t led_count1 = strtol(argv[2], NULL, 10);

  uint8_t gpio_pin2 = atoi(argv[3]);
  uint32_t led_count2 = strtol(argv[4], NULL, 10);

  /*
  Setup the channels. Raspberry Pi supports 2 PWM channels.
  */
  ws2811_t ledstring = {
    .freq = WS2811_TARGET_FREQ,
    .dmanum = DMA_CHANNEL,
    .channel = {
      [0] = {
        .gpionum = gpio_pin1,
        .count = led_count1,
        .invert = 0,
        .brightness = 0,
      },
      [1] = {
        .gpionum = gpio_pin2,
        .count = led_count2,
        .invert = 0,
        .brightness = 0,
      },
    },
  };

  ws2811_return_t rc = ws2811_init(&ledstring);
  if (rc != WS2811_SUCCESS)
    errx(EXIT_FAILURE, "ws2811_init failed: %d (%s)", rc, ws2811_get_return_t_str(rc));

  canvas_t canvas;
  char buffer[16];
  for (;;) {
    if (scanf("%15s", buffer) == 0) {
      if (feof(stdin)) {
        exit(EXIT_SUCCESS);
      } else {
        err(EXIT_FAILURE, "read error");
      }
    }

    if (strcasecmp(buffer, "init_canvas") == 0) {
      init_canvas(&canvas);
    } else if (strcasecmp(buffer, "set_pixel") == 0) {
      set_pixel(ledstring.channel, &canvas);
    } else {
      errx(EXIT_FAILURE, "Unrecognized command: '%s'", buffer);
    }
  }
}
