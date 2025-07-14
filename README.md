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
  - chechboxes of dates: select desired pictures to be included in the visualization.
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


# How to operate

1.) start the app by running the main.m file. Alternatively: install the packaged cvApp.mltbx file and start it through the matlab app handler. 
2.) the GUI will now show. The GUI is divided into different sections. On the very top of the app, there is the toolbar. Below the "File" tab there are the options: 
  - Open: opens a dialog for the user to select a folder which contains datasets to be analyzed (supported file formats: xxx)
  - Quit: closes the app

Below the settings tab, a help button exists. Clicking the help button opens up a help site similar to the readme. 

3.) For ease of quick use, the "open" button is provided in the main view as well. The working principal is equal to the open button below the file tab. 

4.) Once a folder conatining the datasets was selected and the folder was loaded without any errors (a pop-up window would show), the user may proceed with using the app. As a first measure of action, some calculations are required. The user may start these calculatoins by clicking the "caluculate overlay" button. Inside the console visible in the "Overlay" view, the progress is submitted. 


# data

Put the Datasets folder into data folder like so: data/Datasets

# GUI


# Further developing ideas

## Observations

- alignments in general
  - output of homographie is not deterministic, sometimes fails completely --> this could use some error detection and recalculation
- How to align a set of images?
  - when computing H only between preseding images, errors accumulate (e.g. if 1 and 2 and 2 and three can be aligned almost perfectly, there is still a considerable error between 1 and 3)
  - much better, if H is computed between 1 and each other image (much more stable), possibly the first image might not be the perfect choice for this.
  - best results probably with a mix of both methods

## improvements in image alignment

- Feature-based matching with robust estimation
  - Use more sophisticated feature detectors like SIFT, SURF, or ORB, which are robust to scale, rotation, and illumination.
  - Then use RANSAC to robustly estimate transformations and filter out outliers.
- Use affine or polynomial transforms if the homography is too restrictive or unstable.
- Dense image registration methods:
  - Optical flow based methods (e.g., Lucas-Kanade, Farneback) for pixel-level displacement estimation.
  - Dense correlation or mutual information based registration - especially when radiometric changes happen.
- Use Digital Elevation Models (DEM) if available
  - Compensate for terrain-induced parallax by incorporating elevation data.

## How to categorize changes

- Type of change:
  - Appearance: New object appears (e.g., new building, road)
  - Disappearance: Object removed (e.g., deforestation, demolished building)
  - Modification: Object changes shape or intensity (e.g., flooding, urban expansion)
- Land cover changes:
  - Vegetation growth/loss
  - Water body changes
  - Urbanization
  - Agricultural changes
- Change magnitude:
  - Minor vs. major changes (based on pixel difference thresholds or feature magnitudes)
- Change certainty:
  - Confident changes vs. uncertain/noisy changes (using statistical tests)

## How to detect changes:

- Pixel based:
  - Image differencing: Simple pixel-wise difference or ratio between aligned images. Threshold the difference to detect changes.
  - Image ratioing
  - Change vector analysis (CVA): Uses spectral change magnitude and direction in multispectral space to detect changes.
  - Principal Component Analysis (PCA) on difference images
- Normalized Difference Indices: Like NDVI (vegetation index) difference to find vegetation changes.
- Object-based:
  - Segment images into objects (using superpixels or segmentation algorithms)
  - Detect changes at object-level (shape, texture, spectral changes)
- Classification:
  - Image classification + post-classification comparison: Classify each image independently into land cover classes, then compare labels for changes.
