function [wave, info] = p_loadAnnotationWaveforms(params,fn,layerName)
%Function will load all waveforms in annotation layer layerName (or in
%filename fn.mat) and save into fn.mat.
%wave and info are cell arrays