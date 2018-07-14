# MaximallyDirect2D

A dumb "game" made for TerribleHack as a proof of concept of the terrible idea to use the fact that integrated GPUs share memory with the CPU so with Metal you can create a shared buffer, which you can tell the kernel to read UDP packets into, and then turn around and directly render into.

This is a "game" with squares you can control with the mouse and keyboard, that synchronizes positions between all instances on the local LAN using UDP broadcast packets. And it does this with zero copies!
