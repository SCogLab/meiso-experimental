
/** 
 * Simple Heart Rate Display with graph
 * by Dan Julio. 
 * 
 * Send a Get Heartrate command to the HRMI device and
 * then display the received heartrate along with
 * status flags and a dynamic graph.
 *
 * The HRMI device must be configured for serial 
 * operation with a baud rate of 9,600 baud (default
 * with no jumpers).
 *
 */
 

import oscP5.*;

/*
 * Constants
 */
int SCREEN_W = 1200;
int SCREEN_H = 320;
int NUM_HR_POINTS = 900;     // number of previous HR values in graph  60 = 1 minute // 900 = 15min // 5400=90min
int NUM_REQ_HR_VALS = 16;   // number of HR values to get per request // bas 16
int SAMPLE_PERIOD = 1000;   // number of milliseconds between samples
int WAIT_PERIOD = 150;      // number of milliseconds to wait for a response
int STATE_DIS = 0;
int STATE_HOLD = 1;
int STATE_AVG = 2;
int STATE_RAW = 3;

/*
 * GUI related variables
 */
color windowColor = color(27, 173, 173);
color LineColor = color(27, 153, 153);  ///COULEUR DES REPERE DE GRAPH
color itemBaseColor = color(17, 153, 153);
color textColor = color(225);
color activeButtonColor = color(225, 135, 46);
color graphColor = color(225);

PFont fontA;
Button b1, b2, b3, b4;
Label lw, lhr, lstat;
HrDisplay hrInfo;
StatusDisplay statInfo;

/*
 * Control variables
 */
int curScreen = 0;
int curInitState = 0;
int curState;
boolean checkForResponse;
boolean firstSample = true;
int curHrVal;
int curFlags;
int curSampleCount;
int prevSampleCount;
int obciSampleMsec;

// Number of data channels
int numChannels = 8;
float delta[] = new float[numChannels];
float theta[] = new float[numChannels];
float alpha[] = new float[numChannels];
float beta[] = new float[numChannels];
float gamma[] = new float[numChannels];
float acc[] = new float[3];
String chan_data = "";
String acc_data = "";
String channels[] = {"EEG1", "EEG2", "EEG3", "EEG4", "EEG5", "EEG6", "EEG7", "EEG8"};
String trig = "";
String header;
PrintWriter output;

void setup() {
  // Initialize the GUI
  InitGui();
  
  // start oscP5, telling it to listen for incoming messages at port 6400 */
  oscP5 = new OscP5(this, 6400);
  
  // set the remote location to be the localhost on port 12000
  myRemoteLocation = new NetAddress("127.0.0.1", 12000);
  
  curState = STATE_DIS;
  checkForResponse = false;
  output = createWriter("bpm.txt");
  header = "HrVal;timestamps;";
  for (int i=0; i<numChannels; i++) {
    header = header + ";EEG" + (i+1) + "_theta;EEG" + (i+1) + "_alpha;EEG" + (i+1) + "_beta;EEG" + (i+1) + "_gamma";
  }
  header = header + ";trigger;";
  output.println(header);
}


void oscEvent(OscMessage theOscMessage) 
{  
  // print out the message
  if (theOscMessage.addrPattern().equals("/openbci/timestamp") == true) {
    obciSampleMsec = theOscMessage.get(0).intValue();
    print("OSC Message Recieved: " + theOscMessage.addrPattern() + " " + obciSampleMsec);
    //theOscMessage.print();
  } else {
    for (int i=0; i<numChannels; i++) {
      if (theOscMessage.addrPattern().equals("/openbci/chan" + (i+1) + "/alpha") == true) {
        alpha[i] = theOscMessage.get(0).floatValue();
      } else if (theOscMessage.addrPattern().equals("/openbci/chan" + (i+1) + "/beta") == true) {
        beta[i] = theOscMessage.get(0).floatValue();
      } else if (theOscMessage.addrPattern().equals("/openbci/chan" + (i+1) + "/theta") == true) {
        theta[i] = theOscMessage.get(0).floatValue();
      } else if (theOscMessage.addrPattern().equals("/openbci/chan" + (i+1) + "/gamma") == true) {
        gamma[i] = theOscMessage.get(0).floatValue();
      }
    }
  }
}


