import ch.bildspur.artnet.*;

import controlP5.Textfield;
import controlP5.ScrollableList;
import controlP5.ControlP5;
import controlP5.Button;
import controlP5.ControlEvent;

import java.net.InetAddress;
import java.net.NetworkInterface;

import java.util.List;
import java.util.Enumeration;

import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FileNotFoundException;


// Networking stuff
NetworkInterface ni;
List<InetAddress> interfaces = new ArrayList<InetAddress>();
List<String> interfacesString = new ArrayList<String>();
String[] interfacesArray;
String IPAddress = "";


// File stuff
FileOutputStream output;
FileInputStream input;
File folder;
String[] filenames;
File selectedFile;
int selectedFileIndex;


// Artnet stuff
ArtNetClient artnet;
byte[] dmxData = new byte[512];
int artnetSubnet = 0;
int artnetUniverse = 0;


// State machine booleans
boolean recPressed = false;
boolean playPressed = false;
boolean loopPressed = false;
boolean fileSelected = false;
boolean nicSelected = false;
boolean IPAddressSet = false;
boolean subnetNaN = false;
boolean universeNaN = false;
boolean artnetStarted = false;
boolean startTimeSet = false;
boolean endTimeSet = false;


// Timing stuff
String startTimeString = "";
String endTimeString = "";
int startTimeHour;
int startTimeMinute;
int endTimeHour;
int endTimeMinute;


// Control panel stuff
ControlP5 cp5;
Textfield tfS;
Textfield tfU;
Textfield tfIP;
Textfield tfStartTime;
Textfield tfEndTime;
ScrollableList slNIC;
ScrollableList slFiles;
Button playButton;
Button recButton;
Button loopButton;


void setup() {
  // Framerate is set to 44Hz, as that is the speed of DMX framerate, but you can easily change it to a higher rate
  frameRate(44);
  
  // Size of canvas is set to 512 by 255, as that will allow me to visualize the entire universe of data on the background. 512 channels that can each take 255 values
  size(512, 255);
  background(127);
  
  // Artnet
  artnet = new ArtNetClient();
  
  // Will get a list of network interfaces in your computer, so you can choose which one to use
  getInterfaces();
  String[] interfacesArray = new String[interfacesString.size()];
  interfacesArray = interfacesString.toArray(interfacesArray);

  // Will get a list of files in the data folder, this is the location where files are saved and read from when replaying
  getFiles();
  
  // Adding buttons, textfields and scrollable lists
  cp5 = new ControlP5(this);
  tfS = cp5.addTextfield("Subnet")
    .setPosition(10, 10)
    .setSize(95, 20)
    .setFocus(true)
    .setLabel("Subnet: "+artnetSubnet)
    .setColor(color(255));

  tfU = cp5.addTextfield("Universe")
    .setPosition(115, 10)
    .setSize(95, 20)
    .setFocus(true)
    .setLabel("Universe: "+artnetUniverse)
    .setColor(color(255));

  slNIC = cp5.addScrollableList("NIC")
    .setPosition(10, 50)
    .setSize(200, 100)
    .setBarHeight(20)
    .setItemHeight(20)
    .addItems(interfacesArray);
  slNIC.close();

  slFiles = cp5.addScrollableList("ArtnetFiles")
    .setLabel("ArtNet Playback")
    .setPosition(300, 50)
    .setSize(200, 100)
    .setBarHeight(20)
    .setItemHeight(20)
    .addItems(filenames);
  slFiles.close();
  
  tfIP = cp5.addTextfield("IPAddress")
    .setPosition(300, 10)
    .setSize(200, 20)
    .setFocus(true)
    .setLabel("Unicast to IP Address: ")
    .setColor(color(255));
    
  playButton = cp5.addButton("Play")
     .setValue(0)
     .setPosition(300,195)
     .setSize(200,50);
  setButton(playButton, color(50,200,50), "Play");
    
     
  recButton = cp5.addButton("Record")
     .setValue(0)
     .setPosition(10,195)
     .setSize(200,50);
  setButton(recButton, color(50,200,50), "Start recording");
  
  loopButton = cp5.addButton("loopBtn")
     .setValue(0)
     .setPosition(300,155)
     .setSize(40,35);
  setButton(loopButton, color(0,45,90), "loop");
  
  tfStartTime = cp5.addTextfield("Start")
     .setPosition(350, 155)
     .setSize(70,20)
     .setFocus(true)
     .setLabel("Start time: none")
     .setColor(color(255));
   
  tfEndTime = cp5.addTextfield("End")
     .setPosition(430, 155)
     .setSize(70,20)
     .setFocus(true)
     .setLabel("End time: none")
     .setColor(color(255));
}

