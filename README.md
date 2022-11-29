# Bacteria cell wall thickness from TEM Images  

## Overview

We quantify the average and standard deviation (StdDev) of bacteria cell wall thickness from TEM images, by manually drawing inner and outer cell wall borders, 
and then automatically matching the pairs of inner and outer boundaries to create a ring-like region of interest for the cell wall and quantifying the Local thickness along the centerline 
(skeleton) of each cell wall. Manual drawing was done in Fiji [1] and the boundaries were saved as region of interests (ROIs) file. 
Automatic quantification was done using Fiji macro that read the TEM image together with the matching ROIs file.  
All the images were manually calibrated according to the scale bar, in order to get the measurements with proper calibration. Scaling can be done faster using the ScaleAndCropImages.ijm macro from the [Utils](https://github.com/WIS-MICC-CellObservatory/Utils) repository..

This macro was used in:  <br/> <br/>
<p align="center">
	<strong> XXX </strong><br/> <br/>
	</p>
	
<p align="center">
	<strong>YYY </strong><br/> <br/>
	</p>

Software package: Fiji (ImageJ)

Workflow language: ImageJ macro

<p align="center">
<img src="https://github.com/WIS-MICC-CellObservatory/BacteriaCellWallThickness/blob/main/SampleData/ScaledImages/Results/PNG/glu_6800X_0004_FinalInnerOuterOverlay.png" width="300" title="glu_6800X_0004 Final Inner Outer Overlay">
<img src="https://github.com/WIS-MICC-CellObservatory/BacteriaCellWallThickness/blob/main/SampleData/ScaledImages/Results/PNG/glu_6800X_0004_LocThkAndSkeleton.png" width="300" title="glu_6800X_0004 Local Thickness And Skeleton"> 
<img src="https://github.com/WIS-MICC-CellObservatory/BacteriaCellWallThickness/blob/main/SampleData/ScaledImages/Results/PNG/glu_6800X_0004_Mean_Flatten.png" width="300" title="glu_6800X_0004 Mean Thickness"> <br/> <br/>
<img src="https://github.com/WIS-MICC-CellObservatory/BacteriaCellWallThickness/blob/main/SampleData/ScaledImages/Results/PNG/TSB_6800X_0034_FinalInnerOuterOverlay.png" width="300" title="TSB_6800X_0034_Final Inner Outer Overlay"> 
<img src="https://github.com/WIS-MICC-CellObservatory/BacteriaCellWallThickness/blob/main/SampleData/ScaledImages/Results/PNG/TSB_6800X_0034_LocThkAndSkeleton.png" width="300" title="TSB_6800X_0034 Local Thickness And Skeleton"> 
<img src="https://github.com/WIS-MICC-CellObservatory/BacteriaCellWallThickness/blob/main/SampleData/ScaledImages/Results/PNG/TSB_6800X_0034_Mean_Flatten.png" width="300" title="TSB_6800X_0034 Mean Thickness"> 
	<br/> <br/> </p>

It assumes that the samples are carefully posioned and sectioned so that z-projection capture their shape correctly, and that z-projection was done prior to running the macro
The macro relies on (auto-context) pixel classification with Ilastik, it assumes that the given classifier was trained to predict fibrillar collagen (first class) vs crypt (second class)
  
## Workflow

1. Open selected image (FN.tif)
2. Read matched ROIs file (FN_RoiSet.zip)
3. Match pairs of Inner-Outer Rois and create corresponding Ring Rois , the Rois are renamed, sorted and saved in FN_FinalRoiSet.zip
4. Create binary mask of Rings and run local thickness (this is done for each cell individually to avoid miscalculation for touching cells)
5. Skeletonize the binary mask of rings (this is done for each cell individually to avoid miscalculation for touching cells)
6. Use the skeletonized rings to measure average thickness of cell wall and related and StdDev
7. Save results for each individual ring
8. Save quality control images with overlay of the ROIs used for measurement overlayed on the original image, and of Local Thickness with overlay of the skeleton used for measurements.
9. Save color coded images of average and Std of thickness - colors are controlled by MeanThk_MinVal, MeanThk_MaxVal, MeanThk_LUTName, StdThk_MinVal, StdThk_MaxVal, StdThk_LUTName, ZoomFactorForCalibrationBar
10. Write summary line of averages of all selected rings in the file
11. Add Mean/Std/Min/Max lines for the summary table

  	
## Output

For each input image FN, the following output files are saved in ResultsSubFolder under the input folder
- FN_FinalInnerOuterOverlay.tif 	- the original image with overlay of the selected cell wall regions 
- FN_Results.xls 				- the detailed measurements for each selected cell wall in the image  
- FN_FinalRoiSet.zip  			- the matched, renmaed and sorted selected cell wall regions used for measurements
- FN_RingLabel.tif  				- label map of selected cell wall regions 
- FN_RingLocThk.tif  			- local thickness image of selected cell wall regions - usefull for quality control of measurements
- FN_LocThkAndSkeleton.tif		- local thickness image of selected cell wall regions with overlay of the skeleton used for measurement in green - usefull for quality control of measurements
- FN_RingSkeletons.tif			- Skeletons used for measuring the thickness
- FN_Mean_Flatten.tif  			- color coded image of results - each selected cell wall is colored by its average thickness value 
- FN_StdDev_Flatten.tif  		- - color coded image of results - each selected cell wall is colored by the StdDev of its thickness 
 
SummaryResults.xls  	  - Table with one line for each input image files with average values of Mean , Min, Max and StdDev of LocTchikness
AllDetailedResults.xls - Table with one line of measurments for each selected cell wall region in each input image files (this concatanation of all the individual results files)
 

## Dependencies

Fiji (https://imagej.net/Fiji) with ImageJ version > 1.53e (Check Help=>About ImageJ, and if needed use Help=>Update ImageJ...
This macro requires the following Update sites to be activate through Help=>Update=>Manage Update site
- IJPB (https://imagej.net/MorphoLibJ) - for creating the color-coded images

To install it in Fiji:
 - Help=>Update
 - Click “Manage Update sites”
 - Check “IJPB-plugins”
 - Click “Close”
 - Click “Apply changes”
 
Please cite Fiji (https://imagej.net/Citing) and MorphoLibJ (https://imagej.net/plugins/morpholibj#citation) 
 
By Ofra Golani, MICC Cell Observatory, Weizmann Institute of Science, September 2021


##  Usage Instructions

NOTE: Before running the macro, make sure to 
------------------------------------------------------------
 
1. Scale and Crop images eg using ScaleAndCropImages.ijm macro 
 
2. Manually draw Inner and Outer ROIs for Inner and Outer Cell Wall regions
 - rename ROIs names to start either with "I-" for Inner side of the cell wall or "O-" for Outer side of the cell wall  
 - save the Rois in a file named   FN_RoiSet.zip , where FN is the original file name (without extension)  
 
Once you have done scaling and drawing, drag and drop the macro (QuantifyCellWallThickness.ijm) into Fiji and click Run
 - Set processMode to singleFile or wholeFolder

  
  
