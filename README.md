<img src="https://github.com/bastijnvandenboom/PRISM/blob/2fd173dfebb261060eb186d161a2e54ce8fd1e82/PRISM_logo2.png" width="200">

# PRISM: Post-processing ROI Inspection, Sorting, & Merging

Matlab GUI to clean (calcium) imaging datasets of 1- and 2-photon imaging experiments, and cells, axons, and dendrites.

It loads CNMF-E (.mat), CNMF (Caiman) (.mat or .hdf5), and Suite2P (.mat) files. GUI allows the user to manually curate data. After deleting, merging, or both, it saves data as a .mat file for future analyses.

You load a raw session and use the GUI to either delete ROIs (figure 1) or merge ROIs (figure 2). You can include the "bad" ROIs (as defined by the ROI extraction software you used, which are automatically moved to the delete list for easy deleting) and you can use multi-merge (merge more than 2 ROIs simultaneously). Instead of going through all the ROIs, you can click on the spatial overview screen on an ROI which will be visualized (spatially and temporally) and can be deleted and selected to merge with another ROI. As dataset contain more and more ROIs our advice is cleaning data in short rounds (1 or 2 rounds of deleting ROIs, few rounds of merging, final check).

GUI requires to first load data, start GUI, and finally either delete or merge data (depending on which list you are filling). Button appear when you can use it.


# how to use it

Clone/download the code, add to your Matlab path, and run PRISM.

Change settings (Selection and Merge) before loading data:

Selection: allows to filter ROIs
- Spat min: minimum number of pixels (spatial) to include an ROI (0=include all)
- Spat max: maximum number of pixels (spatial) to include an ROI (0=include all)
- SNR min: minimum signal-to-noise (SNR) value to include ROI
- Bad ROIs: move all ROIs identified as unusable by Caiman to delete list (unchecked, don't plot at all)

Merge: filters to identify merge pairs (merge pairs will be in Merge panel)
- Dist thr: find ROIs within this distance (number of pixels)
- Correl thr: minimum correlation between ROIs

The plotting variables can be changed while using the GUI:

Plotting: allows to change visulization while running the GUI
- Cont thr: threshold for the fraction of pixels to include to plot contours or ROIs
- Scale plot: change the scaling of the colorbar
- Cn/Mn: plot correlation image (Cn) or maximum projection (Mn)
- C_raw/C: plot DF/F (C_raw) or denoised signal (C)
- Concat mark: plots repetitive black dotted lines on the temporal traces (useful to indicate recording duration or file size)
- Flip bg: checked will flip the background (in case ROIs don't overlap with background)
- Plot all contours: during GUI, checking this will plot contours of all ROIs

Start GUI
- Load File: manual select file (.hdf5 or .mat)
- Start GUI: start GUI
- restart GUI: restart the GUI (either do all deletes or all merges, then save data, then restart GUI)

Save data
- Delete: delete ROIs in delete list
- Merge: merge ROIs in merge list (make sure no ROI values are repeated)
- Save data: store cleaned data

While visualizing single ROIs in the Delete panel, the Single ROI info will update.

While visualizing ROI pairs in the Merge panel, Merge pair info will update.

Delete panel: allows for single ROI visualization, and adding and removing from delete list. Hit Delete (red button) to actually delete all ROIs that are in the delete list.

Merge panel: go through ROI pairs that are identified by the distance and correlation threshold settings. Use Add pair to add to the merge list. Use the dropdown buttons to manually select 2 ROIs and press Manual add to add to the merge list. Use Find repeats to identify ROIs that occur more than once in the merge list. Use Run multi-merge to automatically find ideal merge pairs. Rerun multi-merge if ROIs are still repeated. Hit Merge (red button) to actually merge ROIs that are in the merge list. 

Workflow: change settings, load file, start gui, work on either delete or merge panel, delete or merge the data, save data, restart gui for a next round of cleaning (to remove backend data).

Make sure there are no repeated ROIs in the merge list before merging. Find them by Find repeats and manually delete them from the merge list, or press Run multi-merge a few times until there are not repeats anymore.


GUI made with Matlab GUIDE but can be run with the latest Matlab version (2026a).

FIGURE 1 - PRISM used to delete ROIs
![PRISM_delete](https://github.com/bastijnvandenboom/PRISM/blob/5422240b65a40e25e658a92837cbdb903b1297b0/PRISM_delete.png)

FIGURE 2 - PRISM used to merge ROI pairs (notice how 3 ROIs will be merged into 1)
![PRISM_merge](https://github.com/bastijnvandenboom/PRISM/blob/7ecf3339892702e255d7b8fae4dc533501c4fdd3/PRISM_merge.png)
