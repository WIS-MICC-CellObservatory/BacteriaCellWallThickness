#@ string(label="Process Mode", choices=("singleFile", "wholeFolder"), style="list") processMode
#@ string (label="File Extension",value=".tif", persist=true, description="eg .tif, .h5") fileExtension


/*
 * QuantifyCellWallThickness.ijm
 * 
 * Measure average and Std of bacterai cell wall thickness
 * 
 * Workflow
 * ========
 * - Open selected image (FN.tif)
 * - Read matched ROIs file (FN_RoiSet.zip)
 * - Match pairs of Inner-Outer Rois and create corresponding Ring Rois , the Rois are renamed, sorted and saved in FN_FinalRoiSet.zip
 * - Create binary mask of Rings and run local thickness (this is done for each cell individually to avoid miscalculation for touching cells)
 * - Skeletonize the binary mask of rings (this is done for each cell individually to avoid miscalculation for touching cells)
 * - Use the skeletonized rings to measure average thickness of cell wall and related and StdDev
 * - save results for each individual ring
 * - save quality control images with overlay of the ROIs used for measurement overlayed on the original image, and of Local Thickness with overlay of the skeleton used for measurements.
 * - save color coded images of average and Std of thickness - colors are controlled by MeanThk_MinVal, MeanThk_MaxVal, MeanThk_LUTName, StdThk_MinVal, StdThk_MaxVal, StdThk_LUTName, ZoomFactorForCalibrationBar
 * - write summary line of averages of all selected rings in the file
 * - Add Mean/Std/Min/Max lines for the summary table
 * 
 * Usage
 * =====
 * 
 * NOTE: Before running the macro, make sure to 
 * ------------------------------------------------------------
 * 
 * 1. Scale and Crop images eg using ScaleAndCropImages.ijm macro 
 * 
 * 2. Manually draw Inner and Outer ROIs for Inner and Outer Cell Wall regions
 * - rename ROIs names to start either with "I-" for Inner side of the cell wall or "O-" for Outer side of the cell wall  
 * - save the Rois in a file named   FN_RoiSet.zip , where FN is the original file name (without extension)  
 * 
 * Once you have done scaling and drawing, drag and drop the macro (QuantifyCellWallThickness.ijm) into Fiji and click Run
 * 	- Set processMode to singleFile or wholeFolder
 * 	- If batchModeFlag is selected (recomended) the macro will run faster and not dispalyed temporary images (but there is a problem saving the flatten overlay :-( )
 * 	
 * Output
 * ======
 * For each input image FN, the following output files are saved in ResultsSubFolder under the input folder
 * - FN_FinalInnerOuterOverlay.tif 	- the original image with overlay of the selected cell wall regions 
 * - FN_Results.xls 				- the detailed measurements for each selected cell wall in the image  
 * - FN_FinalRoiSet.zip  			- the matched, renmaed and sorted selected cell wall regions used for measurements
 * - FN_RingLabel.tif  				- label map of selected cell wall regions 
 * - FN_RingLocThk.tif  			- local thickness image of selected cell wall regions - usefull for quality control of measurements
 * - FN_LocThkAndSkeleton.tif		- local thickness image of selected cell wall regions with overlay of the skeleton used for measurement in green - usefull for quality control of measurements
 * - FN_RingSkeletons.tif			- Skeletons used for measuring the thickness
 * - FN_Mean_Flatten.tif  			- color coded image of results - each selected cell wall is colored by its average thickness value 
 * - FN_StdDev_Flatten.tif  		- - color coded image of results - each selected cell wall is colored by the StdDev of its thickness 
 * 
 * SummaryResults.xls  	  - Table with one line for each input image files with average values of Mean , Min, Max and StdDev of LocTchikness
 * AllDetailedResults.xls - Table with one line of measurments for each selected cell wall region in each input image files (this concatanation of all the individual results files)
 * 
 * Dependencies
 * ============
 * Fiji with ImageJ version > 1.53e (Check Help=>About ImageJ, and if needed use Help=>Update ImageJ...
 * This macro requires the following Update sites to be activate through Help=>Update=>Manage Update site
 * - IJPB (MorphoLibJ) - for creating the color-coded images
 * 
 * Please cite Fiji (https://imagej.net/Citing) and MorphoLibJ (https://imagej.net/plugins/morpholibj#citation) 
 * 
 * By Ofra Golani, MICC Cell Observatory, Weizmann Institute of Science, September 2021
 * 
 * v1: 
 * v2:  - Run local thickness and skeletonization on each ring independently to avoid miscalculation at touching points
 * 		- prune skeleton endpoints 
 * 		- save overlay of skeleton on LocaThickness image for QA
 * 		- batch option removed, as it does not work well.
 * 
 * ToDo: 
 * =====
 * - fix overlay in batch mode
 * 
 * #@ Boolean(label="Batch Mode?",value=false, persist=false, description="Hide images while working. Active only in Quantify mode") batchModeFlag
 */


// ============ Parameters =======================================
var macroVersion = "v2";
//var fileExtension = ".tif";
var batchModeFlag = false;

var runMode = "Quantify";
var RoiSelectionTool = "polygon"; // "ellipse" , "polygon",  "rectangle"

