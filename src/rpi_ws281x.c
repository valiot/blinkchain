#include <stdlib.h>
#include <strings.h>
#include <errno.h>
#include <err.h>

#include "rpi_ws281x/ws2811.h"
#include "base64.h"
#include "utils.h"

#define DMA_CHANNEL 5

typedef struct {
  uint16_t width;
  uint16_t height;
  uint16_t *topology;
} canvas_t;

void init_canvas(uint16_t width, uint16_t height, canvas_t *canvas) {
  printf("Called init_canvas(width: %hu, height: %hu)\n", width, height);
  canvas->width = width;
  canvas->height = height;
  if (canvas->topology != NULL)
    free(canvas->topology);
  canvas->topology = calloc(width * height, sizeof(uint16_t));
}

void init_pixels(uint8_t channel, uint16_t offset, uint16_t x, uint16_t y, uint16_t count, int8_t dx, int8_t dy, canvas_t *canvas) {
  printf("Called init_pixels(channel: %hhu, offset: %hu, x: %hu, y: %hu, count: %hu, dx: %hhi, dy: %hhi)\n", channel, offset, x, y, count, dx, dy);
  // MSB designates which channel to use
  offset |= (channel << 15);
  uint16_t i;
  for (i = 0; i < count; i++) {
    printf("  Setting topology(%hu, %hu) to %hu\n", x, y, offset);
    canvas->topology[(canvas->width * y) + x] = offset++;
    x += dx;
    y += dy;
  }
  printf("  Topology:\n");
  for(y = 0; y < canvas->height; y++) {
    printf("  ");
    for(x = 0; x < canvas->width; x++) {
      printf("[%5hu]", canvas->topology[(canvas->width * y) + x]);
    }
    printf("\n");
  }
}

void set_pixel(uint16_t x, uint16_t y, ws2811_led_t color, ws2811_channel_t *channels, const canvas_t *canvas) {
  printf("Called set_pixel(x: %hu, y: %hu, color: 0x%08x)\n", x, y, color);
  uint16_t offset = canvas->topology[(canvas->width * y) + x];
  // MSB designates which channel to use
  uint8_t channel = offset >> 15;
  // Clear the MSB so we can use pixel as the offset within the channel
  offset &= ~(1 << 15);
  channels[channel].leds[offset] = color;
}

void blit(uint16_t x, uint16_t y, uint16_t width, uint16_t height, const uint8_t *data, ws2811_channel_t *channels, const canvas_t *canvas) {
  printf("Called blit(x: %hu, y: %hu, width: %hu, height: %hu, data: <binary>)\n", x, y, width, height);
  uint16_t row, col;
  ws2811_led_t color;
  for(row = 0; row < height; row++, y++) {
    for(col = 0; col < width; col++, x++) {
      // ws2811_led_t is uint32_t: 0xWWRRGGBB
      // so data should look like [0xWW, 0xRR, 0xGG, 0xBB]
      color = *data++;
      color <<= 8;
      color |= *data++;
      color <<= 8;
      color |= *data++;
      color <<= 8;
      color |= *data++;
      set_pixel(x, y, color, channels, canvas);
    }
  }
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

  canvas_t canvas = {
    .width = 0,
    .height = 0,
    .topology = NULL,
  };

  char buffer[16];
  for (;;) {
    buffer[0] = '\0';
    if (scanf("%15s", buffer) == 0 || strlen(buffer) == 0) {
      if (feof(stdin)) {
        printf("EOF\n");
        exit(EXIT_SUCCESS);
      } else {
        errx(EXIT_FAILURE, "read error");
      }
    }

    if (strcasecmp(buffer, "init_canvas") == 0) {
      uint16_t width, height;
      char nl;
      if (scanf("%hu %hu%c", &width, &height, &nl) != 3 || nl != '\n')
        errx(EXIT_FAILURE, "Argument error in init_canvas command");
      init_canvas(width, height, &canvas);

    } else if (strcasecmp(buffer, "init_pixels") == 0) {
      uint16_t x, y, count, offset;
      uint8_t channel;
      int8_t dx, dy;
      char nl;
      if (scanf("%hhu %hu %hu %hu %hu %hhi %hhi%c", &channel, &offset, &x, &y, &count, &dx, &dy, &nl) != 8 || nl != '\n')
        errx(EXIT_FAILURE, "Argument error in init_pixels command");
      init_pixels(channel, offset, x, y, count, dx, dy, &canvas);

    } else if (strcasecmp(buffer, "set_pixel") == 0) {
      uint16_t x, y;
      uint8_t r, g, b, w;
      char nl;
      if (scanf("%hu %hu %hhu %hhu %hhu %hhu%c", &x, &y, &r, &g, &b, &w, &nl) != 7 || nl != '\n')
        errx(EXIT_FAILURE, "Argument error in set_pixel command");
      if (x >= canvas.width || y >= canvas.height)
        errx(EXIT_FAILURE, "Point (%hu, %hu) is outside canvas dimensions %hu x %hu\n", x, y, canvas.width, canvas.height);
      // ws2811_led_t is uint32_t: 0xWWRRGGBB
      ws2811_led_t color = (w << 24) | (r << 16) | (g << 8) | b;
      set_pixel(x, y, color, ledstring.channel, &canvas);

    } else if (strcasecmp(buffer, "blit") == 0) {
      uint16_t x, y, width, height;
      uint32_t base64_size;
      if (scanf("%hu %hu %hu %hu %u ", &x, &y, &width, &height, &base64_size) != 5)
        errx(EXIT_FAILURE, "Argument error in blit command");
      char format[16], nl;
      sprintf(format, "%%%us%%c", base64_size);
      char *base64_buffer = malloc(base64_size + 1);
      if (scanf(format, base64_buffer, &nl) != 2 || nl != '\n')
        errx(EXIT_FAILURE, "Unable to read base64-encoded binary from blit command");
      int decoded_size;
      uint8_t *data = unbase64(base64_buffer, strlen(base64_buffer), &decoded_size);
      if (decoded_size != width * height * 4) // Each pixel should have 4 8-bit color channels
        errx(EXIT_FAILURE, "Size of binary data didn't match the width and height in blit command");
      printf("Base64-encoded blit data: %s\n", base64_buffer);
      free(base64_buffer);
      blit(x, y, width, height, data, ledstring.channel, &canvas);
      free(data);

    } else if (strcasecmp(buffer, "render") == 0) {
      ws2811_return_t result = ws2811_render(&ledstring);
      if (rc != WS2811_SUCCESS)
        errx(EXIT_FAILURE, "ws2811_render failed: %d (%s)", result, ws2811_get_return_t_str(result));

    } else {
      errx(EXIT_FAILURE, "Unrecognized command: '%s'", buffer);
    }
  }
}
