PortalMatlabTools
=================

This repository contains various matlab scripts to manipulate data and annotations on the portal.  

CONTENTS ARE IN DEVELOPMENT. At this stage the scripts should serve more as examples for data analysis within Matlab. We are currently modifying all scripts to take in common input/outputs for a more streamlined pipeline.

Please contact hoameng@upenn.edu with any questions, bugs, suggestions, etc! I would also request any scripts for analysis (detectors, etc) so they can be incorporated into this toolbox.


Utilities
---------
These scripts help get/manipulate data and annotations

*getAllAnnots.m*	- get all annotations from a given dataset and annotation layer

*removeAnnots.m*	- remove specified annotations from IEEGDataset(s)

*uploadAnnotations.m*	- upload annotations to a given layer - can be used in
conjunction with detection algorithms

*viewannots.m*		- matlab GUI to view and vet annotations	

Analysis - TO BE ADDED 
-----------
These scripts were tailored for specific datasets and I am attempting to make them more general and provide sufficient documentation. I would be surprised if any scripts worked smoothly without a need for tweaking. Use at your own risk and frustration.

*spike_keating_v3*

*spike_AR*

*spike_LL*