var BorderRoisSuffix = "_RoiSet.zip"; // either .zip or .roi 
var FinalRoisSuffix = "_FinalRoiSet.zip"; // either .zip or .roi 
var DefaultNumberOfRoi = 1;

var InnerRoiColor= "cyan";
var OuterRoiColor= "red";

var saveRingLabelMapFlag = 1;
var saveRingLocThkFlag = 1;
var saveLabeledSkeletons = 1;
var SkeletonOverlayColor = "green";
var saveDebugFiles = 0;

// parameters for color-coded images
var createColorCodeImagesFlag = 1;

var MeanThk_MinVal = 0;
var MeanThk_MaxVal = 0.4; 
var MeanThk_DecimalVal = 3;
var MeanThk_LUTName = "Fire";
var StdThk_MinVal = 0;
var StdThk_MaxVal = 0.1; 
var StdThk_DecimalVal = 3;
var StdThk_LUTName = "Fire";
var ZoomFactorForCalibrationBar = 2;

var ResultsSubFolder = "Results";
//var ResultsSubFolder = "Results_MorphoSeg";
var cleanupFlag = 1; 
var debugFlag = 0; //1; //0;

// Global Parameters
var SummaryTable = "SummaryResults.xls";
var AllDetailedTable = "DeatiledResults.xls";
var TimeString;

var SuffixStr = ""; // dummy

var nPairs;
var RingNames;

// ================= Main Code ====================================

Initialization();

// Choose image file or folder
if (matches(processMode, "singleFile")) {
	file_name=File.openDialog("Please select an image file to analyze");
	directory = File.getParent(file_name);
	}
else if (matches(processMode, "wholeFolder")) {
	directory = getDirectory("Please select a folder of images to analyze"); }

else if (matches(processMode, "AllSubFolders")) {
	parentDirectory = getDirectory("Please select a Parent Folder of subfolders to analyze"); }

// Analysis 
if (matches(processMode, "wholeFolder") || matches(processMode, "singleFile")) {
	resFolder = directory + File.separator + ResultsSubFolder + File.separator; 
	File.makeDirectory(resFolder);
	print("inDir=",directory," outDir=",resFolder);
	
	if (matches(processMode, "singleFile")) {
		ProcessFile(directory, resFolder, file_name); }
	else if (matches(processMode, "wholeFolder")) {
		ProcessFiles(directory, resFolder); }
}

else if (matches(processMode, "AllSubFolders")) {
	list = getFileList(parentDirectory);
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(parentDirectory + list[i])) {
			subFolderName = list[i];
			//print(subFolderName);
			subFolderName = substring(subFolderName, 0,lengthOf(subFolderName)-1);
			//print(subFolderName);

			//directory = parentDirectory + list[i];
			directory = parentDirectory + subFolderName + File.separator;
			resFolder = directory + ResultsSubFolder + File.separator; 
			//print(parentDirectory, directory, resFolder);
			File.makeDirectory(resFolder);
			print("inDir=",directory," outDir=",resFolder);
			//if (isOpen("SummaryResults.xls"))
			if (isOpen(SummaryTable))
			{
				//selectWindow("SummaryResults.xls");
				selectWindow(SummaryTable);
				selectWindow(AllDetailedTable);
				run("Close");  // To close non-image window
			}
			ProcessFiles(directory, resFolder);
			print("Processing ",subFolderName, " Done");
		}
	}
}

if (cleanupFlag==true) 
{
	CloseTable(SummaryTable);	
	CloseTable(AllDetailedTable);	
}
setBatchMode(false);
print("=================== Done ! ===================");

// ================= Helper Functions ====================================

//===============================================================================================================
// Loop on all files in the folder and Run analysis on each of them
function ProcessFiles(directory, resFolder) 
{
	dir1=substring(directory, 0,lengthOf(directory)-1);
	idx=lastIndexOf(dir1,File.separator);
	subdir=substring(dir1, idx+1,lengthOf(dir1));

	// Get the files in the folder 
	fileListArray = getFileList(directory);
	
	// Loop over files
	for (fileIndex = 0; fileIndex < lengthOf(fileListArray); fileIndex++) {
		if (endsWith(fileListArray[fileIndex], fileExtension) ) {
			file_name = directory+File.separator+fileListArray[fileIndex];
			//open(file_name);	
			//print("\nProcessing:",fileListArray[fileIndex]);
			showProgress(fileIndex/lengthOf(fileListArray));
			ProcessFile(directory, resFolder, file_name);
		} // end of if 
	} // end of for loop

	// Save Results
	if (isOpen(SummaryTable))
	{
		GenerateSummaryLines(SummaryTable);
		selectWindow(SummaryTable);
		SummaryTable1 = replace(SummaryTable, ".xls", "");
		print("SummaryTable=",SummaryTable,"SummaryTable1=",SummaryTable1,"subdir=",subdir);
		saveAs("Results", resFolder+SummaryTable1+"_"+subdir+".xls");
		run("Close");  // To close non-image window

		GenerateSummaryLines(AllDetailedTable);
		selectWindow(AllDetailedTable);
		AllDetailedTable1 = replace(AllDetailedTable, ".xls", "");
		print("AllDetailedTable=",AllDetailedTable,"AllDetailedTable1=",AllDetailedTable1,"subdir=",subdir);
		saveAs("Results", resFolder+AllDetailedTable1+"_"+subdir+".xls");
		run("Close");  // To close non-image window
	}
	
	// Cleanup
	if (cleanupFlag==true) 
	{
		CloseTable(SummaryTable);	
		CloseTable(AllDetailedTable);	
	}
} // end of ProcessFiles



