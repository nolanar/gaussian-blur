# Image manipulation - Gaussian blur

This is an ARM assembly language implementation of a Gaussian blur image manipulation effect.

The project can be run using [Keil µVision](http://www.keil.com/uvision/).

The image can be viewed using displayImage.jar found in /veiwer. See the acompanying readme for details on how to use.

## Description

A detailed description can be found here: http://nolanar.github.io/documents/gaussian-blur.pdf

### Outline

The outline of this assignment was to create an image manipulation effect and apply them to the Trinity College Dublin crest.

![TCD crest](http://nolanar.github.io/img/gaussian-blur/crest-default.png)

#### Floating Point Arithmetic

The ARM7TDMI microcontroller used in this project does not natively support floating point arithmetic. A software implementation was written to overcome this:
* Conversion between floating point and integers.
* Addition, subtraction, multiplication, and division operators.
* Fast approximation functions for multiplication, division and square root operators.

### Gaussian Blur

The Gaussian blur effect is created through several iterations of a standard box blur. Parameters include the radius of the resulting blur and the number of iterations used.

![blur comparison](http://nolanar.github.io/img/gaussian-blur/crest-compare.png)

(left) box blur; (right) Gaussian blur with radius = 3.5, iterations = 4

The main focus was on making the process as effecient as possible. This was necessary due to the use of software implemented of floating point arithmetic and  because the majoraty of testing was done with a relatively slow simulated microcontroller.