void draw() {
  if (curInitState == 0) {
    InitSelectPortScreen();
    curInitState = 1;
  } else if (curInitState == 1) {
    if (CheckPortSelected()) {
      curInitState = 2;
    }
  } else if (curInitState == 2) {
    InitMainScreen();
    curInitState = 3;
  } else {  
    delay(SAMPLE_PERIOD - WAIT_PERIOD);
  
    // Check if we should send a command
    if ((curState == STATE_AVG) || (curState == STATE_RAW)) {
      GetHrData(NUM_REQ_HR_VALS);
      checkForResponse = true;
    }
  
    delay(WAIT_PERIOD);
  
    // Check if we should check for and process a response
    if (((curState == STATE_AVG) || (curState == STATE_RAW)) && checkForResponse) {        
      UpdateHrInfo(HaveResponse());
      checkForResponse = false;
    }
  }
    chan_data = "";
    for (int i=0; i<numChannels; i++) {
      chan_data = chan_data + ";" + theta[i] + ";" + alpha[i] + ";" + beta[i] + ";" + gamma[i];
    }
  output.println(curHrVal + ";" + obciSampleMsec + ";" + chan_data + ";" + trig);
  trig = "";
}


void InitGui()
{
  // Create the main window
  size(SCREEN_W, SCREEN_H);
  fill(windowColor);
  rect(0, 0, SCREEN_W, SCREEN_H);
  
  // Create a font to use
  fontA = createFont("OpenSans-Regular.ttf", 50);
}

void InitMainScreen()
{
  curScreen = 1;
  
  // Reinitialize the window
  fill(windowColor);
  rect(0, 0, SCREEN_W, SCREEN_H);
  
  // Create the main window labels
  lw = new Label(1000, 4, "OSdysée.BPM");
  lw.configLabel(fontA, 25);
  lw.setBaseColor(windowColor);
  lw.setTextColor(textColor);
  lw.display();
  lhr = new Label(20, 20, "Heartrate");
  lhr.configLabel(fontA, 12);
  lhr.setBaseColor(windowColor);
  lhr.setTextColor(textColor);
  lhr.display();
  lstat = new Label(20, 160, "Status");
  lstat.configLabel(fontA, 12);
  lstat.setBaseColor(windowColor);
  lstat.setTextColor(textColor);
  lstat.display();

  // Create the heart rate display
  hrInfo = new HrDisplay(20, 40, 150, 100, fontA);
  hrInfo.setBaseColor(itemBaseColor);
  hrInfo.setTextColor(textColor);
  hrInfo.display();
  
  // Create the status display
  statInfo = new StatusDisplay(20, 180, 150, 100, fontA);
  statInfo.setBaseColor(itemBaseColor);
  statInfo.setTextColor(textColor);
  statInfo.display();
  
  // Create the graph
  graphLineColor = graphColor;
  graphBgColor = itemBaseColor;
  graphAxisColor = textColor;
  CreateGraph(220, 40, 950, 240, NUM_HR_POINTS);
  ConfigGraph(0, 240, 20, 20, 20);   //240 ordonné de graphe
  
  //Create the lines reperes     
     fill(27, 140, 140);
     noStroke();
     rect(220, 40, 950, 20);
     rect(220, 80, 950, 20);
     rect(220, 120, 950, 20);
     rect(220, 160, 950, 20);
     rect(220, 200, 950, 20);
     rect(220, 240, 950, 20);
     
     stroke(27, 140, 140);
     line(220,70,1170,70);
     line(220,110,1170,110);
     line(220,150,1170,150);
     line(220,190,1170,190);
     line(220,230,1170,230);
     line(220,270,1170,270);

     stroke(27, 173, 173);
     line(220,50,1170,50);
     line(220,90,1170,90);
     line(220,130,1170,130);
     line(220,170,1170,170);
     line(220,210,1170,210);
     line(220,250,1170,250);



  
  // Create the buttons
  b1 = new Button(860, 290, 60, 20, "Disable", fontA, 12);
  b1.enable(true);
  b1.setBaseColor(itemBaseColor);
  b1.setActiveColor(activeButtonColor);
  b1.setTextColor(textColor);
  b1.display();
  
  b2 = new Button(940, 290, 60, 20, "Hold", fontA, 12);
  b2.setBaseColor(itemBaseColor);
  b2.setActiveColor(activeButtonColor);
  b2.setTextColor(textColor);
  b2.display();
  
  b3 = new Button(1020, 290, 60, 20, "Average", fontA, 12);
  b3.setBaseColor(itemBaseColor);
  b3.setActiveColor(activeButtonColor);
  b3.setTextColor(textColor);
  b3.display();
  
  b4 = new Button(1100, 290, 60, 20, "Raw", fontA, 12);
  b4.setBaseColor(itemBaseColor);
  b4.setActiveColor(activeButtonColor);
  b4.setTextColor(textColor);
  b4.display();
}