//===============================================================================================================
// Run analysis of single file
function ProcessFile(directory, resFolder, file_name) 
{

	// ===== Open File ========================
	// later on, replace with a stack and do here Z-Project, change the message above
	//print(file_name);
	if ( endsWith(file_name, "h5") )
		run("Import HDF5", "select=["+file_name+"] datasetname=[/data: (1, 1, 1024, 1024, 1) uint8] axisorder=tzyxc");
	else
		open(file_name);

	directory = File.directory;
	origName = getTitle();
	Im = getImageID();
	origNameNoExt = File.getNameWithoutExtension(file_name);

	if (matches(runMode,"DrawBorderROis")) {
		GetBorderRois(resFolder, origNameNoExt, Im, MeasureRoisSuffix);
	} else if (matches(runMode,"Quantify")) {
		GetRingRoisFromBorderRoisAndQuantify(directory, resFolder, origName, origNameNoExt, Im, BorderRoisSuffix);
	}

	if (debugFlag) waitForUser;
	if(cleanupFlag) Cleanup();
} // end of ProcessFile


//===============================================================================================================
function GetRingRoisFromBorderRoisAndQuantify(inDir, resDir, origName, origNameNoExt, origIm, BorderRoisSuffix)
{
	borderRoiSetFile = inDir+origNameNoExt+BorderRoisSuffix;
	if (File.exists(borderRoiSetFile))
	{
		print(file_name + " - Processing...");
		roiManager("Open", borderRoiSetFile);
	
		/*
		//-------------------------------------------------------------------------------------//
		// Create label mask using updated inner ROIs only , reload all ROis afterward
		//-------------------------------------------------------------------------------------//
		nRoi = roiManager("Count");
		for (n = nRoi-1; n >= 0; n--)
		{	
			roiManager("Select",n);
			roiName=call("ij.plugin.frame.RoiManager.getName", n);
			if (startsWith(roiName, "O-"))
			{
				roiManager("Delete");
			}
		}
		createLabelMaskFromRoiManager(origIm);
		rename("InnerRoiCountMask");
		labelMaskIm=getImageID();
		roiManager("reset");
		roiManager("Open", borderRoiSetFile);
	*/
	
		createLabelMaskFromRoiManager_byText (origName, "LabeledInnerRings", "I-");
		selectWindow("LabeledInnerRings");
		labelMaskIm = getImageID();
	
		//roiManager("Measure");
		
		//-------------------------------------------------------------------------------------//
		// Find Matched Inner-Outer Rois
		//-------------------------------------------------------------------------------------//
		selectImage(labelMaskIm);
		roiManager("Deselect");
		roiManager("Show None");
		getStatistics(areaCM, meanCM, minCM, maxCM);
		nRoi = roiManager("Count");
		roiTypeA = newArray(nRoi); // 0=inner, 1=outer
		roiNameA = newArray(nRoi); // name of each Roi
		roiNewNameA = newArray(nRoi); // new name of each Roi - with prefix of Rnnnn_ where nnnn stands for the pair number
		roiActiveA = newArray(nRoi); // is Roi Used either inner/outer
		countMaskValA = newArray(nRoi); // countMask value of inner idx
		//roiAreaA = newArray(nRoi); // Roi Area
		outerRoiIdx = newArray(nRoi); // Indexes of all outer Rois only
		innerRoiIdx = newArray(nRoi); // Indexes of all inner Rois only
		nInnerRoi = 0;
		nOuterRoi = 0;
		for (n = 0; n < nRoi; n++)
		{	
			roiManager("Select",n);
			roiName=call("ij.plugin.frame.RoiManager.getName", n);
			roiNameA[n] = roiName;
			if (startsWith(roiName, "I-"))
			{
				roiTypeA[n] = 0; // Inner
				innerRoiIdx[nInnerRoi] = n;
				nInnerRoi++;
			} else // Outer Roi (starts with "O-")
			{
				roiTypeA[n] = 1; // Outer
				outerRoiIdx[nOuterRoi] = n;
				nOuterRoi++;
			}
			// find most frequent non-zero value of the countMask within the given outer Roi
			nBins = maxCM + 10;
			getHistogram(values, counts, nBins, 0, nBins);
			maxCount = 0;
			maxVal = -1; // to enable checking for validity
			for (j = 1; j < nBins; j++)
			{
				if (counts[j] > maxCount)
				{
					maxCount = counts[j];
					maxVal = values[j];
				}
			}
			countMaskValA[n] = maxVal; //  the +1 is needed as we started the hist from 1
			//roiAreaA[n] = getResult("Area", n);
		}
		
		
		// Find matching pairs
		nPairs = 0;
		for (n = 0; n < nOuterRoi; n++)
		{
			outerIdx = outerRoiIdx[n];
			outCountMaskVal = countMaskValA[outerIdx];
			found = 0;
			if (outCountMaskVal >= 0)
			{
				m = 0;
				innerIdx = 0;
				do {
					id = innerRoiIdx[m];
					inCountMaskVal = countMaskValA[id];
					if (inCountMaskVal == outCountMaskVal)
					{
						innerIdx = id;
						found = 1;
					}
					m++;
				} while ( (m < nInnerRoi) && (found==0))
			}
			if (found==1)
			{
				nPairs++;
				prefix = "R"+pad(nPairs,4,0)+"-";
				roiNewNameA[outerIdx] = prefix + roiNameA[outerIdx];
				roiNewNameA[innerIdx] = prefix + roiNameA[innerIdx];
				roiActiveA[outerIdx] = 1;
				roiActiveA[innerIdx] = 1;	
			}
			else
			{
				roiActiveA[outerIdx] = 0;
			}
		}
		saveAs("Results", resDir+origNameNoExt+"_FinalResults.csv");
		
		//-------------------------------------------------------------------------------------//
		// Delete all non-relevant Rois, and save the Rois of inner/Outer only 
		//-------------------------------------------------------------------------------------//
		for (n = nRoi-1; n >= 0; n--)
		{	
			roiManager("Select",n);
			if (roiActiveA[n] == 0)
			{
				roiManager("Delete");
			}
			else
			{
				if (startsWith(roiNameA[n], "I-"))
				{
					roiManager("Set Color", InnerRoiColor);
					roiManager("Set Line Width", 2);
				}
				else // Outer Roi
				{
					roiManager("Set Color", OuterRoiColor);
					roiManager("Set Line Width", 2);
				}
				roiManager("rename", roiNewNameA[n]);
			}
		}
		// sort the Rois which have new names now, to put inner and outer Rois together
		roiManager("sort");
		roiManager("Save", resDir+origNameNoExt+FinalRoisSuffix);
		selectImage(origIm);
		roiManager("Deselect");
		roiManager("Show None");
		roiManager("Show All without labels");
		run("Flatten");
		saveAs("Tiff", resDir+origNameNoExt+"_FinalInnerOuterOverlay.tif");
		flatIm = getImageID();
	
		// Now add Ring Rois - note that the inner/outer rings are sorted now
		nRoi = roiManager("count");
		newId = nRoi;
		//print("nRoi=",nRoi);
		RingNames = newArray(nPairs);
		firstRingId = nRoi;
		for (n = 0; n < nPairs; n++)
		{
			roiManager("deselect");
			innerId = 2*n;
			outerId = 2*n+1;
			roiName=call("ij.plugin.frame.RoiManager.getName", innerId);
			//print(n, "innerId=","roiName=", roiName, innerId , "outerId=",outerId, "newId=",newId);
			roiManager("Select", newArray(innerId,outerId));
			roiManager("XOR");
			roiManager("Add");
			roiManager("select", newId);
			newName = replace(roiName, "I-", "R-");
			roiManager("rename", newName);
			RingNames[n] = newName;
			newId++;
		}
		
		createLabelMaskFromRoiManager_byRange (origName, "LabeledRing",nRoi, newId, nRoi);
		if (saveRingLabelMapFlag) 
		{
			selectWindow("LabeledRing");
			saveAs("Tiff", resDir+origNameNoExt+"_RingLabel"+SuffixStr+".tif");
			rename("LabeledRing");
		}
	
		run("Duplicate...", "title=RingMask");
		setThreshold(1, 65535);
		setOption("BlackBackground", true);
		run("Convert to Mask");
	
		//run("Local Thickness (masked, calibrated, silent)");
		// Run local thickness independently on each ring to avoid misscalculation in case of touching rings
		// combine into one image for visualization
		// this assumes that the values at/near the touching areas are not used for measurements 
		nRoi = roiManager("count");
		for (n = firstRingId; n < nRoi; n++)
		{		
			selectWindow("RingMask");
			roiManager("Select", n);
			run("Create Mask");
			selectWindow("Mask");
			run("Local Thickness (masked, calibrated, silent)");
			roiManager("Select", n);
			run("Clear Outside"); // to replace NaNs with 0
			if (n > firstRingId)
			{
				imageCalculator("Add 32-bit", "RingMask_LocThk","Mask_LocThk");
				selectWindow("Mask_LocThk");
				close();
			}
			else 
				rename("RingMask_LocThk");
			selectWindow("Mask");
			close();
		}
		
		//run("Local Thickness (complete process)", "threshold=128");
		if (saveRingLocThkFlag) 
		{
			selectWindow("RingMask_LocThk");
			saveAs("Tiff", resDir+origNameNoExt+"_RingLocThk"+SuffixStr+".tif");
			rename("RingMask_LocThk");
		}
	
		selectWindow("RingMask");
		nRoi = roiManager("count");
		for (n = firstRingId; n < nRoi; n++)
		{		
			roiManager("Select", n);
			run("Create Mask");
			run("Skeletonize (2D/3D)");
		}
		selectWindow("Mask");
		//rename("OrigSkel");
		rename("SkeletonMask");
		// prune end points
		run("Analyze Skeleton (2D/3D)", "prune=[shortest branch] prune_0");
		//rename("SkeletonMask");
		selectWindow("SkeletonMask");
		run("Select None");
		run("Duplicate...", "title=LabeledSkeletons");		

		selectWindow("LabeledSkeletons");
		run("Divide...", "value=255");
	
		imageCalculator("Multiply", "LabeledSkeletons","LabeledRing");

		selectWindow("LabeledSkeletons");
		if (saveLabeledSkeletons) 
		{
			selectWindow("LabeledSkeletons");
			saveAs("Tiff", resDir+origNameNoExt+"_RingSkeletons"+SuffixStr+".tif");
			rename("LabeledSkeletons");

			CalibrationFlag = 1;
			SaveOverlayImage("RingMask_LocThk", "SkeletonMask", origNameNoExt+"_LocThkAndSkeleton", "", resDir, 0, "", SkeletonOverlayColor, CalibrationFlag, MeanThk_DecimalVal, ZoomFactorForCalibrationBar);			
		}
		run("Intensity Measurements 2D/3D", "input=RingMask_LocThk labels=LabeledSkeletons mean stddev max min median mode skewness kurtosis numberofvoxels volume");
		
		// Create and save color coded images
		if (createColorCodeImagesFlag) 
		{
			CreateAndSaveColorCodeImage("LabeledRing", "RingMask_LocThk-intensity-measurements", resDir, origNameNoExt, "Mean", SuffixStr, MeanThk_MinVal, MeanThk_MaxVal, MeanThk_DecimalVal, ZoomFactorForCalibrationBar, MeanThk_LUTName);
			CreateAndSaveColorCodeImage("LabeledRing", "RingMask_LocThk-intensity-measurements", resDir, origNameNoExt, "StdDev",  SuffixStr, StdThk_MinVal,  StdThk_MaxVal,  StdThk_DecimalVal,  ZoomFactorForCalibrationBar, StdThk_LUTName);
		}	
	
		GetAndSaveStat(resDir, origNameNoExt);
		AppendTables(AllDetailedTable,"DetailedResults");
		
		// save All Rois
		if (saveDebugFiles)
		{
			roiManager("Save", resDir+origNameNoExt+"_AllRoiSet"+SuffixStr+".zip");
		}
		
		//-------------------------------------------------------------------------------------//
		// Close newly opened images and tables 
		//-------------------------------------------------------------------------------------//
		if (cleanupFlag == 1)
		{
			CloseTable("RingMask_LocThk-intensity-measurements");
			CloseTable(origNameNoExt+"_AllRoiResults.csv");
			CloseTable("Summary");
			CloseTable("Results");
			selectImage(labelMaskIm);
			close();
			selectImage(flatIm);
			close();
			roiManager("reset");
		}
	} // if roi file exist	
	else {
		print(file_name + " - No matching ROI file ...");
	}
}

