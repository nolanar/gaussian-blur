#include <LPC23xx.H>                    /* LPC23xx/LPC24xx definitions        */
#include "lcd_hw.h"
#include "lcd_grph.h"
#include "crest.h"
#include <stdio.h>

extern void init_serial(void);
extern void start (void);

int main (void)
{
	/* Initialise UART */
	init_serial();

	/* Initialise LCD Hardware */
	lcd_hw_init();

	/* Initialise LCD Device */
	lcd_init();

	lcd_fillScreen(WHITE);
	lcd_fontColor(BLACK, WHITE);
	lcd_putString(5, 5, "CS1022 Mid-Term Assignment");
	loadPic(crest);
	putPic();
	
	printf("\r\nCalling start() ...\r\n");

	start();
	
	printf("start() returned.\r\n");

	while (1);
}
