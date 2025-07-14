# computerVisionChallenge

This is the README for our repo of the computer vision challenge in the summer term 2025.

# matlab requirements

MATLAB R2025a, Image Processing Toolbox, Computer Vision Toolbox, Image Aquisition Toolbox

# Authors: 
Paul Jegen, Moritz Geissler, Martin Muenster, Jonah Driske, Öykü Şevketbeyoğlu

# Description of the GUI
Toolbar: 
  - File: 
    - Open: opens a dialog for the user to select a folder which contains datasets to be analyzed (supported file formats: xxx). 
    - Quit: closes the app. 
  - Settings:
    - Help: opens a help file, which contains information similar to the readme file.
   
Menubar: 
- Open button: opens a dialog for the user to select a folder which contains datasets to be analyzed (supported file formats: xxx).
- No data/Calculate Overlay button: calculates the overlay of all pictures intersected with the neighbours. Necessary for all future proceedings.
- Visualization: select which kind of visulaiztaion is desired (Overlay is initial). Switching between the visualizations during calculations is possible.

Main view:
- Overlay:
  Left: the view depicts the loaded dataset interlaced with each other. Selective presentation is possible.
  Center:
    - Console: outputs progress and general calculation information.
    - Condusion Matrix: depicts the condusion matrix between the selected pictures.
    - Graph: depicts the clustered reachability graph with edge weights included.
  Right: user interaction options
  - Group: select group in order ot integrate selected pictures into groups. Use for quick A-B comparison between several picture sets.
  - Chechboxes of dates: select desired pictures to be included in the visualization.
  - Clear all: clears all checkboxes.
  - Select all: selects all checkboxes.
  - Select algorithm: choose the desired algorithm for overlay calculations. Options: graph, successive
  - Calculate Overlay: calculate the new overlay after parameters have been changed.
 
- Difference:
  Left:
    - Main View: depicts the graphical represantation of differences in between selected pictures.
    - Analysis:
    - Console: outputs progress and general calculation information.
  Right:user interaction options
    - Image Selection: select images to be shown differences in.
      - Groups: select active groupset. 
      - Checkboxes: select pictures.
      - Clear all: clears all checkboxes.
    - Parameters:
      - Environment Preset: select rough preset for different pictures. E.g. select "urban" for a dataset within a city. Options: urban,            natural, mixed
      - Detection algorithm: select detection algorithm for differences. Results will vary depending on selection of algorithm.
      - Custom Detection Presets: use these parameters to tune the behaviour in custom mode quickly. 
        - Spatial Scale: Options: small, medium, large
        - Temporal Processing: Options: fast, medium, slow
      - Detection Parameters: fine tune the parameters for the specific edge case scenario
        - Threshold: defines the threshold in difference above which shall be shown.
        - Block Size: defines the size of block pixels for calculating differences.
        - Min Area: minimum area to be recognized. 
        - Max Area: maximum are to be recognized.
      - Calculate Changes: click to update view with newly set parameters.
    - Visualization:
      - Visualization mode: selects teh view mode. Options: Individual (step through with time slider), combined (see all selected pcitures at the same time)
      - Display Options:
        - Images: displays loaded and selected images (deselect to see only masks). 
        - Masks: displays calculated masks (deselect to see only pictures).
        - Individual Mode Controls:
          - Blend amount: choose how many pictures should be blended into each other.
          - Time Slider: select picture as main picture by date.
        - Combined Mode Controls:
          Select difference visualization to be shown. Options: heatmap, temporal overlay, max, sum, average


# How to operate

1.) start the app by running the main.m file. Alternatively: install the packaged cvApp.mltbx file and start it through the matlab app handler. 

2.) the GUI will now show. The GUI is divided into different sections. Either select open in toolbar -> file -> open or click the "Open" button in the menu bar. 
A pop-up window will open for the user to select the desired folder with the datasets. Beware: the user must have access to the specified folder, it should not be a network drive and ideally it is located in the matlab working directory. 

3.) If no error pup-up window is shown, the import of the specified dataset was successfull. Click on the "Calculate Overlay" button to start calculations for all further processes. 

4.) Use the app to fulfill the desired function of the user. Change views, parameters, switch between different pictures and groupings. Beware: please press the corresponding necessary calculate button after parameters have been changed. 

Please use the app with care. - The developers -