//===============================================================================================================
// createLabelMaskFromRoiManager - Create Labeled Image using firstId-lastID ROis from ROI Manager, apply scaling of the original image
function createLabelMaskFromRoiManager_byRange (ImName, labeledName,firstId, lastId, labelOffset)
{
	selectWindow(ImName);
	getVoxelSize(width, height, depth, unit);
	newImage(labeledName, "16-bit black", getWidth(), getHeight(), 1);
	//newImage("labeling", "16-bit black", getWidth(), getHeight(), 1);

	for (id = firstId; id < lastId; id++) {
		roiManager("select", id);
		index = id - labelOffset;
		setColor(index+1);
		fill();
	}
	roiManager("Deselect");
	run("Select None");
	// apply scaling of original image
	setVoxelSize(width, height, depth, unit);
	
	resetMinAndMax();
	run("glasbey");
}


//===============================================================================================================
// createLabelMaskFromRoiManager - Create Labeled Image using firstId-lastID ROis from ROI Manager, apply scaling of the original image
function createLabelMaskFromRoiManager_byText (ImName, labeledName, TextStr)
{
	selectWindow(ImName);
	getVoxelSize(width, height, depth, unit);
	newImage(labeledName, "16-bit black", getWidth(), getHeight(), 1);
	//newImage("labeling", "16-bit black", getWidth(), getHeight(), 1);

	nRoi = roiManager("count");
	index = 0;
	for (id = 0; id < nRoi; id++) {
		roiName=call("ij.plugin.frame.RoiManager.getName", id);
		if (indexOf(roiName, TextStr) != -1)
		{
			roiManager("select", id);
			index = index+1;
			setColor(index);
			fill();
		}
	}
	roiManager("Deselect");
	run("Select None");
	// apply scaling of original image
	setVoxelSize(width, height, depth, unit);
	
	resetMinAndMax();
	run("glasbey");
}