void draw() {
  background(127);
  
  // If no buttons are pressed, register if there is any DMX data and display it on the screen
  if(!recPressed && !playPressed){
    dmxData = artnet.readDmxData(artnetSubnet, artnetUniverse);
    dmxDisplay(0);
  }

  // If record button is pressed, recording is in session. Reads ArtNet data from the given NIC and writes to file
  if (recPressed && !playPressed) {
    try{
      dmxData = artnet.readDmxData(artnetSubnet, artnetUniverse);
      dmxDisplay(0);
      output.write(dmxData);
    }
    catch(Exception e){
      e.printStackTrace();
    }
  }
  
  // If play is pressed it will check whether we are in the given time interval and if looping is activated. Times must be set in 17:00 format. If you set the same times for start and end, it will play continuously
  if(playPressed && !recPressed){
    try{
      if(isInTimeInterval()){
        // Check if its at the end of the file
        if(input.read(dmxData) != -1){
          artnet.unicastDmx(IPAddress, artnetSubnet, artnetUniverse, dmxData);
        } else {
          if(!loopPressed){
            playPressed = false;
            System.out.println("End of file");
            setButton(playButton, color(50,200,50),"Play");
            setDmxToZero();
            dmxDisplay(255);
          } else {
            input.close();
            try{
              input = new FileInputStream(selectedFile);
              System.out.println("Opened file: "+filenames[selectedFileIndex]);
            } catch(Exception e){
              e.printStackTrace();
            }
          }
        }
      }
      dmxDisplay(255);
    } catch(IOException e){
    e.printStackTrace();
    }
  }
}

// Checks if textfields are filled in
public void controlEvent(ControlEvent theEvent) {
  if (theEvent.isAssignableFrom(Textfield.class)) {
    fill(255);
    
    // Checks for the subnet field and sets the ArtNet subnet to the given value from 0 to 2047
    if (theEvent.getName() == "Subnet") {
      if (isInt(theEvent.getStringValue())) {
        artnetSubnet = Integer.parseInt(theEvent.getStringValue());
        if (artnetSubnet >= 0 && artnetSubnet < 2048) {
          tfS.setLabel("Subnet: "+ artnetSubnet);
        } else {
          tfS.setLabel("Subnet: NaN");
        }
      } else {
        tfS.setLabel("Subnet: NaN");
      }
    }

    // Checks for the universe field and sets the ArtNet universe to the given value from 0 to 15
    if (theEvent.getName() == "Universe") {
      if (isInt(theEvent.getStringValue())) {
        artnetUniverse = Integer.parseInt(theEvent.getStringValue());
        if (artnetUniverse >= 0 && artnetUniverse < 16) {
          tfU.setLabel("Universe: "+ artnetUniverse);
        } else {
          tfU.setLabel("Universe: NaN");
        }
      } else {
        tfU.setLabel("Universe: NaN");
      }
    }
    
    // Checks the IP address and validates that it is a correct IP address
    if (theEvent.getName() == "IPAddress") {
      if (validIP(theEvent.getStringValue())) {
        tfIP.setLabel("Unicast to IP Address: " + theEvent.getStringValue());
        IPAddressSet = true;
        IPAddress = theEvent.getStringValue();
        System.out.println("IP Address set to: " + IPAddress);
      } else {
        tfIP.setLabel("Unicast to IP Address: invalid IP");
      }
    }
    
    // Checks for the start time value and validates that it is in the correct format of 17:00 HH:mm
    if(theEvent.getName() == "Start"){
      if(validTime(theEvent.getStringValue())){
        tfStartTime.setLabel("Start time: " + theEvent.getStringValue());
        startTimeSet = true;
        startTimeHour = Integer.parseInt(theEvent.getStringValue().substring(0,2));
        startTimeMinute = Integer.parseInt(theEvent.getStringValue().substring(3));
        System.out.println("Start time is: " + theEvent.getStringValue());
      }
    }
    
    // Checks for the end time value and validates that it is in the correct format of 17:00 HH:mm
    if(theEvent.getName() == "End"){
      if(validTime(theEvent.getStringValue())){
        tfEndTime.setLabel("End time: " + theEvent.getStringValue());
        endTimeSet = true;
        endTimeHour = Integer.parseInt(theEvent.getStringValue().substring(0,2));
        endTimeMinute = Integer.parseInt(theEvent.getStringValue().substring(3));
        System.out.println("End time is: " + theEvent.getStringValue());
      }
    }
  }
}

// Checks if somestring is an integer
boolean isInt(String str) {
  return str != null && str.matches("-?[0-9]+");
}

// Gets the network interfaces of the computer
void getInterfaces() {
  try {
    Enumeration<NetworkInterface> e = NetworkInterface.getNetworkInterfaces();

    while (e.hasMoreElements()) {
      NetworkInterface ni = e.nextElement();

      Enumeration<InetAddress> e2 = ni.getInetAddresses();

      while (e2.hasMoreElements()) {
        InetAddress ip = e2.nextElement();
        interfaces.add(ip);
        interfacesString.add(ip.toString());
        System.out.println(ip.toString());
      }
    }
  }
  catch (Exception e) {
    e.printStackTrace();
  }
}

