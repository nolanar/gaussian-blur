To output a region of memory from uVision, while running a debug session enter into the command window:

`SAVE [filepath] [start address], [end address]`

Use this to output the region of memory that contains the image.

To display the image use the displayImage.jar:

`java -jar displayImage.jar [filepath] <optional scale factor>`