//ToDo - Delete
//===============================================================================================================
// createLabelMaskFromRoiManager - Create Labeled Image based on ROI Manager, apply scaling of the original image
function createLabelMaskFromRoiManager(origIm)
{
	selectImage(origIm);
	getVoxelSize(width, height, depth, unit);
	newImage("Labeling", "16-bit black", getWidth(), getHeight(), 1);
	
	for (index = 0; index < roiManager("count"); index++) {
		roiManager("select", index);
		setColor(index+1);
		fill();
	}

	// apply scaling of original image
	setVoxelSize(width, height, depth, unit);
	
	resetMinAndMax();
	run("glasbey");
}

//===============================================================================================================
// Add leading zeros to number
function pad(a, left, right) 
{ 
	while (lengthOf(""+a)<left) a="0"+a; 
	if (right > 0)
	{
		separator="."; 
		while (lengthOf(""+separator)<=right) separator=separator+"0"; 
		return ""+a+separator; 
	}
	else 
		return ""+a;
} 



//===============================================================================================================
	
	
// It is assumed that Intensity of Local thickness for each ring-skeleton was already measured 
// and can be found in "RingMask_LockThk-intensity-measurements"
function GetAndSaveStat(resFolder, origNameNoExt)
{
	if (isOpen("RingMask_LocThk-intensity-measurements"))
	{

		selectWindow("RingMask_LocThk-intensity-measurements");
		FileName = newArray(nPairs);
		for (n = 0; n < nPairs; n++) FileName[n] = origNameNoExt;
		
		RingLabel = Table.getColumn("Label");
		MeanThk = Table.getColumn("Mean");
		StdThk = Table.getColumn("StdDev");
		MaxThk = Table.getColumn("Max");
		MinThk = Table.getColumn("Min");
		ModeThk = Table.getColumn("Mode");
	
		Table.showArrays("Results", FileName, RingLabel, RingNames, MeanThk, StdThk, MaxThk, MinThk, ModeThk);
		
		
		selectWindow("Results");
		Table.save(resFolder+origNameNoExt+"_Results"+SuffixStr+".xls");
	
		// Calc statistics
	
		Array.getStatistics(MeanThk, minMeanThk, maxMeanThk, meanMeanThk, stdDevMeanThk);
		Array.getStatistics(StdThk, minStdThk, maxStdThk, meanStdThk, stdDevStdThk);
		Array.getStatistics(MaxThk, minMaxThk, maxMaxThk, meanMaxThk, stdDevMaxThk);
		Array.getStatistics(MinThk, minMinThk, maxMinThk, meanMinThk, stdDevMinThk);
		Array.getStatistics(ModeThk, minModeThk, maxModeThk, meanModeThk, stdDevModeThk);

		//print("meanArea=", meanArea, "meanCirc=", meanCirc, "meanSolidity=", meanSolidity);
	}
	else {
		nPairs= 0;
		meanMeanThk = 0;
		meanStdThk = 0;
		meanMaxThk = 0;
		meanMinThk = 0;
		meanModeThk = 0;
	}	
	// =========== Add line in Summary Table =============
	if (isOpen("Results"))
	{
		//run("Close");
		selectWindow("Results"); // One must select the table to be renamed prior to Table.rename
		Table.rename("Results", "DetailedResults");
		Table.update("DetailedResults");
		Table.create("Results");
	}

	// Output the measured values into new results table
	if (isOpen(SummaryTable))
	{
		selectWindow(SummaryTable); // One must select the table to be renamed prior to Table.rename
		Table.rename(SummaryTable, "Results"); // rename to avoid table overwrite
	}	
	else
		run("Clear Results");

	selectWindow("Results");
	//print("nResults=",nResults);
	Table.set("Label", nResults, origNameNoExt); 
	Table.update;
	Table.set("nPairs", nResults-1, nPairs); 
	Table.set("meanMeanThk", nResults-1, meanMeanThk); 
	Table.set("meanStdThk", nResults-1, meanStdThk); 
	Table.set("meanMaxThk", nResults-1, meanMaxThk); 
	Table.set("meanMinThk", nResults-1, meanMinThk); 
	Table.set("meanModeThk", nResults-1, meanModeThk); 
	//Table.update;
	Table.update("Results");

	// Save Results - actual saving is done at the higher level function as this table include one line for each image
	selectWindow("Results"); // One must select the table to be renamed prior to Table.rename
	Table.rename("Results", SummaryTable); // rename to avoid table overwrite
	Table.update(SummaryTable);

} // end of MeasureDomains


