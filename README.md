# ArtnetRecorderPlayback
Artnet recorder and playback made with Processing

## Description
This artnet recorder and playback utility allows you to record a single universe of ArtNet over any network interface. The recording will be saved as a byte array, each frame taking up 512 bytes, one byte per channel. The framerate is set to 44Hz, as that is what the DMX framerate is set to. You can try to experiment with other framerates if you so desire.

You can select any network interface from your computer, and choose the ArtNet subnet and universe to receive on. Once there is data, the background should reflect that and display it as black lines. Each pixel on the X axis corresponds to a channel in the universe, and the Y value corresponds to the value of the given DMX Address.

Once you are happy and seeing the ArtNet data flow on your background, you can click record, to start recording each frame to a file. The file will be located in the data folder with a timestamp.

Click the ArtNet button again to stop recording. The newly recorded file will now show up in the files list on the right hand side.

To playback, you must select a NIC, type in an IP address for unicast (broadcast has neither been tested nor implemented, however should be quite trivial). Select which file you want to playback, select if you want the file to loop, and decide what timeframe you want the file to play in. If you select the exact same time and press loop, the file will play indefinitely. ArtNet data being sent will be displayed on the background, this time in white.

I do not guarantee anything about this program, and I will most likely not maintain it or fix anything but major bugs.

Made in [processing 4.0.1](https://processing.org/) with [Cansik's Artnet4j](https://github.com/cansik/artnet4j) and [Andreas Schlegel's ControlP5](https://github.com/sojamo/controlp5)
