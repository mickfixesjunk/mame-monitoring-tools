# MAME Analytics and Debugging Tool (MMT)
Visual Tool for assisting in the frame by frame debugging of games in MAME.
In the code I called it HyperTracing, so i gues we can call it that here too.

## Using the tool (HyperTracer)

The tool works by creating memory taps and logs (the HyperTrace), and then reading those files into a vizualizer in python.

- Step 1. Install Python 3 on your machine
- Step 1.1 Create these directories in your mame installation
   - mame/instructions
   - mame/snap/frames
- Step 2. Download or Clone the repo into your mame directory (mame-moniotirng-tools should be at the same level as mame.exe)
- Step 3. Execute the command to start whichever game you wish to debug (below is for STreet FIghter 2) using

`.\mame.exe sf2ua -debug -sound none -autoboot_script .\mame-monitoring-tools\mem-file-sync.lua`

The reason we use `-sound none` is because when you switch the hyper tracing on, it will sound pretty bad.

AT THIS POINT NO HYPER TRACING IS ACTIVE, ITS JUST THE SAME AS REGULAR MAME IN DEBUG MODE

- Step 4. Select the main Mame debug window and press F5 to start runing the emulation
- Step 5. When you have reached the point where you want to HyperTrace, press CTRL+SHIFT+D

THIS IS VERY CPUY INTENSIVE - a 500 MB rolling log file will be created

At this point MMT will start creating the HYperTrace, and a lot of logging will occur

THE GAME WILL SLOW DOWN AT THIS POINT

- The file memory-access.log will be created in the mame directory
- Each frame that was instrumented will be saved as a picture to snap/frames (make sure it exists)
- Instructions written at each frame will be output to mame/instructions
- At this point you have two options
   - Jump straight to the vizualizer while the tracing is still happening OR
   - Stop the trace by pressing CTRL+SHIFT+D again, so you can use the viz without the heavy load of logging

## Using the tool (Vizualiser)
When you have completed (or are in the middle of) a HyperTrace, you can then start the Vizualizer

Step 1. Open a command prompt inside your Mame directory
Step 2. `cd mame-monitoring-tools`
Step 2. Execute the following command

python3 tkinter-viz.py

This starts a live visluzer of the currently running code

-- On the Left, The game code, broken down into small memory blocks
-- On the right, The system memory, broken down into small memory blocks

The tool will draw lines between the boxes when activity is occuring so you can tell which piece of the code is being accessed
and which piece of memory is being written or read.
 - Green memory locations ONLY have writes
 - Blue memory locations ONLY have reads
 - Yellow memory locations have both

An x is overlaid on reads/writes in live mode as they happen

### Interacting with the Vizualizer

The tool has two modes
- Frame By Frame
- Live

It defaults to live mode, and so if you have stopped tracing, it will first load absolutely everything it has seen, 
and then start waiting for new logs, so you will see a LOT of lines connecting code to memory when you load it first.

A good option after you have completed a trace is to press "Frame By Frame" mode and then step through what you just traced

In FbF mode

- You can drag the slider to change frames in Frame By Frame Mode
- The diff between instructions on this frame and the previous frame is shown in the box beside the image
- The entire set of instructions that occurred on this frame are shown in the right most box

Thats it, i hope you find this useful, and have fun