//===============================================================================================================
// append the content of additonalTable to bigTable
// if bigTable does not exist - create it 
// if additonalTable is empty or dont exist - do nothing
function AppendTables(bigTable, additonalTable)
{

	// if additonalTable is empty or don't exist - do nothing
	if (!isOpen(additonalTable)) return;
	selectWindow(additonalTable);
	nAdditionalRows = Table.size;
	if (nAdditionalRows == 0) return;
	Headings = Table.headings;
	headingArr = split(Headings);

	if (!isOpen(bigTable))
	{
		Table.create(bigTable);
	}
	selectWindow(bigTable);
	nRows = Table.size;

	// loop over columns of additional Table and add them to bigTable
	for (i = 0; i < headingArr.length; i++)
	{
		selectWindow(additonalTable);
		ColName = headingArr[i];
		valArr = Table.getColumn(ColName);
		if (valArr.length == 0) continue;
		
		selectWindow(bigTable);
		for (j = 0; j < nAdditionalRows; j++)
		{
			//print(i, ColName, j, valArr[j]);
			Table.set(ColName, nRows+j, valArr[j]); 
		}
	}

	selectWindow(bigTable);
	Table.showRowNumbers(true);
	Table.update;
} // end of AppendTables


//===============================================================================================================
function GenerateSummaryLines(tableName)
{
	if (isOpen(tableName))
	{
		//Table.rename(tableName, "Results");
		selectWindow(tableName);
		nRows = Table.size;
		Headings = Table.headings;
		headingArr = split(Headings);

		selectWindow(tableName);
		Table.set("Label", nRows, "MeanValues"); 
		Table.set("Label", nRows+1, "StdValues"); 
		Table.set("Label", nRows+2, "MinValues"); 
		Table.set("Label", nRows+3, "MaxValues"); 
		for (i = 0; i < headingArr.length; i++)
		{
			ColName = headingArr[i];
			if (matches(ColName, "Label")) continue;

			valArr = Table.getColumn(ColName);
			valArr = Array.trim(valArr, nRows);
			Array.getStatistics(valArr, minVal, maxVal, meanVal, stdVal);
			if (!isNaN(meanVal))
			{
				Table.set(ColName, nRows,   meanVal); 
				Table.set(ColName, nRows+1, stdVal); 
				Table.set(ColName, nRows+2, minVal); 
				Table.set(ColName, nRows+3, maxVal); 
			}
		}
		Table.update;
	}
} // end of GenerateSummaryLines




