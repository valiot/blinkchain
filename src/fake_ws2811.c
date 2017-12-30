// This is a bare-bones implementation of the ws2811 API
// to make it easier to test on non-Raspberry Pi hardware

#include <stdlib.h>
#include <string.h>

#include "rpi_ws281x/ws2811.h"
#define RPI_PWM_CHANNELS 2

ws2811_return_t ws2811_init(ws2811_t *ws2811)
{
  int chan;
  for (chan = 0; chan < RPI_PWM_CHANNELS; chan++) {
    ws2811_channel_t *channel = &ws2811->channel[chan];
    channel->leds = malloc(sizeof(ws2811_led_t) * channel->count);
    memset(channel->leds, 0, sizeof(ws2811_led_t) * channel->count);
    channel->strip_type=WS2811_STRIP_RGB;
  }
  return WS2811_SUCCESS;
}

const char * ws2811_get_return_t_str(const ws2811_return_t state)
{
    const int index = -state;
    static const char * const ret_state_str[] = { WS2811_RETURN_STATES(WS2811_RETURN_STATES_STRING) };

    if (index < (int)(sizeof(ret_state_str) / sizeof(ret_state_str[0])))
    {
        return ret_state_str[index];
    }

    return "";
}
