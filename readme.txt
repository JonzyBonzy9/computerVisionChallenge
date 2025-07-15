This .txt readme is in order to fulfill the task at hand. For github users: please use the .md readme

computerVisionChallenge

This is the README for our repo of the computer vision challenge in the summer term 2025.

MATLAB requirements

MATLAB R2025a (in darkmode to guarantee all elements can be seen!!)
Image Processing Toolbox
Computer Vision Toolbox
Image Aquisition Toolbox
Statistics and Machine Learning Toolbox
Authors:

Paul Jegen, Moritz Geissler, Martin Muenster, Jonah Driske, Öykü Şevketbeyoğlu

Description of the GUI

Toolbar:

File:
Open: opens a dialog for the user to select a folder which contains datasets to be analyzed (supported file formats: xxx).
Quit: closes the app.
Settings:
Help: opens a help file, which contains information similar to the readme file.
Menubar:

Open button: opens a dialog for the user to select a folder which contains datasets to be analyzed (supported file formats: mm_yyyy.jpg, yyyy_mm.jpg, m_yyyy.jpg).
No data/Calculate Overlay button: calculates the overlay of all pictures intersected with the neighbours. Necessary for all future proceedings.
View: select which kind of view is desired. Overlay is initial and can be used to tune the calculation of the image overlay. Difference is used to calculate and display the differences. Switching between the views during calculations is possible.
Views:

Overlay: Left: the view depicts the loaded dataset interlaced with each other. Selective presentation is possible. Center:

Console: outputs progress and general calculation information.
Confusion Matrix: depicts the confusion matrix between the selected pictures.
Graph: depicts the clustered reachability graph with edge weights included. Right: user interaction options
Group: if not all pictures could be aligned, they are split into groups that could. Limit the available selection to one group.
Chechboxes of dates: select desired pictures to be included in the visualization.
Clear all: clears all checkboxes.
Select all: selects all checkboxes.
Select algorithm: choose the desired algorithm for overlay calculations. Options: graph, successive
Calculate Overlay: calculate the new overlay using the parameters.
Difference with visualization on the left:

Main View: depicts the graphical representation of differences in between selected pictures.
Analysis: shows total
Console: outputs progress and general calculation information.
and controls on the right:

Image Selection: select images to be used for calculation. This does not influence the images shown.
Groups: select active groupset. Use apply to reselect all group members.
Checkboxes: select pictures.
Clear all: clears all checkboxes.
Parameters:
Environment Preset: select rough preset for different pictures. E.g. select "urban" for a dataset within a city. Options: urban, natural, mixed. The presets parameter are shown in the advanced section and can be modified.
Detection algorithm: select detection algorithm for differences. Results will vary depending on selection of algorithm. Also weighted combinations are available.
Spatial Scale: Options: small, medium, large
Temporal Processing: Options: fast, medium, slow
Threshold: defines the threshold in difference above which shall be shown.
Block Size: defines the size of block pixels for calculating differences.
Min Area: minimum area to be recognized.
Max Area: maximum are to be recognized.
Calculate Changes: click to update view with newly set parameters.
Visualization:
Individual: blend images and differences dependent on selected blend factor and time value.
Combined: shows overlay of all images and combination of masks. Options: heatmap, temporal overlay, max, sum, avg.
Images Checkbox: displays all images from selected Group (deselect to see only masks).
Masks Checkbox: displays calculated masks (deselect to see only pictures).
How to operate

1.) start the app by running the main.m file. Alternatively: install the packaged cvApp.mltbx file and start it through the matlab app handler.

2.) the GUI will now show. The GUI is divided into different sections. Either select open in toolbar -> file -> open or click the "Open" button in the menu bar. A pop-up window will open for the user to select the desired folder with the datasets. Beware: the user must have access to the specified folder, it should not be a network drive and ideally it is located in the matlab working directory.

3.) If no error pop-up window is shown, the import of the specified dataset was successfull. Click on the "Calculate Overlay" button to start calculations for all further processes.

4.) Use the app to fulfill the desired function of the user. Change views, parameters, switch between different pictures and groupings. Beware: please press the corresponding necessary calculate button after parameters have been changed.

Please use the app with care. - The developers -