//===============================================================================================================
// look for existing ROIs in the results folder, 
// if it does not exist, then ask the user to select foreground and background ROIs, and save them for later runs
function GetBorderRois(resFolder, origNameNoExt, Im, MeasureRoisSuffix)
{
	// clear RoiManager
	roiManager("Reset");

	roi_name = origNameNoExt + MeasureRoisSuffix + ".zip";
	roi_name1 = origNameNoExt + MeasureRoisSuffix + ".roi";

	found = false;
	roiManager("reset");
	if ( matches(existingMeasureRoisMode, "OpenExistingForEditing") || matches(existingMeasureRoisMode, "SkipExisting") )
	{
		// Check for existing ROIs, in Editing mode open Existing Rois
		if (File.exists(resFolder+roi_name))
		{
			found = true;		
			if ( matches(existingMeasureRoisMode, "OpenExistingForEditing")) 
			{
				roiManager("Open", resFolder+roi_name);
				print("GetBorderRois: Open existing Roi File: ", resFolder+roi_name);
			}
			else 
				print("GetBorderRois: Skipping existing Roi File: ", resFolder+roi_name);
		} else if (File.exists(resFolder+roi_name1))
		{
			found = true;		
			if ( matches(existingMeasureRoisMode, "OpenExistingForEditing")) 
			{
				roiManager("Open", resFolder+roi_name1);
				print("GetBorderRois: Open existing Roi File: ", resFolder+roi_name1);
			}
			else 
				print("GetBorderRois: Skipping existing Roi File: ", resFolder+roi_name1);
		}	
		if ( matches(existingMeasureRoisMode, "OpenExistingForEditing") && found)
		{
			roiManager("Show All with labels");
			waitForUser("Check Existing Rois and Edit if needed, \nClick OK when Done");			
		}
	}
	//else // Get New Rois
	if ( !found )
	{
		print(origNameNoExt, ": select New ROIs");
		
		// get User ROIs
		roiTypeText = "Measurment Areas ROIs";
		RoiNamePrefix = "Roi_";
		NumberOfRoi = GetUserRois(Im, roiTypeText, DefaultNumberOfRoi, RoiNamePrefix);
	}
	// Save the Rois
	nRois = roiManager("count");
	if (nRois == 1)
		roiManager("Save", resFolder+roi_name1);	
	if (nRois > 1)
		roiManager("Save", resFolder+roi_name);	
}



//===============================================================================================================
//function numRoi = GetUserRois(Im, roiTypeText, DefaultNumbOfRoi, PrefixText)
function GetUserRois(Im, roiTypeText, DefaultNumbOfRoi, PrefixText)
{
	title = "how many "+ roiTypeText + " do you want?";

	Dialog.create("input dialog");
	Dialog.addMessage(title);
	Dialog.addNumber("ROI:",DefaultNumbOfRoi);
	Dialog.show;
	numRoi= Dialog.getNumber();

	// Loop on number of Rois
	for (r=1; r<=numRoi; r++) {
		selectImage(Im);
		
		run("Select None");
		setTool(RoiSelectionTool);
		waitForUser("Please select  "+roiTypeText + " "+ r + ", Click OK when done");
		roiManager("Add");
		roiManager("Select", roiManager("Count")-1);
		roiManager("Rename", PrefixText+r);
		roiManager("Set Color", DomainColor);
	}	// for numRoi

	run("Select None");
	setTool("hand");		

	return numRoi;
}



