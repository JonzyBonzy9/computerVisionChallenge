# computerVisionChallenge

This is the README for our repo of the computer vision challenge in the summer term 2025.

# data

Put the Datasets folder into data folder like so: data/Datasets

# matlab requirements

MATLAB R2025a, Image Processing Toolbox, Computer Vision Toolbox

Authors: Paul Jegen, Moritz Geissler, Martin Muenster, Jonah Driske, Öykü Şevketbeyoğlu

# GUI

This includes a hint regarding the final packaging of the app. Provide an .mlappinstall file (includes all necessary files). Webapp will also be a part of it.

# Further developing ideas

## imporvements in image alignment

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