// This is what happens when a new network interface is selected. Basically stops the ArtNet server and restarts on the new selected NIC
void NIC(int n) {
  nicSelected = true;
  artnet.stop();
  artnet = new ArtNetClient();
  System.out.println("Selected interface: " + interfaces.get(n).toString());
  artnetStarted = true;
  artnet.start(interfaces.get(n));
}

// Checks which file you chose in the Scrollable list with files. It will then open the file and prepare it for reading
public void ArtnetFiles(int n){
  selectedFileIndex = n;
  selectedFile = new File(dataPath(filenames[n]));
  fileSelected = true;
  try{
    input = new FileInputStream(selectedFile);
    System.out.println("Opened file: "+filenames[n]);
  } catch(Exception e){
    e.printStackTrace();
  }
}

// This is when the play button is pressed, checks if certain conditions are met, and then starts to play
public void Play(int n){
  if(!recPressed && fileSelected && nicSelected && IPAddressSet){
    if(!playPressed){
      System.out.println("Sending ArtNet on interface: " + interfaces.get(n).toString());
      setButton(playButton, color(200,50,50),"Playing...");
    } else {
      setButton(playButton, color(50,200,50),"Play");
      setDmxToZero();
      dmxDisplay(0);
    }
    playPressed = !playPressed; 
  }
}

// This is when the record button is pressed. It will only start if you have selected a NIC and if play is not pressed.
// Either opens a new file for recording, or closes the file when recording is done.
public void Record(){
  if(!playPressed && nicSelected){
    // When rec button is not pressed, and is then activated. This will create a new file
    if(!recPressed){
      setButton(recButton, color(200,50,50),"Recording...");
      File file = new File(dataPath(str(year())+"-"+str(month())+"-"+str(day())+"-"+str(hour())+"."+str(minute())+"."+str(second())+".dat"));
      try{
        file.createNewFile();
      } catch(IOException e){
        e.printStackTrace();
      }
      
      try{
        output = new FileOutputStream(file);
      } catch(FileNotFoundException e){
        e.printStackTrace();
      }
    } else {
      
      // When rec button is already active and is then deactivated. This will close the file and update the files list.
      setButton(recButton, color(50,200,50),"Start recording");
      try{
        output.flush();
        output.close();
      } catch(IOException e){
        e.printStackTrace();
      }
      getFiles();
      slFiles.setItems(filenames);
    }
     
    recPressed = !recPressed;
  }
}

// If loop button is pressed, it sets the flag to true and changes color
void loopBtn(){
  if(!loopPressed){
    setButton(loopButton, color(0,116,217), "Looping");
    loopPressed = true;
  } else {
    setButton(loopButton, color(0,45,90), "Loop");
    loopPressed = false;
  }
}

// The the files in the data folder
void getFiles() {
  folder = new File(dataPath(""));
  filenames = folder.list();
}

// Check if a given string is a valid IP address
public static boolean validIP (String ip) {
    try {
        if ( ip == null || ip.isEmpty() ) {
            return false;
        }

        String[] parts = ip.split( "\\." );
        if ( parts.length != 4 ) {
            return false;
        }

        for ( String s : parts ) {
            int i = Integer.parseInt( s );
            if ( (i < 0) || (i > 255) ) {
                return false;
            }
        }
        if ( ip.endsWith(".") ) {
            return false;
        }

        return true;
    } catch (NumberFormatException nfe) {
        return false;
    }
}

// Check if a time is in the correct format of 17:00 HH:mm
public static boolean validTime(String inputTimeString){
  if (!inputTimeString.matches("^([0-9]|0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]$")){
    System.out.println("Invalid time string: " + inputTimeString);
    return false;
  } else {
    return true;
  }
}

// Checks if current time is within the given time interval. Basically this is used if you want to have it only run a certain period of the day
public boolean isInTimeInterval(){
  boolean overNight = false;
  int startTimeMinutes = startTimeHour * 60 + startTimeMinute;
  int endTimeMinutes = endTimeHour * 60 + endTimeMinute;
  int currentTimeMinutes = hour() * 60 + minute();
  
  if(startTimeMinutes >= endTimeMinutes){
    overNight = true;
  }
  if(!overNight){
    if(currentTimeMinutes >= startTimeMinutes && currentTimeMinutes < endTimeMinutes){
      return true;
    } else {
      return false;
    }
  } else if(currentTimeMinutes >= startTimeMinutes || currentTimeMinutes < endTimeMinutes){
    return true;
  } else {
    return false;
  }
}

// Sets all ArtNet channels to zero
void setDmxToZero(){
  for (int i = 0; i < 512; i++) {
    dmxData[i] = 0;
  }
}

// Set the color and display DMX data on the background
void dmxDisplay(int stroke){
  fill(stroke);
  stroke(stroke);
  for (int i = 0; i < 512; i++) {
    line(i, height, i, height-dmxData[i] & 0xFF);
  }
}

// Set color and label of a button
void setButton(Button btn, color c, String label){
          btn.setColorBackground(c)
                .setColorForeground(c)
                .setColorActive(c)
                .setLabel(label);
}
// By Marcus Willis Albertsen