//===============================================================================================================
function Initialization()
{
	requires("1.53c");
	run("Check Required Update Sites");

	setBatchMode(false);
	run("Close All");
	print("\\Clear");
	run("Options...", "iterations=1 count=1 black");
	run("Set Measurements...", "area redirect=None decimal=3");
	roiManager("Reset");

	SummaryTable = "SummaryResults.xls";
	AllDetailedTable = "AllDetailedResults.xls";

	CloseTable("Results");
	CloseTable("DetailedResults");
	CloseTable(SummaryTable);
	CloseTable(AllDetailedTable);

	run("Collect Garbage");

	if (batchModeFlag)
	{
		print("Working in Batch Mode, processing without opening images");
		setBatchMode(true);
	}	
	//print("Initialization Done");
	print("Initialization Done, nImages=",nImages);
}

//===============================================================================================================
function CreateAndSaveColorCodeImage(labeledImName, TableName, resFolder, saveName, FtrName, SuffixStr, MinVal, MaxVal, decimalVal, calibrationZoom, LUTName)
{
	selectImage(labeledImName);
	run("Assign Measure to Label", "results="+TableName+" column="+FtrName+" min="+MinVal+" max="+MaxVal);
	run(LUTName);
	run("Calibration Bar...", "location=[Upper Right] fill=White label=Black number=5 decimal="+decimalVal+" font=12 zoom="+calibrationZoom+" overlay");
	run("Flatten");
	saveAs("Tiff", resFolder+saveName+"_"+FtrName+"_Flatten"+SuffixStr+".tif");
}


//===============================================================================================================
function Cleanup()
{
	run("Select None");
	run("Close All");
	run("Clear Results");
	roiManager("reset");
	CloseTable("RingMask_LocThk-intensity-measurements");
	run("Collect Garbage");
			
	CloseTable("DetailedResults");
}


//===============================================================================================================
function CloseTable(TableName)
{
	if (isOpen(TableName))
	{
		selectWindow(TableName);
		run("Close");
	}
}

//===============================================================================================================
//function SaveOverlayImage(imageName, MaskImage, baseSaveName, Suffix, resDir)
function SaveOverlayImage(imageID, MaskImage, baseSaveName, Suffix, resDir, OverlayRoisFlag, RoisColor, MaskColor, CalibrationFlag, decimalVal, calibrationZoom)
{
	// Overlay Domain
	//selectImage(imageName);
	//selectImage(imageID);
	im = imageID;
	selectWindow(imageID);
	if (CalibrationFlag)
	{
		run("Calibration Bar...", "location=[Upper Right] fill=White label=Black number=5 decimal="+decimalVal+" font=12 zoom="+calibrationZoom+" overlay");
		run("Flatten");
		im = getImageID();
	}

	//selectWindow(imageName);

	if (OverlayRoisFlag) 
	{
		roiManager("Deselect");
		//roiManager("Show None");
		roiManager("Set Color", RoisColor);
		roiManager("Set Line Width", 0);
		//roiManager("Show All with labels");
		roiManager("Show All without labels");
	
		// Overlay Mask Area
		run("Flatten");
		im1 = getImageID();
	}
	else
		//im = imageID;
		im1 = im;

	//selectImage(MaskImage);
	selectWindow(MaskImage);
	run("Create Selection");
	selectImage(im1);
	run("Restore Selection");
	run("Properties... ", "  stroke="+MaskColor);

	run("Flatten");
	saveAs("Tiff", resDir+baseSaveName+Suffix);
}



//===============================================================================================================
// Open File_Manual.zip ROI file  if it exist, otherwise open  File.zip
// returns 1 if Manual file exist , otherwise returns 0
function OpenExistingROIFile(baseRoiName)
{
	roiManager("Reset");
	manaulROI = baseRoiName+"_Manual.zip";
	manaulROI1 = baseRoiName+"_Manual.roi";
	origROI = baseRoiName+".zip";
	origROI1 = baseRoiName+".roi";
	
	if (File.exists(manaulROI))
	{
		print("opening:",manaulROI);
		roiManager("Open", manaulROI);
		manualROIFound = 1;
	} else if (File.exists(manaulROI1))
	{
		print("opening:",manaulROI1);
		roiManager("Open", manaulROI1);
		manualROIFound = 1;
	} else // Manual file not found, open original ROI file 
	{
		if (File.exists(origROI))
		{
			print("opening:",origROI);
			roiManager("Open", origROI);
			manualROIFound = 0;
		} else if (File.exists(origROI1))
		{
			print("opening:",origROI1);
			roiManager("Open", origROI1);
			manualROIFound = 0;
		} else {
			print(origROI," Not found");
			exit("You need to Run the macro in *Segment* mode before running again in *Update* mode");
		}
	}
	return manualROIFound;
}



//===============================================================================================================
function setTimeString()
{
	MonthNames = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
	DayNames = newArray("Sun", "Mon","Tue","Wed","Thu","Fri","Sat");
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	TimeString ="Date: "+DayNames[dayOfWeek]+" ";
	if (dayOfMonth<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+dayOfMonth+"-"+MonthNames[month]+"-"+year+", Time: ";
	if (hour<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+hour+":";
	if (minute<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+minute+":";
	if (second<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+second;
}