void mousePressed()
{
  if (curScreen == 0) {
    CheckPortSelectScreenButtons();
  } else {
    CheckMainScreenButtons();
  }
}

  
void CheckMainScreenButtons() {
  // Look for a hit in one of the buttons
  if (b1.pressed()) {
    if (curState != STATE_DIS) {
      curState = STATE_DIS;
      CloseSerial();
      b2.enable(false);
      b3.enable(false);
      b4.enable(false);
      hrInfo.enable(false);
      statInfo.enable(false);
      ResetGraph();
    }
  } else if (b2.pressed()) {
    if (curState != STATE_HOLD) {
      if (curState == STATE_DIS) {
        OpenSerial();
      }
      curState = STATE_HOLD;
      firstSample = true;
      b1.enable(false);
      b3.enable(false);
      b4.enable(false);
      hrInfo.enable(true);
      statInfo.enable(true);
    }
  } else if (b3.pressed()) {
    if (curState != STATE_AVG) {
      if (curState == STATE_DIS) {
        OpenSerial();
      }
      curState = STATE_AVG;
      SetAvgMode(true);
      b1.enable(false);
      b2.enable(false);
      b4.enable(false);
      hrInfo.enable(true);
      statInfo.enable(true);
    }
  } else if (b4.pressed()) {
    if (curState != STATE_RAW) {
      if (curState == STATE_DIS) {
        OpenSerial();
      }
      curState = STATE_RAW;
      SetAvgMode(false);
      b1.enable(false);
      b2.enable(false);
      b3.enable(false);
      hrInfo.enable(true);
      statInfo.enable(true);
    }
  }
}

void UpdateHrInfo(boolean haveResponse)
{
  if (haveResponse) {
    curFlags = rspArgArray[0];
    curSampleCount = rspArgArray[1];
    curHrVal = rspArgArray[2];
  
    // Update the heartrate value with the most current value
    hrInfo.setVal(curHrVal);
    hrInfo.display();
  
    // Update the status display
    statInfo.setVal(curFlags);
    statInfo.display();
  
    // Update the graph
    if (firstSample) {
      firstSample = false;
    }
    else if (curSampleCount > prevSampleCount) {
      for (int i=(curSampleCount-prevSampleCount-1); i>=0; i--) {
        PushGraphData(rspArgArray[2+i]);
      }
      DrawGraph();
    } else if (curSampleCount < prevSampleCount) {
      for (int i=(curSampleCount+256-prevSampleCount-1); i>=0; i--) {
        PushGraphData(rspArgArray[2+i]);
      }
      DrawGraph();
    }
    prevSampleCount = curSampleCount;
  } else {
    // Indicate no response
    statInfo.setVal(0x80);
    statInfo.display();
  }
  
}

void keyPressed() { // Press a key to save the data
  if (key == ENTER) {
    output.flush(); // Write the remaining data
    output.close(); // Finish the file
    exit(); // Stop the program
  } else {
    println("key pressed : " + key);
    trig = "" + key;
  }
    
}
